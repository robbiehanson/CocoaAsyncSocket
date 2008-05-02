//
//  AsyncSocket.m
//
//  Created by Dustin Voss on Wed Jan 29 2003.
//  This class is in the public domain.
//  If used, I'd appreciate it if you credit me.
//
//  E-Mail: d-j-v@earthlink.net
//

#import "AsyncSocket.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

#pragma mark Declarations

#define READQUEUE_CAPACITY	5			/* Initial capacity. */
#define WRITEQUEUE_CAPACITY 5			/* Initial capacity. */
#define READALL_CHUNKSIZE	256			/* Incremental increase in buffer size. */ 
#define WRITE_CHUNKSIZE		(4*1024)	/* Limit on size of each write pass. */

#define POLL_INTERVAL		1.0			/* Timer to check for overlooked activity. */

NSString *const AsyncSocketException = @"AsyncSocketException";
NSString *const AsyncSocketErrorDomain = @"AsyncSocketErrorDomain";

// This is a mutex lock used by all instances of AsyncSocket, to protect getaddrinfo.
// The man page says it is not thread-safe.
NSString *getaddrinfoLock = @"lock";

enum AsyncSocketFlags
{
	kDidCallConnectDeleg = 0x01,	// If set, connect delegate has been called.
	kDidPassConnectMethod = 0x02,	// If set, disconnection results in delegate call.
	kForbidReadsWrites = 0x04,		// If set, no new reads or writes are allowed.
	kDisconnectSoon = 0x08			// If set, disconnect as soon as nothing is queued.
};

@interface AsyncSocket (Private)
- (BOOL) isSocketConnected;
- (BOOL) areStreamsConnected;
- (NSString *) connectedHost: (CFSocketRef)socket;
- (UInt16) connectedPort: (CFSocketRef)socket;
- (NSString *) localHost: (CFSocketRef)socket;
- (UInt16) localPort: (CFSocketRef)socket;
- (NSString *) addressHost: (CFDataRef)cfaddr;
- (UInt16) addressPort: (CFDataRef)cfaddr;
- (void) doCFCallback:(CFSocketCallBackType)type forSocket:(CFSocketRef)sock withAddress:(NSData *)address withData:(const void *)pData;
- (void) doCFReadStreamCallback:(CFStreamEventType)type forStream:(CFReadStreamRef)stream;
- (void) doCFWriteStreamCallback:(CFStreamEventType)type forStream:(CFWriteStreamRef)stream;
- (void) doAcceptWithSocket:(CFSocketNativeHandle)newSocket;
- (void) doFinishConnectWithError:(SInt32)err;
- (BOOL) createStreamsFromNative:(CFSocketNativeHandle)native error:(NSError **)errPtr;
- (BOOL) createStreamsToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr;
- (NSData *) sockaddrFromString:(NSString *)addrStr port:(UInt16)port error:(NSError **)errPtr;
- (BOOL) setSocketFromStreamsAndReturnError:(NSError **)errPtr;
- (CFSocketRef) createAcceptSocketForAddress:(NSData *)addr error:(NSError **)errPtr;
- (void) attachAcceptSockets;
- (BOOL) attachStreamsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr;
- (BOOL) configureStreamsAndReturnError:(NSError **)errPtr;
- (BOOL) openStreamsAndReturnError:(NSError **)errPtr;
- (void) doStreamOpen;
- (void) closeWithError:(NSError *)err;
- (void) recoverUnreadData;
- (void) emptyQueues;
- (void) close;
- (NSError *) getAbortError;
- (NSError *) getStreamError;
- (NSError *) getSocketError;
- (NSError *) getReadTimeoutError;
- (NSError *) getWriteTimeoutError;
- (NSError *) errorFromCFStreamError:(CFStreamError)err;
- (void) maybeScheduleDisconnect;
- (void) doBytesAvailable;
- (void) completeCurrentRead;
- (void) endCurrentRead;
- (void) scheduleDequeueRead;
- (void) maybeDequeueRead;
- (void) doReadTimeout:(NSTimer *)timer;
- (void) doSendBytes;
- (void) completeCurrentWrite;
- (void) endCurrentWrite;
- (void) scheduleDequeueWrite;
- (void) maybeDequeueWrite;
- (void) doWriteTimeout:(NSTimer *)timer;
- (void) doPoll:(NSTimer *)timer;
@end

