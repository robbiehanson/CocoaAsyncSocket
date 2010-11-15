#import <UIKit/UIKit.h>

@class InterfaceTestViewController;
@class AsyncSocket;


@interface InterfaceTestAppDelegate : NSObject <UIApplicationDelegate>
{
	CFHostRef host;
	AsyncSocket *asyncSocket;
	
	UIWindow *window;
	InterfaceTestViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet InterfaceTestViewController *viewController;

@end

