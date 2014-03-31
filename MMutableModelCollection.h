//
//  MMutableModelCollection.h
//  Endorsee
//
//  Created by Ben Gotow on 3/30/14.
//  Copyright (c) 2014 Foundry376. All rights reserved.
//

#import "MModelCollection.h"

@interface MMutableModelCollection : MModelCollection

@property (nonatomic, assign) BOOL canMoveItems;

- (void)addItem:(MModel*)model;
- (void)addItemsFromArray:(NSArray*)array;

- (void)removeItemAtIndex:(NSUInteger)i;
- (void)removeItemWithID:(NSString*)ID;

@end
