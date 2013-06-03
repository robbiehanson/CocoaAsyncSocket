//
//  SSLError.m
//  SecureHTTPServer
//
//  Created by Dirk-Willem van Gulik on 05/04/2012.
//  Copyright (c) 2012 British Broadcasting Corporation Public Service, Future Media and Technology, Chief Internet Architect. All rights reserved.
//

#import "SSLError.h"
#import <Security/Security.h>
#import <Security/SecureTransport.h>

@implementation SSLError

static NSDictionary * _dict;

+ (void)initialize {
    _dict = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"errSSLProtocol",	[NSNumber numberWithInt:-9800],
                               @"errSSLNegotiation",	[NSNumber numberWithInt:-9801],
                               @"errSSLFatalAlert",	[NSNumber numberWithInt:-9802],
                               @"errSSLWouldBlock",	[NSNumber numberWithInt:-9803],
                               @"errSSLSessionNotFound",	[NSNumber numberWithInt:-9804],
                               @"errSSLClosedGraceful",	[NSNumber numberWithInt:-9805],
                               @"errSSLClosedAbort",	[NSNumber numberWithInt:-9806],
                               @"errSSLXCertChainInvalid",	[NSNumber numberWithInt:-9807],
                               @"errSSLBadCert",	[NSNumber numberWithInt:-9808],
                               @"errSSLCrypto",	[NSNumber numberWithInt:-9809],
                               @"errSSLInternal",	[NSNumber numberWithInt:-9810],
                               @"errSSLModuleAttach",	[NSNumber numberWithInt:-9811],
                               @"errSSLUnknownRootCert",	[NSNumber numberWithInt:-9812],
                               @"errSSLNoRootCert",	[NSNumber numberWithInt:-9813],
                               @"errSSLCertExpired",	[NSNumber numberWithInt:-9814],
                               @"errSSLCertNotYetValid",	[NSNumber numberWithInt:-9815],
                               @"errSSLClosedNoNotify",	[NSNumber numberWithInt:-9816],
                               @"errSSLBufferOverflow",	[NSNumber numberWithInt:-9817],
                               @"errSSLBadCipherSuite",	[NSNumber numberWithInt:-9818],
                               @"errSSLPeerUnexpectedMsg",	[NSNumber numberWithInt:-9819],
                               @"errSSLPeerBadRecordMac",	[NSNumber numberWithInt:-9820],
                               @"errSSLPeerDecryptionFail",	[NSNumber numberWithInt:-9821],
                               @"errSSLPeerRecordOverflow",	[NSNumber numberWithInt:-9822],
                               @"errSSLPeerDecompressFail",	[NSNumber numberWithInt:-9823],
                               @"errSSLPeerHandshakeFail",	[NSNumber numberWithInt:-9824],
                               @"errSSLPeerBadCert",	[NSNumber numberWithInt:-9825],
                               @"errSSLPeerUnsupportedCert",	[NSNumber numberWithInt:-9826],
                               @"errSSLPeerCertRevoked",	[NSNumber numberWithInt:-9827],
                               @"errSSLPeerCertExpired",	[NSNumber numberWithInt:-9828],
                               @"errSSLPeerCertUnknown",	[NSNumber numberWithInt:-9829],
                               @"errSSLIllegalParam",	[NSNumber numberWithInt:-9830],
                               @"errSSLPeerUnknownCA",	[NSNumber numberWithInt:-9831],
                               @"errSSLPeerAccessDenied",	[NSNumber numberWithInt:-9832],
                               @"errSSLPeerDecodeError",	[NSNumber numberWithInt:-9833],
                               @"errSSLPeerDecryptError",	[NSNumber numberWithInt:-9834],
                               @"errSSLPeerExportRestriction",	[NSNumber numberWithInt:-9835],
                               @"errSSLPeerProtocolVersion",	[NSNumber numberWithInt:-9836],
                               @"errSSLPeerInsufficientSecurity",	[NSNumber numberWithInt:-9837],
                               @"errSSLPeerInternalError",	[NSNumber numberWithInt:-9838],
                               @"errSSLPeerUserCancelled",	[NSNumber numberWithInt:-9839],
                               @"errSSLPeerNoRenegotiation",	[NSNumber numberWithInt:-9840],
                               @"errSSLServerAuthCompleted",	[NSNumber numberWithInt:-9841],
                               @"errSSLClientCertRequested",	[NSNumber numberWithInt:-9842],
                               @"errSSLHostNameMismatch",	[NSNumber numberWithInt:-9843],
                               @"errSSLConnectionRefused",	[NSNumber numberWithInt:-9844],
                               @"errSSLDecryptionFail",	[NSNumber numberWithInt:-9845],
                               @"errSSLBadRecordMac",	[NSNumber numberWithInt:-9846],
                               @"errSSLRecordOverflow",	[NSNumber numberWithInt:-9847],
                               @"errSSLBadConfiguration",	[NSNumber numberWithInt:-9848],
                               @"errSSLLast",	[NSNumber numberWithInt:-9849],
                             nil];
};
+(NSString *)msgForError:(int)err {
    return [_dict objectForKey:[NSNumber numberWithInt:err]];
}
@end
