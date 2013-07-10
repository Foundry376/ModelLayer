//
//  MAPIClient.m
//  Advocate
//
//  Created by Ben Gotow on 6/29/13.
//  Copyright (c) 2013 Bloganizer Inc. All rights reserved.
//

#import "MAPIClient.h"
#import "NSError+MErrors.h"

#define PATH_ACTIONS_STATE [@"~/Documents/Actions2.plist" stringByExpandingTildeInPath]
#define PATH_USER_STATE    [@"~/Documents/User2.plist" stringByExpandingTildeInPath]
#define BASE_URL            @"https://localhost:4430/api/v0"

@implementation MAPIClient

+ (MAPIClient *)shared
{
    static MAPIClient * sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[MAPIClient alloc] initWithBaseURL:[NSURL URLWithString: BASE_URL]];
    });
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        [self registerHTTPOperationClass: [AFJSONRequestOperation class]];
        [self setDefaultHeader:@"Accept" value:@"application/json"];
        [self setAllowsInvalidSSLCertificate: YES];
        
        typeof(self) __weak __self = self;
        [self setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            [__self apiReachabilityChanged: status];
        }];

        @try {
            if ([[NSFileManager defaultManager] fileExistsAtPath: PATH_USER_STATE])
                _user = [NSKeyedUnarchiver unarchiveObjectWithFile: PATH_USER_STATE];

            if ([[NSFileManager defaultManager] fileExistsAtPath: PATH_ACTIONS_STATE])
                _transactionsQueue = [NSKeyedUnarchiver unarchiveObjectWithFile: PATH_ACTIONS_STATE];
            
        } @catch (NSException * e) {
            NSLog(@"%@", [e description]);
        }
        
        if (_user.thirdPartyToken)
            [self setAuthorizationHeaderWithUsername: @"facebook" password: _user.thirdPartyToken];
        else
            _user = nil;
        
        if (!_transactionsQueue)
            _transactionsQueue = [NSMutableArray array];
        [self performNextAction];

        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    }
    return self;
}

- (void)apiReachabilityChanged:(AFNetworkReachabilityStatus)status {
    if (status == AFNetworkReachabilityStatusNotReachable) {
        if (!_hasDisplayedDisconnectionNotice) {
            _hasDisplayedDisconnectionNotice = YES;
            NSString * msg = @"You've been disconnected from the internet. Your work will be saved offline until a connection can be established.";
            UIAlertView * a = [[UIAlertView alloc] initWithTitle:@"Offline" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [a show];
        }
    } else {
        _hasDisplayedDisconnectionNotice = NO;
        [self performNextAction];
    }
}


- (void)updateDiskCache:(BOOL)immediate
{
    if (immediate)
        [self updateDiskCacheDebounced];
    
    else if (!_updateDiskCacheTriggered) {
        [self performSelector:@selector(updateDiskCacheDebounced) withObject:nil afterDelay: 1.0];
        _updateDiskCacheTriggered = YES;
    }
}

- (void)updateDiskCacheDebounced
{
    if (_user) {
        [NSKeyedArchiver archiveRootObject:_user toFile:PATH_USER_STATE];
        [NSKeyedArchiver archiveRootObject:_transactionsQueue toFile: PATH_ACTIONS_STATE];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath: PATH_ACTIONS_STATE error: nil];
        [[NSFileManager defaultManager] removeItemAtPath: PATH_USER_STATE error:nil];
    }
    _updateDiskCacheTriggered = NO;
}

#pragma mark Requesting Object Data

- (void)getModelAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback
{
    [self requestPath:path withMethod:@"GET" withParameters:nil userTriggered:triggered expectedClass:[NSDictionary class] success:successCallback failure:failureCallback];
}

- (void)getCollectionAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback
{
    [self requestPath:path withMethod:@"GET" withParameters:nil userTriggered:triggered expectedClass:[NSArray class] success:successCallback failure:failureCallback];
}

