#import <Cocoa/Cocoa.h>

@class GCDAsyncSocket;


@interface BonjourServerAppDelegate : NSObject <NSApplicationDelegate, NSNetServiceDelegate>
{
	NSNetService *netService;
	GCDAsyncSocket *asyncSocket;
	NSMutableArray *connectedSockets;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
