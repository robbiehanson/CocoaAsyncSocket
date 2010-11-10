#import "WebSocket.h"
#import "HTTPMessage.h"
#import "AsyncSocket.h"
#import "DDNumber.h"
#import "DDData.h"

#define TIMEOUT_NONE          -1
#define TIMEOUT_REQUEST_BODY  10

#define TAG_HTTP_REQUEST_BODY      100
#define TAG_HTTP_RESPONSE_HEADERS  200
#define TAG_HTTP_RESPONSE_BODY     201

#define TAG_PREFIX                 300
#define TAG_MSG_PLUS_SUFFIX        301

#define DEBUG  0

@interface WebSocket (PrivateAPI)

- (void)readRequestBody;
- (void)sendResponseBody;
- (void)sendResponseHeaders;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation WebSocket

+ (BOOL)isWebSocketRequest:(HTTPMessage *)request
{
	// Request (Draft 75):
	// 
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// WebSocket-Protocol: sample
	// 
	// 
	// Request (Draft 76):
	//
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// Sec-WebSocket-Protocol: sample
	// Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5
	// Sec-WebSocket-Key2: 12998 5 Y3 1  .P00
	// 
	// ^n:ds[4U
	
	// Look for Upgrade: and Connection: headers.
	// If we find them, and they have the proper value,
	// we can safely assume this is a websocket request.
	
	NSString *upgradeHeaderValue = [request headerField:@"Upgrade"];
	NSString *connectionHeaderValue = [request headerField:@"Connection"];
	
	BOOL isWebSocket = YES;
	
	if (!upgradeHeaderValue || !connectionHeaderValue) {
		isWebSocket = NO;
	}
	else if (![upgradeHeaderValue caseInsensitiveCompare:@"WebSocket"] == NSOrderedSame) {
		isWebSocket = NO;
	}
	else if (![connectionHeaderValue caseInsensitiveCompare:@"Upgrade"] == NSOrderedSame) {
		isWebSocket = NO;
	}
	
	return isWebSocket;
}

