#import <Foundation/Foundation.h>

@class HTTPMessage;
@class GCDAsyncSocket;


#define WebSocketDidDieNotification  @"WebSocketDidDie"

@interface WebSocket : NSObject
{
	dispatch_queue_t websocketQueue;
	
	HTTPMessage *request;
	GCDAsyncSocket *asyncSocket;
	
	NSData *term;
	
	BOOL isOpen;
	BOOL isVersion76;
}

+ (BOOL)isWebSocketRequest:(HTTPMessage *)request;

- (id)initWithRequest:(HTTPMessage *)request socket:(GCDAsyncSocket *)socket;

- (void)start;
- (void)stop;

- (void)didOpen;

- (void)sendMessage:(NSString *)msg;
- (void)didReceiveMessage:(NSString *)msg;

- (void)didClose;

@end
