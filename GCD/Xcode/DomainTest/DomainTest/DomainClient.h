//
//  DomainClient.h
//  DomainTest
//
//  Created by Jonathan Diehl on 06.10.12.
//  Copyright (c) 2012 Jonathan Diehl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GCDAsyncSocket.h"

@interface DomainClient : NSWindowController <GCDAsyncSocketDelegate>

@property (readonly) GCDAsyncSocket *socket;
@property (strong) IBOutlet NSTextView *outputView;
@property (strong) IBOutlet NSTextField *inputView;

- (void)connectToUrl:(NSURL *)url;
- (IBAction)send:(id)sender;

@end
