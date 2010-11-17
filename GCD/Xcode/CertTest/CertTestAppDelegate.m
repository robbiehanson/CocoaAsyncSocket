#import "CertTestAppDelegate.h"
#import "GCDAsyncSocket.h"
#import "X509Certificate.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

// Debug levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_INFO;


@implementation CertTestAppDelegate

@synthesize window;

- (id)init
{
	if ((self = [super init]))
	{
		// Setup our logging framework
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
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	DDLogInfo(@"Connecting...");
	
	NSError *err = nil;
	if (![asyncSocket connectToHost:@"www.paypal.com" onPort:443 error:&err])
	{
		DDLogError(@"Error: %@", err);
	}
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	DDLogInfo(@"socket:%p didConnectToHost:%@ port:%hu", sock, host, port);
	
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

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
	DDLogInfo(@"socketDidSecure:%p", sock);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	DDLogInfo(@"socketDidDisconnect:%p withError:%@", sock, err);
}

- (IBAction)printCert:(id)sender
{
	NSDictionary *cert = [X509Certificate extractCertDictFromSocket:asyncSocket];
	NSLog(@"X509 Certificate: \n%@", cert);
}

@end
