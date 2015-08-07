#import <UIKit/UIKit.h>
#import "GCDAsyncUdpSocket.h"

@interface ViewController : UIViewController <GCDAsyncUdpSocketDelegate>
{
	IBOutlet UITextField *portField;
	IBOutlet UIButton *startStopButton;
	IBOutlet UIWebView *webView;
}

- (IBAction)startStop:(id)sender;

@end
