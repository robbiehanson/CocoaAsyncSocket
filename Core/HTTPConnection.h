#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class HTTPMessage;
@class HTTPServer;
@class WebSocket;
@protocol HTTPResponse;


#define HTTPConnectionDidDieNotification  @"HTTPConnectionDidDie"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConfig : NSObject
{
	HTTPServer __unsafe_unretained *server;
	NSString __strong *documentRoot;
	dispatch_queue_t queue;
}

- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot;
- (id)initWithServer:(HTTPServer *)server documentRoot:(NSString *)documentRoot queue:(dispatch_queue_t)q;

@property (nonatomic, unsafe_unretained, readonly) HTTPServer *server;
@property (nonatomic, strong, readonly) NSString *documentRoot;
@property (nonatomic, readonly) dispatch_queue_t queue;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extern const id kSSLAcceptableClientCertificatesFromKeychain;

@interface HTTPConnection : NSObject
{
	dispatch_queue_t connectionQueue;
	GCDAsyncSocket *asyncSocket;
	HTTPConfig *config;
	
	BOOL started;
	
	HTTPMessage *request;
	unsigned int numHeaderLines;
	
	BOOL sentResponseHeaders;
	
	NSString *nonce;
	long lastNC;
	
	NSObject<HTTPResponse> *httpResponse;
	
	NSMutableArray *ranges;
	NSMutableArray *ranges_headers;
	NSString *ranges_boundry;
	int rangeIndex;
	
	UInt64 requestContentLength;
	UInt64 requestContentLengthReceived;
	UInt64 requestChunkSize;
	UInt64 requestChunkSizeReceived;
  
	NSMutableArray *responseDataSizes;
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig;

- (void)start;
- (void)stop;

- (void)startConnection;

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path;
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path;

// SSL and Server Authentication *to* the client.
//
- (BOOL)isSecureServer;
- (NSArray *)sslIdentityAndCertificates;

// clientAuthentication - (optional) authentication of the client to the server. This function is
// only called for an isSecureServer. The default is no client authentication.
//
//  kNeverAuthenticate      skip client authentication; sslAcceptableClientCertificates not called.
//  kAlwaysAuthenticate     require it - and check against list returned by sslAcceptableClientCertificates;
//  kTryAuthenticate        try to authenticate against the list provided by sslAcceptableClientCertificates;
//                          but not an error if client doesn't have a cert.
// 
// The default is to return kNeverAuthenticate. I.e. no Client authentication.
//
- (SSLAuthenticate)clientAuthentication;

// List of acceptable certificate (authorities) for client authentication. Called when
// clientAuthentication returns kAlwaysAuthenticate or kTryAuthenticate. Use the constant
// kSSLAcceptableClientCertificatesFromKeychain to indicate that any Certificate (Authority)
// marked as 'trusted' in the keychain is acceptable. In this case or when the array
// returned is empty or nil, no list of acceptable authorities is revealed to the client
// during the initial handshake. When an explicit list of 1 or more certificates is returned
// then this  list is presented to the client, in the order provided. It is an error to
// return nil or an empty array when clientAuthentication is not set to kTryAuthenticate.
//
// The default is to return kSSLAcceptableClientCertificatesFromKeychain
//
- (NSArray *)sslAcceptableClientCertificates;

// Called post SSL negotiation. Can be used to further refine access based on the elements
// of the distingished name (e.g. the CN or Email address in the certificate) or any otehr
// aspect of the certificate and its issuer chain.
//
// If clientAuthentication has returned kAlwaysAuthenticate or kTryAuthenticate and an 
// sslAcceptableClientCertificates was non-nil/empty; then the certificate has already 
// been cryptographically verified against the chain specified. 
// 
// This is not the case when clientAuthentication returned kTryAuthenticate and 
// sslAcceptableClientCertificates was nil/empty. In that case any cryptographic verification
// is left to the implementor of isAcceptableClientCertificate.
//
// The default is to return YES when any sslAcceptableClientCertificates have been specified
// and NO when sslAcceptableClientCertificates returned nil or an empty array.
//
- (BOOL)isAcceptableClientCertificate:(SecCertificateRef *)certificate;

- (BOOL)isPasswordProtected:(NSString *)path;
- (BOOL)useDigestAccessAuthentication;
- (NSString *)realm;
- (NSString *)passwordForUser:(NSString *)username;

- (NSDictionary *)parseParams:(NSString *)query;
- (NSDictionary *)parseGetParams;

- (NSString *)requestURI;

- (NSArray *)directoryIndexFileNames;
- (NSString *)filePathForURI:(NSString *)path;
- (NSString *)filePathForURI:(NSString *)path allowDirectory:(BOOL)allowDirectory;
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path;
- (WebSocket *)webSocketForURI:(NSString *)path;

- (void)prepareForBodyWithSize:(UInt64)contentLength;
- (void)processBodyData:(NSData *)postDataChunk;
- (void)finishBody;

- (void)handleVersionNotSupported:(NSString *)version;
- (void)handleAuthenticationFailed;
- (void)handleResourceNotFound;
- (void)handleInvalidRequest:(NSData *)data;
- (void)handleUnknownMethod:(NSString *)method;

- (NSData *)preprocessResponse:(HTTPMessage *)response;
- (NSData *)preprocessErrorResponse:(HTTPMessage *)response;

- (void)finishResponse;

- (BOOL)shouldDie;
- (void)die;

@end

@interface HTTPConnection (AsynchronousHTTPResponse)
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender;
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender;
@end
