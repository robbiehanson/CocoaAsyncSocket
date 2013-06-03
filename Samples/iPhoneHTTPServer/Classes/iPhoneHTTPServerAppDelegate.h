#import <UIKit/UIKit.h>

@class iPhoneHTTPServerViewController;
@class HTTPServer;

@interface iPhoneHTTPServerAppDelegate : NSObject <UIApplicationDelegate>
{
	HTTPServer *httpServer;
	
	UIWindow *window;
	iPhoneHTTPServerViewController *viewController;
}

@property (nonatomic) IBOutlet UIWindow *window;
@property (nonatomic) IBOutlet iPhoneHTTPServerViewController *viewController;

@end

