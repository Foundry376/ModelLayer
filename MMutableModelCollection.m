//
//  MMutableModelCollection.m
//  Endorsee
//
//  Created by Ben Gotow on 3/30/14.
//  Copyright (c) 2014 Foundry376. All rights reserved.
//

#import "MMutableModelCollection.h"

@implementation MMutableModelCollection

- (BOOL)supportsDictionaryCache
{
    return NO; // because added items may not have IDs yet
}

- (void)addItem:(MModel*)model
{
    [model setParent: self];
    [_cacheArray addObject: model];
    [[NSNotificationCenter defaultCenter] postNotificationName:CHANGE_NOTIF_FOR(self.collectionName) object:self];
}

- (void)addItemsFromArray:(NSArray*)array
{
    for (MModel * item in array) {
        [item setParent: self];
        [_cacheArray addObject: item];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:CHANGE_NOTIF_FOR(self.collectionName) object:self];
}

- (void)removeItemAtIndex:(NSUInteger)index
{
    NSArray * all = [self all];
    if ([all count] > index) {
        MModel * obj = [[self all] objectAtIndex: index];
        
        // NOTE: This implementation doesnt account for the possiblity that an item
        // could be saving for the first time as it's being deleted.. That would involve
        // adding a new "saving" flag to the object and probably just rejecting the deletion.
        // (to keep it simple)
        
        if ([obj ID]) {
            MAPITransaction * t = [MAPITransaction transactionForPerforming:TRANSACTION_DELETE of:obj];
            [[MAPIClient shared] queueAPITransaction: t];
        } else {
            [[MAPIClient shared] removeQueuedTransactionsFor: obj];
        }
        
        [_cacheArray removeObject: obj];
        [[NSNotificationCenter defaultCenter] postNotificationName:CHANGE_NOTIF_FOR(self.collectionName) object:self];
    }
}

- (void)removeItemWithID:(NSString*)ID
{
    [self removeItemAtIndex: [[self all] indexOfObject: [self objectWithID: ID]]];
}

@end
