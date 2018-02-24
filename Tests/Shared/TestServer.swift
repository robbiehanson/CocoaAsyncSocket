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
		let bundle = Bundle(for: TestServer.self)

		guard let url = bundle.url(forResource: "SecureSocketServer", withExtension: "p12") else {
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

	typealias Callback = TestSocket.Callback

	var onAccept: Callback = {}

	var port: UInt16 = 1234

	var lastAcceptedSocket: GCDAsyncSocket? = nil

	lazy var socket: GCDAsyncSocket = { [weak self] in
		let label = "com.asyncSocket.TestServerDelegate"
		let queue = DispatchQueue(label: label)

		return GCDAsyncSocket(delegate: self, delegateQueue: queue)
		}()

	func accept() -> TestSocket {
		let waiter = XCTWaiter(delegate: TestSocket.waiterDelegate)
		let didAccept = XCTestExpectation(description: "Accepted socket")

		self.onAccept = {
			didAccept.fulfill()
		}

		do {
			try self.socket.accept(onPort: self.port)
		}
		catch {
			fatalError("Failed to accept on port \(self.port): \(error)")
		}

		waiter.wait(for: [didAccept], timeout: 0.1)

		guard let accepted = self.lastAcceptedSocket else {
			fatalError("No socket connected")
		}

		let socket = TestSocket(socket: accepted)
		accepted.delegate = socket
		accepted.delegateQueue = socket.queue

		return socket
	}

	deinit {
		self.socket.disconnect()
	}
}

// MARK: GCDAsyncSocketDelegate

extension TestServer: GCDAsyncSocketDelegate {

	func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
		self.lastAcceptedSocket = newSocket

		self.onAccept()
		self.onAccept = {}
	}
}
