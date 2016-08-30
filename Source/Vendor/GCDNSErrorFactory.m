//
//  GCDNSErrorFactory.m
//
//  This file is in the public domain.
//  Originally created by Luis Ascorbe in Q3 2016.
//  Updated and maintained by Deusty LLC and the Apple development community.
//
//  https://github.com/robbiehanson/CocoaAsyncSocket
//

#import "GCDNSErrorFactory.h"

#import <netdb.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
// For more information see: https://github.com/robbiehanson/CocoaAsyncSocket/wiki/ARC
#endif

NSString *const GCDAsyncSocketErrorDomain = @"GCDAsyncSocketErrorDomain";
NSString *const GCDAsyncUdpSocketErrorDomain = @"GCDAsyncUdpSocketErrorDomain";

NSString *const GCDError_kCFStreamErrorDomainNetDB = @"kCFStreamErrorDomainNetDB";
NSString *const GCDError_kCFStreamErrorDomainSSL = @"kCFStreamErrorDomainSSL";

NSString *const GCDErrorHostDictionaryKey = @"GCDErrorHostDictionaryKey";
NSString *const GCDErrorPortDictionaryKey = @"GCDErrorPortDictionaryKey";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - GCDError
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDError

+ (NSError *)gaiError:(int)gai_error tryingToLookUpHost:(NSString *)host andPort:(NSString *)port
{
    NSString *errMsg = [NSString stringWithCString:gai_strerror(gai_error) encoding:NSASCIIStringEncoding];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, NSLocalizedDescriptionKey,
                                                                        host, GCDErrorHostDictionaryKey,
                                                                        port, GCDErrorPortDictionaryKey, nil];
    
    return [NSError errorWithDomain:GCDError_kCFStreamErrorDomainNetDB
                               code:gai_error
                           userInfo:userInfo];
}

+ (NSError *)errnoError
{
    return [self errnoErrorWithReason:nil];
}

+ (NSError *)errnoErrorWithReason:(NSString *)reason
{
    NSString *errMsg = [NSString stringWithUTF8String:strerror(errno)];
    NSDictionary *userInfo;
    if (reason) {
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, NSLocalizedDescriptionKey,
                                                              reason, NSLocalizedFailureReasonErrorKey, nil];
    } else {
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, NSLocalizedDescriptionKey, nil];
    }
    
    return [NSError errorWithDomain:NSPOSIXErrorDomain
                               code:errno
                           userInfo:userInfo];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - GCDAsyncSocketError
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDAsyncSocketError

+ (NSError *)badConfigError:(NSString *)errMsg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindBadConfigError
                           userInfo:userInfo];
}

+ (NSError *)badParamError:(NSString *)errMsg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindBadParamError
                           userInfo:userInfo];
}

+ (NSError *)sslError:(OSStatus)ssl_error
{
    NSString *msg = @"Error code definition can be found in Apple's SecureTransport.h";
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedRecoverySuggestionErrorKey];
    
    return [NSError errorWithDomain:GCDError_kCFStreamErrorDomainSSL
                               code:ssl_error
                           userInfo:userInfo];
}

+ (NSError *)connectTimeoutError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncSocketConnectTimeoutError",
                                                         @"GCDAsyncSocket", [NSBundle mainBundle],
                                                         @"Attempt to connect to host timed out", nil);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindConnectTimeoutError
                           userInfo:userInfo];
}

/**
 * Returns a standard AsyncSocket maxed out error.
 **/
+ (NSError *)readMaxedOutError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncSocketReadMaxedOutError",
                                                         @"GCDAsyncSocket", [NSBundle mainBundle],
                                                         @"Read operation reached set maximum length", nil);
    NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindReadMaxedOutError
                           userInfo:info];
}

/**
 * Returns a standard AsyncSocket write timeout error.
 **/
+ (NSError *)readTimeoutError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncSocketReadTimeoutError",
                                                         @"GCDAsyncSocket", [NSBundle mainBundle],
                                                         @"Read operation timed out", nil);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindReadTimeoutError
                           userInfo:userInfo];
}

/**
 * Returns a standard AsyncSocket write timeout error.
 **/
+ (NSError *)writeTimeoutError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncSocketWriteTimeoutError",
                                                         @"GCDAsyncSocket", [NSBundle mainBundle],
                                                         @"Write operation timed out", nil);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindWriteTimeoutError
                           userInfo:userInfo];
}

+ (NSError *)connectionClosedError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncSocketClosedError",
                                                         @"GCDAsyncSocket", [NSBundle mainBundle],
                                                         @"Socket closed by remote peer", nil);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindClosedError
                           userInfo:userInfo];
}

+ (NSError *)otherError:(NSString *)errMsg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncSocketErrorDomain
                               code:GCDAsyncSocketErrorKindOtherError
                           userInfo:userInfo];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - GCDAsyncUdpSocketError
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GCDAsyncUdpSocketError

+ (NSError *)badConfigError:(NSString *)errMsg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncUdpSocketErrorDomain
                               code:GCDAsyncUdpSocketErrorKindBadConfigError
                           userInfo:userInfo];
}

+ (NSError *)badParamError:(NSString *)errMsg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncUdpSocketErrorDomain
                               code:GCDAsyncUdpSocketErrorKindBadParamError
                           userInfo:userInfo];
}

/**
 * Returns a standard send timeout error.
 **/
+ (NSError *)sendTimeoutError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncUdpSocketSendTimeoutError",
                                                         @"GCDAsyncUdpSocket", [NSBundle mainBundle],
                                                         @"Send operation timed out", nil);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncUdpSocketErrorDomain
                               code:GCDAsyncUdpSocketErrorKindSendTimeoutError
                           userInfo:userInfo];
}

+ (NSError *)socketClosedError
{
    NSString *errMsg = NSLocalizedStringWithDefaultValue(@"GCDAsyncUdpSocketClosedError",
                                                         @"GCDAsyncUdpSocket", [NSBundle mainBundle],
                                                         @"Socket closed", nil);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncUdpSocketErrorDomain
                               code:GCDAsyncUdpSocketErrorKindClosedError
                           userInfo:userInfo];
}

+ (NSError *)otherError:(NSString *)errMsg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:GCDAsyncUdpSocketErrorDomain
                               code:GCDAsyncUdpSocketErrorKindOtherError
                           userInfo:userInfo];
}

@end
