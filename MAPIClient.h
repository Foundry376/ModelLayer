//
//  MAPIClient.h
//  Advocate
//
//  Created by Ben Gotow on 6/29/13.
//  Copyright (c) 2013 Bloganizer Inc. All rights reserved.
//

#import "MUser.h"

#define NOTIF_USER_CHANGED          @"m_user_changed"
#define NOTIF_COLLECTION_CHANGED    @"m_collection_changed"
#define NOTIF_MODEL_CHANGED         @"m_model_changed"
#define NOTIF_API_QUEUE_CHANGED     @"m_api_queue_changed"

@interface MAPIClient : AFHTTPRequestOperationManager
{
    NSMutableArray * _transactionsQueue;
    BOOL _hasDisplayedDisconnectionNotice;
    BOOL _updateDiskCacheTriggered;
    
    NSMutableDictionary * _globalObjectStore;
}

@property (nonatomic, retain) MUser * user;

+ (MAPIClient *)shared;

- (void)updateDiskCache:(BOOL)immediate;
- (void)updateDiskCacheDebounced;


#pragma mark Requesting Object Data

- (void)dictionaryAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback;
- (void)arrayAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback;
- (void)requestPath:(NSString*)path withMethod:(NSString*)method withParameters: params userTriggered:(BOOL)triggered expectedClass:(Class)expectation success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback;

- (MModel*)globalObjectWithID:(NSString*)ID ofClass:(Class)type;
- (void)addGlobalObject:(MModel*)model;

#pragma mark Tracking API Access and Recovering from Offline State

- (int)numberOfQueuedActions;
- (void)queueAPITransaction:(MAPITransaction*)a;
- (void)removeQueuedTransactionsFor:(MModel*)obj;
- (void)finishedAPITransaction:(MAPITransaction*)a withError:(NSError*)err;
- (void)performNextAction;

#pragma mark Handling Request Results

- (void)displayNetworkError:(NSError*)error forOperation:(AFHTTPRequestOperation*)operation withGoal:(NSString*)goal;


@end
