#import "IPhoneConnectTestAppDelegate.h"
#import "IPhoneConnectTestViewController.h"
#import "GCDAsyncSocket.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_INFO;


@implementation IPhoneConnectTestAppDelegate

@synthesize window;
@synthesize viewController;

- (void)normalConnect
{
	NSError *error = nil;
	
	NSString *host = @"google.com";
//	NSString *host = @"deusty.com";
	
	if (![asyncSocket connectToHost:host onPort:80 error:&error])
	{
		DDLogError(@"Error connecting: %@", error);
	}

	// You can also specify an optional connect timeout.
	
//	if (![asyncSocket connectToHost:host onPort:80 withTimeout:5.0 error:&error])
//	{
//		DDLogError(@"Error connecting: %@", error);
//	}
}

- (void)secureConnect
{
	NSError *error = nil;
	if (![asyncSocket connectToHost:@"www.paypal.com" onPort:443 error:&error])
	{
		DDLogError(@"Error connecting: %@", error);
	}
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Setup logging framework
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	// Setup our socket (GCDAsyncSocket).
	// The socket will invoke our delegate methods using the usual delegate paradigm.
	// However, it will invoke the delegate methods on a specified GCD delegate dispatch queue.
	// 
	// Now we can configure the delegate dispatch queue however we want.
	// We could use a dedicated dispatch queue for easy parallelization.
	// Or we could simply use the dispatch queue for the main thread.
	// 
	// The best approach for your application will depend upon convenience, requirements and performance.
	// 
	// For this simple example, we're just going to use the main thread.
	
	dispatch_queue_t mainQueue = dispatch_get_main_queue();
	
	asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
	
	[self normalConnect];
//	[self secureConnect];
	
	// Add the view controller's view to the window and display.
	[window addSubview:viewController.view];
	[window makeKeyAndVisible];
	
	return YES;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	DDLogInfo(@"socket:%p didConnectToHost:%@ port:%hu", sock, host, port);
	
//	DDLogInfo(@"localHost :%@ port:%hu", [sock localHost], [sock localPort]);
	
	if (port == 443)
	{
		
	#if !TARGET_IPHONE_SIMULATOR
		
		// Backgrounding doesn't seem to be supported on the simulator yet
		
		[sock performBlock:^{
			if ([sock enableBackgroundingOnSocketWithCaveat])
				DDLogInfo(@"Enabled backgrounding on socket");
			else
				DDLogWarn(@"Enabling backgrounding failed!");
		}];
		
	#endif
		
		// Configure SSL/TLS settings
		NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
		
		// If you simply want to ensure that the remote host's certificate is valid,
		// then you can use an empty dictionary.
		
		// If you know the name of the remote host, then you should specify the name here.
		// 
		// NOTE:
		// You should understand the security implications if you do not specify the peer name.
		// Please see the documentation for the startTLS method in GCDAsyncSocket.h for a full discussion.
		
		[settings setObject:@"www.paypal.com"
					 forKey:(NSString *)kCFStreamSSLPeerName];
		
		// To connect to a test server, with a self-signed certificate, use settings similar to this:
		
	//	// Allow expired certificates
	//	[settings setObject:[NSNumber numberWithBool:YES]
	//				 forKey:(NSString *)kCFStreamSSLAllowsExpiredCertificates];
	//	
	//	// Allow self-signed certificates
	//	[settings setObject:[NSNumber numberWithBool:YES]
	//				 forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	//	
	//	// In fact, don't even validate the certificate chain
	//	[settings setObject:[NSNumber numberWithBool:NO]
	//				 forKey:(NSString *)kCFStreamSSLValidatesCertificateChain];
		
		DDLogVerbose(@"Starting TLS with settings:\n%@", settings);
		
		[sock startTLS:settings];
		
		// You can also pass nil to the startTLS method, which is the same as passing an empty dictionary.
		// Again, you should understand the security implications of doing so.
		// Please see the documentation for the startTLS method in GCDAsyncSocket.h for a full discussion.
	}
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
	DDLogInfo(@"socketDidSecure:%p", sock);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	DDLogInfo(@"socketDidDisconnect:%p withError: %@", sock, err);
}

- (void)dealloc
{
	[viewController release];
	[window release];
	[super dealloc];
}


@end
