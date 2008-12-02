//
//  AsyncUdpSocket.m
//  
//  This class is in the public domain.
//  Originally created by Robbie Hanson on Wed Oct 01 2008.
//  Updated and maintained by Deusty Designs and the Mac development community.
//
//  http://code.google.com/p/cocoaasyncsocket/
//

#import "AsyncUdpSocket.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <netdb.h>

#if TARGET_OS_IPHONE
// Note: You may need to add the CFNetwork Framework to your project
#import <CFNetwork/CFNetwork.h>
#endif


#define SENDQUEUE_CAPACITY	  5   // Initial capacity
#define RECEIVEQUEUE_CAPACITY 5   // Initial capacity

#define DEFAULT_MAX_RECEIVE_BUFFER_SIZE 9216

NSString *const AsyncUdpSocketException = @"AsyncUdpSocketException";
NSString *const AsyncUdpSocketErrorDomain = @"AsyncUdpSocketErrorDomain";

// This is a mutex lock used by all instances of AsyncSocket, to protect getaddrinfo.
// The man page says it is not thread-safe. (As of Mac OS X 10.4.7, and possibly earlier)
static NSString *getaddrinfoLock = @"lock";

enum AsyncUdpSocketFlags
{
	kDidBind            = 1 << 0,  // If set, bind has been called.
	kDidConnect         = 1 << 1,  // If set, connect has been called.
	kForbidSendReceive  = 1 << 2,  // If set, no new send or receive operations are allowed to be queued.
	kCloseAfterSends    = 1 << 3,  // If set, close as soon as no more sends are queued.
	kCloseAfterReceives = 1 << 4,  // If set, close as soon as no more receives are queued.
	kDidClose           = 1 << 5,  // If set, the socket has been closed, and should not be used anymore.
	kFlipFlop           = 1 << 7,  // Used to alternate between IPv4 and IPv6 sockets.
};

@interface AsyncUdpSocket (Private)

// Utilities
- (NSString *)addressHost4:(struct sockaddr_in *)pSockaddr4;
- (NSString *)addressHost6:(struct sockaddr_in6 *)pSockaddr6;
- (NSString *)addressHost:(struct sockaddr *)pSockaddr;

// Disconnect Implementation
- (void)emptyQueues;
- (void)closeSocket4;
- (void)closeSocket6;
- (void)maybeScheduleClose;

// Errors
- (NSError *)getErrnoError;
- (NSError *)getSocketError;
- (NSError *)getIPv4UnavailableError;
- (NSError *)getIPv6UnavailableError;
- (NSError *)getSendTimeoutError;
- (NSError *)getReceiveTimeoutError;

// Diagnostics
- (NSString *)connectedHost:(CFSocketRef)socket;
- (UInt16)connectedPort:(CFSocketRef)socket;
- (NSString *)localHost:(CFSocketRef)socket;
- (UInt16)localPort:(CFSocketRef)socket;

// Sending
- (BOOL)canAcceptBytes:(CFSocketRef)sockRef;
- (void)scheduleDequeueSend;
- (void)maybeDequeueSend;
- (void)doSend;
- (void)completeCurrentSend;
- (void)failCurrentSend:(NSError *)error;
- (void)endCurrentSend;
- (void)doSendTimeout:(NSTimer *)timer;

// Receiving
- (BOOL)hasBytesAvailable:(CFSocketRef)sockRef;
- (void)scheduleDequeueReceive;
- (void)maybeDequeueReceive;
- (void)doReceive4;
- (void)doReceive6;
- (void)doReceive:(CFSocketRef)sockRef;
- (BOOL)maybeCompleteCurrentReceive;
- (void)failCurrentReceive:(NSError *)error;
- (void)endCurrentReceive;
- (void)doReceiveTimeout:(NSTimer *)timer;

@end

static void MyCFSocketCallback(CFSocketRef, CFSocketCallBackType, CFDataRef, const void *, void *);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The AsyncSendPacket encompasses the instructions for a single send/write.
**/
@interface AsyncSendPacket : NSObject
{
@public
	NSData *buffer;
	NSData *address;
	NSTimeInterval timeout;
	long tag;
}
- (id)initWithData:(NSData *)d address:(NSData *)a timeout:(NSTimeInterval)t tag:(long)i;
@end

@implementation AsyncSendPacket

- (id)initWithData:(NSData *)d address:(NSData *)a timeout:(NSTimeInterval)t tag:(long)i;
{
	if(self = [super init])
	{
		buffer = [d retain];
		address = [a retain];
		timeout = t;
		tag = i;
	}
	return self;
}

