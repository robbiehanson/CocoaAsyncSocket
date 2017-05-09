//
//  GCDAsyncSocketConnectionTests.m
//  GCDAsyncSocketConnectionTests
//
//  Created by Christopher Ballinger on 10/31/14.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#include <netinet/in.h>
#include <arpa/inet.h>
@import CocoaAsyncSocket;

@interface GCDAsyncSocketConnectionTests : XCTestCase <GCDAsyncSocketDelegate>
@property (nonatomic) uint16_t portNumber;
@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) GCDAsyncSocket *acceptedServerSocket;

@property (nonatomic, strong) XCTestExpectation *expectation;
@end

@implementation GCDAsyncSocketConnectionTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.portNumber = [self randomValidPort];
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
}

- (uint16_t) randomValidPort {
    uint16_t minPort = 1024;
    uint16_t maxPort = UINT16_MAX;
    return minPort + arc4random_uniform(maxPort - minPort + 1);
}

- (void)testFullConnection {
    NSError *error = nil;
    BOOL success = NO;
    success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);
    success = [self.clientSocket connectToHost:@"127.0.0.1" onPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Client failed connecting to up server socket on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Full Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
    }];
}

- (void)testConnectionWithAnIPv4OnlyServer {
    self.serverSocket.IPv6Enabled = NO;
    
    NSError *error = nil;
    BOOL success = NO;
    success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);
    success = [self.clientSocket connectToHost:@"127.0.0.1" onPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Client failed connecting to up server socket on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Full Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
        else {
            XCTAssertTrue(self.acceptedServerSocket.isIPv4, @"Established connection is not IPv4");
        }
    }];
}

- (void)testConnectionWithAnIPv6OnlyServer {
    self.serverSocket.IPv4Enabled = NO;
    
    NSError *error = nil;
    BOOL success = NO;
    success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);
    success = [self.clientSocket connectToHost:@"::1" onPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Client failed connecting to up server socket on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Full Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
        else {
            XCTAssertTrue(self.acceptedServerSocket.isIPv6, @"Established connection is not IPv6");
        }
    }];
}

- (void)testConnectionWithLocalhostWithClientPreferringIPv4 {
    [self.clientSocket setIPv4PreferredOverIPv6:YES];
    
    NSError *error = nil;
    BOOL success = NO;
    success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);
    success = [self.clientSocket connectToHost:@"localhost" onPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Client failed connecting to up server socket on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Full Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
    }];
}

- (void)testConnectionWithLocalhostWithClientPreferringIPv6 {
  [self.clientSocket setIPv4PreferredOverIPv6:NO];

    NSError *error = nil;
    BOOL success = NO;
    success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);
    success = [self.clientSocket connectToHost:@"localhost" onPort:self.portNumber error:&error];
    XCTAssertTrue(success, @"Client failed connecting to up server socket on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Full Connection"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test connection");
        }
    }];
}

- (void)testConnectionWithLocalhostWithConnectedSocketFD4 {
  [self.serverSocket setIPv6Enabled:NO];
  
  NSError *error = nil;
  BOOL success = NO;
  success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
  XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);

  int socketFD4;
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(self.portNumber);
  addr.sin_addr.s_addr = inet_addr("127.0.0.1");
  
  socketFD4 = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  XCTAssertTrue(socketFD4 >=0, @"Failed to create IPv4 socket");
  
  int errorCode = connect(socketFD4, (struct sockaddr *)&addr, sizeof(addr));
  XCTAssertTrue(errorCode == 0, @"Failed to connect to server");

  GCDAsyncSocket *socket = [GCDAsyncSocket socketFromConnectedSocketFD:socketFD4 delegate:nil delegateQueue:NULL error:&error];
  XCTAssertTrue(socket && !error, @"Failed to create socket from socket FD");
  
  XCTAssertTrue([socket isConnected], @"GCDAsyncSocket is should connected");
  XCTAssertTrue([socket.connectedHost isEqualToString:@"127.0.0.1"], @"Something is wrong with GCDAsyncSocket. Connected host is wrong");
  XCTAssertTrue(socket.connectedPort == self.portNumber, @"Something is wrong with the GCDAsyncSocket. Connected port is wrong");
}

- (void)testConnectionWithLocalhostWithConnectedSocketFD6 {
  [self.serverSocket setIPv4Enabled:NO];
  
  NSError *error = nil;
  BOOL success = NO;
  success = [self.serverSocket acceptOnPort:self.portNumber error:&error];
  XCTAssertTrue(success, @"Server failed setting up socket on port %d %@", self.portNumber, error);
  
  int socketFD6;
  struct sockaddr_in6 addr;
  addr.sin6_family = AF_INET6;
  addr.sin6_port = htons(self.portNumber);
  inet_pton(AF_INET6, "::1", &addr.sin6_addr);
  
  socketFD6 = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
  XCTAssertTrue(socketFD6 >=0, @"Failed to create IPv6 socket");
  
  int errorCode = connect(socketFD6, (struct sockaddr *)&addr, sizeof(addr));
  XCTAssertTrue(errorCode == 0, @"Failed to connect to server");
  
  GCDAsyncSocket *socket = [GCDAsyncSocket socketFromConnectedSocketFD:socketFD6 delegate:nil delegateQueue:NULL error:&error];
  XCTAssertTrue(socket && !error, @"Failed to create socket from socket FD");

  XCTAssertTrue([socket isConnected], @"GCDAsyncSocket is should connected");
  XCTAssertTrue([socket.connectedHost isEqualToString:@"::1"], @"Something is wrong with GCDAsyncSocket. Connected host is wrong");
  XCTAssertTrue(socket.connectedPort == self.portNumber, @"Something is wrong with the GCDAsyncSocket. Connected port is wrong");
}

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
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"didConnectToHost %@ %@ %d", sock, host, port);
    [self.expectation fulfill];
}


@end
