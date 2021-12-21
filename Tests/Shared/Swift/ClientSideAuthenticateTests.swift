import XCTest
import CocoaAsyncSocket

class ClientSideAuthenticateTests: XCTestCase {
    var server: TestServer!
    var client: TestSocket!
    var accepted: TestSocket!
    
    override func setUp() {
        server = TestServer()
        (client, accepted) = server.createPair()
    }
    
    override func tearDown() {
        client.close()
        accepted.close()
        server.close()
    }
    
    func testAlwaysAuthenticateClient() {
        let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
        let didSecure = XCTestExpectation(description: "Socket did secure")
        didSecure.expectedFulfillmentCount = 2
        let didReceiveTrust = XCTestExpectation(description: "Socket did receive trust")

        accepted.onReceiveTrust = { _ in
            didReceiveTrust.fulfill()
            return true
        }
        accepted.startTLS(as: .server, additionalSettings: [
            GCDAsyncSocketManuallyEvaluateTrust: NSNumber(value: true),
            GCDAsyncSocketSSLClientSideAuthenticate: NSNumber(value: SSLAuthenticate.alwaysAuthenticate.rawValue),
        ]) {
            didSecure.fulfill()
        }

        client.startTLS(as: .client) {
            didSecure.fulfill()
        }

        waiter.wait(for: [didReceiveTrust, didSecure], timeout: TestSocket.waiterTimeout)
    }
    
    func testTryAuthenticateClient() {
        let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
        let didSecure = XCTestExpectation(description: "Socket did secure")
        didSecure.expectedFulfillmentCount = 2
        let didReceiveTrust = XCTestExpectation(description: "Socket did receive trust")
        
        accepted.onReceiveTrust = { _ in
            didReceiveTrust.fulfill()
            return true
        }
        accepted.startTLS(as: .server, additionalSettings: [
            GCDAsyncSocketManuallyEvaluateTrust: NSNumber(value: true),
            GCDAsyncSocketSSLClientSideAuthenticate: NSNumber(value: SSLAuthenticate.tryAuthenticate.rawValue),
        ]) {
            didSecure.fulfill()
        }

        client.startTLS(as: .client) {
            didSecure.fulfill()
        }

        waiter.wait(for: [didReceiveTrust, didSecure], timeout: TestSocket.waiterTimeout)
    }
    
    func testDoNotManuallyEvaluate() {
        let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
        let didSecure = XCTestExpectation(description: "Socket did secure")
        didSecure.expectedFulfillmentCount = 2
        
        accepted.onReceiveTrust = { _ in
            XCTFail("Socket should not receive trust")
            return false
        }
        accepted.startTLS(as: .server) {
            didSecure.fulfill()
        }

        client.startTLS(as: .client) {
            didSecure.fulfill()
        }

        waiter.wait(for: [didSecure], timeout: TestSocket.waiterTimeout)
    }
}
