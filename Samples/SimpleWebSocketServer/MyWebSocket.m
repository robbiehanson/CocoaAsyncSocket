#import "MyWebSocket.h"


@implementation MyWebSocket

- (void)didOpen
{
	NSLog(@"MyWebSocket: didOpen");
	
	[self sendMessage:@"Welcome to my WebSocket"];
	
	[super didOpen];
}

- (void)didReceiveMessage:(NSString *)msg
{
	NSLog(@"MyWebSocket: didReceiveMessage: %@", msg);
	
	[self sendMessage:[NSString stringWithFormat:@"%@", [NSDate date]]];
}

- (void)didClose
{
	NSLog(@"MyWebSocket: didClose");
	
	[super didClose];
}

@end