static void MyCFSocketCallback (CFSocketRef, CFSocketCallBackType, CFDataRef, const void *, void *);
static void MyCFReadStreamCallback (CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void MyCFWriteStreamCallback (CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -
#pragma mark AsyncReadPacket

@interface AsyncReadPacket : NSObject
{
@public
	NSMutableData *buffer;
	CFIndex bytesDone;
	NSTimeInterval timeout;
	long tag;
	NSData *term;
	BOOL readAllAvailableData;
}
- (id)initWithData:(NSMutableData *)d timeout:(NSTimeInterval)t tag:(long)i readAllAvailable:(BOOL)a terminator:(NSData *)e bufferOffset:(CFIndex)b;
- (void)dealloc;
@end

@implementation AsyncReadPacket
- (id)initWithData:(NSMutableData *)d timeout:(NSTimeInterval)t tag:(long)i readAllAvailable:(BOOL)a terminator:(NSData *)e  bufferOffset:(CFIndex)b
{
	self = [super init];
	buffer = [d retain];
	timeout = t;
	tag = i;
	term = [e copy];
	bytesDone = b;
	readAllAvailableData = a;
	return self;
}
- (void)dealloc
{
	[buffer release];
	[term release];
	[super dealloc];
}
@end


#pragma mark -
#pragma mark AsyncWritePacket

@interface AsyncWritePacket : NSObject
{
	@public
	NSData *buffer;
	CFIndex bytesDone;
	long tag;
	NSTimeInterval timeout;
}
- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(long)i;
- (void)dealloc;
@end

@implementation AsyncWritePacket
- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(long)i;
{
	self = [super init];
	buffer = [d retain];
	timeout = t;
	tag = i;
	bytesDone = 0;
	return self;
}
- (void)dealloc
{
	[buffer release];
	[super dealloc];
}
@end

@implementation AsyncSocket

#pragma mark -
#pragma mark Initialization

- (id) init
{
	return [self initWithDelegate:nil userData:0];
}

- (id) initWithDelegate:(id)delegate
{
	return [self initWithDelegate:delegate userData:0];
}

// Designated initializer.
- (id) initWithDelegate:(id)delegate userData:(long)userData
{
	self = [super init];

	theFlags = 0x00;
	theDelegate = delegate;
	theUserData = userData;
	thePollTimer = nil;

	theSocket = NULL;
	theSource = NULL;
	theSocket6 = NULL;
	theSource6 = NULL;
	theRunLoop = NULL;
	theReadStream = NULL;
	theWriteStream = NULL;

	theReadQueue = [[NSMutableArray alloc] initWithCapacity:READQUEUE_CAPACITY];
	theCurrentRead = nil;
	theReadTimer = nil;
	
	partialReadBuffer = nil;
	
	theWriteQueue = [[NSMutableArray alloc] initWithCapacity:WRITEQUEUE_CAPACITY];
	theCurrentWrite = nil;
	theWriteTimer = nil;

	// Socket context
	NSAssert (sizeof(CFSocketContext) == sizeof(CFStreamClientContext), @"CFSocketContext and CFStreamClientContext aren't the same size anymore. Contact the developer.");
	theContext.version = 0;
	theContext.info = self;
	theContext.retain = nil;
	theContext.release = nil;
	theContext.copyDescription = nil;

	return self;
}

// The socket may been initialized in a connected state and auto-released, so this should close it down cleanly.
- (void) dealloc
{
	[self close];
	[theReadQueue release];
	[theWriteQueue release];
	[NSObject cancelPreviousPerformRequestsWithTarget: theDelegate selector: @selector(onSocketDidDisconnect:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget: self];
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (long) userData
{
	return theUserData;
}

- (void) setUserData:(long)userData
{
	theUserData = userData;
}

- (id) delegate
{
	return theDelegate;
}

- (void) setDelegate:(id)delegate
{
	theDelegate = delegate;
}

- (BOOL) canSafelySetDelegate
{
	return ([theReadQueue count] == 0 && [theWriteQueue count] == 0 && theCurrentRead == nil && theCurrentWrite == nil);
}

- (CFSocketRef) getCFSocket
{
	return theSocket;
}

- (CFReadStreamRef) getCFReadStream
{
	return theReadStream;
}

- (CFWriteStreamRef) getCFWriteStream
{
	return theWriteStream;
}

- (float) progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total
{
	if (!theCurrentRead) return NAN;
	BOOL hasTotal = (theCurrentRead->readAllAvailableData == NO &&
					 theCurrentRead->term == nil);
	CFIndex d = theCurrentRead->bytesDone;
	CFIndex t = hasTotal ? [theCurrentRead->buffer length] : 0;
	if (tag != NULL)   *tag = theCurrentRead->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	float ratio = (float)d/(float)t;
	return isnan(ratio) ? 1.0 : ratio; // 0 of 0 bytes is 100% done.
}

- (float) progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total
{
	if (!theCurrentWrite) return NAN;
	CFIndex d = theCurrentWrite->bytesDone;
	CFIndex t = [theCurrentWrite->buffer length];
	if (tag != NULL)   *tag = theCurrentWrite->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	return (float)d/(float)t;
}

#pragma mark -
#pragma mark Class Methods

// Return line separators.
+ (NSData *) CRLFData
{ return [NSData dataWithBytes:"\x0D\x0A" length:2]; }

+ (NSData *) CRData
{ return [NSData dataWithBytes:"\x0D" length:1]; }

+ (NSData *) LFData
{ return [NSData dataWithBytes:"\x0A" length:1]; }

+ (NSData *) ZeroData
{ return [NSData dataWithBytes:"" length:1]; }

#pragma mark -
#pragma mark Connection

- (BOOL) acceptOnPort:(UInt16)port error:(NSError **)errPtr
{
	return [self acceptOnAddress:nil port:port error:errPtr];
}
	
// Setting up IPv4 and IPv6 accepting sockets.
- (BOOL) acceptOnAddress:(NSString *)hostaddr port:(UInt16)port error:(NSError **)errPtr
{
	if (theDelegate == NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to accept without a delegate. Set a delegate first."];
	
	if (theSocket != NULL || theSocket6 != NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to accept while connected or accepting connections. Disconnect first."];

	// Set up the listen sockaddr structs if needed.

	NSData *address = nil, *address6 = nil;
	if (hostaddr != nil && [hostaddr length] != 0)
	{
		address = [self sockaddrFromString:hostaddr port:port error:errPtr];
		if (!address) return NO;
	}
	else
	{
		// Set up the addresses.
		struct sockaddr_in nativeAddr =
		{
			/*sin_len*/			sizeof(struct sockaddr_in),
			/*sin_family*/		AF_INET,
			/*sin_port*/		htons (port),
			/*sin_addr*/		{ htonl (INADDR_ANY) },
			/*sin_zero*/		{ 0 }
		};
		struct sockaddr_in6 nativeAddr6 =
		{
			/*sin6_len*/		sizeof(struct sockaddr_in6),
			/*sin6_family*/		AF_INET6,
			/*sin6_port*/		htons (port),
			/*sin6_flowinfo*/	0,
			/*sin6_addr*/		in6addr_any,
			/*sin6_scope_id*/	0
		};

		// Wrap the native address structures for CFSocketSetAddress.
		address = [NSData dataWithBytesNoCopy:&nativeAddr length:sizeof(nativeAddr) freeWhenDone:NO];
		address6 = [NSData dataWithBytesNoCopy:&nativeAddr6 length:sizeof(nativeAddr6) freeWhenDone:NO];
	}

	// Create the sockets.

	if (address)
	{
		theSocket = [self createAcceptSocketForAddress:address error:errPtr];
		if (theSocket == NULL) goto Failed;
	}
	
	if (address6)
	{
		theSocket6 = [self createAcceptSocketForAddress:address6 error:errPtr];
		if (theSocket6 == NULL) goto Failed;
	}
	
	[self attachAcceptSockets];
	
	// Set the SO_REUSEADDR flags.

	int reuseOn = 1;
	if (theSocket)	setsockopt (CFSocketGetNative(theSocket), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
	if (theSocket6)	setsockopt (CFSocketGetNative(theSocket6), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));

	// Set the local bindings which causes the sockets to start listening.

	CFSocketError err;
	if (theSocket)
	{
		err = CFSocketSetAddress (theSocket, (CFDataRef)address);
		if (err != kCFSocketSuccess) goto Failed;
	}
	if (theSocket6)
	{
		err = CFSocketSetAddress (theSocket6, (CFDataRef)address6);
		if (err != kCFSocketSuccess) goto Failed;
	}

	theFlags |= kDidPassConnectMethod;
	return YES;
	
Failed:;
	if (errPtr) *errPtr = [self getSocketError];
	return NO;
}

- (BOOL) connectToHost:(NSString*)hostname onPort:(UInt16)port error:(NSError **)errPtr
{
	if (theDelegate == NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to connect without a delegate. Set a delegate first."];

	if (theSocket != NULL || theSocket6 != NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to connect while connected or accepting connections. Disconnect first."];
	
	if (![self createStreamsToHost:hostname onPort:port error:errPtr]) goto Failed;
	if (![self attachStreamsToRunLoop:nil error:errPtr]) goto Failed;
	if (![self configureStreamsAndReturnError:errPtr]) goto Failed;
	if (![self openStreamsAndReturnError:errPtr]) goto Failed;
	
	theFlags |= kDidPassConnectMethod;
	return YES;
	
Failed:;
	[self close];
	return NO;
}

- (void) disconnect
{
	[self close];
}

- (void) disconnectAfterWriting
{
	theFlags |= kForbidReadsWrites;
	theFlags |= kDisconnectSoon;
	[self maybeScheduleDisconnect];
}

#pragma mark -
#pragma mark Accept Impl.

- (NSData *) sockaddrFromString:(NSString *)addrStr port:(UInt16)port error:(NSError **)errPtr
{
	NSData *resultData = nil;
	
	struct addrinfo hints = {0}, *result;
	hints.ai_family	 = PF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	hints.ai_flags	 = AI_NUMERICHOST | AI_PASSIVE;
	
	@synchronized (getaddrinfoLock)
	{
		NSData *addrStrData = [addrStr dataUsingEncoding:NSASCIIStringEncoding
									allowLossyConversion:YES];

		char portStr[] = "65535"; // Reserve space for max port number.
		snprintf(portStr, sizeof(portStr), "%u", port);

		int err = getaddrinfo ([addrStrData bytes], portStr,
							   (const struct addrinfo *)&hints,
							   (struct addrinfo **)&result);
		if (!err)
		{
			resultData = [NSData dataWithBytes:result->ai_addr
										length:result->ai_addrlen];
			freeaddrinfo (result);
		}
		else if (errPtr)
		{
			NSString *errMsg = [NSString stringWithCString: gai_strerror(err)
												  encoding: NSASCIIStringEncoding];

			NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
				errMsg, NSLocalizedDescriptionKey, nil];

			*errPtr = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB"
									   code:err
								   userInfo:info];
		}
	}
	
	return resultData;
}

// Creates the accept sockets. Returns true if either IPv4 or IPv6 is created. If either is missing, an error is returned (even though the method may return true).
- (CFSocketRef) createAcceptSocketForAddress:(NSData *)addr error:(NSError **)errPtr
{
	struct sockaddr *pSockAddr = (struct sockaddr *)[addr bytes];
	int addressFamily = pSockAddr->sa_family;
	
	CFSocketRef socket = CFSocketCreate (kCFAllocatorDefault, addressFamily, SOCK_STREAM, 0, kCFSocketAcceptCallBack, (CFSocketCallBack)&MyCFSocketCallback, &theContext);

	if (socket == NULL && errPtr)
		*errPtr = [self getSocketError];
	
	return socket;
}

// Adds the sockets to the run-loop.
- (void) attachAcceptSockets
{
	theRunLoop = CFRunLoopGetCurrent();
	
	if (theSocket)
	{
		theSource  = CFSocketCreateRunLoopSource (kCFAllocatorDefault, theSocket, 0);
		CFRunLoopAddSource (theRunLoop, theSource, kCFRunLoopDefaultMode);
	}
	
	if (theSocket6)
	{
		theSource6 = CFSocketCreateRunLoopSource (kCFAllocatorDefault, theSocket6, 0);
		CFRunLoopAddSource (theRunLoop, theSource6, kCFRunLoopDefaultMode);
	}
}

// If I can't make the new socket, ignore this event.
- (void) doAcceptWithSocket:(CFSocketNativeHandle)newNative
{
	AsyncSocket *newSocket = [[[AsyncSocket alloc] initWithDelegate:theDelegate] autorelease];
	if (newSocket != nil)
	{
		NSRunLoop *runLoop = nil;
		if ([theDelegate respondsToSelector:@selector(onSocket:didAcceptNewSocket:)])
			[theDelegate onSocket:self didAcceptNewSocket:newSocket];
		
		if ([theDelegate respondsToSelector:@selector(onSocket:wantsRunLoopForNewSocket:)])
			runLoop = [theDelegate onSocket:self wantsRunLoopForNewSocket:newSocket];

		if (![newSocket createStreamsFromNative:newNative error:nil]) goto Failed;
		if (![newSocket attachStreamsToRunLoop:runLoop error:nil]) goto Failed;
		if (![newSocket configureStreamsAndReturnError:nil]) goto Failed;
		if (![newSocket openStreamsAndReturnError:nil]) goto Failed;

		newSocket->theFlags |= kDidPassConnectMethod;
	}
	return;
	
Failed:;
	// No NSError, but errors will still get logged from the above functions.
	[newSocket close];
	return;
}

#pragma mark -
#pragma mark Connect Impl.

// Creates the socket from a native socket.
- (BOOL) createStreamsFromNative:(CFSocketNativeHandle)native error:(NSError **)errPtr
{
	// Create the socket & streams.
	CFStreamCreatePairWithSocket (kCFAllocatorDefault, native, &theReadStream, &theWriteStream);
	if (theReadStream == NULL || theWriteStream == NULL)
	{
		NSError *err = [self getStreamError];
		NSLog (@"AsyncSocket %p couldn't create streams from accepted socket, %@", self, err);
		if (errPtr) *errPtr = err;
		return NO;
	}
	
	return YES;
}

- (BOOL) createStreamsToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr
{
	// Create the socket & streams.
	CFStreamCreatePairWithSocketToHost (kCFAllocatorDefault, (CFStringRef)hostname, port, &theReadStream, &theWriteStream);
	if (theReadStream == NULL || theWriteStream == NULL)
	{
		if (errPtr) *errPtr = [self getStreamError];
		return NO;
	}
	
	return YES;
}

- (BOOL) attachStreamsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr
{
	// Get the CFRunLoop to which the socket should be attached.
	theRunLoop = (runLoop == nil) ? CFRunLoopGetCurrent() : [runLoop getCFRunLoop];

	// Make read stream non-blocking.
	if (!CFReadStreamSetClient (theReadStream,
		kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
		(CFReadStreamClientCallBack)&MyCFReadStreamCallback,
		(CFStreamClientContext *)(&theContext) ))
	{
		NSLog (@"AsyncSocket %p couldn't attach read stream to run-loop,", self);
		goto Failed;
	}
	CFReadStreamScheduleWithRunLoop (theReadStream, theRunLoop, kCFRunLoopDefaultMode);

	// Make write stream non-blocking.
	if (!CFWriteStreamSetClient (theWriteStream,
		kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
		(CFWriteStreamClientCallBack)&MyCFWriteStreamCallback,
		(CFStreamClientContext *)(&theContext) ))
	{
		NSLog (@"AsyncSocket %p couldn't attach write stream to run-loop,", self);
		goto Failed;
	}
	CFWriteStreamScheduleWithRunLoop (theWriteStream, theRunLoop, kCFRunLoopDefaultMode);

	return YES;

Failed:;
	NSError *err = [self getStreamError];
	NSLog (@"%@", err);
	if (errPtr) *errPtr = err;
	return NO;
}

- (BOOL) configureStreamsAndReturnError:(NSError **)errPtr
{
	// Ensure the CF & BSD socket is closed when the streams are closed.
	CFReadStreamSetProperty(theReadStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(theWriteStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	// Call the delegate method for further configuration.
	if ([theDelegate respondsToSelector:@selector(onSocketWillConnect:)])
		if ([theDelegate onSocketWillConnect:self] == NO)
			goto Aborted;
	
	return YES;
	
Aborted:;
	NSError *err = [self getAbortError];
	if (errPtr) *errPtr = err;
	return NO;
};	

- (BOOL) openStreamsAndReturnError:(NSError **)errPtr
{
	if (!CFReadStreamOpen (theReadStream))
	{
		NSLog (@"AsyncSocket %p couldn't open read stream,", self);
		goto Failed;
	}
	
	if (!CFWriteStreamOpen (theWriteStream))
	{
		NSLog (@"AsyncSocket %p couldn't open write stream,", self);
		goto Failed;
	}
	
	return YES;
	
Failed:;
	NSError *err = [self getStreamError];
	NSLog (@"%@", err);
	if (errPtr) *errPtr = err;
	return NO;
}

// Called when read or write streams open. When the socket is connected and both streams are open, consider the AsyncSocket instance to be ready.
- (void) doStreamOpen
{
	NSError *err = nil;
	if ([self areStreamsConnected] && !(theFlags & kDidCallConnectDeleg))
	{
		// Get the socket.
		if (![self setSocketFromStreamsAndReturnError: &err])
		{
			NSLog (@"AsyncSocket %p couldn't get socket from streams, %@. Disconnecting.", self, err);
			[self closeWithError:err];
		}
		
		// Schedule a poll timer to make up for lost ready-to-read/write notifications. This doesn't have to have a tight poll interval, since it is a backup system.
		thePollTimer = [NSTimer scheduledTimerWithTimeInterval:POLL_INTERVAL target:self selector:@selector(doPoll:) userInfo:nil repeats:YES];

		// Call the delegate.
		CFDataRef peer = CFSocketCopyPeerAddress (theSocket);
		theFlags |= kDidCallConnectDeleg;
		if ([theDelegate respondsToSelector:@selector(onSocket:didConnectToHost:port:)])
			[theDelegate onSocket:self
				 didConnectToHost:[self addressHost:peer]
							 port:[self addressPort:peer]];
		CFRelease (peer);
		
		// Immediately deal with any already-queued requests.
		[self maybeDequeueRead];
		[self maybeDequeueWrite];
	}
}

- (BOOL) setSocketFromStreamsAndReturnError:(NSError **)errPtr
{
	CFSocketNativeHandle native;
	CFDataRef nativeProp = CFReadStreamCopyProperty (theReadStream, kCFStreamPropertySocketNativeHandle);
	if (nativeProp == NULL)
	{
		if (errPtr) *errPtr = [self getStreamError];
		goto Failed;
	}
	
	CFDataGetBytes (nativeProp, CFRangeMake(0, CFDataGetLength(nativeProp)), (UInt8 *)&native);
	CFRelease (nativeProp);
	
	theSocket = CFSocketCreateWithNative (kCFAllocatorDefault, native, 0, NULL, NULL);
	if (theSocket == NULL)
	{
		if (errPtr) *errPtr = [self getSocketError];
		goto Failed;
	}
	
	return YES;
	
Failed:;
	return NO;
}	

#pragma mark -
#pragma mark Disconnect Impl.

// Sends error message and disconnects.
- (void) closeWithError:(NSError *)err
{
	if (theFlags & kDidPassConnectMethod)
	{
		// Try to salvage what data we can.
		[self recoverUnreadData];
		
		// Let the delegate know, so it can try to recover if it likes.
		if ([theDelegate respondsToSelector:@selector(onSocket:willDisconnectWithError:)])
			[theDelegate onSocket:self willDisconnectWithError:err];
	}
	[self close];
}

// Prepare partially read data for recovery.
- (void) recoverUnreadData
{
	if (theCurrentRead) [theCurrentRead->buffer setLength: theCurrentRead->bytesDone];
	partialReadBuffer = (theCurrentRead ? [theCurrentRead->buffer copy] : nil);
	[self emptyQueues];
}

- (void) emptyQueues
{
	if (theCurrentRead != nil)	[self endCurrentRead];
	if (theCurrentWrite != nil)	[self endCurrentWrite];
	[theReadQueue removeAllObjects];
	[theWriteQueue removeAllObjects];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueRead) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueWrite) object:nil];
}

// Disconnects. This is called for both error and clean disconnections.
- (void) close
{
	// Stop polling.
	[thePollTimer invalidate];
	thePollTimer = nil;
	
	// Empty queues.
	[self emptyQueues];
	[partialReadBuffer release];
	partialReadBuffer = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(disconnect) object:nil];	

	// Close streams.
	if (theReadStream != NULL)
	{
		CFReadStreamUnscheduleFromRunLoop (theReadStream, theRunLoop, kCFRunLoopDefaultMode);
		CFReadStreamClose (theReadStream);
		CFRelease (theReadStream);
		theReadStream = NULL;
	}
	if (theWriteStream != NULL)
	{
		CFWriteStreamUnscheduleFromRunLoop (theWriteStream, theRunLoop, kCFRunLoopDefaultMode);
		CFWriteStreamClose (theWriteStream);
		CFRelease (theWriteStream);
		theWriteStream = NULL;
	}

	// Close sockets.
	if (theSocket != NULL)
	{
		CFSocketInvalidate (theSocket);
		CFRelease (theSocket);
		theSocket = NULL;
	}
	if (theSocket6 != NULL)
	{
		CFSocketInvalidate (theSocket6);
		CFRelease (theSocket6);
		theSocket6 = NULL;
	}
	if (theSource != NULL)
	{
		CFRunLoopRemoveSource (theRunLoop, theSource, kCFRunLoopDefaultMode);
		CFRelease (theSource);
		theSource = NULL;
	}
	if (theSource6 != NULL)
	{
		CFRunLoopRemoveSource (theRunLoop, theSource6, kCFRunLoopDefaultMode);
		CFRelease (theSource6);
		theSource6 = NULL;
	}
	theRunLoop = NULL;

	// If the client has passed the connect/accept method, then the connection has at least begun. Notify delegate that it is now ending.
	if (theFlags & kDidPassConnectMethod)
	{
		// Delay notification to give him freedom to release without returning here and core-dumping.
		if ([theDelegate respondsToSelector: @selector(onSocketDidDisconnect:)])
			[theDelegate performSelector:@selector(onSocketDidDisconnect:) withObject:self afterDelay:0];
	}

	// Clear flags.
	theFlags = 0x00;
}

#pragma mark -
#pragma mark Errors

- (NSError *) getStreamError
{
	CFStreamError err;
	if (theReadStream != NULL)
	{
		err = CFReadStreamGetError (theReadStream);
		if (err.error != 0) return [self errorFromCFStreamError: err];
	}
	
	if (theWriteStream != NULL)
	{
		err = CFWriteStreamGetError (theWriteStream);
		if (err.error != 0) return [self errorFromCFStreamError: err];
	}
	
	return nil;
}

// Unfortunately, CFSocket offers no feedback on its errors.
- (NSError *) getSocketError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue
		(@"AsyncSocketCFSocketError", @"AsyncSocket", [NSBundle mainBundle],
		 @"General CFSocket error", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  errMsg, NSLocalizedDescriptionKey, nil];
	
	return [NSError errorWithDomain: AsyncSocketErrorDomain
							   code: AsyncSocketCFSocketError
						   userInfo: info];
}

- (NSError *) getAbortError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue
		(@"AsyncSocketCanceledError", @"AsyncSocket", [NSBundle mainBundle],
		 @"Connection canceled", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  errMsg, NSLocalizedDescriptionKey, nil];
	
	return [NSError errorWithDomain: AsyncSocketErrorDomain
							   code: AsyncSocketCanceledError
						   userInfo: info];
}

- (NSError *) getReadTimeoutError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue
		(@"AsyncSocketReadTimeoutError", @"AsyncSocket", [NSBundle mainBundle],
		 @"Read operation timed out", nil);	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  errMsg, NSLocalizedDescriptionKey, nil];
	
	return [NSError errorWithDomain: AsyncSocketErrorDomain
							   code: AsyncSocketReadTimeoutError
						   userInfo: info];
}

