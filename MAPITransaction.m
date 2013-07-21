//
//  MAPIAction.m
//  Mib.io
//
//  Created by Ben Gotow on 10/16/12.
//  Copyright (c) 2012 Foundry376. All rights reserved.
//

#import "MAPITransaction.h"
#import "MAPIClient.h"
#import "MModel.h"

@implementation MAPITransaction

+ (MAPITransaction *)transactionForPerforming:(MAPITransactionType)type of:(MModel*)object
{
    MAPITransaction * t = [[MAPITransaction alloc] init];
    [t setCallback: NULL];
    [t setType: type];
    [t setObject: object];
    
    if (type == TRANSACTION_DELETE) {
        [t setRequestURL: [object resourcePath]];
        [t setRequestMethod: @"DELETE"];
    } else {
        if ((type == TRANSACTION_SAVE) && ([object isUnsaved])) {
            [t setRequestURL: [[object parent] resourcePath]];
            [t setRequestMethod: @"POST"];
        } else {
            [t setRequestURL: [object resourcePath]];
            [t setRequestMethod: @"PUT"];
        }
    }

    return t;
}

+ (MAPITransaction *)transactionForMethod:(NSString*)method onPath:(NSString*)path
{
    MAPITransaction * t = [[MAPITransaction alloc] init];
    [t setCallback: NULL];
    [t setType: TRANSACTION_CUSTOM];
    [t setRequestURL: path];
    [t setRequestMethod: method];
    
    return t;    
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _type = [aDecoder decodeIntForKey: @"type"];
        _object = [aDecoder decodeObjectForKey: @"object"];
        _requestURL = [aDecoder decodeObjectForKey: @"requestURL"];
        _requestMethod = [aDecoder decodeObjectForKey: @"requestMethod"];
        _callback = NULL;
        _started = NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_object forKey:@"object"];
    [aCoder encodeObject:_requestURL forKey: @"requestURL"];
    [aCoder encodeObject:_requestMethod forKey: @"requestMethod"];
    [aCoder encodeInt:_type forKey:@"type"];
}

- (void)perform
{
    _started = true;

    [[MAPIClient shared] requestPath:_requestURL withMethod:_requestMethod withParameters:[_object resourceJSON] userTriggered:NO expectedClass:[NSDictionary class] success:^(id responseObject) {
        [self.object updateWithResourceJSON: responseObject];
        [[MAPIClient shared] finishedAPITransaction:self withError: nil];
        if (_callback)
            _callback(YES);

    } failure:^(NSError *err) {
        [[MAPIClient shared] finishedAPITransaction:self withError: err];
        _started = NO;
        if (_callback)
            _callback(NO);

    }];
}

- (void)performDeferred
{
    _started = YES;
    [self performSelectorOnMainThread:@selector(perform) withObject:nil waitUntilDone:NO];
}

- (BOOL)isEqual:(id)other
{
    if (([other isKindOfClass: [self class]]) && ([[other object] isEqual: [self object]]) && ([other started] == NO) && ([self started] == NO))
        return YES;
    return NO;
}

@end
