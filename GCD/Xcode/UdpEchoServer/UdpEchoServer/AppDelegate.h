#import <Cocoa/Cocoa.h>
#import "GCDAsyncUdpSocket.h"


@interface AppDelegate : NSObject <NSApplicationDelegate>
{
	GCDAsyncUdpSocket *udpSocket;
	BOOL isRunning;
}

@property (assign) IBOutlet NSWindow *window;
@property (retain) IBOutlet NSTextField *portField;
@property (retain) IBOutlet NSButton *startStopButton;
@property (retain) IBOutlet NSTextView *logView;

- (IBAction)startStopButtonPressed:(id)sender;

@end
