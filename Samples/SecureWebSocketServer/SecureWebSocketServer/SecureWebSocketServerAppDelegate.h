#import <Cocoa/Cocoa.h>

@class HTTPServer;


@interface SecureWebSocketServerAppDelegate : NSObject <NSApplicationDelegate> {
@private
	HTTPServer *httpServer;
	NSWindow *__unsafe_unretained window;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;

@end
