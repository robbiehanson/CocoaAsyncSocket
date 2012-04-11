//
//  SimpleCertificate.m
//  SecureHTTPServer
//
//  Created by Dirk-Willem van Gulik on 06/04/2012.
//  Copyright (c) 2012 WebWeaving, All rights reserved.
//

#import "SimpleCertificate.h"
#import "DDData.h"

@implementation SimpleCertificate

+(NSDictionary *)distinguishedNameDictionary:(SecCertificateRef) cert {
    // NSMutableString * out = [[NSMutableString alloc] init];
 
    const void *oids[] = { kSecOIDX509V1SubjectName };    
    CFArrayRef keys = CFArrayCreate(NULL, oids, sizeof(oids)/sizeof(void*), NULL);
    
    CFErrorRef error;
    NSDictionary * certCopyValues = (__bridge_transfer NSDictionary *)SecCertificateCopyValues(cert, keys, &error);
    CFRelease(keys);
        
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithCapacity:10];
    
    for(id i in certCopyValues) 
    {
        NSDictionary *dict = [certCopyValues objectForKey:i];
        for(NSDictionary *entry in (NSArray *)[dict objectForKey:(__bridge NSString *)kSecPropertyKeyValue]) 
        {
            NSString *label = [entry objectForKey:(__bridge NSString *)kSecPropertyKeyLabel];
            // CFStringRef type = CFDictionaryGetValue(dict, kSecPropertyKeyType);
            NSString *value = [entry objectForKey:(__bridge NSString *)kSecPropertyKeyValue];
            if (![result objectForKey:label])
                [result setObject:[NSMutableArray arrayWithObject:value] forKey:label];
            else
                [[result objectForKey:label] addObject:value];
        }
    }

    return result;
}
// We're ordering our DN. Is this quite right - as the order of SecCertificateCopyValues() is
// already as per cert.
//
+(NSString *)distinguishedName:(SecCertificateRef) cert {
    NSArray * mapping = [NSArray arrayWithObjects:
                         (__bridge NSString *)kSecOIDX509V1SubjectName,    @"Subject",
                         (__bridge NSString *)kSecOIDDescription,          @"Description",
                         (__bridge NSString *)kSecOIDTitle,                @"Title",
                         (__bridge NSString *)kSecOIDGivenName,            @"GivenName",
                         (__bridge NSString *)kSecOIDSurname,              @"Surname",
                         (__bridge NSString *)kSecOIDCommonName,           @"CN",
                         (__bridge NSString *)kSecOIDOrganizationalUnitName,       @"OU",
                         (__bridge NSString *)kSecOIDOrganizationName,             @"O",
                         (__bridge NSString *)kSecOIDCollectiveStateProvinceName,  @"S",
                         (__bridge NSString *)kSecOIDCollectiveStreetAddress,      @"Address",
                         (__bridge NSString *)kSecOIDCountryName,          @"C",
                         (__bridge NSString *)kSecOIDEmailAddress,         @"E",
                         nil];

    assert([mapping count] % 2 == 0);
    NSDictionary * entries = [SimpleCertificate distinguishedNameDictionary:cert];
    NSMutableString *str = [NSMutableString string];

    for(int i = 0; i < [mapping count];) 
    {
        NSString * keyVal = [mapping objectAtIndex:i++];
        NSString * keyName = [mapping objectAtIndex:i++];

        NSArray * vals = [entries objectForKey:keyVal];
        if (!vals) 
            continue;
        
        // We're not sorting. Emperical evidence suggests that
        // the order of the array is the order encoded in the cert.
        // Not sure if this is per spec.
        //
        for(NSString *v in vals) {
            [str appendFormat:@"/%@=%@", keyName, 
              [[v stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                  stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"]];
        }
    }
    return str;
}

+(NSData *)sha1:(SecCertificateRef) cert {
    // fingerprint is over canonical DER rep.
    CFDataRef data = SecCertificateCopyData(cert);
    NSData * out = [[NSData dataWithData:(__bridge NSData*)data] sha1Digest];
    CFRelease(data);
    return out;
}

+(NSString *)sha1fingerprint:(SecCertificateRef) cert {
    return[[SimpleCertificate sha1:cert] hexColonSeperatedStringValue];    
}

// Returns the serial number as an actual serial numer.
//
// Bit inefficient - but assumes big-endian DER mapping regardless of
// local endianness and allows any non **2 length.
//
+(uint64)serialNumber:(SecCertificateRef) cert {
    CFDataRef data = SecCertificateCopySerialNumber(cert, NULL);
    const uint8 *derWireOrderedBytes = CFDataGetBytePtr(data);

    uint64 cls = 0;
    for(int i = 0; i < sizeof(cls) && i < CFDataGetLength(data);i++) {
        cls = (cls << 8) |  derWireOrderedBytes[i];
    }
    
    CFRelease(data);
    return cls;
}


// Return the serial number as a hex-colon string (e.g. 01:A1:73:19:02).
//
// Most mac tools represent the serial number in decimals. Firefox and
// a some entprise/java based tools tend to represent it either as a 
// hex string or as a per-to-hex-digit colon separated string.
//
+(NSString *)serialNumberAsHexColonString:(SecCertificateRef) cert {
    CFDataRef data = SecCertificateCopySerialNumber(cert, NULL);
    NSString * out = [[NSData dataWithData:(__bridge NSData*)data] hexColonSeperatedStringValue];
    CFRelease(data);
    return out;
}
@end
