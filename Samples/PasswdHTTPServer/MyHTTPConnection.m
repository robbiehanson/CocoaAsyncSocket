#import "MyHTTPConnection.h"


@implementation MyHTTPConnection

- (BOOL)isPasswordProtected:(NSString *)path
{
	// We're only going to password protect the "secret" directory.
	
	return [path hasPrefix:@"/secret"];
}

- (BOOL)useDigestAccessAuthentication
{
	// Digest access authentication is the default setting.
	// Notice in Safari that when you're prompted for your password,
	// Safari tells you "Your login information will be sent securely."
	// 
	// If you return NO in this method, the HTTP server will use
	// basic authentication. Try it and you'll see that Safari
	// will tell you "Your password will be sent unencrypted",
	// which is strongly discouraged.
	
	return YES;
}

- (NSString *)passwordForUser:(NSString *)username
{
	// You can do all kinds of cool stuff here.
	// For simplicity, we're not going to check the username, only the password.
	
	return @"secret";
}

@end
