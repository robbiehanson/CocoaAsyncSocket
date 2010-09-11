#import <Cocoa/Cocoa.h>

@class MyHTTPServer;


@interface SimpleWebSocketServerAppDelegate : NSObject <NSApplicationDelegate>
{
	MyHTTPServer *httpServer;
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
