#import <Cocoa/Cocoa.h>
@class AsyncSocket;

@interface AppController : NSObject
{
	AsyncSocket *asyncSocket;
}

- (IBAction)printCert:(id)sender;
@end