- (void)dealloc
{
	[buffer release];
	[address release];
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The AsyncReceivePacket encompasses the instructions for a single receive/read.
**/
@interface AsyncReceivePacket : NSObject
{
@public
	NSTimeInterval timeout;
	long tag;
	NSMutableData *buffer;
	NSString *host;
	UInt16 port;
}
- (id)initWithTimeout:(NSTimeInterval)t tag:(long)i;
@end

@implementation AsyncReceivePacket

- (id)initWithTimeout:(NSTimeInterval)t tag:(long)i
{
	if(self = [super init])
	{
		timeout = t;
		tag = i;
		
		buffer = nil;
		host = nil;
		port = 0;
	}
	return self;
}

- (void)dealloc
{
	[buffer release];
	[host release];
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation AsyncUdpSocket

- (id)initWithDelegate:(id)delegate userData:(long)userData enableIPv4:(BOOL)enableIPv4 enableIPv6:(BOOL)enableIPv6
{
	if(self = [super init])
	{
		theFlags = 0;
		theDelegate = delegate;
		theUserData = userData;
		maxReceiveBufferSize = DEFAULT_MAX_RECEIVE_BUFFER_SIZE;
		
		theSendQueue = [[NSMutableArray alloc] initWithCapacity:SENDQUEUE_CAPACITY];
		theCurrentSend = nil;
		theSendTimer = nil;
		
		theReceiveQueue = [[NSMutableArray alloc] initWithCapacity:RECEIVEQUEUE_CAPACITY];
		theCurrentReceive = nil;
		theReceiveTimer = nil;
		
		// Socket context
		theContext.version = 0;
		theContext.info = self;
		theContext.retain = nil;
		theContext.release = nil;
		theContext.copyDescription = nil;
		
		// Create the sockets
		theSocket4 = NULL;
		theSocket6 = NULL;
		
		if(enableIPv4)
		{
			theSocket4 = CFSocketCreate(kCFAllocatorDefault,
										PF_INET,
										SOCK_DGRAM,
										IPPROTO_UDP,
										kCFSocketReadCallBack | kCFSocketWriteCallBack,
										(CFSocketCallBack)&MyCFSocketCallback,
										&theContext);
		}
		if(enableIPv6)
		{
			theSocket6 = CFSocketCreate(kCFAllocatorDefault,
										PF_INET6,
										SOCK_DGRAM,
										IPPROTO_UDP,
										kCFSocketReadCallBack | kCFSocketWriteCallBack,
										(CFSocketCallBack)&MyCFSocketCallback,
										&theContext);
		}
		
		// Disable continuous callbacks for read and write.
		// If we don't do this, the socket(s) will just sit there firing read callbacks
		// at us hundreds of times a second if we don't immediately read the available data.
		if(theSocket4)
		{
			CFSocketSetSocketFlags(theSocket4, kCFSocketCloseOnInvalidate);
		}
		if(theSocket6)
		{
			CFSocketSetSocketFlags(theSocket6, kCFSocketCloseOnInvalidate);
		}
		
		// Get the CFRunLoop to which the socket should be attached.
		theRunLoop = CFRunLoopGetCurrent();
		
		// Attach the sockets to the run loop
		
		if(theSocket4)
		{
			theSource4  = CFSocketCreateRunLoopSource(kCFAllocatorDefault, theSocket4, 0);
			CFRunLoopAddSource(theRunLoop, theSource4, kCFRunLoopDefaultMode);
		}
		
		if(theSocket6)
		{
			theSource6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, theSocket6, 0);
			CFRunLoopAddSource(theRunLoop, theSource6, kCFRunLoopDefaultMode);
		}
		
		cachedLocalPort = 0;
		cachedConnectedPort = 0;
	}
	return self;
}

- (id)init
{
	return [self initWithDelegate:nil userData:0 enableIPv4:YES enableIPv6:YES];
}

- (id)initWithDelegate:(id)delegate
{
	return [self initWithDelegate:delegate userData:0 enableIPv4:YES enableIPv6:YES];
}

- (id)initWithDelegate:(id)delegate userData:(long)userData
{
	return [self initWithDelegate:delegate userData:userData enableIPv4:YES enableIPv6:YES];
}

- (id)initIPv4
{
	return [self initWithDelegate:nil userData:0 enableIPv4:YES enableIPv6:NO];
}

- (id)initIPv6
{
	return [self initWithDelegate:nil userData:0 enableIPv4:NO enableIPv6:YES];
}

- (void) dealloc
{
	[self close];
	[theSendQueue release];
	[theReceiveQueue release];
	[cachedLocalHost release];
	[cachedConnectedHost release];
	[NSObject cancelPreviousPerformRequestsWithTarget:theDelegate selector:@selector(onUdpSocketDidClose:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)delegate
{
	return theDelegate;
}

- (void)setDelegate:(id)delegate
{
	theDelegate = delegate;
}

- (long)userData
{
	return theUserData;
}

- (void)setUserData:(long)userData
{
	theUserData = userData;
}

- (UInt32)maxReceiveBufferSize
{
	return maxReceiveBufferSize;
}

- (void)setMaxReceiveBufferSize:(UInt32)max
{
	maxReceiveBufferSize = max;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Attempts to convert the given host/port into and IPv6 and/or IPv6 data structure.
 * The data structure is of type sockaddr_in for IPv4 and sockaddr_in6 for IPv6.
 *
 * Returns zero on success, or one of the error codes listed in gai_strerror if an error occurs (as per getaddrinfo).
**/
- (int)convertForBindHost:(NSString *)host
					 port:(UInt16)port
			 intoAddress4:(NSData **)address4
				 address6:(NSData **)address6
{
	if(host == nil || ([host length] == 0))
	{
		// Use ANY address
		struct sockaddr_in nativeAddr;
		nativeAddr.sin_len         = sizeof(struct sockaddr_in);
		nativeAddr.sin_family      = AF_INET;
		nativeAddr.sin_port        = htons(port);
		nativeAddr.sin_addr.s_addr = htonl(INADDR_ANY);
		memset(&(nativeAddr.sin_zero), 0, sizeof(nativeAddr.sin_zero));
		
		struct sockaddr_in6 nativeAddr6;
		nativeAddr6.sin6_len       = sizeof(struct sockaddr_in6);
		nativeAddr6.sin6_family    = AF_INET6;
		nativeAddr6.sin6_port      = htons(port);
		nativeAddr6.sin6_flowinfo  = 0;
		nativeAddr6.sin6_addr      = in6addr_any;
		nativeAddr6.sin6_scope_id  = 0;
		
		// Wrap the native address structures for CFSocketSetAddress.
		if(address4) *address4 = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
		if(address6) *address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
		
		return 0;
	}
	else if([host isEqualToString:@"localhost"] || [host isEqualToString:@"loopback"])
	{
		// Note: getaddrinfo("localhost",...) fails on 10.5.3
		
		// Use LOOPBACK address
		struct sockaddr_in nativeAddr;
		nativeAddr.sin_len         = sizeof(struct sockaddr_in);
		nativeAddr.sin_family      = AF_INET;
		nativeAddr.sin_port        = htons(port);
		nativeAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
		memset(&(nativeAddr.sin_zero), 0, sizeof(nativeAddr.sin_zero));
		
		struct sockaddr_in6 nativeAddr6;
		nativeAddr6.sin6_len       = sizeof(struct sockaddr_in6);
		nativeAddr6.sin6_family    = AF_INET6;
		nativeAddr6.sin6_port      = htons(port);
		nativeAddr6.sin6_flowinfo  = 0;
		nativeAddr6.sin6_addr      = in6addr_loopback;
		nativeAddr6.sin6_scope_id  = 0;
		
		// Wrap the native address structures for CFSocketSetAddress.
		if(address4) *address4 = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
		if(address6) *address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
		
		return 0;
	}
	else
	{
		NSString *portStr = [NSString stringWithFormat:@"%hu", port];
		
		@synchronized (getaddrinfoLock)
		{
			struct addrinfo hints, *res, *res0;
			
			memset(&hints, 0, sizeof(hints));
			hints.ai_family   = PF_UNSPEC;
			hints.ai_socktype = SOCK_DGRAM;
			hints.ai_protocol = IPPROTO_UDP;
			hints.ai_flags    = AI_PASSIVE;
			
			int error = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res0);
			
			if(error) return error;
			
			for(res = res0; res; res = res->ai_next)
			{
				if(address4 && !*address4 && (res->ai_family == AF_INET))
				{
					// Found IPv4 address
					// Wrap the native address structures for CFSocketSetAddress.
					if(address4) *address4 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
				else if(address6 && !*address6 && (res->ai_family == AF_INET6))
				{
					// Found IPv6 address
					// Wrap the native address structures for CFSocketSetAddress.
					if(address6) *address6 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
			}
			freeaddrinfo(res0);
		}
		
		return 0;
	}
}

/**
 * Attempts to convert the given host/port into and IPv6 and/or IPv6 data structure.
 * The data structure is of type sockaddr_in for IPv4 and sockaddr_in6 for IPv6.
 *
 * Returns zero on success, or one of the error codes listed in gai_strerror if an error occurs (as per getaddrinfo).
**/
- (int)convertForSendHost:(NSString *)host
					  port:(UInt16)port
			  intoAddress4:(NSData **)address4
				  address6:(NSData **)address6
{
	if(host == nil || ([host length] == 0))
	{
		// We're not binding, so what are we supposed to do with this?
		return EAI_NONAME;
	}
	else if([host isEqualToString:@"localhost"] || [host isEqualToString:@"loopback"])
	{
		// Note: getaddrinfo("localhost",...) fails on 10.5.3
		
		// Use LOOPBACK address
		struct sockaddr_in nativeAddr;
		nativeAddr.sin_len         = sizeof(struct sockaddr_in);
		nativeAddr.sin_family      = AF_INET;
		nativeAddr.sin_port        = htons(port);
		nativeAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
		memset(&(nativeAddr.sin_zero), 0, sizeof(nativeAddr.sin_zero));
		
		struct sockaddr_in6 nativeAddr6;
		nativeAddr6.sin6_len       = sizeof(struct sockaddr_in6);
		nativeAddr6.sin6_family    = AF_INET6;
		nativeAddr6.sin6_port      = htons(port);
		nativeAddr6.sin6_flowinfo  = 0;
		nativeAddr6.sin6_addr      = in6addr_loopback;
		nativeAddr6.sin6_scope_id  = 0;
		
		// Wrap the native address structures for CFSocketSetAddress.
		if(address4) *address4 = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
		if(address6) *address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
		
		return 0;
	}
	else
	{
		NSString *portStr = [NSString stringWithFormat:@"%hu", port];
		
		@synchronized (getaddrinfoLock)
		{
			struct addrinfo hints, *res, *res0;
			
			memset(&hints, 0, sizeof(hints));
			hints.ai_family   = PF_UNSPEC;
			hints.ai_socktype = SOCK_DGRAM;
			hints.ai_protocol = IPPROTO_UDP;
			// No passive flag on a send or connect
			
			int error = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res0);
			
			if(error) return error;
			
			for(res = res0; res; res = res->ai_next)
			{
				if(address4 && !*address4 && (res->ai_family == AF_INET))
				{
					// Found IPv4 address
					// Wrap the native address structures for CFSocketSetAddress.
					if(address4) *address4 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
				else if(address6 && !*address6 && (res->ai_family == AF_INET6))
				{
					// Found IPv6 address
					// Wrap the native address structures for CFSocketSetAddress.
					if(address6) *address6 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
			}
			freeaddrinfo(res0);
		}
		
		return 0;
	}
}

- (NSString *)addressHost4:(struct sockaddr_in *)pSockaddr4
{
	char addrBuf[INET_ADDRSTRLEN];
	
	if(inet_ntop(AF_INET, &pSockaddr4->sin_addr, addrBuf, sizeof(addrBuf)) == NULL)
	{
		[NSException raise:NSInternalInconsistencyException format:@"Cannot convert address to string."];
	}
	
	return [NSString stringWithCString:addrBuf encoding:NSASCIIStringEncoding];
}

- (NSString *)addressHost6:(struct sockaddr_in6 *)pSockaddr6
{
	char addrBuf[INET6_ADDRSTRLEN];
	
	if(inet_ntop(AF_INET6, &pSockaddr6->sin6_addr, addrBuf, sizeof(addrBuf)) == NULL)
	{
		[NSException raise:NSInternalInconsistencyException format:@"Cannot convert address to string."];
	}
	
	return [NSString stringWithCString:addrBuf encoding:NSASCIIStringEncoding];
}

- (NSString *)addressHost:(struct sockaddr *)pSockaddr
{
	if(pSockaddr->sa_family == AF_INET)
	{
		return [self addressHost4:(struct sockaddr_in *)pSockaddr];
	}
	else
	{
		return [self addressHost6:(struct sockaddr_in6 *)pSockaddr];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Socket Implementation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Binds the underlying socket(s) to the given port.
 * The socket(s) will be able to receive data on any interface.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
**/
- (BOOL)bindToPort:(UInt16)port error:(NSError **)errPtr
{
	return [self bindToAddress:nil port:port error:errPtr];
}

/**
 * Binds the underlying socket(s) to the given address and port.
 * The sockets(s) will be able to receive data only on the given interface.
 * 
 * To receive data on any interface, pass nil or "".
 * To receive data only on the loopback interface, pass "localhost" or "loopback".
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
**/
- (BOOL)bindToAddress:(NSString *)host port:(UInt16)port error:(NSError **)errPtr
{
	if(theFlags & kDidClose)
	{
		NSString *message = @"The socket is closed.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	if(theFlags & kDidBind)
	{
		NSString *message = @"Cannot bind a socket more than once.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	if(theFlags & kDidConnect)
	{
		NSString *message = @"Cannot bind after connecting. If needed, bind first, then connect.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	
	// Convert the given host/port into native address structures for CFSocketSetAddress
	NSData *address4 = nil, *address6 = nil;
	
	int error = [self convertForBindHost:host port:port intoAddress4:&address4 address6:&address6];
	if(error)
	{
		if(errPtr)
		{
			NSString *errMsg = [NSString stringWithCString:gai_strerror(error) encoding:NSASCIIStringEncoding];
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB" code:error userInfo:info];
		}
		return NO;
	}
	
	NSAssert((address4 || address6), @"address4 and address6 are nil");
	
	// Set the SO_REUSEADDR flags
	
	int reuseOn = 1;
	if (theSocket4)	setsockopt(CFSocketGetNative(theSocket4), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
	if (theSocket6)	setsockopt(CFSocketGetNative(theSocket6), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
	
	// Bind the sockets
	
	if(address4)
	{
		if(theSocket4)
		{
			CFSocketError error = CFSocketSetAddress(theSocket4, (CFDataRef)address4);
			if(error != kCFSocketSuccess)
			{
				if(errPtr) *errPtr = [self getSocketError];
				return NO;
			}
			
			if(!address6)
			{
				// Using IPv4 only
				[self closeSocket6];
			}
		}
		else if(!address6)
		{
			if(errPtr) *errPtr = [self getIPv4UnavailableError];
			return NO;
		}
	}
	
	if(address6)
	{
		// Note: The iPhone doesn't currently support IPv6
		
		if(theSocket6)
		{
			CFSocketError error = CFSocketSetAddress(theSocket6, (CFDataRef)address6);
			if(error != kCFSocketSuccess)
			{
				if(errPtr) *errPtr = [self getSocketError];
				return NO;
			}
			
			if(!address4)
			{
				// Using IPv6 only
				[self closeSocket4];
			}
		}
		else if(!address4)
		{
			if(errPtr) *errPtr = [self getIPv6UnavailableError];
			return NO;
		}
	}
	
	theFlags |= kDidBind;
	return YES;
}

/**
 * Connects the underlying UDP socket to the given host and port.
 * If an IPv4 address is resolved, the IPv4 socket is connected, and the IPv6 socket is invalidated and released.
 * If an IPv6 address is resolved, the IPv6 socket is connected, and the IPv4 socket is invalidated and released.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
**/
- (BOOL)connectToHost:(NSString *)host onPort:(UInt16)port error:(NSError **)errPtr
{
	if(theFlags & kDidClose)
	{
		NSString *message = @"The socket is closed.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	if(theFlags & kDidConnect)
	{
		NSString *message = @"Cannot connect a socket more than once.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	
	// Convert the given host/port into native address structures for CFSocketSetAddress
	NSData *address4 = nil, *address6 = nil;
	
	int error = [self convertForSendHost:host port:port intoAddress4:&address4 address6:&address6];
	if(error)
	{
		if(errPtr)
		{
			NSString *errMsg = [NSString stringWithCString:gai_strerror(error) encoding:NSASCIIStringEncoding];
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB" code:error userInfo:info];
		}
		return NO;
	}
	
	NSAssert((address4 || address6), @"address4 and address6 are nil");
	
	// We only want to connect via a single interface.
	// IPv4 is currently preferred, but this may change in the future.
	
	BOOL done = NO;
	
	if(address4)
	{
		if(theSocket4)
		{
			CFSocketError sockErr = CFSocketConnectToAddress(theSocket4, (CFDataRef)address4, (CFTimeInterval)0.0);
			if(sockErr != kCFSocketSuccess)
			{
				if(errPtr) *errPtr = [self getSocketError];
				return NO;
			}
			done = YES;
			
			// We're connected to an IPv4 address, so no need for the IPv6 socket
			[self closeSocket6];
		}
		else if(!address6)
		{
			if(errPtr) *errPtr = [self getIPv4UnavailableError];
			return NO;
		}
	}
	
	if(!done && address6)
	{
		// Note: The iPhone doesn't currently support IPv6
		
		if(theSocket6)
		{
			CFSocketError sockErr = CFSocketConnectToAddress(theSocket6, (CFDataRef)address6, (CFTimeInterval)0.0);
			if(sockErr != kCFSocketSuccess)
			{
				if(errPtr) *errPtr = [self getSocketError];
				return NO;
			}
			
			// We're connected to an IPv6 address, so no need for the IPv4 socket
			[self closeSocket4];
		}
		else
		{
			if(errPtr) *errPtr = [self getIPv6UnavailableError];
			return NO;
		}
	}
	
	theFlags |= kDidConnect;
	return YES;
}

/**
 * Connects the underlying UDP socket to the remote address.
 * If the address is an IPv4 address, the IPv4 socket is connected, and the IPv6 socket is invalidated and released.
 * If the address is an IPv6 address, the IPv6 socket is connected, and the IPv4 socket is invalidated and released.
 * 
 * The address is a native address structure, as may be returned from API's such as Bonjour.
 * An address may be created manually by simply wrapping a sockaddr_in or sockaddr_in6 in an NSData object.
 * 
 * On success, returns YES.
 * Otherwise returns NO, and sets errPtr. If you don't care about the error, you can pass nil for errPtr.
**/
- (BOOL)connectToAddress:(NSData *)remoteAddr error:(NSError **)errPtr
{
	if(theFlags & kDidClose)
	{
		NSString *message = @"The socket is closed.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	if(theFlags & kDidConnect)
	{
		NSString *message = @"Cannot connect a socket more than once.";
		[NSException raise:AsyncUdpSocketException format:message];
	}
	
	// Is remoteAddr an IPv4 address?
	if([remoteAddr length] == sizeof(struct sockaddr_in))
	{
		if(theSocket4)
		{
			CFSocketError error = CFSocketConnectToAddress(theSocket4, (CFDataRef)remoteAddr, (CFTimeInterval)0.0);
			if(error != kCFSocketSuccess)
			{
				if(errPtr) *errPtr = [self getSocketError];
				return NO;
			}
			
			theFlags |= kDidConnect;
			return YES;
		}
		else
		{
			if(errPtr) *errPtr = [self getIPv4UnavailableError];
			return NO;
		}
	}
	
	// Is remoteAddr an IPv6 address?
	if([remoteAddr length] == sizeof(struct sockaddr_in6))
	{
		if(theSocket6)
		{
			CFSocketError error = CFSocketConnectToAddress(theSocket6, (CFDataRef)remoteAddr, (CFTimeInterval)0.0);
			if(error != kCFSocketSuccess)
			{
				if(errPtr) *errPtr = [self getSocketError];
				return NO;
			}
			
			theFlags |= kDidConnect;
			return YES;
		}
		else
		{
			if(errPtr) *errPtr = [self getIPv6UnavailableError];
			return NO;
		}
	}
	
	// The remoteAddr was invalid
	if(errPtr)
	{
		NSString *errMsg = @"remoteAddr parameter is not a valid address";
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		
		*errPtr = [NSError errorWithDomain:AsyncUdpSocketErrorDomain
									  code:AsyncUdpSocketBadParameter
								  userInfo:info];
	}
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Disconnect Implementation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)emptyQueues
{
	if (theCurrentSend)     [self endCurrentSend];
	if (theCurrentReceive)  [self endCurrentReceive];
	[theSendQueue removeAllObjects];
	[theReceiveQueue removeAllObjects];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueSend) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueReceive) object:nil];
}

- (void)closeSocket4
{
	if (theSocket4 != NULL)
	{
		CFSocketInvalidate(theSocket4);
		CFRelease(theSocket4);
		theSocket4 = NULL;
	}
	if (theSource4 != NULL)
	{
		CFRunLoopRemoveSource(theRunLoop, theSource4, kCFRunLoopDefaultMode);
		CFRelease(theSource4);
		theSource4 = NULL;
	}
}

- (void)closeSocket6
{
	if (theSocket6 != NULL)
	{
		CFSocketInvalidate(theSocket6);
		CFRelease(theSocket6);
		theSocket6 = NULL;
	}
	if (theSource6 != NULL)
	{
		CFRunLoopRemoveSource(theRunLoop, theSource6, kCFRunLoopDefaultMode);
		CFRelease(theSource6);
		theSource6 = NULL;
	}
}

- (void)close
{
	[self emptyQueues];
	[self closeSocket4];
	[self closeSocket6];
	
	theRunLoop = NULL;
	
	// Delay notification to give user freedom to release without returning here and core-dumping.
	if ([theDelegate respondsToSelector: @selector(onUdpSocketDidClose:)])
	{
		[theDelegate performSelector:@selector(onUdpSocketDidClose:) withObject:self afterDelay:0];
	}
	
	theFlags |= kDidClose;
}

- (void)closeAfterSending
{
	if(theFlags & kDidClose) return;
	
	theFlags |= kForbidSendReceive;
	theFlags |= kCloseAfterSends;
	[self maybeScheduleClose];
}

- (void)closeAfterReceiving
{
	if(theFlags & kDidClose) return;
	
	theFlags |= kForbidSendReceive;
	theFlags |= kCloseAfterReceives;
	[self maybeScheduleClose];
}

- (void)maybeScheduleClose
{
	if(theFlags & kCloseAfterSends)
	{
		if(([theSendQueue count] == 0) && (theCurrentSend == nil))
		{
			[self performSelector:@selector(close) withObject:nil afterDelay:0];
		}
	}
	if(theFlags & kCloseAfterReceives)
	{
		if(([theReceiveQueue count] == 0) && (theCurrentReceive == nil))
		{
			[self performSelector:@selector(close) withObject:nil afterDelay:0];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Errors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns a standard error object for the current errno value.
 * Errno is used for low-level BSD socket errors.
**/
- (NSError *)getErrnoError
{
	NSString *errorMsg = [NSString stringWithUTF8String:strerror(errno)];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
}

/**
 * Returns a standard error message for a CFSocket error.
 * Unfortunately, CFSocket offers no feedback on its errors.
**/
- (NSError *)getSocketError
{
	NSString *errMsg = @"General CFSocket error";
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncUdpSocketErrorDomain code:AsyncUdpSocketCFSocketError userInfo:info];
}

- (NSError *)getIPv4UnavailableError
{
	NSString *errMsg = @"IPv4 is unavailable due to binding/connecting using IPv6 only";
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncUdpSocketErrorDomain code:AsyncUdpSocketIPv4Unavailable userInfo:info];
}

- (NSError *)getIPv6UnavailableError
{
	NSString *errMsg = @"IPv6 is unavailable due to binding/connecting using IPv4 only or is not supported on this platform";
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncUdpSocketErrorDomain code:AsyncUdpSocketIPv6Unavailable userInfo:info];
}

- (NSError *)getSendTimeoutError
{
	NSString *errMsg = @"Send operation timed out";
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncUdpSocketErrorDomain code:AsyncUdpSocketSendTimeoutError userInfo:info];
}
- (NSError *)getReceiveTimeoutError
{
	NSString *errMsg = @"Receive operation timed out";
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncUdpSocketErrorDomain code:AsyncUdpSocketReceiveTimeoutError userInfo:info];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Diagnostics
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)localHost
{
	if(cachedLocalHost) return cachedLocalHost;
	
	if(theSocket4)
		return [self localHost:theSocket4];
	else
		return [self localHost:theSocket6];
}

- (UInt16)localPort
{
	if(cachedLocalPort > 0) return cachedLocalPort;
	
	if(theSocket4)
		return [self localPort:theSocket4];
	else
		return [self localPort:theSocket6];
}

- (NSString *)connectedHost
{
	if(cachedConnectedHost) return cachedConnectedHost;
	
	if(theSocket4)
		return [self connectedHost:theSocket4];
	else
		return [self connectedHost:theSocket6];
}

- (UInt16)connectedPort
{
	if(cachedConnectedPort > 0) return cachedConnectedPort;
	
	if(theSocket4)
		return [self connectedPort:theSocket4];
	else
		return [self connectedPort:theSocket6];
}

- (NSString *)localHost:(CFSocketRef)socket
{
	if(socket == NULL) return nil;
	
	// Unfortunately we can't use CFSocketCopyAddress.
	// The CFSocket library caches the address the first time you call CFSocketCopyAddress.
	// So if this is called prior to binding/connecting/sending, it won't be updated again when necessary,
	// and will continue to return the old value of the socket address.
	
	NSString *result = nil;
	
	if(socket == theSocket4)
	{
		struct sockaddr_in sockaddr4;
		socklen_t sockaddr4len = sizeof(sockaddr4);
		
		if(getsockname(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr4, &sockaddr4len) < 0)
		{
			return nil;
		}
		result = [self addressHost4:&sockaddr4];
	}
	else
	{
		struct sockaddr_in6 sockaddr6;
		socklen_t sockaddr6len = sizeof(sockaddr6);
		
		if(getsockname(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr6, &sockaddr6len) < 0)
		{
			return nil;
		}
		result = [self addressHost6:&sockaddr6];
	}
	
	if(theFlags & kDidBind)
	{
		[cachedLocalHost release];
		cachedLocalHost = [result copy];
	}
	
	return result;
}

- (UInt16)localPort:(CFSocketRef)socket
{
	if(socket == NULL) return 0;
	
	// Unfortunately we can't use CFSocketCopyAddress.
	// The CFSocket library caches the address the first time you call CFSocketCopyAddress.
	// So if this is called prior to binding/connecting/sending, it won't be updated again when necessary,
	// and will continue to return the old value of the socket address.
	
	UInt16 result = 0;
	
	if(socket == theSocket4)
	{
		struct sockaddr_in sockaddr4;
		socklen_t sockaddr4len = sizeof(sockaddr4);
		
		if(getsockname(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr4, &sockaddr4len) < 0)
		{
			return 0;
		}
		result = ntohs(sockaddr4.sin_port);
	}
	else
	{
		struct sockaddr_in6 sockaddr6;
		socklen_t sockaddr6len = sizeof(sockaddr6);
		
		if(getsockname(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr6, &sockaddr6len) < 0)
		{
			return 0;
		}
		result = ntohs(sockaddr6.sin6_port);
	}
	
	if(theFlags & kDidBind)
	{
		cachedLocalPort = result;
	}
	
	return result;
}

- (NSString *)connectedHost:(CFSocketRef)socket
{
	if(socket == NULL) return nil;
	
	// Unfortunately we can't use CFSocketCopyPeerAddress.
	// The CFSocket library caches the address the first time you call CFSocketCopyPeerAddress.
	// So if this is called prior to binding/connecting/sending, it may not be updated again when necessary,
	// and will continue to return the old value of the socket peer address.
	
	NSString *result = nil;
	
	if(socket == theSocket4)
	{
		struct sockaddr_in sockaddr4;
		socklen_t sockaddr4len = sizeof(sockaddr4);
		
		if(getpeername(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr4, &sockaddr4len) < 0)
		{
			return nil;
		}
		result = [self addressHost4:&sockaddr4];
	}
	else
	{
		struct sockaddr_in6 sockaddr6;
		socklen_t sockaddr6len = sizeof(sockaddr6);
		
		if(getpeername(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr6, &sockaddr6len) < 0)
		{
			return nil;
		}
		result = [self addressHost6:&sockaddr6];
	}
	
	if(theFlags & kDidConnect)
	{
		[cachedConnectedHost release];
		cachedConnectedHost = [result copy];
	}
	
	return result;
}

- (UInt16)connectedPort:(CFSocketRef)socket
{
	if(socket == NULL) return 0;
	
	// Unfortunately we can't use CFSocketCopyPeerAddress.
	// The CFSocket library caches the address the first time you call CFSocketCopyPeerAddress.
	// So if this is called prior to binding/connecting/sending, it may not be updated again when necessary,
	// and will continue to return the old value of the socket peer address.
	
	UInt16 result = 0;
	
	if(socket == theSocket4)
	{
		struct sockaddr_in sockaddr4;
		socklen_t sockaddr4len = sizeof(sockaddr4);
		
		if(getpeername(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr4, &sockaddr4len) < 0)
		{
			return 0;
		}
		result = ntohs(sockaddr4.sin_port);
	}
	else
	{
		struct sockaddr_in6 sockaddr6;
		socklen_t sockaddr6len = sizeof(sockaddr6);
		
		if(getpeername(CFSocketGetNative(socket), (struct sockaddr *)&sockaddr6, &sockaddr6len) < 0)
		{
			return 0;
		}
		result = ntohs(sockaddr6.sin6_port);
	}
	
	if(theFlags & kDidConnect)
	{
		cachedConnectedPort = result;
	}
	
	return result;
}

- (BOOL)isConnected
{
	return (((theFlags & kDidConnect) != 0) && ((theFlags & kDidClose) == 0));
}

- (BOOL)isConnectedToHost:(NSString *)host port:(UInt16)port
{
	return [[self connectedHost] isEqualToString:host] && ([self connectedPort] == port);
}

- (BOOL)isClosed
{
	return (theFlags & kDidClose);
}

- (BOOL)isIPv4
{
	return (theSocket4 != NULL);
}

- (BOOL)isIPv6
{
	return (theSocket6 != NULL);
}

- (unsigned int)maximumTransmissionUnit
{
	CFSocketNativeHandle theNativeSocket;
	if(theSocket4)
		theNativeSocket = CFSocketGetNative(theSocket4);
	else if(theSocket6)
		theNativeSocket = CFSocketGetNative(theSocket6);
	else
		return 0;
	
	if(theNativeSocket == 0)
	{
		return 0;
	}
	
	struct ifreq ifr;
	bzero(&ifr, sizeof(ifr));
	
	if(if_indextoname(theNativeSocket, ifr.ifr_name) == NULL)
	{
		return 0;
	}
	
	if(ioctl(theNativeSocket, SIOCGIFMTU, &ifr) >= 0)
	{
		return ifr.ifr_mtu;
	}
	
	return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sending
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)sendData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if((data == nil) || ([data length] == 0)) return NO;
	if(theFlags & kForbidSendReceive) return NO;
	if(theFlags & kDidClose) return NO;
	
	// This method is only for connected sockets
	if(![self isConnected]) return NO;
	
	AsyncSendPacket *packet = [[AsyncSendPacket alloc] initWithData:data address:nil timeout:timeout tag:tag];
	
	[theSendQueue addObject:packet];
	[self scheduleDequeueSend];
	
	[packet release];
	return YES;
}

- (BOOL)sendData:(NSData *)data toHost:(NSString *)host port:(UInt16)port withTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if((data == nil) || ([data length] == 0)) return NO;
	if(theFlags & kForbidSendReceive) return NO;
	if(theFlags & kDidClose) return NO;
	
	// This method is only for non-connected sockets
	if([self isConnected]) return NO;
	
	NSData *address4 = nil, *address6 = nil;
	[self convertForSendHost:host port:port intoAddress4:&address4 address6:&address6];
	
	AsyncSendPacket *packet = nil;
	
	if(address4 && theSocket4)
		packet = [[AsyncSendPacket alloc] initWithData:data address:address4 timeout:timeout tag:tag];
	else if(address6 && theSocket6)
		packet = [[AsyncSendPacket alloc] initWithData:data address:address6 timeout:timeout tag:tag];
	else
		return NO;
	
	[theSendQueue addObject:packet];
	[self scheduleDequeueSend];
	
	[packet release];
	return YES;
}

- (BOOL)sendData:(NSData *)data toAddress:(NSData *)remoteAddr withTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if((data == nil) || ([data length] == 0)) return NO;
	if(theFlags & kForbidSendReceive) return NO;
	if(theFlags & kDidClose) return NO;
	
	// This method is only for non-connected sockets
	if([self isConnected]) return NO;
	
	if([remoteAddr length] == sizeof(struct sockaddr_in) && !theSocket4)
		return NO;
	
	if([remoteAddr length] == sizeof(struct sockaddr_in6) && !theSocket6)
		return NO;
	
	AsyncSendPacket *packet = [[AsyncSendPacket alloc] initWithData:data address:remoteAddr timeout:timeout tag:tag];
	
	[theSendQueue addObject:packet];
	[self scheduleDequeueSend];
	
	[packet release];
	return YES;
}

- (BOOL)canAcceptBytes:(CFSocketRef)sockRef
{
	CFSocketNativeHandle theNativeSocket = CFSocketGetNative(sockRef);
	
	if(theNativeSocket == 0)
	{
		NSLog(@"Error - Could not get CFSocketNativeHandle from CFSocketRef");
		return NO;
	} 
	
	fd_set fds;
	FD_ZERO(&fds);
	FD_SET(theNativeSocket, &fds);
	
	struct timeval timeout;
	timeout.tv_sec = 0;
	timeout.tv_usec = 0;
	
	return select(FD_SETSIZE, NULL, &fds, NULL, &timeout) > 0;
}

- (CFSocketRef)socketForPacket:(AsyncSendPacket *)packet
{
	if(!theSocket4)
		return theSocket6;
	if(!theSocket6)
		return theSocket4;
	
	return ([packet->address length] == sizeof(struct sockaddr_in)) ? theSocket4 : theSocket6;
}

/**
 * Puts a maybeDequeueSend on the run loop.
**/
- (void)scheduleDequeueSend
{
	[self performSelector:@selector(maybeDequeueSend) withObject:nil afterDelay:0];
}

/**
 * This method starts a new send, if needed.
 * It is called when a user requests a send.
**/
- (void)maybeDequeueSend
{
	if(theCurrentSend == nil)
	{
		if([theSendQueue count] > 0)
		{
			// Get next send packet
			AsyncSendPacket *newPacket = [theSendQueue objectAtIndex:0];
			theCurrentSend = [newPacket retain];
			[theSendQueue removeObjectAtIndex:0];
			
			// Start time-out timer.
			if(theCurrentSend->timeout >= 0.0)
			{
				theSendTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentSend->timeout
																target:self 
															  selector:@selector(doSendTimeout:)
															  userInfo:nil
															   repeats:NO];
			}
			
			// Immediately send, if possible.
			[self doSend];
		}
		else if(theFlags & kCloseAfterSends)
		{
			[self close];
		}
	}
}

/**
 * This method is called when a new read is taken from the read queue or when new data becomes available on the stream.
**/
- (void)doSend
{
	if(theCurrentSend != nil)
	{
		CFSocketRef theSocket = [self socketForPacket:theCurrentSend];
		
		if([self canAcceptBytes:theSocket])
		{
			int result;
			CFSocketNativeHandle theNativeSocket = CFSocketGetNative(theSocket);
			
			const void *buf  = [theCurrentSend->buffer bytes];
			unsigned bufSize = [theCurrentSend->buffer length];
			
			if([self isConnected])
			{
				result = send(theNativeSocket, buf, bufSize, 0);
			}
			else
			{
				const void *dst  = [theCurrentSend->address bytes];
				unsigned dstSize = [theCurrentSend->address length];
				
				result = sendto(theNativeSocket, buf, bufSize, 0, dst, dstSize);
			}
			
			if(result < 0)
			{
				[self failCurrentSend:[self getErrnoError]];
			}
			else
			{
				// If it wasn't bound before, it's bound now
				theFlags |= kDidBind;
				
				[self completeCurrentSend];
			}
			
			[self scheduleDequeueSend];
		}
		else
		{
			// Request notification when the socket is ready to send more data
			CFSocketEnableCallBacks(theSocket, kCFSocketReadCallBack | kCFSocketWriteCallBack);
		}
	}
}

- (void)completeCurrentSend
{
	NSAssert (theCurrentSend, @"Trying to complete current send when there is no current send.");
	
	if ([theDelegate respondsToSelector:@selector(onUdpSocket:didSendDataWithTag:)])
	{
		[theDelegate onUdpSocket:self didSendDataWithTag:theCurrentSend->tag];
	}
	
	if (theCurrentSend != nil) [self endCurrentSend]; // Caller may have disconnected.
}

- (void)failCurrentSend:(NSError *)error
{
	NSAssert (theCurrentSend, @"Trying to fail current send when there is no current send.");
	
	if ([theDelegate respondsToSelector:@selector(onUdpSocket:didNotSendDataWithTag:dueToError:)])
	{
		[theDelegate onUdpSocket:self didNotSendDataWithTag:theCurrentSend->tag dueToError:error];
	}
	
	if (theCurrentSend != nil) [self endCurrentSend]; // Caller may have disconnected.
}

/**
 * Ends the current send, and all associated variables such as the send timer.
**/
- (void)endCurrentSend
{
	NSAssert (theCurrentSend, @"Trying to end current send when there is no current send.");
	
	[theSendTimer invalidate];
	theSendTimer = nil;
	
	[theCurrentSend release];
	theCurrentSend = nil;
}

- (void)doSendTimeout:(NSTimer *)timer
{
	if (timer != theSendTimer) return; // Old timer. Ignore it.
	if (theCurrentSend != nil)
	{
		[self failCurrentSend:[self getSendTimeoutError]];
		[self scheduleDequeueSend];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Receiving
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)receiveWithTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if(theFlags & kForbidSendReceive) return;
	if(theFlags & kDidClose) return;
	
	AsyncReceivePacket *packet = [[AsyncReceivePacket alloc] initWithTimeout:timeout tag:tag];
	
	[theReceiveQueue addObject:packet];
	[self scheduleDequeueReceive];
	
	[packet release];
}

- (BOOL)hasBytesAvailable:(CFSocketRef)sockRef
{
	CFSocketNativeHandle theNativeSocket = CFSocketGetNative(sockRef);
	
	if(theNativeSocket == 0)
	{
		NSLog(@"Error - Could not get CFSocketNativeHandle from CFSocketRef");
		return NO;
	} 
	
	fd_set fds;
	FD_ZERO(&fds);
	FD_SET(theNativeSocket, &fds);
	
	struct timeval timeout;
	timeout.tv_sec = 0;
	timeout.tv_usec = 0;
	
	return select(FD_SETSIZE, &fds, NULL, NULL, &timeout) > 0;
}

/**
 * Puts a maybeDequeueReceive on the run loop.
**/
- (void)scheduleDequeueReceive
{
	[self performSelector:@selector(maybeDequeueReceive) withObject:nil afterDelay:0];
}

/**
 * Starts a new receive operation if needed
**/
- (void)maybeDequeueReceive
{
	if (theCurrentReceive == nil)
	{
		if([theReceiveQueue count] > 0)
		{
			// Get next receive packet
			AsyncReceivePacket *newPacket = [theReceiveQueue objectAtIndex:0];
			theCurrentReceive = [newPacket retain];
			[theReceiveQueue removeObjectAtIndex:0];
			
			// Start time-out timer.
			if (theCurrentReceive->timeout >= 0.0)
			{
				theReceiveTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentReceive->timeout
																   target:self
																 selector:@selector(doReceiveTimeout:)
																 userInfo:nil
																  repeats:NO];
			}
			
			// Immediately receive, if possible
			// We always check both sockets so we don't ever starve one of them.
			// We also check them in alternating orders to prevent starvation if both of them
			// have a continuous flow of incoming data.
			if(theFlags & kFlipFlop)
			{
				[self doReceive4];
				[self doReceive6];
			}
			else
			{
				[self doReceive6];
				[self doReceive4];
			}
			
			theFlags ^= kFlipFlop;
		}
		else if(theFlags & kCloseAfterReceives)
		{
			[self close];
		}
	}
}

- (void)doReceive4
{
	if(theSocket4) [self doReceive:theSocket4];
}

- (void)doReceive6
{
	if(theSocket6) [self doReceive:theSocket6];
}

- (void)doReceive:(CFSocketRef)theSocket
{
	if (theCurrentReceive != nil)
	{
		BOOL appIgnoredReceivedData;
		BOOL userIgnoredReceivedData;
		
		do
		{
			// Set or reset ignored variables.
			// If the app or user ignores the received data, we'll continue this do-while loop.
			appIgnoredReceivedData = NO;
			userIgnoredReceivedData = NO;
		
			if([self hasBytesAvailable:theSocket])
			{
				int result;
				CFSocketNativeHandle theNativeSocket = CFSocketGetNative(theSocket);
				
				// Allocate buffer for recvfrom operation.
				// If the operation is successful, we'll realloc the buffer to the appropriate size,
				// and create an NSData wrapper around it without needing to copy any bytes around.
				void *buf = malloc(maxReceiveBufferSize);
				size_t bufSize = maxReceiveBufferSize;
				
				if(theSocket == theSocket4)
				{
					struct sockaddr_in sockaddr4;
					socklen_t sockaddr4len = sizeof(sockaddr4);
					
					result = recvfrom(theNativeSocket, buf, bufSize, 0, (struct sockaddr *)&sockaddr4, &sockaddr4len);
					
					if(result >= 0)
					{
						NSString *host = [self addressHost4:&sockaddr4];
						UInt16 port = ntohs(sockaddr4.sin_port);
						
						if([self isConnected] && ![self isConnectedToHost:host port:port])
						{
							// The user connected to an address, and the received data doesn't match the address.
							// This may happen if the data is received by the kernel prior to the connect call.
							appIgnoredReceivedData = YES;
						}
						else
						{
							buf = realloc(buf, result);
							theCurrentReceive->buffer = [[NSData alloc] initWithBytesNoCopy:buf
																					 length:result
																			   freeWhenDone:YES];
							theCurrentReceive->host = [host retain];
							theCurrentReceive->port = port;
						}
					}
				}
				else
				{
					struct sockaddr_in6 sockaddr6;
					socklen_t sockaddr6len = sizeof(sockaddr6);
					
					result = recvfrom(theNativeSocket, buf, bufSize, 0, (struct sockaddr *)&sockaddr6, &sockaddr6len);
					
					if(result >= 0)
					{
						NSString *host = [self addressHost6:&sockaddr6];
						UInt16 port = ntohs(sockaddr6.sin6_port);
						
						if([self isConnected] && ![self isConnectedToHost:host port:port])
						{
							// The user connected to an address, and the received data doesn't match the address.
							// This may happen if the data is received by the kernel prior to the connect call.
							appIgnoredReceivedData = YES;
						}
						else
						{
							buf = realloc(buf, result);
							theCurrentReceive->buffer = [[NSData alloc] initWithBytesNoCopy:buf
																					 length:result
																			   freeWhenDone:YES];
							theCurrentReceive->host = [host retain];
							theCurrentReceive->port = port;
						}
					}
				}
				
				// Check to see if we need to free our alloc'd buffer
				// If the buffer is non-nil, this means it has taken ownership of the buffer
				if(theCurrentReceive->buffer == nil)
				{
					free(buf);
				}
				
				if(result < 0)
				{
					[self failCurrentReceive:[self getErrnoError]];
					[self scheduleDequeueReceive];
				}
				else if(!appIgnoredReceivedData)
				{
					BOOL finished = [self maybeCompleteCurrentReceive];
					
					if(finished)
					{
						[self scheduleDequeueReceive];
					}
					else
					{
						[theCurrentReceive->buffer release];
						[theCurrentReceive->host release];
						
						theCurrentReceive->buffer = nil;
						theCurrentReceive->host = nil;
						
						userIgnoredReceivedData = YES;
					}
				}
			}
			else
			{
				// Request notification when the socket is ready to receive more data
				CFSocketEnableCallBacks(theSocket, kCFSocketReadCallBack | kCFSocketWriteCallBack);
			}
			
		} while(appIgnoredReceivedData || userIgnoredReceivedData);
	}
}

- (BOOL)maybeCompleteCurrentReceive
{
	NSAssert (theCurrentReceive, @"Trying to complete current receive when there is no current receive.");
	
	BOOL finished = YES;
	
	if ([theDelegate respondsToSelector:@selector(onUdpSocket:didReceiveData:withTag:fromHost:port:)])
	{
		finished = [theDelegate onUdpSocket:self
							 didReceiveData:theCurrentReceive->buffer
									withTag:theCurrentReceive->tag
								   fromHost:theCurrentReceive->host
									   port:theCurrentReceive->port];
	}
	
	if (finished)
	{
		if (theCurrentReceive != nil) [self endCurrentReceive]; // Caller may have disconnected.
	}
	return finished;
}

- (void)failCurrentReceive:(NSError *)error
{
	NSAssert (theCurrentReceive, @"Trying to fail current receive when there is no current receive.");
	
	if ([theDelegate respondsToSelector:@selector(onUdpSocket:didNotReceiveDataWithTag:dueToError:)])
	{
		[theDelegate onUdpSocket:self didNotReceiveDataWithTag:theCurrentReceive->tag dueToError:error];
	}
	
	if (theCurrentReceive != nil) [self endCurrentReceive]; // Caller may have disconnected.
}

- (void)endCurrentReceive
{
	NSAssert (theCurrentReceive, @"Trying to end current receive when there is no current receive.");
	
	[theReceiveTimer invalidate];
	theReceiveTimer = nil;
	
	[theCurrentReceive release];
	theCurrentReceive = nil;
}

- (void)doReceiveTimeout:(NSTimer *)timer
{
	if (timer != theReceiveTimer) return; // Old timer. Ignore it.
	if (theCurrentReceive != nil)
	{
		[self failCurrentReceive:[self getReceiveTimeoutError]];
		[self scheduleDequeueReceive];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark CF Callbacks
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)doCFSocketCallback:(CFSocketCallBackType)type
				 forSocket:(CFSocketRef)sock
			   withAddress:(NSData *)address
				  withData:(const void *)pData
{
	NSParameterAssert((sock == theSocket4) || (sock == theSocket6));
	
	switch (type)
	{
		case kCFSocketReadCallBack:
			[self doReceive:sock];
			break;
		case kCFSocketWriteCallBack:
			[self doSend];
			break;
		default:
			NSLog (@"AsyncUdpSocket %p received unexpected CFSocketCallBackType %d.", self, type);
			break;
	}
}

/**
 * This is the callback we setup for CFSocket.
 * This method does nothing but forward the call to it's Objective-C counterpart
**/
static void MyCFSocketCallback(CFSocketRef sref, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AsyncUdpSocket *socket = [[(AsyncUdpSocket *)pInfo retain] autorelease];
	[socket doCFSocketCallback:type forSocket:sref withAddress:(NSData *)address withData:pData];
	
	[pool release];
}

@end