+ (BOOL)isVersion76Request:(HTTPMessage *)request
{
	NSString *key1 = [request headerField:@"Sec-WebSocket-Key1"];
	NSString *key2 = [request headerField:@"Sec-WebSocket-Key2"];
	
	BOOL isVersion76;
	
	if (!key1 || !key2) {
		isVersion76 = NO;
	}
	else {
		isVersion76 = YES;
	}
	
	return isVersion76;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup and Teardown
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithRequest:(HTTPMessage *)aRequest socket:(AsyncSocket *)socket
{
	if (aRequest == nil)
	{
		[self release];
		return nil;
	}
	
	if ((self = [super init]))
	{
		request = [aRequest retain];
		
		asyncSocket = [socket retain];
		[asyncSocket setDelegate:self];
		
		isOpen = NO;
		isVersion76 = [[self class] isVersion76Request:request];
		
		term = [[NSData alloc] initWithBytes:"\xFF" length:1];
		
		if (isVersion76)
		{
			[self readRequestBody];
		}
		else
		{
			[self sendResponseHeaders];
			[self didOpen];
		}
	}
	return self;
}

- (void)dealloc
{
	[request release];
	
	[asyncSocket setDelegate:nil];
	[asyncSocket release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTP Response
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)readRequestBody
{
	NSAssert(isVersion76, @"WebSocket version 75 doesn't contain a request body");
	
	[asyncSocket readDataToLength:8 withTimeout:TIMEOUT_NONE tag:TAG_HTTP_REQUEST_BODY];
}

- (NSString *)originResponseHeaderValue
{
	NSString *origin = [request headerField:@"Origin"];
	
	if (origin == nil)
	{
		NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
		
		return [NSString stringWithFormat:@"http://localhost:%@", port];
	}
	else
	{
		return origin;
	}
}

- (NSString *)locationResponseHeaderValue
{
	NSString *location;
	NSString *host = [request headerField:@"Host"];
	
	NSString *requestUri = [[request url] relativeString];
	
	if (host == nil)
	{
		NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
		
		location = [NSString stringWithFormat:@"ws://localhost:%@%@", port, requestUri];
	}
	else
	{
		location = [NSString stringWithFormat:@"ws://%@%@", host, requestUri];
	}
	
	return location;
}

- (void)sendResponseHeaders
{
	// Request (Draft 75):
	// 
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// WebSocket-Protocol: sample
	// 
	// 
	// Request (Draft 76):
	//
	// GET /demo HTTP/1.1
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Host: example.com
	// Origin: http://example.com
	// Sec-WebSocket-Protocol: sample
	// Sec-WebSocket-Key2: 12998 5 Y3 1  .P00
	// Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5
	// 
	// ^n:ds[4U

	
	// Response (Draft 75):
	// 
	// HTTP/1.1 101 Web Socket Protocol Handshake
	// Upgrade: WebSocket
	// Connection: Upgrade
	// WebSocket-Origin: http://example.com
	// WebSocket-Location: ws://example.com/demo
	// WebSocket-Protocol: sample
	// 
	// 
	// Response (Draft 76):
	//
	// HTTP/1.1 101 WebSocket Protocol Handshake
	// Upgrade: WebSocket
	// Connection: Upgrade
	// Sec-WebSocket-Origin: http://example.com
	// Sec-WebSocket-Location: ws://example.com/demo
	// Sec-WebSocket-Protocol: sample
	// 
	// 8jKS'y:G*Co,Wxa-

	
	HTTPMessage *wsResponse = [[HTTPMessage alloc] initResponseWithStatusCode:101
	                                                              description:@"Web Socket Protocol Handshake"
	                                                                  version:HTTPVersion1_1];
	
	[wsResponse setHeaderField:@"Upgrade" value:@"WebSocket"];
	[wsResponse setHeaderField:@"Connection" value:@"Upgrade"];
	
	// Note: It appears that WebSocket-Origin and WebSocket-Location
	// are required for Google's Chrome implementation to work properly.
	// 
	// If we don't send either header, Chrome will never report the WebSocket as open.
	// If we only send one of the two, Chrome will immediately close the WebSocket.
	// 
	// In addition to this it appears that Chrome's implementation is very picky of the values of the headers.
	// They have to match exactly with what Chrome sent us or it will close the WebSocket.
	
	NSString *originValue = [self originResponseHeaderValue];
	NSString *locationValue = [self locationResponseHeaderValue];
	
	NSString *originField = isVersion76 ? @"Sec-WebSocket-Origin" : @"WebSocket-Origin";
	NSString *locationField = isVersion76 ? @"Sec-WebSocket-Location" : @"WebSocket-Location";
	
	[wsResponse setHeaderField:originField value:originValue];
	[wsResponse setHeaderField:locationField value:locationValue];
	
	// Do not invoke super.
	// These are the only headers required for a WebSocket.
	
	NSData *responseHeaders = [wsResponse messageData];
	
#if DEBUG
	
	NSString *temp = [[NSString alloc] initWithData:responseHeaders encoding:NSUTF8StringEncoding];
	NSLog(@"WebSocket Response Headers:\n%@", temp);
	[temp release];
	
#endif
	
	[asyncSocket writeData:responseHeaders withTimeout:TIMEOUT_NONE tag:TAG_HTTP_RESPONSE_HEADERS];
}

- (NSData *)processKey:(NSString *)key
{
	unichar c;
	NSUInteger i;
	NSUInteger length = [key length];
	
	// Concatenate the digits into a string,
	// and count the number of spaces.
	
	NSMutableString *numStr = [NSMutableString stringWithCapacity:10];
	long numSpaces = 0;
	
	for (i = 0; i < length; i++)
	{
		c = [key characterAtIndex:i];
		
		if (c >= '0' && c <= '9')
		{
			[numStr appendFormat:@"%C", c];
		}
		else if (c == ' ')
		{
			numSpaces++;
		}
	}
	
	long num = strtol([numStr UTF8String], NULL, 10);
	
	long resultHostNum;
	
	if (numSpaces == 0)
		resultHostNum = 0;
	else
		resultHostNum = num / numSpaces;
	
#if DEBUG
	
	NSLog(@"key(%@) -> %ld / %ld = %ld", key, num, numSpaces, resultHostNum);
	
#endif
	
	// Convert result to 4 byte big-endian (network byte order)
	// and then convert to raw data.
	
	UInt32 result = EndianU32_LtoN((UInt32)resultHostNum);
	
	return [NSData dataWithBytes:&result length:4];
}

- (void)sendResponseBody:(NSData *)d3
{
	NSAssert(isVersion76, @"WebSocket version 75 doesn't contain a response body");
	NSAssert([d3 length] == 8, @"Invalid requestBody length");
	
	NSString *key1 = [request headerField:@"Sec-WebSocket-Key1"];
	NSString *key2 = [request headerField:@"Sec-WebSocket-Key2"];
	
	NSData *d1 = [self processKey:key1];
	NSData *d2 = [self processKey:key2];
	
	// Concatenated d1, d2 & d3
	
	NSMutableData *d0 = [NSMutableData dataWithCapacity:(4+4+8)];
	[d0 appendData:d1];
	[d0 appendData:d2];
	[d0 appendData:d3];
	
	// Hash the data using MD5
	
	NSData *responseBody = [d0 md5Digest];
	
	[asyncSocket writeData:responseBody withTimeout:TIMEOUT_NONE tag:TAG_HTTP_RESPONSE_BODY];
	
#if DEBUG
	
	NSString *s1 = [[NSString alloc] initWithData:d1 encoding:NSASCIIStringEncoding];
	NSString *s2 = [[NSString alloc] initWithData:d2 encoding:NSASCIIStringEncoding];
	NSString *s3 = [[NSString alloc] initWithData:d3 encoding:NSASCIIStringEncoding];
	
	NSString *s0 = [[NSString alloc] initWithData:d0 encoding:NSASCIIStringEncoding];
	
	NSString *sH = [[NSString alloc] initWithData:responseBody encoding:NSASCIIStringEncoding];
	
	NSLog(@"key1 result : %@", s1);
	NSLog(@"key2 result : %@", s2);
	NSLog(@"key3 passed : %@", s3);
	
	NSLog(@"keys concat : %@", s0);
	
	NSLog(@"responseBody: %@", sH);
	
	[s1 release];
	[s2 release];
	[s3 release];
	[s0 release];
	[sH release];
	
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Core Functionality
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didOpen
{
	// Override me to perform any custom actions once the WebSocket has been opened
	// 
	// Don't forget to invoke [super didOpen] at the end of your method.
	
	// Start reading for messages
	[asyncSocket readDataToLength:1 withTimeout:TIMEOUT_NONE tag:TAG_PREFIX];
}

- (void)sendMessage:(NSString *)msg
{
	NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableData *data = [NSMutableData dataWithCapacity:([msgData length] + 2)];
	
	[data appendBytes:"\x00" length:1];
	[data appendData:msgData];
	[data appendBytes:"\xFF" length:1];
	
	[asyncSocket writeData:data withTimeout:TIMEOUT_NONE tag:0];
}

- (void)didReceiveMessage:(NSString *)msg
{
	// Override me to process incoming messages
}

- (void)didClose
{
	// Override me to perform any cleanup when the socket is closed
	// 
	// Don't forget to invoke [super didClose] at the end of your method.
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WebSocketDidDieNotification object:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	if (tag == TAG_HTTP_REQUEST_BODY)
	{
		[self sendResponseHeaders];
		[self sendResponseBody:data];
		[self didOpen];
	}
	else if (tag == TAG_PREFIX)
	{
		UInt8 *pFrame = (UInt8 *)[data bytes];
		UInt8 frame = *pFrame;
		
		if (frame <= 0x7F)
		{
			[asyncSocket readDataToData:term withTimeout:TIMEOUT_NONE tag:TAG_MSG_PLUS_SUFFIX];
		}
		else
		{
			// Unsupported frame type
			[self didClose];
		}
	}
	else
	{
		NSUInteger msgLength = [data length] - 1; // Excluding ending 0xFF frame
		
		NSString *msg = [[NSString alloc] initWithBytes:[data bytes] length:msgLength encoding:NSUTF8StringEncoding];
		
		[self didReceiveMessage:msg];
		
		[msg release];
		
		// Read next message
		[asyncSocket readDataToLength:1 withTimeout:TIMEOUT_NONE tag:TAG_PREFIX];
	}
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	[self didClose];
}

@end