- (NSError *) getWriteTimeoutError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue
		(@"AsyncSocketWriteTimeoutError", @"AsyncSocket", [NSBundle mainBundle],
		 @"Write operation timed out", nil);	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  errMsg, NSLocalizedDescriptionKey, nil];
	
	return [NSError errorWithDomain: AsyncSocketErrorDomain
							   code: AsyncSocketWriteTimeoutError
						   userInfo: info];
}

- (NSError *) errorFromCFStreamError:(CFStreamError)err
{
	if (err.domain == 0 && err.error == 0) return nil;
	
	// Can't use switch; these constants aren't int literals.
	NSString *domain = @"CFStreamError (unlisted domain)";
	NSString *message = nil;
	if      (err.domain == kCFStreamErrorDomainPOSIX)
		domain = NSPOSIXErrorDomain;
	else if (err.domain == kCFStreamErrorDomainMacOSStatus)
		domain = NSOSStatusErrorDomain;
	else if (err.domain == kCFStreamErrorDomainMach)
		domain = NSMachErrorDomain;
	else if (err.domain == kCFStreamErrorDomainNetDB)
	{
		domain = @"kCFStreamErrorDomainNetDB";
		message = [NSString stringWithCString: gai_strerror(err.error)
									 encoding: NSASCIIStringEncoding];
	}
	else if (err.domain == kCFStreamErrorDomainNetServices)
		domain = @"kCFStreamErrorDomainNetServices";
	else if (err.domain == kCFStreamErrorDomainSOCKS)
		domain = @"kCFStreamErrorDomainSOCKS";
	else if (err.domain == kCFStreamErrorDomainSystemConfiguration)
		domain = @"kCFStreamErrorDomainSystemConfiguration";
	else if (err.domain == kCFStreamErrorDomainSSL)
		domain = @"kCFStreamErrorDomainSSL";
	
	NSDictionary *info = nil;
	if (message != nil)
	{
		info = [NSDictionary dictionaryWithObjectsAndKeys:
				message, NSLocalizedDescriptionKey, nil];
	}
	return [NSError errorWithDomain:domain code:err.error userInfo:info];
}

