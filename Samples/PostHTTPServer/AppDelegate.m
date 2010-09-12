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
	
	// We're going to extend the base HTTPConnection class with our MyHTTPConnection class.
	// This allows us to do custom password protection on our sensitive directories.
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	
	// Serve files from our embedded Web folder
	NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:webPath]];
	
	NSError *error;
	BOOL success = [httpServer start:&error];
	
	if(!success)
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
}

@end
