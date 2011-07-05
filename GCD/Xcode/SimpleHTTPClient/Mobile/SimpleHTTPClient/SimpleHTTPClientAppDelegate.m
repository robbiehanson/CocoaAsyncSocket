#import "SimpleHTTPClientAppDelegate.h"
#import "SimpleHTTPClientViewController.h"
#import "GCDAsyncSocket.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation SimpleHTTPClientAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// AsyncSocket optionally uses the Lumberjack logging framework.
	// 
	// Lumberjack is a professional logging framework. It's extremely fast and flexible.
	// It also uses GCD, making it a great fit for GCDAsyncSocket.
	// 
	// As mentioned earlier, enabling logging in GCDAsyncSocket is entirely optional.
	// Doing so simply helps give you a deeper understanding of the inner workings of the library (if you care).
	// You can do so at the top of GCDAsyncSocket.m,
	// where you can also control things such as the log level,
	// and whether or not logging should be asynchronous (helps to improve speed, and
	// perfect for reducing interference with those pesky timing bugs in your code).
	// 
	// There is a massive amount of documentation on the Lumberjack project page:
	// http://code.google.com/p/cocoalumberjack/
	// 
	// But this one line is all you need to instruct Lumberjack to spit out log statements to the Xcode console.
	
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	// Create our GCDAsyncSocket instance.
	// 
	// Notice that we give it the normal delegate AND a delegate queue.
	// The socket will do all of its operations in a background queue,
	// and you can tell it which thread/queue to invoke your delegate on.
	// In this case, we're just saying invoke us on the main thread.
	// But you can see how trivial it would be to create your own queue,
	// and parallelize your networking processing code by having your
	// delegate methods invoked and run on background queues.
	
	asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	// Now we tell the ASYNCHRONOUS socket to connect.
	// 
	// Recall that GCDAsyncSocket is ... asynchronous.
	// This means when you tell the socket to connect, it will do so ... asynchronously.
	// After all, do you want your main thread to block on a slow network connection?
	// 
	// So what's with the BOOL return value, and error pointer?
	// These are for early detection of obvious problems, such as:
	// 
	// - The socket is already connected.
	// - You passed in an invalid parameter.
	// - The socket isn't configured properly.
	// 
	// The error message might be something like "Attempting to connect without a delegate. Set a delegate first."
	// 
	// When the asynchronous sockets connects, it will invoke the socket:didConnectToHost:port: delegate method.
	
	NSError *error = nil;
	if (![asyncSocket connectToHost:@"deusty.com" onPort:80 error:&error])
	{
		DDLogError(@"Unable to connect to due to invalid configuration: %@", error);
	}
	else
	{
		DDLogVerbose(@"Connecting...");
	}
	
	// Normal iOS stuff...
	
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];
    return YES;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	DDLogVerbose(@"socket:didConnectToHost:%@ port:%hu", host, port);
	
	// HTTP is a really simple protocol.
	// 
	// If you don't already know all about it, this is one of the best resources I know (short and sweet):
	// http://www.jmarshall.com/easy/http/
	// 
	// We're just going to tell the server to send us the metadata (essentially) about a particular resource.
	// The server will send an http response, and then immediately close the connection.
	
	NSString *requestStr = @"HEAD / HTTP/1.0\r\nHost: deusty.com\r\n\r\n";
	NSData *requestData = [requestStr dataUsingEncoding:NSUTF8StringEncoding];
	
	[asyncSocket writeData:requestData withTimeout:-1.0 tag:0];
	
	// Side Note:
	// 
	// The AsyncSocket family supports queued reads and writes.
	// 
	// This means that you don't have to wait for the socket to connect before issuing your read or write commands.
	// If you do so before the socket is connected, it will simply queue the requests,
	// and process them after the socket is connected.
	// Also, you can issue multiple write commands (or read commands) at a time.
	// You don't have to wait for one write operation to complete before sending another write command.
	// 
	// The whole point is to make YOUR code easier to write, easier to read, and easier to maintain.
	// Do networking stuff when it is easiest for you, or when it makes the most sense for you.
	// AsyncSocket adapts to your schedule, not the other way around.
	
	
	// Now we tell the socket to read the full header for the http response.
	// As per the http protocol, we know the header is terminated with two CFLF's (carriage return, line feed).
	
	NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
	
	[asyncSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	DDLogVerbose(@"socket:didWriteDataWithTag:");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	DDLogVerbose(@"socket:didReadData:withTag:");
	
	if (LOG_INFO)
	{
		NSString *httpResponse = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		
		DDLogInfo(@"httpResponse: %@", httpResponse);
	}
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	// Since we requested HTTP/1.0, we expect the server to close the connection as soon as it has sent the response.
	
	DDLogVerbose(@"socketDidDisconnect:withError:%@", err);
}

- (void)dealloc
{
	[_window release];
	[_viewController release];
    [super dealloc];
}

@end