#pragma mark -
#pragma mark Diagnostics

- (BOOL) isConnected
{
	return [self isSocketConnected] && [self areStreamsConnected];
}

- (NSString *) connectedHost
{
	return [self connectedHost:theSocket];
}

- (UInt16) connectedPort
{
	return [self connectedPort:theSocket];
}

- (NSString *) localHost
{
	return [self localHost:theSocket];
}

- (UInt16) localPort
{
	return [self localPort:theSocket];
}

- (NSString *) connectedHost: (CFSocketRef)socket
{
	if (socket == NULL) return nil;
	CFDataRef peeraddr;
	NSString *peerstr = nil;

	if (socket && (peeraddr = CFSocketCopyPeerAddress (socket)))
	{
		peerstr = [self addressHost:peeraddr];
		CFRelease (peeraddr);
	}

	return peerstr;
}

- (UInt16) connectedPort: (CFSocketRef)socket
{
	if (socket == NULL) return 0;
	CFDataRef peeraddr;
	UInt16 peerport = 0;

	if (socket && (peeraddr = CFSocketCopyPeerAddress (socket)))
	{
		peerport = [self addressPort:peeraddr];
		CFRelease (peeraddr);
	}

	return peerport;
}

- (NSString *) localHost: (CFSocketRef)socket
{
	if (socket == NULL) return nil;
	CFDataRef selfaddr;
	NSString *selfstr = nil;

	if (socket && (selfaddr = CFSocketCopyAddress (socket)))
	{
		selfstr = [self addressHost:selfaddr];
		CFRelease (selfaddr);
	}

	return selfstr;
}

