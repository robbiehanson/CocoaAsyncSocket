#import <Foundation/Foundation.h>
#import <CoreFoundation/CFStream.h>
#import "../AsyncSocket.h"
#include <fcntl.h>
#include <unistd.h>

#pragma mark Declarations

@interface Echo : NSObject
{
	BOOL shouldExitLoop;
	AsyncSocket *socket;
	NSMutableString *text;
}
-(id)init;
-(void)dealloc;
-(void)runLoop;
-(void)stopRunLoop;
-(void)readFromServer;
-(void)readFromStdIn;
-(void)doTextCommand;
-(void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
-(void)onSocketDidDisconnect:(AsyncSocket *)sock;
-(void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
-(void)onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)t;
@end

void showHelp();

#pragma mark -
#pragma mark Implementation

@implementation Echo : NSObject


/*
 This method creates the socket. Echo reuses this one socket throughout its life.
 Echo also sets up the input. While a command-line app is waiting for input, it
 is usually blocked; I make the input non-blocking so that the run-loop remains
 active.
*/
- (id)init
{
	self = [super init];

	// Create socket.
	NSLog (@"Creating socket.");
	socket = [[AsyncSocket alloc] initWithDelegate:self];
	
	// Create command buffer.
	text = [[NSMutableString alloc] init];
	
	// Set up stdin for non-blocking.
	if (fcntl (STDIN_FILENO, F_SETFL, O_NONBLOCK) == -1)
	{
		NSLog (@"Can't make STDIN non-blocking.");
		exit(1);
	}
	
	return self;
}


/*
 I release allocated resources here, including the socket. The socket will close
 any connection before releasing itself, but it will not need to. I explicitly
 close any connections in the "quit" command handler.
*/
- (void)dealloc
{
	[socket release];
	[text release];
	[super dealloc];
}


/*
 Echo spends one second handling any run-loop activity (i.e. socket activity)
 and then comes up for air to check if any new commands have been entered and,
 if so, executing them. Wash, rinse, repeat.

 Note the use of the shouldExitLoop flag to control when the run-loop ends and
 the app quits. I could have just called exit(), but this allows the app to clean
 up after itself properly. You should use a similar technique if you create a
 thread for socket activity and processing.
*/
- (void)runLoop
{
	shouldExitLoop = NO;
	while (!shouldExitLoop)
	{
		[self readFromStdIn];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	}
}


/* This method just abstracts the stop-run-loop operation. */
- (void)stopRunLoop
{
	shouldExitLoop = YES;
}


/*
 This method simply abstracts the read-from-server operation. It is called
 from -onSocket:didReadData:withTag: to set up another read operation. If it did
 not set up another read operation, AsyncSocket would not do anything with any
 further packets from Echo Server.
 
 You should not use "\n" as a packet delimiter in your own code. I explain why
 in EchoServerMain.c.
*/
- (void)readFromServer
{
	NSData *newline = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
	[socket readDataToData:newline withTimeout:-1 tag:0];
}


/*
 This method queues up a message that will be sent immediately upon connecting
 to Echo Server. Note that the message consists of two write requests. They will
 be sent consecutively, though, and will appear as one packet to Echo Server,
 because Echo Server looks for the "\n" to determine when the packet ends.
*/
- (void)prepareHello
{
	// Yes, you can call methods on NSString constants.
	
	NSData *message =
		[@"Hello, Echo Server! " dataUsingEncoding:NSASCIIStringEncoding];

	NSData *newline =
		[@"I am a new client.\n" dataUsingEncoding:NSASCIIStringEncoding];

	[socket writeData:message withTimeout:-1 tag:0];
	[socket writeData:newline withTimeout:-1 tag:0];
};


/*
 I only runs the run-loop for a second at a time, because I need to receive and
 act on input from the user (which won't result in run-loop activity).
 That happens here.
*/
- (void)readFromStdIn
{
	Byte c;
	while (read (STDIN_FILENO, &c, 1) == 1)
	{
		[text appendString: [NSString stringWithFormat:@"%c", c]];
		if (c == '\n') [self doTextCommand];
	}
}


/*
 This method sends text to Echo Server, or executes a command.
*/
- (void)doTextCommand
{
	NSArray *params = [text componentsSeparatedByString:@" "];
	if ([text hasPrefix: @"quit"] || [text hasPrefix: @"exit"])
	{
		// I don't technically need to call -disconnect here. When the app quits,
		// the socket will disconnect itself if needed. But it is easier to keep
		// track of here. Note that -onSocket:willDisconnectWithError: will NOT
		// be called here, though -onSocketDidDisconnect: will be.
		
		// I stop the run loop like a gentleman instead of simply calling exit()
		// so that the app exits cleanly. This is also technically unnecessary;
		// the OS will destroy the socket connection when it cleans up after the
		// process.  
		
		NSLog (@"Disconnecting & exiting.");
		[socket disconnect];
		[self stopRunLoop];
	}
	else if ([text hasPrefix: @"disconnect"])
	{
		NSLog (@"Disconnecting.");
		[socket disconnect];
	}
	else if ([text hasPrefix: @"connect"])
	{
		UInt16 port;
		NSString *host;
		if ([params count] == 3)
		{
			port = [[params objectAtIndex:2] intValue];
			host = [params objectAtIndex:1];
		}
		else
		{
			port = [[params objectAtIndex:1] intValue];
			host = @"localhost";
		}

		// This starts to establish a connection to the server.
		// The connection will not be finished until later, when
		// -onSocket:didConnectToPort:host: is called. But even so, you can
		// immediately queue a read or write operation here. It will be
		// performed when the connection is established.
		//
		// Note that I enclose the connect method call in a @try block. An
		// exception will be thrown if the socket is already connected. Usually,
		// if an exception was thrown, that indicates programmer error. In this
		// case, an exception would indicate that I did not forsee a user trying
		// to make a new connection when one already exists. I could and should
		// have used -isConnected to check for that case in advance, but I wanted
		// to demonstrate the exception-handling.
		//
		// Note also, that I call -prepareHello (which writes to the socket)
		// before the socket is actually connected. The write request will be
		// queued up and transmitted as soon as the connection is complete.
		
		@try
		{
			NSError *err;
			
			if ([socket connectToHost:host onPort:port error:&err])
			{
				NSLog (@"Connecting to %@ port %u.", host, port);
				[self prepareHello];
			}
			else
			{
				NSLog (@"Couldn't connect to %@ port %u (%@).", host, port, err);
			}
		}
		@catch (NSException *exception)
		{
			NSLog ([exception reason]);
		}
	}
	else if ([text hasPrefix: @"dump"])
	{
		// This demonstrates AsyncSocket's -description method.
		NSLog (@"%@", socket);
	}
	else if ([text hasPrefix: @"help"])
	{
		showHelp();
	}
	else
	{
		// Anything other than a command is sent to Echo Server. Note that data
		// will include the final press of the Return key, which is "\n". That
		// is why I use "\n" verbatim as the packet delimiter, instead of
		// specifying CRLF or something.
		
		NSData *data = [text dataUsingEncoding:NSASCIIStringEncoding];
		[socket writeData:data withTimeout:-1 tag:0];
	}
	[text setString:@""];
}


#pragma mark -
#pragma mark AsyncSocket Delegate Methods


/*
 This will be called whenever AsyncSocket is about to disconnect. In Echo Server,
 it does not do anything other than report what went wrong (this delegate method
 is the only place to get that information), but in a more serious app, this is
 a good place to do disaster-recovery by getting partially-read data. This is
 not, however, a good place to do cleanup. The socket must still exist when this
 method returns.
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
 Normally, this is the place to release the socket and perform the appropriate
 housekeeping and notification. But I intend to re-use this same socket for
 other connections, so I do nothing.
*/
-(void) onSocketDidDisconnect:(AsyncSocket *)sock
{
	NSLog (@"Disconnected.");
}


/*
 This method is called when Echo has connected to Echo Server. I immediately
 wait for incoming data from the server, but I already have two write requests
 queued up (from -prepareHello), and will also be sending data when
 the user gives me some to send.
*/
-(void) onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{
	NSLog (@"Connected to %@ %u.", host, port);
	[self readFromServer];
}


/*
 This method is called when Echo has finished reading a packet from Echo Server.
 It prints it out and immediately calls -readFromServer, which will queue up a
 read operation, waiting for the next packet.

 You'll note that I do not implement -onSocket:didWriteDataWithTag:. That is
 because Echo does not care about the data once it is transmitted. AsyncSocket
 will still send the data, but will not notify Echo when that it done.
*/
-(void) onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)t
{
	NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	printf ([str cString]);
	fflush (stdout);
	[str release];
	[self readFromServer];
}


@end

#pragma mark -
#pragma mark C Functions

void showHelp()
{
	printf ("ECHO by Dustin Voss copyright 2003. Sample code for using AsyncSocket.");
	printf ("\nReads and writes text to an ECHO SERVER. The following commands are available:");
	printf ("\n\tquit, exit -- exit the program");
	printf ("\n\thelp -- display this message");
	printf ("\n\tconnect host port -- connects to the server on the given host and port");
	printf ("\n\tdisconnect -- disconnects from the current server");
	printf ("\n\tdump -- displays the socket's status");
	printf ("\nAnything else gets transmitted to the server. Begin!\n");
	fflush (stdout);
}

int main (int argc, const char * argv[])
{
	showHelp();
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Echo *e = [[Echo alloc] init];
	[e runLoop];
	[e release];
	[pool release];
	return 0;
}
