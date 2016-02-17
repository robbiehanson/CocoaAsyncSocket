//
//  SwiftTests.swift
//  CocoaAsyncSocket
//
//  Created by Chris Ballinger on 2/17/16.
//
//

import XCTest
import CocoaAsyncSocket

class SwiftTests: XCTestCase, GCDAsyncSocketDelegate {
    
    let kTestPort: UInt16 = 30301
    
    var clientSocket: GCDAsyncSocket?
    var serverSocket: GCDAsyncSocket?
    var acceptedServerSocket: GCDAsyncSocket?
    var expectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        clientSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        clientSocket?.disconnect()
        serverSocket?.disconnect()
        acceptedServerSocket?.disconnect()
        clientSocket = nil
        serverSocket = nil
        acceptedServerSocket = nil
    }

    func testFullConnection() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        do {
            try serverSocket?.acceptOnPort(kTestPort)
        } catch {
            XCTFail("\(error)")
        }
        do {
            try clientSocket?.connectToHost("127.0.0.1", onPort: kTestPort)
        } catch {
            XCTFail("\(error)")
        }
        expectation = expectationWithDescription("Test Full connnection")
        waitForExpectationsWithTimeout(30) { (error: NSError?) -> Void in
            if error != nil {
                XCTFail("\(error)")
            }
        }
    }

    
    //MARK:- GCDAsyncSocketDelegate
    func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        NSLog("didAcceptNewSocket %@ %@", sock, newSocket)
        acceptedServerSocket = newSocket
    }
    
    func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        NSLog("didConnectToHost %@ %@ %d", sock, host, port);
        expectation?.fulfill()
    }
    
    
}
