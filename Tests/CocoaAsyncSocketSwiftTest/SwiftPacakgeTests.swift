import XCTest
import Foundation
import CocoaAsyncSocket

class SwiftPacakgeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testInit() {
        
        let socket = GCDAsyncSocket()
        XCTAssert(socket.connectedUrl == nil)
    }
    
}
