#import <Cocoa/Cocoa.h>


@interface HTTPAuthenticationRequest : NSObject
{
	NSString *username;
	NSString *realm;
	NSString *nonce;
	NSString *uri;
	NSString *qop;
	NSString *nc;
	NSString *cnonce;
	NSString *response;
}
- (id)initWithRequest:(CFHTTPMessageRef)request;

- (NSString *)username;
- (NSString *)realm;
- (NSString *)nonce;
- (NSString *)uri;
- (NSString *)qop;
- (NSString *)nc;
- (NSString *)cnonce;
- (NSString *)response;

@end
