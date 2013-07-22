//
//  MModelCollection.m
//  Packer
//
//  Created by Ben Gotow on 4/17/13.
//  Copyright (c) 2013 Mib.io. All rights reserved.
//

#import "MModelCollection.h"
#import "MAPIClient.h"
#import "MModel.h"

@implementation MModelCollection

- (id)initWithCollectionName:(NSString*)name andClass:(Class)c
{
    self = [super init];
    if (self) {
        _collectionName = name;
        _collectionClass = c;
        _collectionPageSize = 30;
        _cache = [NSMutableArray array];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _collectionClass = NSClassFromString([aDecoder decodeObjectForKey: @"_collectionClass"]);
        _collectionName = [aDecoder decodeObjectForKey: @"_collectionName"];
        _collectionPageSize = [aDecoder decodeIntForKey: @"_collectionPageSize"];
        _cache = [aDecoder decodeObjectForKey: @"_cache"];
        if (!_cache)
            _cache = [NSMutableArray array];
        for (MModel * model in _cache)
            [model setParent: self];
        
        NSLog(@"Initialized collection of %d %@ objects", [_cache count], NSStringFromClass(_collectionClass));
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_collectionName forKey:@"_collectionName"];
    [aCoder encodeInt:_collectionPageSize forKey:@"_collectionPageSize"];
    [aCoder encodeObject:NSStringFromClass(_collectionClass) forKey:@"_collectionClass"];
    [aCoder encodeObject:_cache forKey:@"_cache"];
}

- (void)dealloc
{
}

- (NSString*)resourcePath
{
    if (self.collectionIsNested)
        return [NSString stringWithFormat: @"%@/%@", [_parent resourcePath], _collectionName];
    else
        return _collectionName;
}

- (MModel*)objectAtIndex:(NSUInteger)index
{
    NSArray * all = [self all];
    if ([all count] > index)
        return [all objectAtIndex: index];
    return nil;
}

- (MModel*)objectWithID:(NSString*)ID
{
    for (MModel * obj in [self all])
        if ([[obj ID] isEqualToString: ID])
            return obj;
    return nil;
}

- (void)addItem:(MModel*)model
{
    [model setParent: self];
    [_cache addObject: model];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_COLLECTION_CHANGED object:self];
}

- (void)addItemsFromArray:(NSArray*)array
{
    for (MModel * item in array) {
        [item setParent: self];
        [_cache addObject: item];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_COLLECTION_CHANGED object:self];
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
        
        [_cache removeObject: obj];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_COLLECTION_CHANGED object:self];
    }
}

- (void)removeItemWithID:(NSString*)ID
{
    [self removeItemAtIndex: [[self all] indexOfObject: [self objectWithID: ID]]];
}

- (void)updateWithResourceJSON:(NSArray*)jsons discardMissingModels:(BOOL)discardMissing
{
    NSMutableArray * unused = [NSMutableArray arrayWithArray: _cache];
    
    for (NSDictionary * json in jsons) {
        NSString * ID = [json objectForKey: @"id"];
        if ([ID isKindOfClass: [NSString class]] == NO)
            ID = [(NSNumber*)ID stringValue];

        MModel * model = nil;
        if (_collectionObjectsGloballyUnique) {
            model = [[MAPIClient shared] globalObjectWithID:ID ofClass: _collectionClass];
        } else {
            for (MModel * obj in unused) {
                if ([[obj ID] isEqualToString: ID]) {
                    model = obj;
                    break;
                }
            }
        }

        if (model) {
            [model updateWithResourceJSON: json];
            [unused removeObject: model];
            [model setParent: self];
            if (![_cache containsObject: model])
                [_cache addObject: model];
        } else {
            model = [[self.collectionClass alloc] initWithDictionary: json];
            [[MAPIClient shared] addGlobalObject: model];
            [model setParent: self];
            [_cache addObject: model];
        }
    }
    
    if (discardMissing) {
        [unused makeObjectsPerformSelector:@selector(setParent:) withObject: nil];
        [_cache removeObjectsInArray: unused];
    }
    
    [_cache sortUsingSelector: @selector(sort:)];
}

- (void)updateFromPath:(NSString*)path replaceExistingContents:(BOOL)replace withCallback:(void(^)(void))callback
{
    if (_refreshInProgress)
        return;
    
    _refreshInProgress = YES;

    [[MAPIClient shared] getCollectionAtPath:path userTriggered:NO success:^(id responseObject) {
        _loadReturnedLessThanRequested = ([responseObject count] < _collectionPageSize);
        [self updateWithResourceJSON: responseObject discardMissingModels: replace];
        [self setRefreshDate: [NSDate date]];
        [[MAPIClient shared] updateDiskCache: NO];
        _refreshInProgress = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_COLLECTION_CHANGED object:self];
        if (callback)
            callback();
        
    } failure:^(NSError *err) {
        [self setRefreshDate: [NSDate date]];
        _refreshInProgress = NO;
        _loadReturnedLessThanRequested = NO;
        if (callback)
            callback();
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_COLLECTION_CHANGED object:self];
    }];
}


- (NSArray*)all
{
    [self refreshIfOld];
    return _cache;
}

- (int)count
{
    return [[self all] count];
}

- (void)refresh
{
    [self refreshWithCallback: NULL];
}

- (void)refreshWithCallback:(void(^)(void))callback
{
    NSString * path = [[self resourcePath] stringByAppendingFormat:@"?count=%d", _collectionPageSize];
    [self updateFromPath:path replaceExistingContents:YES withCallback: callback];
}

- (void)refreshIfOld
{
    BOOL expired = (!_refreshDate || ([_refreshDate timeIntervalSinceNow] > 5000));
    if (expired)
        [self refresh];
}

- (void)loadMore
{
    if (_loadReturnedLessThanRequested)
        return;
    
    int page = floorf([[self all] count] / _collectionPageSize) + 1;
    NSString * path = [[self resourcePath] stringByAppendingFormat:@"?page=%d&count=%d", page, _collectionPageSize];
    [self updateFromPath: path replaceExistingContents:NO withCallback:NULL];
}


@end
