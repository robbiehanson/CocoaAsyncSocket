#import "AppController.h"
#import "AsyncSocket.h"
#import "X509Certificate.h"


@implementation AppController

- (id)init
{
	if(self = [super init])
	{
		asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"Ready");
	
	NSError *err = nil;
	if(![asyncSocket connectToHost:@"paypal.com" onPort:443 error:&err])
	{
		NSLog(@"Error: %@", err);
	}
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	NSLog(@"onSocket:%p didConnectToHost:%@ port:%hu", sock, host, port);
	
	// Configure SSL/TLS settings
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
	
	/* For your regular security checks, use only this setting */
	
	[settings setObject:@"www.paypal.com"
				 forKey:(NSString *)kCFStreamSSLPeerName];
	
	/* To connect to a test server, with a self-signed certificate, use settings similar to this */
	
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
	
	[sock startTLS:settings];
}

- (void)onSocket:(AsyncSocket *)sock didSecure:(BOOL)flag
{
	if(flag)
		NSLog(@"onSocket:%p didSecure:YES", sock);
	else
		NSLog(@"onSocket:%p didSecure:NO", sock);
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	NSLog(@"onSocket:%p willDisconnectWithError:%@", sock, err);
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	NSLog(@"onSocketDidDisconnect:%p", sock);
}

- (IBAction)printCert:(id)sender
{
	NSDictionary *cert = [X509Certificate extractCertDictFromAsyncSocket:asyncSocket];
	NSLog(@"X509 Certificate: \n%@", cert);
}

@end
