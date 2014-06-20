//
//  MModelCollection.h
//  Packer
//
//  Created by Ben Gotow on 4/17/13.
//  Copyright (c) 2013 Mib.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRestfulObject.h"


@class MModel;

@interface MModelCollection : NSObject <NSCoding, MRestfulObject>
{
    NSMutableArray * _cache;
    BOOL _loadReturnedLessThanRequested;
}

@property (nonatomic, assign) BOOL disableNetworking;

@property (nonatomic, strong) NSString * collectionName;
@property (nonatomic, assign) BOOL collectionIsNested;
@property (nonatomic, assign) BOOL collectionObjectsGloballyUnique;
@property (nonatomic, assign) int collectionPageSize;

@property (nonatomic, assign) BOOL canMoveItems;
@property (nonatomic, assign) Class collectionClass;
@property (nonatomic, strong) NSObject<MRestfulObject> * parent;
@property (nonatomic, strong) NSDate * refreshDate;
@property (nonatomic, assign) BOOL refreshInProgress;

- (id)initWithCollectionName:(NSString*)name andClass:(Class)c;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (NSString*)resourcePath;

- (MModel*)objectAtIndex:(NSUInteger)index;
- (MModel*)objectWithID:(NSString*)ID;

- (void)addItem:(MModel*)model;
- (void)addItemsFromArray:(NSArray*)array;

- (void)removeItemAtIndex:(NSUInteger)i;
- (void)removeItemWithID:(NSString*)ID;

- (void)updateWithResourceJSON:(NSArray*)jsons discardMissingModels:(BOOL)discardMissing;
- (void)updateFromPath:(NSString*)path replaceExistingContents:(BOOL)replace withCallback:(void(^)(void))callback;

- (NSArray*)all;
- (NSArray*)allCached;
- (NSInteger)count;

- (void)refresh;
- (void)refreshWithCallback:(void(^)(void))callback;
- (void)refreshIfOld;

- (void)loadMore;

@end
