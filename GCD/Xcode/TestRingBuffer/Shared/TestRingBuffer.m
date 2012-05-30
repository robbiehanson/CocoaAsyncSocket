#import "TestRingBuffer.h"
#import <Security/SecRandom.h>
#import <mach/mach.h>

#define COUNT 25000

/**
 * Interface definition copied from GCDAsyncSocket.m (to make it public for testing).
 * 
 * The implementation itself remains within GCDAsyncSocket.m
**/

@interface GCDAsyncSocketRingBuffer : NSObject

- (id)initWithCapacity:(size_t)numBytes;

- (void)ensureCapacityForWrite:(size_t)numBytes;

- (size_t)availableBytes;
- (uint8_t *)readBuffer;

- (void)getReadBuffer:(uint8_t **)bufferPtr availableBytes:(size_t *)availableBytesPtr;

- (size_t)availableSpace;
- (uint8_t *)writeBuffer;

- (void)getWriteBuffer:(uint8_t **)bufferPtr availableSpace:(size_t *)availableSpacePtr;

- (void)didRead:(size_t)bytesRead;
- (void)didWrite:(size_t)bytesWritten;

- (void)reset;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface TestRingBuffer ()

+ (void)test_ringBuffer;

+ (void)benchmark_mutableData;
+ (void)benchmark_ringBuffer;

@end


@implementation TestRingBuffer

static size_t bufferSize;

static int randomSize1;
static int randomSize2;

+ (void)start
{
	// Run unit tests
	
	[self test_ringBuffer];
	
	// Setup benchmarks.
	// 
	// We're going to test a common pattern within GCDAsyncSocket, which is:
	// - write a chunk of data to the preBuffer
	// - read a chunk of data out of the preBuffer
	// - read another chunk of data out of the preBuffer
	
	bufferSize = vm_page_size * 2;
	
	randomSize1 = (arc4random() % (bufferSize / 2));
	randomSize2 = (arc4random() % (bufferSize / 2));
	
	// Run benchmarks (on different runloop cycles to be fair)
	
	[self performSelector:@selector(benchmark_mutableData) withObject:nil afterDelay:2.0];
	[self performSelector:@selector(benchmark_ringBuffer)  withObject:nil afterDelay:4.0];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Unit Tests
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)test_ringBuffer
{
	GCDAsyncSocketRingBuffer *ringBuffer = [[GCDAsyncSocketRingBuffer alloc] initWithCapacity:1024];
	
	size_t capacity = [ringBuffer availableSpace];
	
	NSAssert([ringBuffer availableSpace] >= 1024, @"1A");
	NSAssert([ringBuffer availableBytes] == 0, @"1B");
	
	uint8_t *writePointer1;
	uint8_t *writePointer2;
	
	writePointer1 = [ringBuffer writeBuffer];
	[ringBuffer didWrite:512];
	writePointer2 = [ringBuffer writeBuffer];
	
	NSAssert(writePointer2 - writePointer1 == 512, @"2A");
	NSAssert([ringBuffer availableBytes] == 512, @"2B");
	
	uint8_t *readPointer1;
	uint8_t *readPointer2;
	
	readPointer1 = [ringBuffer readBuffer];
	[ringBuffer didRead:256];
	readPointer2 = [ringBuffer readBuffer];
	
	NSAssert(readPointer2 - readPointer1 == 256, @"3A");
	NSAssert([ringBuffer availableBytes] == 256, @"3B");
	
	[ringBuffer didRead:256];
	
	NSAssert([ringBuffer availableBytes] == 0, @"4A");
	NSAssert([ringBuffer availableSpace] == capacity, @"4B");
	
	char *str = "test";
	size_t strLen = strlen(str);
	
	memcpy([ringBuffer writeBuffer], str, strLen);
	[ringBuffer didWrite:strLen];
	
	NSAssert([ringBuffer availableBytes] == strLen, @"5A");
	NSAssert(memcmp([ringBuffer readBuffer], str, strLen) == 0, @"5B");
	
	[ringBuffer ensureCapacityForWrite:(capacity * 2)];
	
	NSAssert([ringBuffer availableSpace] >= (capacity * 2), @"6A");
	NSAssert([ringBuffer availableBytes] == strLen, @"6B");
	NSAssert(memcmp([ringBuffer readBuffer], str, strLen) == 0, @"6C");
	
	NSLog(@"%@: passed", NSStringFromSelector(_cmd));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Benchmarks
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)benchmark_mutableData
{
	NSMutableData *data = [[NSMutableData alloc] initWithCapacity:bufferSize];
	
	void *readBuffer  = malloc(bufferSize);
	void *writeBuffer = malloc(bufferSize);
	
	SecRandomCopyBytes(kSecRandomDefault, (randomSize1+randomSize2), writeBuffer);
	
	NSDate *start = [NSDate date];
	
	int i;
	for (i = 0; i < COUNT; i++)
	{
		// Copy data into buffer.
		// Simulate reading from socket into preBuffer.
		
		[data appendBytes:writeBuffer length:(randomSize1+randomSize2)];
		
		// Read 1st chunk.
		// Simulate reading partial data out of preBuffer.
		
		memcpy(readBuffer, [data mutableBytes], randomSize1);
		[data replaceBytesInRange:NSMakeRange(0, randomSize1) withBytes:NULL length:0];
		
		// Read 2nd chunk.
		// Simulate draining preBuffer.
		
		memcpy(readBuffer+randomSize1, [data mutableBytes], randomSize2);
		[data replaceBytesInRange:NSMakeRange(0, randomSize2) withBytes:NULL length:0];
	}
	
	NSTimeInterval elapsed = [start timeIntervalSinceNow] * -1.0;
	NSLog(@"%@: elapsed = %.6f", NSStringFromSelector(_cmd), elapsed);
	
	free(readBuffer);
	free(writeBuffer);
}

