/**
 * The HTTPMessage class is a simple Objective-C wrapper around Apple's CFHTTPMessage class.
**/

#import <Foundation/Foundation.h>

#define HTTPVersion1_0  ((NSString *)kCFHTTPVersion1_0)
#define HTTPVersion1_1  ((NSString *)kCFHTTPVersion1_1)


@interface HTTPMessage : NSObject
{
	CFHTTPMessageRef message;
}

- (id)initEmptyRequest;

- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version;

- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version;

- (BOOL)appendData:(NSData *)data;

- (BOOL)isHeaderComplete;

- (NSString *)version;

- (NSString *)method;
- (NSURL *)url;

- (NSInteger)statusCode;

- (NSDictionary *)allHeaderFields;
- (NSString *)headerField:(NSString *)headerField;

- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue;

- (NSData *)messageData;

- (NSData *)body;
- (void)setBody:(NSData *)body;

@end
