//
//  SimpleCertificate.h
//  SecureHTTPServer
//
//  Created by Dirk-Willem van Gulik on 06/04/2012.
//  Copyright (c) 2012 WebWeaving, All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SimpleCertificate : NSObject

+(NSDictionary *)distinguishedNameDictionary:(SecCertificateRef) cert;
+(NSString *)distinguishedName:(SecCertificateRef) cert;
+(NSData *)sha1:(SecCertificateRef) cert;
+(NSString *)sha1fingerprint:(SecCertificateRef) cert;
+(uint64)serialNumber:(SecCertificateRef) cert;
@end
