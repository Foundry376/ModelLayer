//
//  MAPIAction.h
//  Mib.io
//
//  Created by Ben Gotow on 10/16/12.
//  Copyright (c) 2012 Foundry376. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRestfulObject.h"

@class  MModel;

typedef void (^MAPITransactionCallback)(BOOL success);

typedef enum MAPITransactionType {
    TRANSACTION_DELETE = 1,
    TRANSACTION_SAVE = 2,
    TRANSACTION_CUSTOM = 3
} MAPITransactionType;


@interface MAPITransaction : NSObject <NSCoding>

@property (nonatomic, strong) MModel * object;
@property (nonatomic, strong) NSString * requestURL;
@property (nonatomic, strong) NSString * requestMethod;
@property (nonatomic, assign) BOOL requestReturnsModel;
@property (nonatomic, assign) MAPITransactionType type;
@property (nonatomic, strong) MAPITransactionCallback callback;
@property (nonatomic, assign) BOOL started;

+ (MAPITransaction *)transactionForPerforming:(MAPITransactionType)type of:(MModel*)object;
+ (MAPITransaction *)transactionForMethod:(NSString*)method onPath:(NSString*)path;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (void)perform;
- (void)performDeferred;

@end
