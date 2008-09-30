#import <Foundation/Foundation.h>

@class AsyncSocket;
@class HTTPServer;
@protocol HTTPResponse;


#define HTTPConnectionDidDieNotification  @"HTTPConnectionDidDie"

@interface HTTPConnection : NSObject
{
	AsyncSocket *asyncSocket;
	HTTPServer *server;
	
	CFHTTPMessageRef request;
	int numHeaderLines;
	
	NSString *nonce;
	int lastNC;
	
	NSObject<HTTPResponse> *httpResponse;
	
	NSMutableArray *ranges;
	NSMutableArray *ranges_headers;
	NSString *ranges_boundry;
	int rangeIndex;
}

- (id)initWithAsyncSocket:(AsyncSocket *)newSocket forServer:(HTTPServer *)myServer;

- (BOOL)isSecureServer;

- (NSArray *)sslIdentityAndCertificates;

- (BOOL)isPasswordProtected:(NSString *)path;

- (BOOL)useDigestAccessAuthentication;

- (NSString *)realm;
- (NSString *)passwordForUser:(NSString *)username;

- (NSString *)filePathForURI:(NSString *)path;

- (NSObject<HTTPResponse> *)httpResponseForURI:(NSString *)path;

- (void)handleVersionNotSupported:(NSString *)version;
- (void)handleAuthenticationFailed;
- (void)handleResourceNotFound;
- (void)handleInvalidRequest:(NSData *)data;
- (void)handleUnknownMethod:(NSString *)method;

- (NSData *)preprocessResponse:(CFHTTPMessageRef)response;
- (NSData *)preprocessErrorResponse:(CFHTTPMessageRef)response;

- (void)die;

@end
