#import <Cocoa/Cocoa.h>

@class GCDAsyncSocket;


@interface BonjourClientAppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
	NSNetServiceBrowser *netServiceBrowser;
	NSNetService *serverService;
	NSMutableArray *serverAddresses;
	GCDAsyncSocket *asyncSocket;
	BOOL connected;
	
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