- (void)requestPath:(NSString*)path withMethod:(NSString*)method withParameters: params userTriggered:(BOOL)triggered expectedClass:(Class)expectation success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback
{
    NSURLRequest *request = [[MAPIClient shared] requestWithMethod:method path:path parameters:params];
    AFHTTPRequestOperation *operation = [[MAPIClient shared] HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (expectation && ([responseObject isKindOfClass: expectation] == NO)) {
            NSError * err = [NSError errorWithExpectationFailure: [responseObject class]];
            if (triggered)
                [self criticalRequestFailed: err];
            if (failureCallback)
                failureCallback(err);
            return;
        }
        successCallback(responseObject);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *err) {
        if (triggered)
            [self criticalRequestFailed: err];
        if (failureCallback)
            failureCallback(err);
    }];
    
    [[MAPIClient shared] enqueueHTTPRequestOperation:operation];
}

- (void)setUser:(BAUser *)user
{
    _user = user;
    [self updateDiskCache: YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_USER_CHANGED object:nil];
    
}
- (void)authenticateWithToken:(NSString*)accessToken
{
    if (accessToken) {
        [self setAuthorizationHeaderWithUsername: @"facebook" password: accessToken];
        [self getModelAtPath:@"users/me" userTriggered:YES success:^(id responseObject){
            self.user = [[BAUser alloc] initWithDictionary: responseObject];
            self.user.thirdPartyToken = accessToken;
            
        } failure:^(NSError *err) {
            [self clearAuthorizationHeader];
            self.user = nil;
        }];
    } else {
        [self clearAuthorizationHeader];
        self.user = nil;
    }
}

#pragma mark Tracking API Access and Recovering from Offline State

- (int)numberOfQueuedActions
{
    return [_transactionsQueue count];
}

- (void)queueAPITransaction:(MAPITransaction*)a
{
    if ([a object] == nil)
        @throw [NSException exceptionWithName:@"Queue API Action" reason:@"Trying to enqueue item with nil object" userInfo:nil];
    
    
    // look for another item in the queue effecting the same item that has not started yet
    if ([_transactionsQueue containsObject: a] == YES)
        return;
    
    [_transactionsQueue addObject: a];
    if (([self networkReachabilityStatus] != AFNetworkReachabilityStatusNotReachable) && (![a started]))
        [a performDeferred];
    
    NSLog(@"API: Queued API action: %@", [a description]);
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}

- (void)removeQueuedTransactionsFor:(MModel*)obj
{
    for (int ii = [_transactionsQueue count] - 1; ii >= 0; ii--) {
        MAPITransaction * t = [_transactionsQueue objectAtIndex: ii];
        if ([t object] == obj)
            [_transactionsQueue removeObjectAtIndex: ii];
    }
    
    NSLog(@"API: Removed API actions for: %@", [obj description]);
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}

- (void)finishedAPITransaction:(MAPITransaction*)a withError:(NSError*)err
{
    if ([_transactionsQueue containsObject: a] == NO)
        return NSLog(@"Finished unknown API call.");
    
    NSLog(@"API: Finished API action: %@ with error: %@", [a description], [err localizedDescription]);
    
    if (!err) {
        [self dequeueAPITransaction: a];
        [self performNextAction];
        
    } else if (err) {
        // TODO: Additional logic was here... Do we always want to throw away the transaction if it fails once?
        [self dequeueAPITransaction: a];
        [self criticalRequestFailed: err];
    }
}

- (void)dequeueAPITransaction:(MAPITransaction*)a
{
    [_transactionsQueue removeObject: a];
    [NSKeyedArchiver archiveRootObject:_transactionsQueue toFile:PATH_ACTIONS_STATE];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}

- (void)performNextActionIfReconnected
{
    if ([self networkReachabilityStatus] != AFNetworkReachabilityStatusNotReachable)
        [self performNextAction];
    else {
        NSString * msg = @"Please connect to the internet and try to sync again.";
        UIAlertView * a = [[UIAlertView alloc] initWithTitle:@"Offline" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [a show];
    }
}

- (void)performNextAction
{
    for (MAPITransaction * a in _transactionsQueue)
        if ([a started] == NO)
            return [a performDeferred];
    
    // triggers an update of the queue interface
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}


#pragma mark Handling Request Results

- (void)criticalRequestFailed:(NSError*)err
{
    NSData * jsonData = [[err.userInfo objectForKey: @"NSLocalizedRecoverySuggestion"] dataUsingEncoding: NSUTF8StringEncoding];
    NSString * message = err.localizedDescription;

    if (jsonData) {
        NSDictionary * json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:NULL];
        if (json) message = [json objectForKey: @"error"];
    }

    if (message)
        [[[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}


@end