- (UInt16) localPort: (CFSocketRef) socket
{
	if (socket == NULL) return 0;
	CFDataRef selfaddr;
	UInt16 selfport = 0;

	if (socket && (selfaddr = CFSocketCopyAddress (socket)))
	{
		selfport = [self addressPort:selfaddr];
		CFRelease (selfaddr);
	}

	return selfport;
}

- (BOOL) isSocketConnected
{
	if (theSocket == NULL && theSocket6 == NULL) return NO;
	return CFSocketIsValid (theSocket) || CFSocketIsValid (theSocket6);
}

- (BOOL) areStreamsConnected
{
	CFStreamStatus s;

	if (theReadStream != NULL)
	{
		s = CFReadStreamGetStatus (theReadStream);
		if ( !(s == kCFStreamStatusOpen || s == kCFStreamStatusReading || s == kCFStreamStatusError) )
			return NO;
	}
	else return NO;

	if (theWriteStream != NULL)
	{
		s = CFWriteStreamGetStatus (theWriteStream);
		if ( !(s == kCFStreamStatusOpen || s == kCFStreamStatusWriting || s == kCFStreamStatusError) )
			return NO;
	}
	else return NO;

	return YES;
}

- (NSString *) addressHost: (CFDataRef)cfaddr
{
	if (cfaddr == NULL) return nil;
	char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
	struct sockaddr *pSockAddr = (struct sockaddr *) CFDataGetBytePtr (cfaddr);
	struct sockaddr_in  *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
	struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;

	const void *pAddr = (pSockAddr->sa_family == AF_INET) ?
							(void *)(&(pSockAddrV4->sin_addr)) :
							(void *)(&(pSockAddrV6->sin6_addr));

	const char *pStr = inet_ntop (pSockAddr->sa_family, pAddr, addrBuf, sizeof(addrBuf));
	if (pStr == NULL) [NSException raise: NSInternalInconsistencyException
								  format: @"Cannot convert address to string."];

	return [NSString stringWithCString:pStr encoding:NSASCIIStringEncoding];
}

