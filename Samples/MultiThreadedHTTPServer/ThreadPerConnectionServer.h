//
//  The ThreadPerConnectionServer creates a new thread for every incoming connection.
//  After the thread is created, the connection is moved to the new thread.
//
//  This is for DEMONSTRATION purposes only, and this technique will not scale well.
//  Please understand the cost of creating threads on your target platform.
//

#import "HTTPServer.h"
#import "HTTPConnection.h"

@interface ThreadPerConnectionServer : HTTPServer
{

}

@end

@interface TPCConnection : HTTPConnection
{
	NSRunLoop *myRunLoop;
	BOOL continueRunLoop;
}

@end