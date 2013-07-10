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
    
    if ((type == TRANSACTION_SAVE) && ([object isUnsaved]))
        [t setRequestURL: [[object parent] resourcePath]];
    else
        [t setRequestURL: [object resourcePath]];

    return t;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _type = [aDecoder decodeIntForKey: @"type"];
        _object = [aDecoder decodeObjectForKey: @"object"];
        _callback = NULL;
        _started = NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_object forKey:@"object"];
    [aCoder encodeObject:_requestURL forKey: @"requestURL"];
    [aCoder encodeInt:_type forKey:@"type"];
}

- (void)perform
{
    _started = true;
    
    if (!_object) {
        NSLog(@"Throwing away action that cannot be performed, object ID: %@", [_object ID]);
        [[MAPIClient shared] finishedAPITransaction:self withError: [NSError errorWithDomain:@"Advocate" code:500 userInfo:nil]];
        _started = YES;
        if (_callback)
            _callback(NO);
        return;
    }
    
    NSString * method = @"PUT";
    if ([_object isUnsaved])
        method = @"POST";

    [[MAPIClient shared] requestPath:_requestURL withMethod:method withParameters:[_object resourceJSON] userTriggered:NO expectedClass:[NSDictionary class] success:^(id responseObject) {
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
