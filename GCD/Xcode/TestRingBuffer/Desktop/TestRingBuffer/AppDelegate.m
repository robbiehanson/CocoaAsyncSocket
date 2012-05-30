#import "AppDelegate.h"
#import "TestRingBuffer.h"


@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[TestRingBuffer start];
}

@end
