#import <Foundation/Foundation.h>
#import "../AsyncSocket.h"

#pragma mark Interface

@interface EchoServer : NSObject
{
	NSMutableArray *sockets;
}
-(id) init;
-(void) dealloc;
-(void) acceptOnPortString:(NSString *)str;
-(void) onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
-(void) onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket;
-(void) onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
-(void) onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag;
-(void) onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag;
@end

#pragma mark -
#pragma mark Implementation

@implementation EchoServer


/*
 This method sets up the accept socket, but does not actually start it.
 Once started, the accept socket accepts incoming connections and creates new
 instances of AsyncSocket to handle them.
 Echo Server keeps the accept socket in index 0 of the sockets array and adds
 incoming connections at indices 1 and up.
*/
-(id) init
{
	self = [super init];
	sockets = [[NSMutableArray alloc] initWithCapacity:2];

	AsyncSocket *acceptor = [[AsyncSocket alloc] initWithDelegate:self];
	[sockets addObject:acceptor];
	[acceptor release];
	return self;
}


/*
 This method will never get called, because you'll be using Ctrl-C to exit the
 app.
*/
-(void) dealloc
{
	// Releasing a socket will close it if it is connected or listening.
	[sockets release];
	[super dealloc];
}


/*
 This method actually starts the accept socket. It is the first thing called by
 the run-loop.
*/
- (void) acceptOnPortString:(NSString *)str
{
	// AsyncSocket requires a run-loop.
	NSAssert ([[NSRunLoop currentRunLoop] currentMode] != nil, @"Run loop is not running");
	
	UInt16 port = [str intValue];
	AsyncSocket *acceptor = (AsyncSocket *)[sockets objectAtIndex:0];

	NSError *err = nil;
	if ([acceptor acceptOnPort:port error:&err])
		NSLog (@"Waiting for connections on port %u.", port);
	else
	{
		// If you get a generic CFSocket error, you probably tried to use a port
		// number reserved by the operating system.
		
		NSLog (@"Cannot accept connections on port %u. Error domain %@ code %d (%@). Exiting.", port, [err domain], [err code], [err localizedDescription]);
		exit(1);
	}
}


/*
 This will be called whenever AsyncSocket is about to disconnect. In Echo Server,
 it does not do anything other than report what went wrong (this delegate method
 is the only place to get that information), but in a more serious app, this is
 a good place to do disaster-recovery by getting partially-read data. This is
 not, however, a good place to do cleanup. The socket must still exist when this
 method returns.
 
 I do not implement -onSocketDidDisconnect:. Normally, that is where you would
 release the disconnected socket and perform housekeeping, but I am satisfied
 to leave the disconnected socket instances alone until Echo Server quits.
*/
-(void) onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if (err != nil)
		NSLog (@"Socket will disconnect. Error domain %@, code %d (%@).",
			   [err domain], [err code], [err localizedDescription]);
	else
		NSLog (@"Socket will disconnect. No error.");
}


/*
 This method is called when a connection is accepted and a new socket is created.
 This is a good place to perform housekeeping and re-assignment -- assigning an
 controller for the new socket, or retaining it. Here, I add it to the array of
 sockets. However, the new socket has not yet connected and no information is
 available about the remote socket, so this is not a good place to screen incoming
 connections. Use onSocket:didConnectToHost:port: for that.
*/
-(void) onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	NSLog (@"Socket %d accepting connection.", [sockets count]);
	[sockets addObject:newSocket];
}


/*
 At this point, the new socket is ready to use. This is where you can screen the
 remote socket or find its DNS name (the host parameter is just an IP address).
 This is also where you should set up your initial read or write request, unless
 you have a particular reason for delaying it.
*/
-(void) onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	NSLog (@"Socket %d successfully accepted connection from %@ %u.", [sockets indexOfObject:sock], host, port);
	NSData *newline = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];

	// In Echo Server, each packet consists of a line of text, delimited by "\n".
	// This is not a technique you should use. I do not know what "\n" actually
	// means in terms of bytes. It could be CR, LF, or CRLF.
	//
	// In your own networking protocols, you must be more explicit. AsyncSocket 
	// provides byte sequences for each line ending. These are CRData, LFData,
	// and CRLFData. You should use one of those instead of "\n".
	
	// Start reading.
	[sock readDataToData:newline withTimeout:-1 tag:[sockets indexOfObject:sock]];
}


/*
 This method is called whenever a packet is read. In Echo Server, a packet is
 simply a line of text, and it is transmitted to the connected Echo clients.
 Once you have dealt with the incoming packet, you should set up another read or
 write request, or -- unless there are other requests queued up -- AsyncSocket
 will sit idle.
*/
-(void) onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
	NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

	// Print string.
	NSString *trimStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
	[str release];
	NSLog (@"Socket %d sent text \"%@\".", tag, trimStr);

	// Forward string to other sockets.
	int i; for (i = 1; i < [sockets count]; ++i)
		[(AsyncSocket *)[sockets objectAtIndex:i] writeData:data withTimeout:-1 tag:i];

	// Read more from this socket.
	NSData *newline = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
	[sock readDataToData:newline withTimeout:-1 tag:tag];
}


/*
 This method is called when AsyncSocket has finished writing something. Echo
 Server does not need to do anything after writing, but your own app might need
 to wait for a command from the remote application, or begin writing the next
 packet.
*/
-(void) onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	NSLog (@"Wrote to socket %d.", tag);
}

@end

#pragma mark -
#pragma mark Main

int main (int argc, const char * argv[])
{
	printf ("ECHO SERVER by Dustin Voss copyright 2003. Sample code for using AsyncSocket.");
	printf ("\nSYNTAX: %s port", argv[0]);
	printf ("\nAccepts multiple connections from ECHO clients, echoing any client to all\nclients.\n");
	if (argc != 2) exit(1);
	
	printf ("Press Ctrl-C to exit.\n");
	fflush (stdout);

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	EchoServer *es = [[EchoServer alloc] init];
	NSString *portString = [NSString stringWithCString:argv[1]];

	// Here, I use perform...afterDelay to put an action on the run-loop before
	// it starts running. That action will actually start the accept socket, and
	// AsyncSocket will then be able to create other activity on the run-loop.
	// But main() will have no other opportunity to do so; the run-loop does not
	// give me any way in, other than the AsyncSocket delegate methods.

	// Note that I cannot call AsyncSocket's -acceptOnPort:error: outside of the
	// run-loop.
	
	[es performSelector:@selector(acceptOnPortString:) withObject:portString afterDelay:1.0];
	[[NSRunLoop currentRunLoop] run];
	[EchoServer release];
	[pool release];

	return 0;
}
