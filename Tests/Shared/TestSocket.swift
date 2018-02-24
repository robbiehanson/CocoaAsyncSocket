import CocoaAsyncSocket
import XCTest

/**
 *	Creates a wrapper for a GCDAsyncSocket connection providing a synchronous API useful for testing.
 */
class TestSocket: NSObject {

	/**
	 *  Identifies what end of the socket the instance represents.
	 */
	enum Role {
		case server, client
	}

	/**
	 *  Handles any expectation failures
	 */
	static var waiterDelegate: XCTWaiterDelegate? = nil

	static func connect(to server: TestServer) -> TestSocket {
		let socket = TestSocket()
		socket.connect(on: server.port)

		return socket
	}

	var socket: GCDAsyncSocket {
		didSet {
			socket.delegate = self
			socket.delegateQueue = self.queue
		}
	}

	let queue: DispatchQueue = DispatchQueue(label: "com.asyncSocket.TestSocketDelegate")

	// MARK: Convience callbacks

	typealias Callback = () -> Void

	var onSecure: Callback = {}
	var onRead: Callback = {}
	var onWrite: Callback = {}
	var onDisconnect: Callback = {}

	// MARK: Counters

	var bytesRead = 0
	var bytesWritten = 0

	override convenience init() {
		self.init(socket: GCDAsyncSocket())

		self.socket.delegate = self
		self.socket.delegateQueue = self.queue
	}

	init(socket: GCDAsyncSocket) {
		self.socket = socket
	}

	deinit {
		self.socket.disconnect()
	}
}

// MARK: Synchronous API

extension TestSocket {

	/**
	 *  Connects to the localhost `port`
	 */
	func connect(on port: UInt16) {
		do {
			try self.socket.connect(toHost: "localhost", onPort: port)
		}
		catch {
			XCTFail("Failed to connect on \(port): \(error)")
		}
	}

	/**
	 *	Reads the specified number of bytes
	 *
	 *	This method will wait until the `socket:didRead:withTag` is called or trigger a test
	 *  assertion if it takes too long.
	 */
	func read(bytes length: UInt) {
		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didRead = XCTestExpectation(description: "Read data")

		self.onRead = {
			didRead.fulfill()
		}

		self.socket.readData(toLength: length, withTimeout: 0.1, tag: 1)
		waiter.wait(for: [didRead], timeout: 0.5)

		self.bytesWritten += Int(length)
	}

	/**
	 *	Writes the specified number of bytes
	 *
	 *	This method will wait until the `socket:didWriteDataWithTag` is called or trigger a test
	 *  assertion if it takes too long.
	 */
	func write(bytes length: Int) {
		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didWrite = XCTestExpectation(description: "Wrote data")

		self.onWrite = {
			didWrite.fulfill()
		}

		let fakeData = Data(repeating: 0, count: length)
		self.socket.write(fakeData, withTimeout: 0.1, tag: 1)

		waiter.wait(for: [didWrite], timeout: 0.5)
	}

	/**
	 *  Starts the TLS for the provided `role`
	 *
	 *  The `callback` will be executed when `socketDidSecure:` is triggered.
	 */
	func startTLS(as role: Role, callback: Callback? = nil) {
		if let onSecure = callback {
			self.onSecure = onSecure
		}

		let settings: [String: NSObject]

		switch role {
		case .server:
			settings = [
				kCFStreamSSLPeerName as String: NSString(string: "SecureSocketServer"),
				kCFStreamSSLIsServer as String: NSNumber(value: true),
				kCFStreamSSLCertificates as String: NSArray(array: [TestServer.identity])
			]
		case .client:
			settings = [
				GCDAsyncSocketManuallyEvaluateTrust: NSNumber(value: true)
			]
		}

		self.socket.startTLS(settings)
	}
}

// MARK: GCDAsyncSocketDelegate

extension TestSocket: GCDAsyncSocketDelegate {

	func socketDidSecure(_ sock: GCDAsyncSocket) {
		self.onSecure()
		self.onSecure = {}
	}

	func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
		self.onWrite()
		self.onWrite = {}
	}

	func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
		self.bytesRead += data.count

		self.onRead()
		self.onRead = {}
	}

	func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
		self.onDisconnect()
		self.onDisconnect = {}
	}

	func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
		completionHandler(true) // Trust all the things!!
	}
}

// MARK: Factory

extension TestSocket {

	static func createPair() -> (client: TestSocket, accepted: TestSocket) {
		let server = TestServer()
		let client = TestSocket.connect(to: server)

		let accepted = server.accept()

		return (client, accepted)
	}

	static func createSecurePair() -> (client: TestSocket, accepted: TestSocket) {
		let (client, accepted) = self.createPair()

		let waiter = XCTWaiter(delegate: self.waiterDelegate)
		let didSecure = XCTestExpectation(description: "Socket did secure")
		didSecure.expectedFulfillmentCount = 2

		accepted.startTLS(as: .server) {
			didSecure.fulfill()
		}

		client.startTLS(as: .client) {
			didSecure.fulfill()
		}

		waiter.wait(for: [didSecure], timeout: 2.0)

		return (client, accepted)
	}
}
