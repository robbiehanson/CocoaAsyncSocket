#import <Foundation/Foundation.h>

@interface NSData (DDData)

- (NSData *)md5Digest;

- (NSData *)sha1Digest;

- (NSString *)hexStringValue;
- (NSString *)hexColonSeperatedStringValueWithCapitals:(BOOL)capitalize;
- (NSString *)hexColonSeperatedStringValue;

- (NSString *)base64Encoded;
- (NSData *)base64Decoded;

@end
