#import "ThreadPoolServer.h"

@interface HTTPServer (InternalAPI)

- (void)connectionDidDie:(NSNotification *)notification;

@end


@implementation ThreadPoolServer

- (id)init
{
	if(self = [super init])
	{
		// Initialize an array to reference all the threads
		runLoops = [[NSMutableArray alloc] initWithCapacity:THREAD_POOL_SIZE];
		
		#if THREAD_POOL_LOAD_BALANCE
			// Initialize an array to hold the number of connections being processed for each thread
			runLoopsLoad = [[NSMutableArray alloc] initWithCapacity:THREAD_POOL_SIZE];
		#else
			// Initialize run loop index
			nextRunLoopIndex = 0;
		#endif
		
		// Start threads
		NSUInteger i;
		for(i = 0; i < THREAD_POOL_SIZE; i++)
		{
			[NSThread detachNewThreadSelector:@selector(connectionThread:)
			                         toTarget:self
			                       withObject:[NSNumber numberWithUnsignedInteger:i]];
		}
	}
	return self;
}


- (void)connectionThread:(NSNumber *)threadNum
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@synchronized(runLoops)
	{
		[runLoops addObject:[NSRunLoop currentRunLoop]];
		
		#if THREAD_POOL_LOAD_BALANCE
			[runLoopsLoad addObject:[NSNumber numberWithUnsignedInteger:0]];
		#endif
	}
	
	NSLog(@"Starting thread %@", threadNum);
	
	// We can't run the run loop unless it has an associated input source or a timer.
	// So we'll just create a timer that will never fire - unless the server runs for 10,000 years.
	[NSTimer scheduledTimerWithTimeInterval:DBL_MAX target:self selector:@selector(ignore:) userInfo:nil repeats:NO];
	
	// Start the run loop
	[[NSRunLoop currentRunLoop] run];
	
	[pool release];
}

/**
 * Called when a new socket is spawned to handle a connection.  This method should return the runloop of the
 * thread on which the new socket and its delegate should operate. If omitted, [NSRunLoop currentRunLoop] is used.
**/
- (NSRunLoop *)onSocket:(AsyncSocket *)sock wantsRunLoopForNewSocket:(AsyncSocket *)newSocket
{
	// Figure out what thread/runloop to run the new connection on.
	
	#if THREAD_POOL_LOAD_BALANCE
	
	// We choose the thread/runloop with the lowest number of connections.
	
	NSRunLoop *mLoop = nil;
	NSUInteger m = 0;
	NSUInteger mLoad = 0;
	
	@synchronized(runLoops)
	{
		mLoop = [runLoops objectAtIndex:0];
		mLoad = [[runLoopsLoad objectAtIndex:0] unsignedIntegerValue];
		
		NSUInteger i;
		for(i = 1; i < THREAD_POOL_SIZE; i++)
		{
			NSUInteger iLoad = [[runLoopsLoad objectAtIndex:i] unsignedIntegerValue];
			
			if (iLoad < mLoad)
			{
				mLoop = [runLoops objectAtIndex:i];
				m = i;
				mLoad = iLoad;
			}
		}
		
		[runLoopsLoad replaceObjectAtIndex:m withObject:[NSNumber numberWithUnsignedInteger:(mLoad + 1)]];
	}
	
//	NSLog(@"Choosing run loop %u with load %u", m, mLoad);
	
	return mLoop;
	
	#else
	
	NSRunLoop *runLoop = [runLoops objectAtIndex:nextRunLoopIndex];
	
	nextRunLoopIndex++;
	if (nextRunLoopIndex >= THREAD_POOL_SIZE)
		nextRunLoopIndex = 0;
	
	return runLoop;
	
	#endif
}

/**
 * This method is automatically called when a HTTPConnection dies.
 * We need to update the number of connections per thread.
**/
- (void)connectionDidDie:(NSNotification *)notification
{
	// Note: This method is called on the thread/runloop that posted the notification
	
	#if THREAD_POOL_LOAD_BALANCE
	
	@synchronized(runLoops)
	{
		NSUInteger runLoopIndex = [runLoops indexOfObject:[NSRunLoop currentRunLoop]];
		
		if (runLoopIndex < [runLoops count])
		{
			NSUInteger runLoopLoad = [[runLoopsLoad objectAtIndex:runLoopIndex] unsignedIntegerValue];
			
			NSNumber *newLoad = [NSNumber numberWithUnsignedInteger:(runLoopLoad - 1)];
			
			[runLoopsLoad replaceObjectAtIndex:runLoopIndex withObject:newLoad];
			
		//	NSLog(@"Updating run loop %u with load %@", runLoopIndex, newLoad);
		}
	}
	
	#endif
	
	// Don't forget to call super, or the connection won't get proper deallocated!
	[super connectionDidDie:notification];
}

@end
