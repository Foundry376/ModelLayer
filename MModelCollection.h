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
}

@property (nonatomic, strong) NSString * collectionName;
@property (nonatomic, assign) BOOL collectionIsNested;

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

- (void)updateWithResourceJSON:(NSArray*)jsons;

- (NSArray*)all;
- (int)count;

- (void)refresh;
- (void)refreshIfOld;




@end
