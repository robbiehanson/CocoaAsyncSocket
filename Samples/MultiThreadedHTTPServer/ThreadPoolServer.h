//
//  The ThreadPoolServer uses a pool of threads to handle connections.
//  Each incoming connection is moved to a thread within the thread pool.
//  We attempt to evenly spread the connections between the threads.
//  To do this, we maintain the number of connections that are on each thread.
//  A new incoming connection will be placed on the thread with the least connections.
//

#import "HTTPServer.h"
#import "HTTPConnection.h"

// Define number of connection threads to run
#define THREAD_POOL_SIZE  4

// Attempt primitive load balancing of thread pool
#define THREAD_POOL_LOAD_BALANCE 0

@interface ThreadPoolServer : HTTPServer
{
	NSMutableArray *runLoops;
	
#if THREAD_POOL_LOAD_BALANCE
	NSMutableArray *runLoopsLoad;
#else
	int nextRunLoopIndex;
#endif	
}

@end