- (UInt16) addressPort: (CFDataRef)cfaddr
{
	struct sockaddr_in *pAddr = (struct sockaddr_in *) CFDataGetBytePtr (cfaddr);
	return ntohs (pAddr->sin_port);
}

- (NSString *) description
{
	static const char *statstr[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	CFStreamStatus rs = (theReadStream != NULL) ? CFReadStreamGetStatus (theReadStream) : 0;
	CFStreamStatus ws = (theWriteStream != NULL) ? CFWriteStreamGetStatus (theWriteStream) : 0;
	NSString *peerstr, *selfstr;
	CFDataRef peeraddr, selfaddr = NULL, selfaddr6 = NULL;

	if (theSocket && (peeraddr = CFSocketCopyPeerAddress (theSocket)))
	{
		peerstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:peeraddr], [self addressPort:peeraddr]];
		CFRelease (peeraddr);
		peeraddr = NULL;
	}
	else peerstr = @"nowhere";

	if (theSocket)  selfaddr  = CFSocketCopyAddress (theSocket);
	if (theSocket6) selfaddr6 = CFSocketCopyAddress (theSocket6);
	if (theSocket || theSocket6)
	{
		if (theSocket6)
		{
			selfstr = [NSString stringWithFormat: @"%@/%@ %u", [self addressHost:selfaddr], [self addressHost:selfaddr6], [self addressPort:selfaddr]];
		}
		else
		{
			selfstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:selfaddr], [self addressPort:selfaddr]];
		}

		if (selfaddr)  CFRelease (selfaddr);
		if (selfaddr6) CFRelease (selfaddr6);
		selfaddr = NULL;
		selfaddr6 = NULL;
	}
	else selfstr = @"nowhere";
	
	NSMutableString *ms = [[NSMutableString alloc] init];
	[ms appendString: [NSString stringWithFormat:@"<AsyncSocket %p #%u: Socket %p", self, [self hash], theSocket]];
	[ms appendString: [NSString stringWithFormat:@" local %@ remote %@ ", selfstr, peerstr ]];
	[ms appendString: [NSString stringWithFormat:@"has queued %d reads %d writes, ", [theReadQueue count], [theWriteQueue count] ]];

	if (theCurrentRead == nil)
		[ms appendString: @"no current read, "];
	else
	{
		int percentDone;
		if ([theCurrentRead->buffer length] != 0)
			percentDone = (float)theCurrentRead->bytesDone /
						  (float)[theCurrentRead->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently read %u bytes (%d%% done), ",
			[theCurrentRead->buffer length],
			theCurrentRead->bytesDone ? percentDone : 0]];
	}

	if (theCurrentWrite == nil)
		[ms appendString: @"no current write, "];
	else
	{
		int percentDone;
		if ([theCurrentWrite->buffer length] != 0)
			percentDone = (float)theCurrentWrite->bytesDone /
						  (float)[theCurrentWrite->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently written %u (%d%%), ",
			[theCurrentWrite->buffer length],
			theCurrentWrite->bytesDone ? percentDone : 0]];
	}
	
	[ms appendString: [NSString stringWithFormat:@"read stream %p %s, write stream %p %s", theReadStream, statstr [rs], theWriteStream, statstr [ws] ]];
	if (theFlags & kDisconnectSoon) [ms appendString: @", will disconnect soon"];
	if (![self isConnected]) [ms appendString: @", not connected"];

	 [ms appendString: @">"];

	return [ms autorelease];
}

#pragma mark -
#pragma mark Polling

- (void) doPoll:(NSTimer *)timer
{
	[self doBytesAvailable];
	[self doSendBytes];
}

