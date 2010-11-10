#import "MyHTTPConnection.h"
#import "HTTPMessage.h"
#import "HTTPResponse.h"
#import "DDNumber.h"

/**
 * All we have to do is override appropriate methods in HTTPConnection.
**/

@implementation MyHTTPConnection

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	// Add support for POST
	
	if ([method isEqualToString:@"POST"])
	{
		if ([path isEqualToString:@"/post.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 50;
		}
	}
	
	return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
	// Inform HTTP server that we expect a body to accompany a POST request
	
	if([method isEqualToString:@"POST"])
		return YES;
	
	return [super expectsRequestBodyFromMethod:method atPath:path];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/post.html"])
	{
		NSLog(@"postContentLength: %qu", requestContentLength);
		
		NSString *postStr = nil;
		
		NSData *postData = [request body];
		if (postData)
		{
			postStr = [[[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding] autorelease];
		}
		
		NSLog(@"postStr: %@", postStr);
		
		// Result will be of the form "answer=..."
		
		int answer = [[postStr substringFromIndex:7] intValue];
		
		NSData *response = nil;
		if(answer == 10)
		{
			response = [@"<html><body>Correct<body></html>" dataUsingEncoding:NSUTF8StringEncoding];
		}
		else
		{
			response = [@"<html><body>Sorry - Try Again<body></html>" dataUsingEncoding:NSUTF8StringEncoding];
		}
		
		return [[[HTTPDataResponse alloc] initWithData:response] autorelease];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
	// If we supported large uploads,
	// we might use this method to create/open files, allocate memory, etc.
}

- (void)processDataChunk:(NSData *)postDataChunk
{
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
	BOOL result = [request appendData:postDataChunk];
	if (!result)
	{
		NSLog(@"Couldn't append bytes!");
	}
}

@end
