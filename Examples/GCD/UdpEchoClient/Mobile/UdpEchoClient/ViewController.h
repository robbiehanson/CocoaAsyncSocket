#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "GCDAsyncUdpSocket.h"

@interface ViewController : UIViewController <GCDAsyncUdpSocketDelegate>
{
	IBOutlet UITextField *addrField;
	IBOutlet UITextField *portField;
	IBOutlet UITextField *messageField;
	IBOutlet WKWebView *webView;
}

- (IBAction)send:(id)sender;

@end
