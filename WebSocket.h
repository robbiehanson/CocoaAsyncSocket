#import <Foundation/Foundation.h>

@class HTTPMessage;
@class AsyncSocket;


#define WebSocketDidDieNotification  @"WebSocketDidDie"

@interface WebSocket : NSObject
{
	HTTPMessage *request;
	AsyncSocket *asyncSocket;
	
	NSData *term;
	
	BOOL isOpen;
	BOOL isVersion76;
}

+ (BOOL)isWebSocketRequest:(HTTPMessage *)request;

- (id)initWithRequest:(HTTPMessage *)request socket:(AsyncSocket *)socket;

- (void)didOpen;

- (void)sendMessage:(NSString *)msg;
- (void)didReceiveMessage:(NSString *)msg;

- (void)didClose;

@end
