//
//  AppDelegate.h
//  DomainTest
//
//  Created by Jonathan Diehl on 06.10.12.
//  Copyright (c) 2012 Jonathan Diehl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DomainServer.h"
#import "DomainClient.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) DomainServer *server;
@property (strong) NSMutableArray *clients;

- (IBAction)addClient:(id)sender;

@end
