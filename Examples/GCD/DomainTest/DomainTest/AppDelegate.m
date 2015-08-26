//
//  AppDelegate.m
//  DomainTest
//
//  Created by Jonathan Diehl on 06.10.12.
//  Copyright (c) 2012 Jonathan Diehl. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize server = _server;
@synthesize clients = _clients;

- (IBAction)addClient:(id)sender;
{
	DomainClient *client = [[DomainClient alloc] initWithWindowNibName:@"DomainClient"];
	[self.clients addObject:client];
	[client connectToUrl:self.server.url];
	[client showWindow:sender];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_clients = [NSMutableArray new];
	
	NSError *error = nil;
	_server = [DomainServer new];
	self.server.url = [NSURL fileURLWithPath:@"/tmp/socket"];
	if (![self.server start:&error]) {
		[self.window presentError:error];
	}
	
	[self addClient:nil];
}

@end
