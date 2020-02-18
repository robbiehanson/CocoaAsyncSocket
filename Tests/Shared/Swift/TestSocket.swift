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
    static let waiterTimeout: TimeInterval = 5.0

	lazy var queue: DispatchQueue = { [unowned self] in
		return DispatchQueue(label: "com.asyncSocket.\(self)")
	}()

	let socket: GCDAsyncSocket

	// MARK: Convience callbacks

	typealias Callback = Optional<() -> Void>

	var onConnect: Callback = nil
	var onSecure: Callback = nil
	var onRead: Callback = nil
	var onWrite: Callback = nil
	var onDisconnect: Callback = nil

	// MARK: Counters

	var bytesRead = 0
	var bytesWritten = 0

	override convenience init() {
		self.init(socket: GCDAsyncSocket())
	}

	init(socket: GCDAsyncSocket) {
		self.socket = socket
		super.init()

		self.socket.delegate = self
		self.socket.delegateQueue = self.queue
	}

	func close() {
		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didDisconnect = XCTestExpectation(description: "Disconnected")

		self.queue.async {
			guard self.socket.isConnected else {
				didDisconnect.fulfill()
				return
			}

			self.onDisconnect = {
				didDisconnect.fulfill()
			}

			self.socket.disconnect()
		}

        waiter.wait(for: [didDisconnect], timeout: TestSocket.waiterTimeout)
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
		waiter.wait(for: [didRead], timeout: TestSocket.waiterTimeout)
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

		waiter.wait(for: [didWrite], timeout: TestSocket.waiterTimeout)

		self.bytesWritten += Int(length)
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

	func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
		self.onConnect?()
	}

	func socketDidSecure(_ sock: GCDAsyncSocket) {
		self.onSecure?()
	}

	func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
		self.onWrite?()
	}

	func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
		self.bytesRead += data.count
		self.onRead?()
	}

	func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
		self.onDisconnect?()
	}

	func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
		completionHandler(true) // Trust all the things!!
	}
}