#pragma mark -
#pragma mark Reading

- (void) readDataToLength:(CFIndex)length withTimeout:(NSTimeInterval)timeout tag:(long)tag;
{
	if (length == 0) return;
	if (theFlags & kForbidReadsWrites) return;
	
	NSMutableData *buffer = [[NSMutableData alloc] initWithLength:length];
	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithData:buffer timeout:timeout tag:tag readAllAvailable:NO terminator:nil bufferOffset:0];

	[theReadQueue addObject:packet];
	[self maybeDequeueRead];

	[packet release];
	[buffer release];
}

- (void) readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if (data == nil || [data length] == 0) return;
	if (theFlags & kForbidReadsWrites) return;
	
	NSMutableData *buffer = [[NSMutableData alloc] initWithLength:0];
	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithData:buffer timeout:timeout tag:tag readAllAvailable:NO terminator:data bufferOffset:0];

	[theReadQueue addObject:packet];
	[self maybeDequeueRead];

	[packet release];
	[buffer release];
}

- (void) readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if (theFlags & kForbidReadsWrites) return;
	
	// partialReadBuffer is used when recovering data from a broken connection.
	NSMutableData *buffer;
	if (partialReadBuffer)  buffer = [partialReadBuffer mutableCopy];
	else					buffer = [[NSMutableData alloc] initWithLength:0];

	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithData:buffer timeout:timeout tag:tag readAllAvailable:YES terminator:nil bufferOffset:[buffer length]];
	
	[theReadQueue addObject:packet];
	[self maybeDequeueRead];
	
	[packet release];
	[buffer release];
}

// Puts a maybeDequeueRead on the run loop. An assumption here is that selectors will be performed consecutively within their priority.
- (void) scheduleDequeueRead
{
	[self performSelector:@selector(maybeDequeueRead) withObject:nil afterDelay:0];
}

// Start a new read.
- (void) maybeDequeueRead
{
	if (theCurrentRead == nil && [theReadQueue count] != 0 && theReadStream != NULL)
	{
		// Get new current read AsyncReadPacket.
		AsyncReadPacket *newPacket = [theReadQueue objectAtIndex:0];
		theCurrentRead = [newPacket retain];
		[theReadQueue removeObjectAtIndex:0];

		// Start time-out timer.
		if (theCurrentRead->timeout >= 0.0)
		{
			theReadTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentRead->timeout target:self selector:@selector(doReadTimeout:) userInfo:nil repeats:NO];
		}

		// Immediately read, if possible.
		[self doBytesAvailable];
	}
}

// Reads several bytes into the buffer.
- (void) doBytesAvailable
{
	if (theCurrentRead != nil && theReadStream != NULL)
	{
		BOOL error = NO, done = NO;
		while (!done && !error && CFReadStreamHasBytesAvailable (theReadStream))
		{
			// If reading all available data, make sure there's room in the packet buffer.
			if (theCurrentRead->readAllAvailableData == YES)
				[theCurrentRead->buffer increaseLengthBy:READALL_CHUNKSIZE];

			// If reading until data, just do one byte.
			if (theCurrentRead->term != nil)
				[theCurrentRead->buffer increaseLengthBy:1];
			
			// Number of bytes to read is space left in packet buffer.
			CFIndex bytesToRead = [theCurrentRead->buffer length] - theCurrentRead->bytesDone;

			// Read stuff into start of unfilled packet buffer space.
			UInt8 *packetbuf = (UInt8 *)( [theCurrentRead->buffer mutableBytes] + theCurrentRead->bytesDone );
			CFIndex bytesRead = CFReadStreamRead (theReadStream, packetbuf, bytesToRead);

			// Check results.
			if (bytesRead < 0)
			{
				bytesRead = 0;
				error = YES;
			}

			// Is packet done?
			theCurrentRead->bytesDone += bytesRead;
			if (theCurrentRead->readAllAvailableData != YES)
			{
				if (theCurrentRead->term != nil)
				{
					// Search for the terminating sequence in the buffer.
					int termlen = [theCurrentRead->term length];
					if (theCurrentRead->bytesDone >= termlen)
					{
						const void *buf = [theCurrentRead->buffer bytes] + (theCurrentRead->bytesDone - termlen);
						const void *seq = [theCurrentRead->term bytes];
						done = (memcmp (buf, seq, termlen) == 0);
					}
					else done = NO;
				}
				else
				{
					// Done when (sized) buffer is full.
					done = ([theCurrentRead->buffer length] == theCurrentRead->bytesDone);
				}
			}
			// else readAllAvailable doesn't end until all readable is read.
		}

		if (theCurrentRead->readAllAvailableData && theCurrentRead->bytesDone > 0)
			done = YES;	// Ran out of bytes, so the "read-all-data" type packet is done.

		if (done)
		{
			[self completeCurrentRead];
			if (!error) [self scheduleDequeueRead];
		}

		if (error)
		{
			CFStreamError err = CFReadStreamGetError (theReadStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			return;
		}
	}
}

// Ends current read and calls delegate.
- (void) completeCurrentRead
{
	NSAssert (theCurrentRead, @"Trying to complete current read when there is no current read.");
	[theCurrentRead->buffer setLength:theCurrentRead->bytesDone];
	if ([theDelegate respondsToSelector:@selector(onSocket:didReadData:withTag:)])
	{
		[theDelegate onSocket:self didReadData:theCurrentRead->buffer withTag:theCurrentRead->tag];
	}
	if (theCurrentRead != nil) [self endCurrentRead]; // Caller may have disconnected.
}

// Ends current read.
- (void) endCurrentRead
{
	NSAssert (theCurrentRead, @"Trying to end current read when there is no current read.");
	[theReadTimer invalidate];
	theReadTimer = nil;
	[theCurrentRead release];
	theCurrentRead = nil;
}

- (void) doReadTimeout:(NSTimer *)timer
{
	if (timer != theReadTimer) return; // Old timer. Ignore it.
	if (theCurrentRead != nil)
	{
		// Send what we got.
		[self endCurrentRead];
	}
	[self closeWithError: [self getReadTimeoutError]];
}

#pragma mark -
#pragma mark Writing

- (void) writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
{
	if (data == nil || [data length] == 0) return;
	if (theFlags & kForbidReadsWrites) return;
	
	AsyncWritePacket *packet = [[AsyncWritePacket alloc] initWithData:data timeout:timeout tag:tag];

	[theWriteQueue addObject:packet];
	[self maybeDequeueWrite];

	[packet release];
}

- (void) scheduleDequeueWrite
{
	[self performSelector:@selector(maybeDequeueWrite) withObject:nil afterDelay:0];
}

// Start a new write.
- (void) maybeDequeueWrite
{
	if (theCurrentWrite == nil && [theWriteQueue count] != 0 && theWriteStream != NULL)
	{
		// Get new current write AsyncWritePacket.
		AsyncWritePacket *newPacket = [theWriteQueue objectAtIndex:0];
		theCurrentWrite = [newPacket retain];
		[theWriteQueue removeObjectAtIndex:0];
		
		// Start time-out timer.
		if (theCurrentWrite->timeout >= 0.0)
		{
			theWriteTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentWrite->timeout target:self selector:@selector(doWriteTimeout:) userInfo:nil repeats:NO];
		}

		// Immediately write, if possible.
		[self doSendBytes];
	}
}

