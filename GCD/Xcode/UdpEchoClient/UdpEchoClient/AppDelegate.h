#import <Cocoa/Cocoa.h>

@class GCDAsyncUdpSocket;


@interface AppDelegate : NSObject <NSApplicationDelegate>
{
	long tag;
	GCDAsyncUdpSocket *udpSocket;
}

@property (assign) IBOutlet NSWindow    * window;
@property (retain) IBOutlet NSTextField * addrField;
@property (retain) IBOutlet NSTextField * portField;
@property (retain) IBOutlet NSTextField * messageField;
@property (retain) IBOutlet NSButton    * sendButton;
@property (retain) IBOutlet NSTextView  * logView;

- (IBAction)send:(id)sender;

@end
