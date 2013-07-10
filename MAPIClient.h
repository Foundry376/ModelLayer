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
#define NOTIF_API_QUEUE_CHANGED     @"m_api_queue_changed"

#define API_TIMESTAMP_FORMAT @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"


@interface MAPIClient : AFHTTPClient
{
    NSMutableArray * _transactionsQueue;
    BOOL _hasDisplayedDisconnectionNotice;
    BOOL _updateDiskCacheTriggered;
    
}

@property (nonatomic, retain) MUser * user;

+ (MAPIClient *)shared;

- (void)updateDiskCache:(BOOL)immediate;
- (void)updateDiskCacheDebounced;


#pragma mark Requesting Object Data

- (void)getModelAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback;
- (void)getCollectionAtPath:(NSString*)path userTriggered:(BOOL)triggered success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback;
- (void)requestPath:(NSString*)path withMethod:(NSString*)method withParameters: params userTriggered:(BOOL)triggered expectedClass:(Class)expectation success:(void (^)(id responseObject))successCallback failure:(void (^)(NSError *err))failureCallback;

- (void)authenticateWithToken:(NSString*)accessToken;


#pragma mark Tracking API Access and Recovering from Offline State

- (int)numberOfQueuedActions;
- (void)queueAPITransaction:(MAPITransaction*)a;
- (void)removeQueuedTransactionsFor:(MModel*)obj;
- (void)finishedAPITransaction:(MAPITransaction*)a withError:(NSError*)err;
- (void)performNextAction;

#pragma mark Handling Request Results

- (void)criticalRequestFailed:(NSError*)err;


@end
