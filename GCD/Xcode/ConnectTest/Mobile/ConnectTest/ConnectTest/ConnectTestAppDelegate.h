#import <UIKit/UIKit.h>

@class ConnectTestViewController;
@class GCDAsyncSocket;


@interface ConnectTestAppDelegate : NSObject <UIApplicationDelegate>
{
	GCDAsyncSocket *asyncSocket;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet ConnectTestViewController *viewController;

@end
