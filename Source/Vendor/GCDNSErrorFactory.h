//
//  GCDNSErrorFactory.h
//
//  This file is in the public domain.
//  Originally created by Luis Ascorbe in Q3 2016.
//  Updated and maintained by Deusty LLC and the Apple development community.
//
//  https://github.com/robbiehanson/CocoaAsyncSocket
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const GCDAsyncSocketErrorDomain;
extern NSString *const GCDAsyncUdpSocketErrorDomain;

extern NSString *const GCDError_kCFStreamErrorDomainNetDB;
extern NSString *const GCDError_kCFStreamErrorDomainSSL;

extern NSString *const GCDErrorHostDictionaryKey;
extern NSString *const GCDErrorPortDictionaryKey;

typedef NS_ENUM(NSInteger, GCDAsyncSocketErrorKind) {
    GCDAsyncSocketErrorKindNoError = 0,           // Never used
    GCDAsyncSocketErrorKindBadConfigError,        // Invalid configuration
    GCDAsyncSocketErrorKindBadParamError,         // Invalid parameter was passed
    GCDAsyncSocketErrorKindConnectTimeoutError,   // A connect operation timed out
    GCDAsyncSocketErrorKindReadTimeoutError,      // A read operation timed out
    GCDAsyncSocketErrorKindWriteTimeoutError,     // A write operation timed out
    GCDAsyncSocketErrorKindReadMaxedOutError,     // Reached set maxLength without completing
    GCDAsyncSocketErrorKindClosedError,           // The remote peer closed the connection
    GCDAsyncSocketErrorKindOtherError,            // Description provided in userInfo
};

typedef NS_ENUM(NSInteger, GCDAsyncUdpSocketErrorKind) {
    GCDAsyncUdpSocketErrorKindNoError = 0,          // Never used
    GCDAsyncUdpSocketErrorKindBadConfigError,       // Invalid configuration
    GCDAsyncUdpSocketErrorKindBadParamError,        // Invalid parameter was passed
    GCDAsyncUdpSocketErrorKindSendTimeoutError,     // A send operation timed out
    GCDAsyncUdpSocketErrorKindClosedError,          // The socket was closed
    GCDAsyncUdpSocketErrorKindOtherError,           // Description provided in userInfo
};

@interface GCDError: NSObject

+ (NSError *)gaiError:(int)gai_error tryingToLookUpHost:(NSString *)host andPort:(NSString *)port;
+ (NSError *)errnoError;
+ (NSError *)errnoErrorWithReason:(nullable NSString *)reason;

@end

@interface GCDAsyncSocketError: NSObject

+ (NSError *)badConfigError:(NSString *)errMsg;
+ (NSError *)badParamError:(NSString *)errMsg;
+ (NSError *)sslError:(OSStatus)ssl_error;
+ (NSError *)connectTimeoutError;
+ (NSError *)readMaxedOutError;
+ (NSError *)readTimeoutError;
+ (NSError *)writeTimeoutError;
+ (NSError *)connectionClosedError;
+ (NSError *)otherError:(NSString *)errMsg;

@end

@interface GCDAsyncUdpSocketError: NSObject

+ (NSError *)badConfigError:(NSString *)errMsg;
+ (NSError *)badParamError:(NSString *)errMsg;
+ (NSError *)sendTimeoutError;
+ (NSError *)socketClosedError;
+ (NSError *)otherError:(NSString *)errMsg;

@end

NS_ASSUME_NONNULL_END
