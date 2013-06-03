//
//  SSLError.h
//  SecureHTTPServer
//
//  Created by Dirk-Willem van Gulik on 05/04/2012.
//  Copyright (c) 2012 British Broadcasting Corporation Public Service, Future Media and Technology, Chief Internet Architect. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SSLError : NSObject
+(NSString *)msgForError:(int)err;
@end
