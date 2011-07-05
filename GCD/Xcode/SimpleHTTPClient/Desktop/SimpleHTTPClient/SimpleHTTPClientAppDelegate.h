#import <Cocoa/Cocoa.h>

@class GCDAsyncSocket;


@interface SimpleHTTPClientAppDelegate : NSObject <NSApplicationDelegate> {
@private
	GCDAsyncSocket *asyncSocket;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
