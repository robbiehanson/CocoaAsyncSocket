//
//  CocoaAsyncSocket.m
//  CocoaAsyncSocket
//
//  Created by Andrew Mackenzie-Ross on 3/02/2015.
//  Copyright (c) 2015 Deusty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <CocoaAsyncSocket/CocoaAsyncSocket.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface CocoaAsyncSocket_Tests : XCTestCase

@end

@implementation CocoaAsyncSocket_Tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

static DDLogLevel ddLogLevel = DDLogLevelAll;

- (void)testDDLog {
    // You can see the dynamic library loading work by going to this test target
    // unchecking copy on install for CocoaLumberjack and running this test.
    // Recheck copy on install to disable logging and clean build folder.
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    DDLogError(@"\n\n\n"
               "=========================================================\n"
               "I only log when the CocoaLumberjack framework is present.\n"
               "=========================================================\n"
               "\n\n");
    __unused id obj = [[GCDAsyncSocket alloc] init];
    obj = nil;
}

@end
