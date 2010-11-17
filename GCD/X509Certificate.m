//
//  X509Certificate.m
//  
//  This class is in the public domain.
//  Originally created by Robbie Hanson on Mon Jan 26 2009.
//  Updated and maintained by Deusty Designs and the Mac development community.
//
//  http://code.google.com/p/cocoaasyncsocket/
//  
//  This class is largely derived from Apple's sample code project: SSLSample.
//  This class does not extract every bit of available information, just the most common fields.

#import "X509Certificate.h"
#import "GCDAsyncSocket.h"
#import <Security/Security.h>

#define UTC_TIME_STRLEN          13
#define GENERALIZED_TIME_STRLEN  15


@implementation X509Certificate

// Standard app-level memory functions required by CDSA

static void * appMalloc (uint32 size, void *allocRef)
{
	return malloc(size);
}
static void * appCalloc(uint32 num, uint32 size, void *allocRef)
{
	return calloc(num, size);
}
static void * appRealloc (void *ptr, uint32 size, void *allocRef)
{
	return realloc(ptr, size);
}
static void appFree (void *mem_ptr, void *allocRef)
{
	free(mem_ptr);
}


static const CSSM_API_MEMORY_FUNCS memFuncs = {
    (CSSM_MALLOC)appMalloc,
    (CSSM_FREE)appFree,
    (CSSM_REALLOC)appRealloc,
    (CSSM_CALLOC)appCalloc,
    NULL
};

static const CSSM_VERSION vers = {2, 0};
static const CSSM_GUID testGuid = { 0xFADE, 0, 0, { 1,2,3,4,5,6,7,0 }};

static BOOL CSSMStartup()
{
	CSSM_RETURN  crtn;
    CSSM_PVC_MODE pvcPolicy = CSSM_PVC_NONE;
	
	crtn = CSSM_Init (&vers, 
					  CSSM_PRIVILEGE_SCOPE_NONE,
					  &testGuid,
					  CSSM_KEY_HIERARCHY_NONE,
					  &pvcPolicy,
					  NULL /* reserved */);
	
	if(crtn != CSSM_OK) 
	{
		cssmPerror("CSSM_Init", crtn);
		return NO;
	}
	else
	{
		return YES;
	}
}

static CSSM_CL_HANDLE CLStartup()
{
	CSSM_CL_HANDLE clHandle;
	CSSM_RETURN crtn;
	
	if(CSSMStartup() == NO)
	{
		return 0;
	}
	
	crtn = CSSM_ModuleLoad(&gGuidAppleX509CL,
						   CSSM_KEY_HIERARCHY_NONE,
						   NULL,   // eventHandler
						   NULL);  // AppNotifyCallbackCtx
	if(crtn != CSSM_OK)
	{
		cssmPerror("CSSM_ModuleLoad", crtn);
		return 0;
	}
	
	crtn = CSSM_ModuleAttach (&gGuidAppleX509CL,
							  &vers,
							  &memFuncs,         // memFuncs
							  0,                 // SubserviceID
							  CSSM_SERVICE_CL,   // SubserviceFlags - Where is this used?
							  0,                 // AttachFlags
							  CSSM_KEY_HIERARCHY_NONE,
							  NULL,              // FunctionTable
							  0,                 // NumFuncTable
							  NULL,              // reserved
							  &clHandle);
	if(crtn != CSSM_OK)
	{
		cssmPerror("CSSM_ModuleAttach", crtn);
		return 0;
	}
	
	return clHandle;
}

static void CLShutdown(CSSM_CL_HANDLE clHandle)
{
	CSSM_RETURN crtn;
	
	crtn = CSSM_ModuleDetach(clHandle);
	if(crtn != CSSM_OK)
	{
		cssmPerror("CSSM_ModuleDetach", crtn);
	}
	
	crtn = CSSM_ModuleUnload(&gGuidAppleX509CL, NULL, NULL);
	if(crtn != CSSM_OK)
	{
		cssmPerror("CSSM_ModuleUnload", crtn);
	}
}

static BOOL CompareCSSMData(const CSSM_DATA *d1, const CSSM_DATA *d2)
{
	if(d1 == NULL || d2 == NULL)
	{
		return NO;
	}
	if(d1->Length != d2->Length)
	{
		return NO;
	}
	
	return memcmp(d1->Data, d2->Data, d1->Length) == 0;
}

static BOOL CompareOids(const CSSM_OID *oid1, const CSSM_OID *oid2)
{
	if(oid1 == NULL || oid2 == NULL)
	{
		return NO;
	}
	if(oid1->Length != oid2->Length)
	{
		return NO;
	}
	
	return memcmp(oid1->Data, oid2->Data, oid1->Length) == 0;
}

