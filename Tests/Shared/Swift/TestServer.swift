import CocoaAsyncSocket
import XCTest

/**
 *  A simple test wrapper around GCDAsyncSocket which acts as a server
 */
class TestServer: NSObject {

	/**
	 *	Creates a SecIdentity from the bundled SecureSocketServer.p12
	 *
	 *  For creating a secure connection, we need to start TLS with a valid identity. The one in
	 *  in SecureSocketServer.p12 is a self signed SSL sever cert that was creating following Apple's
	 *  "Creating Certificates for TLS Testing". No root CA is used, however.
	 *
	 *    https://developer.apple.com/library/content/technotes/tn2326/_index.html
	 *
	 *  Most of this code in the this method from Apple's examples on reading in the contents of a
	 *  p12.
	 *
	 *    https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity
	 */
	static var identity: SecIdentity = {

		guard let url = credentialsFileURL else {
			fatalError("Missing the server cert resource from the bundle")
		}

		do {
			let p12 = try Data(contentsOf: url) as CFData
			let options = [kSecImportExportPassphrase as String: "test"] as CFDictionary

			var rawItems: CFArray?

			guard SecPKCS12Import(p12, options, &rawItems) == errSecSuccess else {
				fatalError("Error in p12 import")
			}

			let items = rawItems as! Array<Dictionary<String,Any>>
			let identity = items[0][kSecImportItemIdentity as String] as! SecIdentity

			return identity
		}
		catch {
			fatalError("Could not create server certificate")
		}
	}()

    static private var credentialsFileURL: URL? {
        let fileName = "SecureSocketServer"
        let fileExtension = "p12"

    #if SWIFT_PACKAGE
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisSourceDirectory = thisSourceFile.deletingLastPathComponent()
        return thisSourceDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
    #else
        let bundle = Bundle(for: TestServer.self)
        return bundle.url(forResource: fileName, withExtension: fileExtension)
    #endif
    }

	private static func randomValidPort() -> UInt16 {
		let minPort = UInt32(1024)
		let maxPort = UInt32(UINT16_MAX)
		let value = maxPort - minPort + 1

		return UInt16(minPort + arc4random_uniform(value))
	}

	// MARK: Convenience Callbacks

	typealias Callback = TestSocket.Callback

	var onAccept: Callback = nil
	var onDisconnect: Callback = nil

	let port: UInt16 = TestServer.randomValidPort()
	let queue = DispatchQueue(label: "com.asyncSocket.TestServerDelegate")
	let socket: GCDAsyncSocket

	var lastAcceptedSocket: TestSocket? = nil

	override init() {
		self.socket = GCDAsyncSocket()
		super.init()

		self.socket.delegate = self
		self.socket.delegateQueue = self.queue
	}

	func accept() {
		do {
			try self.socket.accept(onPort: self.port)
		}
		catch {
			fatalError("Failed to accept on port \(self.port): \(error)")
		}
	}

	func close() {
		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didDisconnect = XCTestExpectation(description: "Server disconnected")

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

// MARK: GCDAsyncSocketDelegate

extension TestServer: GCDAsyncSocketDelegate {

	func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
		self.lastAcceptedSocket = TestSocket(socket: newSocket)

		self.onAccept?()
		self.onAccept = nil
	}

	func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
		self.onDisconnect?()
		self.onDisconnect = nil
	}
}

// MARK: Factory

extension TestServer {

	func createPair() -> (client: TestSocket, accepted: TestSocket) {
		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didConnect = XCTestExpectation(description: "Pair connected")
		didConnect.expectedFulfillmentCount = 2

		let client = TestSocket()

		self.onAccept = {
			didConnect.fulfill()
		}

		client.onConnect = {
			didConnect.fulfill()
		}

		self.accept()
		client.connect(on: self.port)

		let _ = waiter.wait(for: [didConnect], timeout: TestSocket.waiterTimeout)

		guard let accepted = self.lastAcceptedSocket else {
			fatalError("No socket connected on \(self.port)")
		}

		return (client, accepted)
	}

	func createSecurePair() -> (client: TestSocket, accepted: TestSocket) {
		let (client, accepted) = self.createPair()

		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didSecure = XCTestExpectation(description: "Socket did secure")
		didSecure.expectedFulfillmentCount = 2

		accepted.startTLS(as: .server) {
			didSecure.fulfill()
		}

		client.startTLS(as: .client) {
			didSecure.fulfill()
		}

        waiter.wait(for: [didSecure], timeout: TestSocket.waiterTimeout)

		return (client, accepted)
	}
}