+ (void)benchmark_ringBuffer
{
	GCDAsyncSocketRingBuffer *ringBuffer = [[GCDAsyncSocketRingBuffer alloc] initWithCapacity:bufferSize];
	
	void *readBuffer  = malloc(bufferSize);
	void *writeBuffer = malloc(bufferSize);
	
	SecRandomCopyBytes(kSecRandomDefault, (randomSize1+randomSize2), writeBuffer);
	
	uint8_t *ringWriteBuffer;
	size_t availableSpace;
	
	uint8_t *ringReadBuffer;
	size_t availableBytes;
	
	NSDate *start = [NSDate date];
	
	int i;
	for (i = 0; i < COUNT; i++)
	{
		// Copy data into buffer.
		// Simulate reading from socket into preBuffer.
		
		[ringBuffer getWriteBuffer:&ringWriteBuffer availableSpace:&availableSpace];
		
		memcpy(ringWriteBuffer, writeBuffer, randomSize1+randomSize2);
		[ringBuffer didWrite:(randomSize1+randomSize2)];
		
		// Read 1st chunk.
		// Simulate reading partial data out of preBuffer.
		
		[ringBuffer getReadBuffer:&ringReadBuffer availableBytes:&availableBytes];
		
		memcpy(readBuffer, ringReadBuffer, randomSize1);
		[ringBuffer didRead:randomSize1];
		
		// Read 2nd chunk.
		// Simulate draining preBuffer.
		
		[ringBuffer getReadBuffer:&ringReadBuffer availableBytes:&availableBytes];
		
		memcpy(readBuffer+randomSize1, ringReadBuffer, randomSize2);
		[ringBuffer didRead:randomSize2];
	}
	
	NSTimeInterval elapsed = [start timeIntervalSinceNow] * -1.0;
	NSLog(@"%@ : elapsed = %.6f", NSStringFromSelector(_cmd), elapsed);
	
	free(readBuffer);
	free(writeBuffer);
}


@end