static NSString* KeyForOid(const CSSM_OID *oid)
{
	if(CompareOids(oid, &CSSMOID_CountryName))
	{
		return X509_COUNTRY;
	}
	if(CompareOids(oid, &CSSMOID_OrganizationName))
	{
		return X509_ORGANIZATION;
	}
	if(CompareOids(oid, &CSSMOID_LocalityName))
	{
		return X509_LOCALITY;
	}
	if(CompareOids(oid, &CSSMOID_OrganizationalUnitName))
	{
		return X509_ORANIZATIONAL_UNIT;
	}
	if(CompareOids(oid, &CSSMOID_CommonName))
	{
		return X509_COMMON_NAME;
	}
	if(CompareOids(oid, &CSSMOID_Surname))
	{
		return X509_SURNAME;
	}
	if(CompareOids(oid, &CSSMOID_Title))
	{
		return X509_TITLE;
	}
	if(CompareOids(oid, &CSSMOID_StateProvinceName))
	{
		return X509_STATE_PROVINCE;
	}
	if(CompareOids(oid, &CSSMOID_CollectiveStateProvinceName))
	{
		return X509_COLLECTIVE_STATE_PROVINCE;
	}
	if(CompareOids(oid, &CSSMOID_EmailAddress))
	{
		return X509_EMAIL_ADDRESS;
	}
	if(CompareOids(oid, &CSSMOID_StreetAddress))
	{
		return X509_STREET_ADDRESS;
	}
	if(CompareOids(oid, &CSSMOID_PostalCode))
	{
		return X509_POSTAL_CODE;
	}
	
	// Not every possible Oid is checked for.
	// Feel free to add any you may need.
	// They are listed in the Security Framework's aoisattr.h file.
	
	return nil;
}

static NSString* DataToString(const CSSM_DATA *data, const CSSM_BER_TAG *type)
{
	NSStringEncoding encoding;
	switch (*type)
	{
		case BER_TAG_PRINTABLE_STRING      :
		case BER_TAG_TELETEX_STRING        :
			
			encoding = NSISOLatin1StringEncoding;
			break;
			
		case BER_TAG_PKIX_BMP_STRING       :
		case BER_TAG_PKIX_UNIVERSAL_STRING :
		case BER_TAG_PKIX_UTF8_STRING      :
			
			encoding = NSUTF8StringEncoding;
			break;
			
		default                            :
			return nil;
	}
	
	NSString *result = [[NSString alloc] initWithBytes:data->Data
	                                            length:data->Length
	                                          encoding:encoding];
	return [result autorelease];
}

static NSDate* TimeToDate(const char *str, unsigned len)
{
	BOOL isUTC;
	unsigned i;
	long year, month, day, hour, minute, second;
	
	// Check for null or empty strings
	if(str == NULL || len == 0)
	{
		return nil;
    }
	
	// Ignore NULL termination
	if(str[len - 1] == '\0')
	{
		len--;
	}
	
	// Check for proper string length
	if(len == UTC_TIME_STRLEN)
	{
		// 2-digit year, not Y2K compliant
		isUTC = YES;
	}
	else if(len == GENERALIZED_TIME_STRLEN)
	{
		// 4-digit year
		isUTC = NO;
	}
	else
	{
		// Unknown format
		return nil;
    }
    
	// Check that all characters except last are digits
	for(i = 0; i < (len - 1); i++)
	{
		if(!(isdigit(str[i])))
		{
			return nil;
		}
	}
	
	// Check last character is a 'Z'
    if(str[len - 1] != 'Z' )
	{
		return nil;
    }
	
	// Start parsing
	i = 0;
	char tmp[5];
	
	// Year
	if(isUTC)
	{
		tmp[0] = str[i++];
		tmp[1] = str[i++];
		tmp[2] = '\0';
		
		year = strtol(tmp, NULL, 10);
		
		// 2-digit year:
		// 0  <= year <  50 : assume century 21
		// 50 <= year <  70 : illegal per PKIX
		// 70 <  year <= 99 : assume century 20
		
		if(year < 50)
		{
			year += 2000;
		}
		else if(year < 70)
		{
			return nil;
		}
		else
		{
			year += 1900;
		}
	}
	else
	{
		tmp[0] = str[i++];
		tmp[1] = str[i++];
		tmp[2] = str[i++];
		tmp[3] = str[i++];
		tmp[4] = '\0';
		
		year = strtol(tmp, NULL, 10);
	}
	
	// Month
	tmp[0] = str[i++];
	tmp[1] = str[i++];
	tmp[2] = '\0';
	
	month = strtol(tmp, NULL, 10);
	
	// Months are represented in format from 1 to 12
	if(month > 12 || month <= 0)
	{
		return nil;
	}
	
	// Day
	tmp[0] = str[i++];
	tmp[1] = str[i++];
	tmp[2] = '\0';
	
	day = strtol(tmp, NULL, 10);
	
	// Days are represented in format from 1 to 31
	if(day > 31 || day <= 0)
	{
		return nil;
	}
	
	// Hour
	tmp[0] = str[i++];
	tmp[1] = str[i++];
	tmp[2] = '\0';
	
	hour = strtol(tmp, NULL, 10);
	
	// Hours are represented in format from 0 to 23
	if(hour > 23 || hour < 0)
	{
		return nil;
	}
	
	// Minute
	tmp[0] = str[i++];
	tmp[1] = str[i++];
	tmp[2] = '\0';
	
	minute = strtol(tmp, NULL, 10);
	
	// Minutes are represented in format from 0 to 59
	if(minute > 59 || minute < 0)
	{
		return nil;
	}
	
	// Second
	tmp[0] = str[i++];
	tmp[1] = str[i++];
	tmp[2] = '\0';
	
	second = strtol(tmp, NULL, 10);
	
	// Seconds are represented in format from 0 to 59
	if(second > 59 || second < 0)
	{
		return nil;
	}
	
	CFGregorianDate gDate = { year, month, day, hour, minute, second };
	CFAbsoluteTime aTime = CFGregorianDateGetAbsoluteTime(gDate, NULL);
	
	return [NSDate dateWithTimeIntervalSinceReferenceDate:aTime];
}

