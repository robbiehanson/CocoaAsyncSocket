#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "GCDAsyncUdpSocket.h"

@interface ViewController : UIViewController <GCDAsyncUdpSocketDelegate>
{
	IBOutlet UITextField *portField;
	IBOutlet UIButton *startStopButton;
	IBOutlet WKWebView *webView;
}

- (IBAction)startStop:(id)sender;

@end
