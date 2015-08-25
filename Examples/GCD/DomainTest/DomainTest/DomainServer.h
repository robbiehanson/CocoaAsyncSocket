//
//  DomainServer.h
//  DomainTest
//
//  Created by Jonathan Diehl on 06.10.12.
//  Copyright (c) 2012 Jonathan Diehl. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GCDAsyncSocket.h"

@interface DomainServer : NSObject

@property (readonly) GCDAsyncSocket *socket;
@property (readonly) NSMutableSet *connectedSockets;
@property (strong) NSURL *url;

- (BOOL)start:(NSError **)error;
- (void)stop;

@end
