#import "ThreadPerConnectionServer.h"
#import "AsyncSocket.h"


@interface HTTPConnection (InternalAPI)

- (void)startReadingRequest;

@end

@implementation ThreadPerConnectionServer

- (id)init
{
	if(self = [super init])
	{
		connectionClass = [TPCConnection self];
	}
	return self;
}

@end

@implementation TPCConnection

- (id)initWithAsyncSocket:(AsyncSocket *)newSocket forServer:(HTTPServer *)myServer
{
	if(self = [super initWithAsyncSocket:newSocket forServer:myServer])
	{
		continueRunLoop = YES;
		[NSThread detachNewThreadSelector:@selector(setupRunLoop) toTarget:self withObject:nil];
		
		// Note: The target of the thread is automatically retained, and released when the thread exits.
	}
	return self;
}

- (void)setupRunLoop
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@synchronized(self)
	{
		myRunLoop = [NSRunLoop currentRunLoop];
	}
	
	// Note: It is assumed the main listening socket is running on the main thread.
	// If this assumption is incorrect in your case, you'll need to call switchRunLoop on correct thread.
	[self performSelectorOnMainThread:@selector(switchRunLoop) withObject:nil waitUntilDone:YES];
	
	[self startReadingRequest];
	
	while (continueRunLoop)
	{
		NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
		
		[myRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
		
		NSLog(@"iteration");
		[innerPool release];
	}
	
	NSLog(@"%p: RunLoop closing down", self);
	
	[pool release];
}

- (void)switchRunLoop
{
	@synchronized(self)
	{
		// The moveToRunLoop method must be called on the socket's existing runloop/thread
		[asyncSocket moveToRunLoop:myRunLoop];
	}
	
	NSLog(@"%p: Run loop up", self);
}


- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	// Do nothing here - wait until the socket has been moved to the proper thread
}

/**
 * Called when the connection dies.
**/
- (void)die
{
	continueRunLoop = NO;
	[super die];
}

@end
