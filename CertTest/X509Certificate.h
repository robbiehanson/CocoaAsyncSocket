//
//  X509Certificate.h
//  
//  This class is in the public domain.
//  Originally created by Robbie Hanson on Mon Jan 26 2009.
//  Updated and maintained by Deusty Designs and the Mac development community.
//
//  http://code.google.com/p/cocoaasyncsocket/
//  
//  This class is largely derived from Apple's sample code project: SSLSample.
//  This class does not extract every bit of available information, just the most common fields.

#import <Foundation/Foundation.h>
@class AsyncSocket;

// Top Level Keys
#define X509_ISSUER                     @"Issuer"
#define X509_SUBJECT                    @"Subject"
#define X509_NOT_VALID_BEFORE           @"NotValidBefore"
#define X509_NOT_VALID_AFTER            @"NotValidAfter"
#define X509_PUBLIC_KEY                 @"PublicKey"
#define X509_SERIAL_NUMBER              @"SerialNumber"

// Keys For Issuer/Subject Dictionaries
#define X509_COUNTRY                    @"Country"
#define X509_ORGANIZATION               @"Organization"
#define X509_LOCALITY                   @"Locality"
#define X509_ORANIZATIONAL_UNIT         @"OrganizationalUnit"
#define X509_COMMON_NAME                @"CommonName"
#define X509_SURNAME                    @"Surname"
#define X509_TITLE                      @"Title"
#define X509_STATE_PROVINCE             @"StateProvince"
#define X509_COLLECTIVE_STATE_PROVINCE  @"CollectiveStateProvince"
#define X509_EMAIL_ADDRESS              @"EmailAddress"
#define X509_STREET_ADDRESS             @"StreetAddress"
#define X509_POSTAL_CODE                @"PostalCode"
#define X509_OTHERS                     @"Others"

@interface X509Certificate : NSObject

+ (NSDictionary *)extractCertDictFromAsyncSocket:(AsyncSocket *)socket;
+ (NSDictionary *)extractCertDictFromReadStream:(CFReadStreamRef)readStream;
+ (NSDictionary *)extractCertDictFromIdentity:(SecIdentityRef)identity;
+ (NSDictionary *)extractCertDictFromCert:(SecCertificateRef)cert;

@end
