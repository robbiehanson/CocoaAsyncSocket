#import <UIKit/UIKit.h>

@class IPhoneConnectTestViewController;
@class GCDAsyncSocket;


@interface IPhoneConnectTestAppDelegate : NSObject <UIApplicationDelegate>
{
	GCDAsyncSocket *asyncSocket;
	
	UIWindow *window;
	IPhoneConnectTestViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet IPhoneConnectTestViewController *viewController;

@end

