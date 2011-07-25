#import <Cocoa/Cocoa.h>

@class GCDAsyncSocket;


@interface ConnectTestAppDelegate : NSObject <NSApplicationDelegate> {
@private
	GCDAsyncSocket *asyncSocket;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
