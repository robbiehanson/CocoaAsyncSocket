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
    
    var portNumber: UInt16 = 0
    var clientSocket: GCDAsyncSocket?
    var serverSocket: GCDAsyncSocket?
    var acceptedServerSocket: GCDAsyncSocket?
    var expectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        portNumber = randomValidPort()
        clientSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
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
    
    fileprivate func randomValidPort() -> UInt16 {
        let minPort = UInt32(1024)
        let maxPort = UInt32(UINT16_MAX)
        let value = maxPort - minPort + 1
        return UInt16(minPort + arc4random_uniform(value))
    }

    func testFullConnection() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        do {
            try serverSocket?.accept(onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        do {
            try clientSocket?.connect(toHost: "127.0.0.1", onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        expectation = self.expectation(description: "Test Full connnection")
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testConnectionWithAnIPv4OnlyServer() {
        serverSocket?.isIPv6Enabled = false
        do {
            try serverSocket?.accept(onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        do {
            try clientSocket?.connect(toHost: "127.0.0.1", onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        expectation = self.expectation(description: "Test Full connnection")
        waitForExpectations(timeout: 30, handler: { (error) in
            if let error = error {
                XCTFail("\(error)")
            }
            else {
                if let isIPv4 = self.acceptedServerSocket?.isIPv4 {
                    XCTAssertTrue(isIPv4)
                }
            }
        })
    }

    func testConnectionWithAnIPv6OnlyServer() {
        serverSocket?.isIPv4Enabled = false
        do {
            try serverSocket?.accept(onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        do {
            try clientSocket?.connect(toHost: "::1", onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        expectation = self.expectation(description: "Test Full connnection")
        waitForExpectations(timeout: 30, handler: { (error) in
            if let error = error {
                XCTFail("\(error)")
            }
            else {
                if let isIPv6 = self.acceptedServerSocket?.isIPv6 {
                    XCTAssertTrue(isIPv6)
                }
            }
        })
    }
    
    func testConnectionWithLocalhostWithClientPreferringIPv4() {
        clientSocket?.isIPv4PreferredOverIPv6 = true
        
        do {
            try serverSocket?.accept(onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        do {
            try clientSocket?.connect(toHost: "localhost", onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        expectation = self.expectation(description: "Test Full connnection")
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testConnectionWithLocalhostWithClientPreferringIPv6() {
        clientSocket?.isIPv4PreferredOverIPv6 = false
        
        do {
            try serverSocket?.accept(onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        do {
            try clientSocket?.connect(toHost: "localhost", onPort: portNumber)
        } catch {
            XCTFail("\(error)")
        }
        expectation = self.expectation(description: "Test Full connnection")
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    //MARK:- GCDAsyncSocketDelegate
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        NSLog("didAcceptNewSocket %@ %@", sock, newSocket)
        acceptedServerSocket = newSocket
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        NSLog("didConnectToHost %@ %@ %d", sock, host, port);
        expectation?.fulfill()
    }
    
    
}