static NSData* RawToData(const CSSM_DATA *data)
{
	if(data == NULL)
	{
		return nil;
	}
	
	return [NSData dataWithBytes:data->Data length:data->Length];
}

static NSDictionary* X509NameToDictionary(const CSSM_X509_NAME *x509Name)
{
	if(x509Name == NULL)
	{
		return nil;
	}
	
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:6];
	NSMutableArray *others = [NSMutableArray arrayWithCapacity:6];
	
	UInt32 i, j;
	for(i = 0; i < x509Name->numberOfRDNs; i++)
	{
		const CSSM_X509_RDN *name = &x509Name->RelativeDistinguishedName[i];
		
		for(j = 0; j < name->numberOfPairs; j++)
		{
			const CSSM_X509_TYPE_VALUE_PAIR *pair = &name->AttributeTypeAndValue[j];
			
			NSString *value = DataToString(&pair->value, &pair->valueType);
			if(value)
			{
				NSString *key = KeyForOid(&pair->type);
				if(key)
					[result setObject:value forKey:key];
				else
					[others addObject:value];
			}
		}
	}
	
	if([others count] > 0)
	{
		[result setObject:others forKey:X509_OTHERS];
	}
	
	return result;
}

static void AddCSSMField(const CSSM_FIELD *field, NSMutableDictionary *dict)
{
	const CSSM_DATA *fieldData = &field->FieldValue;
	const CSSM_OID  *fieldOid  = &field->FieldOid;
	
	if(CompareOids(fieldOid, &CSSMOID_X509V1SerialNumber))
	{
		NSData *data = RawToData(fieldData);
		if(data)
		{
			[dict setObject:data forKey:X509_SERIAL_NUMBER];
		}
	}
	else if(CompareOids(fieldOid, &CSSMOID_X509V1IssuerNameCStruct))
	{
		CSSM_X509_NAME_PTR issuer = (CSSM_X509_NAME_PTR)fieldData->Data;
		if(issuer && fieldData->Length == sizeof(CSSM_X509_NAME))
		{
			NSDictionary *issuerDict = X509NameToDictionary(issuer);
			if(issuerDict)
			{
				[dict setObject:issuerDict forKey:X509_ISSUER];
			}
		}
	}
	else if(CompareOids(fieldOid, &CSSMOID_X509V1SubjectNameCStruct))
	{
		CSSM_X509_NAME_PTR subject = (CSSM_X509_NAME_PTR)fieldData->Data;
		if(subject && fieldData->Length == sizeof(CSSM_X509_NAME))
		{
			NSDictionary *subjectDict = X509NameToDictionary(subject);
			if(subjectDict)
			{
				[dict setObject:subjectDict forKey:X509_SUBJECT];
			}
		}
	}
	else if(CompareOids(fieldOid, &CSSMOID_X509V1ValidityNotBefore))
	{
		CSSM_X509_TIME_PTR time = (CSSM_X509_TIME_PTR)fieldData->Data;
		if(time && fieldData->Length == sizeof(CSSM_X509_TIME))
		{
			NSDate *date = TimeToDate((const char *)time->time.Data, time->time.Length);
			if(date)
			{
				[dict setObject:date forKey:X509_NOT_VALID_BEFORE];
			}
		}
	}
	else if(CompareOids(fieldOid, &CSSMOID_X509V1ValidityNotAfter))
	{
		CSSM_X509_TIME_PTR time = (CSSM_X509_TIME_PTR)fieldData->Data;
		if(time && fieldData->Length == sizeof(CSSM_X509_TIME))
		{
			NSDate *date = TimeToDate((const char *)time->time.Data, time->time.Length);
			if(date)
			{
				[dict setObject:date forKey:X509_NOT_VALID_AFTER];
			}
		}
	}
	else if(CompareOids(fieldOid, &CSSMOID_X509V1SubjectPublicKeyCStruct))
	{
		CSSM_X509_SUBJECT_PUBLIC_KEY_INFO_PTR pubKeyInfo = (CSSM_X509_SUBJECT_PUBLIC_KEY_INFO_PTR)fieldData->Data;
		if(pubKeyInfo && fieldData->Length == sizeof(CSSM_X509_SUBJECT_PUBLIC_KEY_INFO))
		{
			NSData *data = RawToData(&pubKeyInfo->subjectPublicKey);
			if(data)
			{
				[dict setObject:data forKey:X509_PUBLIC_KEY];
			}
		}
	}
}

