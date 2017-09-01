// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2016, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#import "DDContextFilterLogFormatter.h"
#import <pthread/pthread.h>

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface DDLoggingContextSet : NSObject

- (void)addToSet:(int)loggingContext;
- (void)removeFromSet:(int)loggingContext;

- (NSArray *)currentSet;

- (BOOL)isInSet:(int)loggingContext;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDContextWhitelistFilterLogFormatter
{
    DDLoggingContextSet *contextSet;
}

- (id)init
{
    if ((self = [super init]))
    {
        contextSet = [[DDLoggingContextSet alloc] init];
    }
    return self;
}


- (void)addToWhitelist:(int)loggingContext
{
    [contextSet addToSet:loggingContext];
}

- (void)removeFromWhitelist:(int)loggingContext
{
    [contextSet removeFromSet:loggingContext];
}

- (NSArray *)whitelist
{
    return [contextSet currentSet];
}

- (BOOL)isOnWhitelist:(int)loggingContext
{
    return [contextSet isInSet:loggingContext];
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    if ([self isOnWhitelist:logMessage->logContext])
        return logMessage->logMsg;
    else
        return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDContextBlacklistFilterLogFormatter
{
    DDLoggingContextSet *contextSet;
}

- (id)init
{
    if ((self = [super init]))
    {
        contextSet = [[DDLoggingContextSet alloc] init];
    }
    return self;
}


- (void)addToBlacklist:(int)loggingContext
{
    [contextSet addToSet:loggingContext];
}

- (void)removeFromBlacklist:(int)loggingContext
{
    [contextSet removeFromSet:loggingContext];
}

- (NSArray *)blacklist
{
    return [contextSet currentSet];
}

- (BOOL)isOnBlacklist:(int)loggingContext
{
    return [contextSet isInSet:loggingContext];
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    if ([self isOnBlacklist:logMessage->logContext])
        return nil;
    else
        return logMessage->logMsg;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


@interface DDLoggingContextSet () {
    pthread_mutex_t _mutex;
    NSMutableSet *_set;
}

@end


@implementation DDLoggingContextSet

- (instancetype)init {
    if ((self = [super init])) {
        _set = [[NSMutableSet alloc] init];
        pthread_mutex_init(&_mutex, NULL);
    }

    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_mutex);
}

- (void)addToSet:(int)loggingContext {
    pthread_mutex_lock(&_mutex);
    {
        [_set addObject:@(loggingContext)];
    }
    pthread_mutex_unlock(&_mutex);
}

- (void)removeFromSet:(int)loggingContext {
    pthread_mutex_lock(&_mutex);
    {
        [_set removeObject:@(loggingContext)];
    }
    pthread_mutex_unlock(&_mutex);
}

- (NSArray *)currentSet {
    NSArray *result = nil;

    pthread_mutex_lock(&_mutex);
    {
        result = [_set allObjects];
    }
    pthread_mutex_unlock(&_mutex);

    return result;
}

- (BOOL)isInSet:(int)loggingContext {
    BOOL result = NO;

    pthread_mutex_lock(&_mutex);
    {
        result = [_set containsObject:@(loggingContext)];
    }
    pthread_mutex_unlock(&_mutex);

    return result;
}

@end
