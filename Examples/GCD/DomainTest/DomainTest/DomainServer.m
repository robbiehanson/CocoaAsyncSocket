//
//  DomainServer.m
//  DomainTest
//
//  Created by Jonathan Diehl on 06.10.12.
//  Copyright (c) 2012 Jonathan Diehl. All rights reserved.
//

#import "DomainServer.h"

@implementation DomainServer

@synthesize socket = _socket;
@synthesize url = _url;

- (BOOL)start:(NSError **)error;
{
	_connectedSockets = [NSMutableSet new];
	_socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	BOOL result = [self.socket acceptOnUrl:self.url error:error];
	if (result) {
		NSLog(@"[Server] Started at: %@", self.url.path);
	}
	return result;
}

- (void)stop;
{
	_socket = nil;
	NSLog(@"[Server] Stopped.");
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;
{
	NSLog(@"[Server] New connection.");
	[self.connectedSockets addObject:newSocket];
	[newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)error;
{
	[self.connectedSockets removeObject:socket];
	NSLog(@"[Server] Closed connection: %@", error);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;
{
	NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSLog(@"[Server] Received: %@", text);
	
	[sock writeData:data withTimeout:-1 tag:0];
	[sock readDataWithTimeout:-1 tag:0];
}

@end
