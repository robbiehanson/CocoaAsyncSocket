//
//  GCDAsyncUdpSocketConnectionTests.m
//  CocoaAsyncSocket
//
//  Created by 李博文 on 2017/3/25.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
@import CocoaAsyncSocket;

@interface GCDAsyncUdpSocketConnectionTests : XCTestCase<GCDAsyncUdpSocketDelegate>
@property (nonatomic) uint16_t portNumber;
@property (nonatomic, strong) GCDAsyncUdpSocket *clientSocket;
@property (nonatomic, strong) GCDAsyncUdpSocket *serverSocket;

@property (nonatomic, strong) NSMutableData *testData;
@property (nonatomic, assign) NSInteger sendDataLength;

@property (nonatomic, strong) XCTestExpectation *expectation;

@end

@implementation GCDAsyncUdpSocketConnectionTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.portNumber = [self randomValidPort];
    self.clientSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    self.serverSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    self.testData = [NSMutableData data];
    
    NSData* data = [@"test-data-" dataUsingEncoding:NSUTF8StringEncoding];
    
    for (int i = 0; i < 7000; i ++)
    {
        [self.testData appendData:data];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    self.clientSocket = nil;
    self.serverSocket = nil;
    
    self.testData = nil;
}

- (uint16_t) randomValidPort {
    uint16_t minPort = 1024;
    uint16_t maxPort = UINT16_MAX;
    return minPort + arc4random_uniform(maxPort - minPort + 1);
}

- (uint16_t) randomLengthOfLargePacket {
    uint16_t minLength = 9217;
    uint16_t maxLength = UINT16_MAX;
    return minLength + arc4random_uniform(maxLength - minLength + 1);
}

- (uint32_t) randomLengthOfInvaildPacket {
    uint32_t minLength = 65536;
    uint32_t maxLength = (uint32_t)self.testData.length;
    return minLength + arc4random_uniform(maxLength - minLength + 1);
}

- (void)testSendBoardcastWithMicroPacket
{
    NSError * error = nil;
    BOOL success = NO;
    success = [self.serverSocket bindToPort:self.portNumber error:&error] && [self.serverSocket beginReceiving:&error];
    XCTAssertTrue(success, @"UDP Server failed setting up socket on port %d %@", self.portNumber, error);
    
    NSData * sendData = [self.testData subdataWithRange:NSMakeRange(0, arc4random_uniform(9217))];
    NSLog(@"Send data Length is %ld",sendData.length);
    self.sendDataLength = sendData.length;
    
    [self.clientSocket sendData:sendData toHost:@"127.0.0.1" port:self.portNumber withTimeout:30 tag:0];
    
    self.expectation = [self expectationWithDescription:@"Test Sending/Receving Micro Packet"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test sending/receving micro packet");
        }
    }];
}

- (void)testSendBoardcastWithLargePacket
{
    NSError * error = nil;
    BOOL success = NO;
    success = [self.serverSocket bindToPort:self.portNumber error:&error] && [self.serverSocket beginReceiving:&error];
    XCTAssertTrue(success, @"UDP Server failed setting up socket on port %d %@", self.portNumber, error);
    
    NSData * sendData = [self.testData subdataWithRange:NSMakeRange(0, [self randomLengthOfLargePacket])];
    NSLog(@"Send data Length is %ld",sendData.length);
    self.sendDataLength = sendData.length;
    [self.clientSocket sendData:sendData toHost:@"127.0.0.1" port:self.portNumber withTimeout:30 tag:0];
    
    self.expectation = [self expectationWithDescription:@"Test Sending/Receving Large Packet"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test sending/receving large Packet");
        }
    }];
}

- (void)testSendBoardcastWithInvaildPacket
{
    NSError * error = nil;
    BOOL success = NO;
    success = [self.serverSocket bindToPort:self.portNumber error:&error] && [self.serverSocket beginReceiving:&error];
    XCTAssertTrue(success, @"UDP Server failed setting up socket on port %d %@", self.portNumber, error);
    
    NSData * sendData = [self.testData subdataWithRange:NSMakeRange(0, [self randomLengthOfInvaildPacket])];
    NSLog(@"Send data Length is %ld",sendData.length);
    self.sendDataLength = sendData.length;
    [self.clientSocket sendData:sendData toHost:@"127.0.0.1" port:self.portNumber withTimeout:30 tag:0];
    
    self.expectation = [self expectationWithDescription:@"Test Sending/Receving Invaild Packet"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing test sending/receving invaild packet");
        }
    }];
}

- (void)testAlterMaxSendBufferSizeWithVaildValue
{
    NSError * error = nil;
    BOOL success = NO;
    
    uint16_t dataLength = arc4random_uniform(UINT16_MAX);
    NSLog(@"random data length is %hu",dataLength);
    
    success = [self.serverSocket bindToPort:self.portNumber error:&error] && [self.serverSocket beginReceiving:&error];
    XCTAssertTrue(success, @"UDP Server failed setting up socket on port %d %@", self.portNumber, error);
    
    NSData * sendData = [self.testData subdataWithRange:NSMakeRange(0, dataLength)];
    NSLog(@"Send data Length is %ld",sendData.length);
    
    self.clientSocket.maxSendBufferSize = dataLength;
    [self.clientSocket sendData:sendData toHost:@"127.0.0.1" port:self.portNumber withTimeout:30 tag:0];
    self.sendDataLength = dataLength;
    XCTAssertTrue(self.clientSocket.maxSendBufferSize == dataLength, @"Alter socket maxSendBufferSize fail on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Altering maxSendBufferSize With Vaild Value"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing altering maxSendBufferSize with vaild value ");
        }
    }];
}

- (void)testAlterMaxSendBufferSizeWithInvaildValue
{
    NSError * error = nil;
    BOOL success = NO;
    
    uint16_t dataLength = arc4random_uniform(UINT16_MAX);
    NSLog(@"random data length is %hu",dataLength);
    
    success = [self.serverSocket bindToPort:self.portNumber error:&error] && [self.serverSocket beginReceiving:&error];
    XCTAssertTrue(success, @"UDP Server failed setting up socket on port %d %@", self.portNumber, error);
    
    NSData * sendData = [self.testData subdataWithRange:NSMakeRange(0, dataLength + 1)];
    NSLog(@"Send data Length is %ld",sendData.length);
    
    self.clientSocket.maxSendBufferSize = dataLength;
    [self.clientSocket sendData:sendData toHost:@"127.0.0.1" port:self.portNumber withTimeout:30 tag:0];
    self.sendDataLength = dataLength;
    XCTAssertTrue(self.clientSocket.maxSendBufferSize == dataLength, @"Alter socket maxSendBufferSize fail on port %d %@", self.portNumber, error);
    
    self.expectation = [self expectationWithDescription:@"Test Altering maxSendBufferSize With Invaild Value"];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error establishing altering maxSendBufferSize with invaild value ");
        }
    }];
}

#pragma mark GCDAsyncUdpSocketDelegate methods
/**
 * Called when the datagram with the given tag has been sent.
 **/
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    NSLog(@"Send data");
}


- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error
{
    NSLog(@"Close socket, error is %@",error);
    [self.expectation fulfill];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(nullable id)filterContext
{
    XCTAssertTrue(data.length == self.sendDataLength, @"UDP packet is truncated on port %d", self.portNumber);
    NSLog(@"Receive data");
    [self.expectation fulfill];
}

\
@end
