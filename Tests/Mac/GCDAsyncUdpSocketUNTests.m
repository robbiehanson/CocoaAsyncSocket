//
//  GCDAsyncUdpSocketUNTests.m
//  GCDAsyncUdpSocketUNTests
//
//  Created by Stanislav Pankevich on 08/21/18.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
@import CocoaAsyncSocket;

static const uint16_t UdpPort = 12345;

@interface GCDAsyncUdpSocketUNTests : XCTestCase <GCDAsyncUdpSocketDelegate>
@property (nonatomic, strong) GCDAsyncUdpSocket *clientSocket;
@property (nonatomic, strong) GCDAsyncUdpSocket *serverSocket;
@property (nonatomic, strong) NSData *readData;

@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation GCDAsyncUdpSocketUNTests

- (void)setUp {
    [super setUp];
    self.clientSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                                      delegateQueue:dispatch_get_main_queue()];
    self.serverSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
                                                      delegateQueue:dispatch_get_main_queue()];
}

- (void)tearDown {
    [super tearDown];
    self.clientSocket = nil;
    self.serverSocket = nil;
    [self.serverSocket close];
}

- (void)testConnectSendAndReceiveData {
    NSError *error = nil;
    BOOL success = NO;
    
    success = [self.serverSocket bindToPort:UdpPort error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket: %@", error);
    
    success = [self.serverSocket beginReceiving:&error];
    XCTAssertTrue(success, @"Server failed to start receiving messages: %@", error);
    
    success = [self.clientSocket connectToHost:@"127.0.0.1" onPort:UdpPort error:&error];
    XCTAssertTrue(success, @"Client failed connecting to server socket at path %@", error);
    
    self.expectation = [self expectationWithDescription:@"Test Client Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing client connection");
        }
    }];

    NSData *testData = [@"Test string" dataUsingEncoding:NSUTF8StringEncoding];
    [self.clientSocket sendData:testData withTimeout:5 tag:0];

    self.expectation = [self expectationWithDescription:@"Data Received"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
    }];
    XCTAssertTrue([testData isEqualToData:self.readData]);
}

#pragma mark GCDAsyncUdpSocketDelegate methods

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    NSLog(@"didConnectToAddress %@", address);
    [self.expectation fulfill];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
	NSLog(@"didReadData: %@ address: %@", data, address);
	self.readData = data;
	[self.expectation fulfill];
}

@end
