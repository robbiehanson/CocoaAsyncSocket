#import "AppDelegate.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	httpServer = [[HTTPServer alloc] init];
	
	// Set the bonjour type of the http server.
	// This allows the server to broadcast itself via bonjour.
	// You can automatically discover the service in Safari's bonjour bookmarks section.
	[httpServer setType:@"_http._tcp."];
	
	// Note: Clicking the bonjour service in Safari won't work because Safari will use http and not https.
	// Just change the url to https for proper access.
	
	// We're going to extend the base HTTPConnection class with our MyHTTPConnection class.
	// This allows us to customize the server for things such as SSL and password-protection.
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	
	// Serve files from the standard Sites folder
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:[@"~/Sites" stringByExpandingTildeInPath]]];
	
	NSError *error;
	BOOL success = [httpServer start:&error];
	
	if(!success)
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
}

@end
