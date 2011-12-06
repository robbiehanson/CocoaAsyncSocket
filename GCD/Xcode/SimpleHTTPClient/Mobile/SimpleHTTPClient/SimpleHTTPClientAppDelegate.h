#import <UIKit/UIKit.h>

@class SimpleHTTPClientViewController;
@class GCDAsyncSocket;


@interface SimpleHTTPClientAppDelegate : NSObject <UIApplicationDelegate>
{
	GCDAsyncSocket *asyncSocket;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet SimpleHTTPClientViewController *viewController;

@end
