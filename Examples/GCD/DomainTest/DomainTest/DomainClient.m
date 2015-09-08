//
//  DomainClient.m
//  DomainTest
//
//  Created by Jonathan Diehl on 06.10.12.
//  Copyright (c) 2012 Jonathan Diehl. All rights reserved.
//

#import "DomainClient.h"

@implementation DomainClient

@synthesize socket = _socket;
@synthesize outputView = _outputView;
@synthesize inputView = _inputView;

- (void)connectToUrl:(NSURL *)url;
{
	NSError *error = nil;
	_socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	if (![self.socket connectToUrl:url withTimeout:-1 error:&error]) {
		[self presentError:error];
	}
}

- (IBAction)send:(id)sender;
{
	NSData *data = [self.inputView.stringValue dataUsingEncoding:NSUTF8StringEncoding];
	[self.socket writeData:data withTimeout:-1 tag:0];
	self.inputView.stringValue = @"";
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url;
{
	NSLog(@"[Client] Connected to %@", url);
	[sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)error;
{
	NSLog(@"[Client] Closed connection: %@", error);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;
{
	NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSLog(@"[Client] Received: %@", text);
	
	text = [text stringByAppendingString:@"\n"];
	NSAttributedString *string = [[NSAttributedString alloc] initWithString:text];
	NSTextStorage *storage = self.outputView.textStorage;
	
	[storage beginEditing];
	[storage appendAttributedString:string];
	[storage endEditing];
	
	[sock readDataWithTimeout:-1 tag:0];
}

@end
