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
#define PATH_STORE_STATE    [@"~/Documents/Store2.plist" stringByExpandingTildeInPath]

@implementation MAPIClient

+ (MAPIClient *)shared
{
    static MAPIClient * sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL * baseURL = [NSURL URLWithString: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"APIRoot"]];
        NSLog(@"%@", [baseURL absoluteString]);
        sharedClient = [[MAPIClient alloc] initWithBaseURL: baseURL];
    });
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        [self setRequestSerializer: [AFJSONRequestSerializer serializer]];
		[[self requestSerializer] setHTTPShouldHandleCookies: NO];

        [self setResponseSerializer: [AFJSONResponseSerializer serializerWithReadingOptions: NSJSONReadingAllowFragments]];

        @try {
            if ([[NSFileManager defaultManager] fileExistsAtPath: PATH_STORE_STATE]) {
                NSDictionary * dict = [NSKeyedUnarchiver unarchiveObjectWithFile: PATH_STORE_STATE];
                _globalObjectStore = [dict objectForKey:@"objectStore"];
                [self setUser: [dict objectForKey:@"user"]];
            }
            
            if ([[NSFileManager defaultManager] fileExistsAtPath: PATH_ACTIONS_STATE])
                _transactionsQueue = [NSKeyedUnarchiver unarchiveObjectWithFile: PATH_ACTIONS_STATE];
            
        } @catch (NSException * e) {
            NSLog(@"%@", [e description]);
        }
        
        if (!_globalObjectStore)
            _globalObjectStore = [NSMutableDictionary dictionary];
        if (!_transactionsQueue)
            _transactionsQueue = [NSMutableArray array];
        [self performNextAction];
    }
    return self;
}

- (void)apiReachabilityChanged:(AFNetworkReachabilityStatus)status
{
    if (status == AFNetworkReachabilityStatusNotReachable) {
        if (!_hasDisplayedDisconnectionNotice) {
            _hasDisplayedDisconnectionNotice = YES;
            NSString * msg = @"You've been disconnected from the internet. Your activity will be saved offline until a connection can be established.";
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
        [NSKeyedArchiver archiveRootObject:@{@"user":_user, @"objectStore":_globalObjectStore} toFile:PATH_STORE_STATE];
        [NSKeyedArchiver archiveRootObject:_transactionsQueue toFile: PATH_ACTIONS_STATE];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath: PATH_ACTIONS_STATE error: nil];
        [[NSFileManager defaultManager] removeItemAtPath: PATH_STORE_STATE error:nil];
    }
    _updateDiskCacheTriggered = NO;
}

#pragma mark Requesting Object Data

- (void)dictionaryAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback
{
    [self requestPath:path withMethod:@"GET" withParameters:nil userTriggered:triggered expectedClass:[NSDictionary class] success:successCallback failure:failureCallback];
}

- (void)arrayAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback
{
    [self requestPath:path withMethod:@"GET" withParameters:nil userTriggered:triggered expectedClass:[NSArray class] success:successCallback failure:failureCallback];
}

- (void)requestPath:(NSString*)path withMethod:(NSString*)method withParameters: params userTriggered:(BOOL)triggered expectedClass:(Class)expectation success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback
{
    if (!self.baseURL)
        @throw [NSException exceptionWithName:@"Cannot make request" reason:@"Base URL is not defined." userInfo:nil];
        
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:[[NSURL URLWithString:path relativeToURL:self.baseURL] absoluteString] parameters:params error:nil];
    AFHTTPRequestOperation * operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (expectation && ([responseObject isKindOfClass: expectation] == NO)) {
            NSError * error = [NSError errorWithExpectationFailure: [responseObject class]];
            if (triggered)
                [self displayNetworkError:error forOperation:operation withGoal:@"Request"];
            if (failureCallback)
                failureCallback(error);
            return;
        }
        successCallback(responseObject);

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (triggered)
            [self displayNetworkError:error forOperation:operation withGoal:@"Request"];
        if (failureCallback)
            failureCallback(error);
    }];
    [self.operationQueue addOperation:operation];
}

- (MModel*)globalObjectWithID:(NSString*)ID ofClass:(Class)type
{
    NSString * key = NSStringFromClass(type);
    NSMutableDictionary * dict = [_globalObjectStore objectForKey: key];
    return [dict objectForKey: ID];
}

- (void)addGlobalObject:(MModel*)model
{
    NSString * key = NSStringFromClass([model class]);

    if (![_globalObjectStore objectForKey: key])
        [_globalObjectStore setObject:[NSMutableDictionary dictionary] forKey:key];
    
    [[_globalObjectStore objectForKey: key] setObject: model forKey: [model ID]];
}

- (void)setUser:(MUser *)user
{
    _user = user;

    if (user)
        [[self requestSerializer] setAuthorizationHeaderFieldWithUsername:[user credentialUsername] password:[user credentialPassword]];
    else
        [[self requestSerializer] clearAuthorizationHeader];
    
    [self updateDiskCache: YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_USER_CHANGED object:nil];
}

#pragma mark Tracking API Access and Recovering from Offline State

- (NSUInteger)numberOfQueuedActions
{
    return [_transactionsQueue count];
}

- (void)queueAPITransaction:(MAPITransaction*)a
{
    // look for another item in the queue effecting the same item that has not started yet
    if ([_transactionsQueue containsObject: a] == YES)
        return;
    
    [_transactionsQueue addObject: a];
    if (([[self reachabilityManager] networkReachabilityStatus] != AFNetworkReachabilityStatusNotReachable) && (![a started]))
        [a performDeferred];
    
    NSLog(@"API: Queued API action: %@", [a description]);
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}

- (void)removeQueuedTransactionsFor:(MModel*)obj
{
    for (int ii = (int)[_transactionsQueue count] - 1; ii >= 0; ii--) {
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
        [self displayNetworkError:err forOperation:nil withGoal:@"Request"];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}

- (void)dequeueAPITransaction:(MAPITransaction*)a
{
    [_transactionsQueue removeObject: a];
    [NSKeyedArchiver archiveRootObject:_transactionsQueue toFile:PATH_ACTIONS_STATE];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_API_QUEUE_CHANGED object:nil];
}

- (void)performNextActionIfReconnected
{
    if ([[self reachabilityManager] networkReachabilityStatus] != AFNetworkReachabilityStatusNotReachable)
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

- (void)displayNetworkError:(NSError*)error forOperation:(AFHTTPRequestOperation*)operation withGoal:(NSString*)goal
{
    NSString * message = nil;
    BOOL responseIsDict = [[operation responseObject] isKindOfClass: [NSDictionary class]];
    
    if (responseIsDict && [[[operation responseObject] objectForKey: @"error"] isKindOfClass: [NSString class]]) {
        message = [[operation responseObject] objectForKey: @"error"];
    
    } else if (responseIsDict && [[[operation responseObject] allKeys] count] == 1) {
        id onlyValue = [[[operation responseObject] allValues] lastObject];
        if ([onlyValue isKindOfClass: [NSArray class]])
            message = [onlyValue lastObject];
        else if ([onlyValue isKindOfClass: [NSString class]])
            message = onlyValue;
    
    } else if (([error code] == 401) || ([[operation response] statusCode] == 401)) {
        message = @"Please check your email address and password.";

    } else {
        message = [error localizedDescription];
    }

    NSString * title = [goal stringByAppendingString: @" Failed"];
    [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
}



@end
