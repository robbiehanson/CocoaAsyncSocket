#import <Cocoa/Cocoa.h>
@class AsyncSocket;

// Top Level Keys
#define X509_VERSION                    @"Version"
#define X509_SERIAL_NUMBER              @"SerialNumber"
#define X509_ISSUER                     @"Issuer"
#define X509_SUBJECT                    @"Subject"
#define X509_NOT_VALID_BEFORE           @"NotValidBefore"
#define X509_NOT_VALID_AFTER            @"NotValidAfter"
#define X509_PUBLIC_KEY                 @"PublicKey"

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


@interface AppController : NSObject
{
	AsyncSocket *asyncSocket;
}

- (IBAction)printCert:(id)sender;
@end
