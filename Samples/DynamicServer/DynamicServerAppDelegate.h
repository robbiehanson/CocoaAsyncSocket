#import <Cocoa/Cocoa.h>

@class HTTPServer;


@interface DynamicServerAppDelegate : NSObject <NSApplicationDelegate>
{
	HTTPServer *httpServer;
	
	NSWindow *__unsafe_unretained window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