+ (NSDictionary *)extractCertDictFromSocket:(GCDAsyncSocket *)socket
{
	if (socket == nil)
	{
		return nil;
	}
	
	__block NSDictionary *result = nil;
	
#if TARGET_OS_IPHONE
	
	dispatch_block_t block = ^{
		
		CFReadStreamRef readStream = [socket readStream];
		if (readStream == NULL)
			return;
		
		CFArrayRef certs = CFReadStreamCopyProperty(readStream, kCFStreamPropertySSLPeerCertificates);
		if (certs && (CFArrayGetCount(certs) > 0))
		{
			// The first cert in the chain is the subject cert
			SecCertificateRef cert = (SecCertificateRef)CFArrayGetValueAtIndex(certs, 0);
			
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			result = [[self extractCertDictFromCert:cert] retain];
			
			[pool release];
		}
		
		if(certs) CFRelease(certs);
	};
	[socket performBlock:block];
	
#else
	
	dispatch_block_t block = ^{
		
		SSLContextRef sslContext = [socket sslContext];
		if (sslContext == NULL)
			return;
		
		CFArrayRef certs = NULL;
		OSStatus status = SSLCopyPeerCertificates(sslContext, &certs);
		if (status == noErr && certs && (CFArrayGetCount(certs) > 0))
		{
			// The first cert in the chain is the subject cert
			SecCertificateRef cert = (SecCertificateRef)CFArrayGetValueAtIndex(certs, 0);
			
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			result = [[self extractCertDictFromCert:cert] retain];
			
			[pool release];
		}
		
		if(certs) CFRelease(certs);
	};
	[socket performBlock:block];
	
#endif
	
	return [result autorelease];
}

+ (NSDictionary *)extractCertDictFromIdentity:(SecIdentityRef)identity
{
	if(identity == NULL)
	{
		return nil;
	}
	
	NSDictionary *result = nil;
	SecCertificateRef cert = NULL;
	
	OSStatus err = SecIdentityCopyCertificate(identity, &cert);
	if(err)
	{
		cssmPerror("SecIdentityCopyCertificate", err);
		return nil;
	}
	else
	{
		result = [self extractCertDictFromCert:cert];
	}
	
	if(cert) CFRelease(cert);
	
	return result;
}

+ (NSDictionary *)extractCertDictFromCert:(SecCertificateRef)cert
{
	CSSM_CL_HANDLE clHandle = CLStartup();
	if(clHandle == 0)
	{
		return nil;
	}
	
	NSMutableDictionary *result = nil;
	
	CSSM_DATA certData;
	if(SecCertificateGetData(cert, &certData) == noErr)
	{
		uint32 i;
		uint32 numFields;
		CSSM_FIELD_PTR fieldPtr;
		
		CSSM_RETURN crtn = CSSM_CL_CertGetAllFields(clHandle, &certData, &numFields, &fieldPtr);
		if(crtn == CSSM_OK)
		{
			result = [NSMutableDictionary dictionaryWithCapacity:6];
			
			for(i = 0; i < numFields; i++)
			{
				AddCSSMField(&fieldPtr[i], result);
			}
			
			CSSM_CL_FreeFields(clHandle, numFields, &fieldPtr);
		}
	}
	
	CLShutdown(clHandle);
	
	return result;
}

@end
