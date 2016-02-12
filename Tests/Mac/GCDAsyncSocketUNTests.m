//
//  GCDAsyncSocketConnectionTests.m
//  GCDAsyncSocketConnectionTests
//
//  Created by Christopher Ballinger on 10/31/14.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
@import CocoaAsyncSocket;

@interface GCDAsyncSocketUNTests : XCTestCase <GCDAsyncSocketDelegate>
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) GCDAsyncSocket *acceptedServerSocket;
@property (nonatomic, strong) NSData *readData;

@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation GCDAsyncSocketUNTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
	self.url = [NSURL fileURLWithPath:@"/tmp/GCDAsyncSocketUNTests"];
    self.clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [self.clientSocket disconnect];
    [self.serverSocket disconnect];
    [self.acceptedServerSocket disconnect];
    self.clientSocket = nil;
    self.serverSocket = nil;
    self.acceptedServerSocket = nil;
	[[NSFileManager defaultManager] removeItemAtURL:self.url error:nil];
}

- (void)testFullConnection {
    NSError *error = nil;
    BOOL success = NO;
    success = [self.serverSocket acceptOnUrl:self.url error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket at path %@ %@", self.url.path, error);
	success = [self.clientSocket connectToUrl:self.url withTimeout:-1 error:&error];
    XCTAssertTrue(success, @"Client failed connecting to server socket at path %@ %@", self.url.path, error);
    
    self.expectation = [self expectationWithDescription:@"Test Full Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
    }];
}

/****  BROKEN TESTS *******
 
 
- (void)testTransferFromClient {

	NSData *testData = [@"ThisTestRocks!!!" dataUsingEncoding:NSUTF8StringEncoding];

	// set up and conncet to socket
	[self.serverSocket acceptOnUrl:self.url error:nil];
	[self.clientSocket connectToUrl:self.url withTimeout:-1 error:nil];

	// wait for connection
	self.expectation = [self expectationWithDescription:@"Socket Connected"];
	[self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {

		// start reading
		[self.acceptedServerSocket readDataWithTimeout:-1 tag:0];

		// send data
		self.expectation = [self expectationWithDescription:@"Data Sent"];
		[self.clientSocket writeData:testData withTimeout:-1 tag:0];
		[self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
			if (error) {
				return NSLog(@"Error reading data");
			}
			XCTAssertTrue([testData isEqual:self.readData], @"Read data did not match test data");
		}];
	}];
}

- (void)testTransferFromServer {
	
	NSData *testData = [@"ThisTestRocks!!!" dataUsingEncoding:NSUTF8StringEncoding];
	
	// set up and conncet to socket
	[self.serverSocket acceptOnUrl:self.url error:nil];
	[self.clientSocket connectToUrl:self.url withTimeout:-1 error:nil];
	
	// wait for connection
	self.expectation = [self expectationWithDescription:@"Socket Connected"];
	[self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
		
		// start reading
		[self.clientSocket readDataWithTimeout:-1 tag:0];
		
		// send data
		self.expectation = [self expectationWithDescription:@"Data Sent"];
		[self.acceptedServerSocket writeData:testData withTimeout:-1 tag:0];
		[self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
			if (error) {
				return NSLog(@"Error reading data");
			}
			XCTAssertTrue([testData isEqual:self.readData], @"Read data did not match test data");
		}];
	}];
}
 
 **************/

#pragma mark GCDAsyncSocketDelegate methods

/**
 * Called when a socket accepts a connection.
 * Another socket is automatically spawned to handle it.
 *
 * You must retain the newSocket if you wish to handle the connection.
 * Otherwise the newSocket instance will be released and the spawned connection will be closed.
 *
 * By default the new socket will have the same delegate and delegateQueue.
 * You may, of course, change this at any time.
 **/
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"didAcceptNewSocket %@ %@", sock, newSocket);
    self.acceptedServerSocket = newSocket;
}

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
 **/
- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    NSLog(@"didConnectToUrl %@", url);
    [self.expectation fulfill];
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
	NSLog(@"didReadData: %@ tag: %ld", data, tag);
	self.readData = data;
	[self.expectation fulfill];
}


@end
