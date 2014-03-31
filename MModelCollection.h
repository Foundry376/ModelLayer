//
//  MModelCollection.h
//  Packer
//
//  Created by Ben Gotow on 4/17/13.
//  Copyright (c) 2013 Mib.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRestfulObject.h"
#import "MModelCollectionFetcher.h"



@class MModel;

@interface MModelCollection : NSObject <NSCoding, MRestfulObject, MModelCollectionFetcherDelegate>
{
    NSMutableArray * _cacheArray;
    NSMutableDictionary * _cacheDictionary;
}

@property (nonatomic, strong) NSString * collectionName;
@property (nonatomic, assign) BOOL collectionIsNested;
@property (nonatomic, assign) BOOL collectionObjectsGloballyUnique;

@property (nonatomic, assign) Class collectionClass;
@property (nonatomic, strong) NSObject<MRestfulObject> * parent;
@property (nonatomic, strong) MModelCollectionFetcher * fetcher;

@property (nonatomic, strong) NSDate * refreshDate;
@property (nonatomic, strong) RefreshCallbackBlock refreshCallback;
@property (nonatomic, assign) BOOL refreshInProgress;


- (id)initWithCollectionName:(NSString*)name andClass:(Class)c;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (NSString*)resourcePath;

- (MModel*)objectAtIndex:(NSUInteger)index;
- (MModel*)objectWithID:(NSString*)ID;

- (NSArray*)all;
- (NSArray*)allCached;
- (int)count;

- (void)refresh;
- (void)refreshIfOld;
- (void)refreshWithCallback:(RefreshCallbackBlock)callback;

- (void)modelsFetched:(NSArray*)jsons replaceExistingContents:(BOOL)replaceExistingContents;
- (void)modelsFetchFailed;

@end
