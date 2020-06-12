//
//  CocoaAsyncSocket.h
//  CocoaAsyncSocket
//
//  Created by Derek Clarkson on 10/08/2015.
//  CocoaAsyncSocket project is in the public domain.
//

#if __has_feature(modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import Foundation;
#endif

//! Project version number for CocoaAsyncSocket.
FOUNDATION_EXPORT double cocoaAsyncSocketVersionNumber;

//! Project version string for CocoaAsyncSocket.
FOUNDATION_EXPORT const unsigned char cocoaAsyncSocketVersionString[];

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
