#import "AppDelegate.h"
#import "ThreadPoolServer.h"
#import "ThreadPerConnectionServer.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	httpServer = [[ThreadPoolServer alloc] init];
//	httpServer = [[ThreadPerConnectionServer alloc] init];
	
	[httpServer setType:@"_http._tcp."];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:[@"~/Sites" stringByExpandingTildeInPath]]];
	
	NSError *error = nil;
	BOOL success = [httpServer start:&error];
	
	if(!success)
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
}

@end
