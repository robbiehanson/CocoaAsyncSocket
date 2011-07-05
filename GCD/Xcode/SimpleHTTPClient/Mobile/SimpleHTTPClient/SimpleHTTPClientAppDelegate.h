#import <UIKit/UIKit.h>

@class SimpleHTTPClientViewController;
@class GCDAsyncSocket;


@interface SimpleHTTPClientAppDelegate : NSObject <UIApplicationDelegate>
{
	GCDAsyncSocket *asyncSocket;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet SimpleHTTPClientViewController *viewController;

@end