- (void) doSendBytes
{
	if (theCurrentWrite != nil && theWriteStream != NULL)
	{
		BOOL done = NO, error = NO;
		while (!done && !error && CFWriteStreamCanAcceptBytes (theWriteStream))
		{
			// Figure out what to write.
			CFIndex bytesRemaining = [theCurrentWrite->buffer length] - theCurrentWrite->bytesDone;
			CFIndex bytesToWrite = (bytesRemaining < WRITE_CHUNKSIZE) ? bytesRemaining : WRITE_CHUNKSIZE;
			UInt8 *writestart = (UInt8 *)([theCurrentWrite->buffer bytes] + theCurrentWrite->bytesDone);

			// Write.
			CFIndex bytesWritten = CFWriteStreamWrite (theWriteStream, writestart, bytesToWrite);

			// Check results.
			if (bytesWritten < 0)
			{
				bytesWritten = 0;
				error = YES;
			}

			// Is packet done?
			theCurrentWrite->bytesDone += bytesWritten;
			done = ([theCurrentWrite->buffer length] == theCurrentWrite->bytesDone);
		}

		if (done)
		{
			[self completeCurrentWrite];
			if (!error) [self scheduleDequeueWrite];
		}

		if (error)
		{
			CFStreamError err = CFWriteStreamGetError (theWriteStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			return;
		}
	}
}

// Ends current write and calls delegate.
- (void) completeCurrentWrite
{
	NSAssert (theCurrentWrite, @"Trying to complete current write when there is no current write.");
	if ([theDelegate respondsToSelector:@selector(onSocket:didWriteDataWithTag:)])
	{
		int tag = theCurrentWrite->tag;
		[theDelegate onSocket:self didWriteDataWithTag:tag];
	}
	if (theCurrentWrite != nil) [self endCurrentWrite]; // Caller may have disconnected.
}

// Ends current write.
- (void) endCurrentWrite
{
	NSAssert (theCurrentWrite, @"Trying to complete current write when there is no current write.");
	[theWriteTimer invalidate];
	theWriteTimer = nil;
	[theCurrentWrite release];
	theCurrentWrite = nil;
	[self maybeScheduleDisconnect];
}

// Checks to see if all writes have been completed for disconnectAfterWriting.
- (void) maybeScheduleDisconnect
{
	if (theFlags & kDisconnectSoon)
		if ([theWriteQueue count] == 0 && theCurrentWrite == nil)
			[self performSelector:@selector(disconnect) withObject:nil afterDelay:0];
}

- (void) doWriteTimeout:(NSTimer *)timer
{
	if (timer != theWriteTimer) return; // Old timer. Ignore it.
	if (theCurrentWrite != nil)
	{
		// Send what we got.
		[self completeCurrentWrite];
	}
	[self closeWithError: [self getWriteTimeoutError]];
}

#pragma mark -
#pragma mark CF Callbacks

- (void) doCFSocketCallback:(CFSocketCallBackType)type forSocket:(CFSocketRef)sock withAddress:(NSData *)address withData:(const void *)pData
{
	NSParameterAssert ((sock == theSocket) || (sock == theSocket6));
	switch (type)
	{
		case kCFSocketAcceptCallBack:
			[self doAcceptWithSocket: *((CFSocketNativeHandle *)pData)];
			break;
		default:
			NSLog (@"AsyncSocket %p received unexpected CFSocketCallBackType %d.", self, type);
			break;
	}
}

- (void) doCFReadStreamCallback:(CFStreamEventType)type forStream:(CFReadStreamRef)stream
{
	CFStreamError err;
	switch (type)
	{
		case kCFStreamEventOpenCompleted:
			[self doStreamOpen];
			break;
		case kCFStreamEventHasBytesAvailable:
			[self doBytesAvailable];
			break;
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
			err = CFReadStreamGetError (theReadStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			break;
		default:
			NSLog (@"AsyncSocket %p received unexpected CFReadStream callback, CFStreamEventType %d.", self, type);
	}
}

- (void) doCFWriteStreamCallback:(CFStreamEventType)type forStream:(CFWriteStreamRef)stream
{
	CFStreamError err;
	switch (type)
	{
		case kCFStreamEventOpenCompleted:
			[self doStreamOpen];
			break;
		case kCFStreamEventCanAcceptBytes:
			[self doSendBytes];
			break;
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
			err = CFWriteStreamGetError (theWriteStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			break;
		default:
			NSLog (@"AsyncSocket %p received unexpected CFWriteStream callback, CFStreamEventType %d.", self, type);
	}
}

// This is the callback we set up for CFSocket.
static void MyCFSocketCallback (CFSocketRef sref, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo)
{
	AsyncSocket *socket = (AsyncSocket *)pInfo;
	[socket doCFSocketCallback:type forSocket:sref withAddress:(NSData *)address withData:pData];
}

// This is the callback we set up for CFReadStream.
static void MyCFReadStreamCallback (CFReadStreamRef stream, CFStreamEventType type, void *pInfo)
{
	AsyncSocket *socket = (AsyncSocket *)pInfo;
	[socket doCFReadStreamCallback:type forStream:stream];
}

// This is the callback we set up for CFWriteStream.
static void MyCFWriteStreamCallback (CFWriteStreamRef stream, CFStreamEventType type, void *pInfo)
{
	AsyncSocket *socket = (AsyncSocket *)pInfo;
	[socket doCFWriteStreamCallback:type forStream:stream];
}

@end
