#import <Cocoa/Cocoa.h>

@class GCDAsyncSocket;


@interface CertTestAppDelegate : NSObject <NSApplicationDelegate>
{
	GCDAsyncSocket *asyncSocket;
	NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)printCert:(id)sender;

@end
