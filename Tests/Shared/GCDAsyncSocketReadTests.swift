import XCTest
import CocoaAsyncSocket

class GCDAsyncSocketReadTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        TestSocket.waiterDelegate = self
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func test_repeatedConnections() {
        let maxIterations = 100
        for i in 0..<maxIterations {
            debugPrint("Running test #\(i)/\(maxIterations)")
            test_whenBytesAvailableIsLessThanReadLength_readDoesNotTimeout()
        }
    }

	func test_whenBytesAvailableIsLessThanReadLength_readDoesNotTimeout() {
        let (client, server) = TestSocket.createSecurePair()

		// Write once to fire the readSource on the client, also causing the
		// readSource to be suspended.
		server.write(bytes: 1024 * 50)

		// Write a second time to ensure there is more on the socket than in the
		// "estimatedBytesAvailable + 16kb" upperbound in our SSLRead.
		server.write(bytes: 1024 * 50)

		// Ensure our socket is not disconnected when we attempt to read everything in
		client.onDisconnect = {
			XCTFail("Socket was disconnected")
		}

		// Ensure our read does not timeout.
		client.read(bytes: 1024 * 100)

		XCTAssertEqual(client.bytesRead, 1024 * 100)
	}
}
