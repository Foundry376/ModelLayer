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
#import "MModelCollectionPaginatingFetcher.h"

@implementation MModelCollection

- (id)initWithCollectionName:(NSString*)name andClass:(Class)c
{
    self = [super init];
    if (self) {
        _collectionName = name;
        _collectionClass = c;
        _cacheArray = [NSMutableArray array];
        _cacheDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _collectionClass = NSClassFromString([aDecoder decodeObjectForKey: @"_collectionClass"]);
        _collectionName = [aDecoder decodeObjectForKey: @"_collectionName"];
        _cacheArray = [aDecoder decodeObjectForKey: @"_cache"];
        if (!_cacheArray)
            _cacheArray = [NSMutableArray array];
        for (MModel * model in _cacheArray)
            [model setParent: self];
        
        [self rebuildDictionaryCache];
        
        NSLog(@"Initialized collection of %lu %@ objects", (unsigned long)[_cacheArray count], NSStringFromClass(_collectionClass));
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_collectionName forKey:@"_collectionName"];
    [aCoder encodeObject:NSStringFromClass(_collectionClass) forKey:@"_collectionClass"];
    [aCoder encodeObject:_cacheArray forKey:@"_cache"];
}

- (void)setFetcher:(MModelCollectionFetcher *)fetcher
{
    [fetcher setDelegate: self];
    _fetcher = fetcher;
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
    if ([self supportsDictionaryCache])
        return [_cacheDictionary objectForKey: ID];

    for (MModel * obj in [self all])
        if ([[obj ID] isEqualToString: ID])
            return obj;
    
    return nil;
}

- (NSArray*)all
{
    [self refreshIfOld];
    return _cacheArray;
}

- (NSArray*)allCached
{
    return _cacheArray;
}

- (NSUInteger)count
{
    return [[self all] count];
}

- (void)refresh
{
    [self refreshWithCallback: NULL];
}

- (void)refreshIfOld
{
    BOOL expired = (!_refreshDate || ([_refreshDate timeIntervalSinceNow] > 5000));
    if (expired)
        [self refreshWithCallback: NULL];
}

- (void)refreshWithCallback:(RefreshCallbackBlock)callback
{
    if (!_fetcher)
        [self setFetcher: [[MModelCollectionPaginatingFetcher alloc] init]];
    
    if (callback)
        _refreshCallback = callback;

    if (_refreshInProgress)
        return;
    
    _refreshInProgress = YES;
    [[self fetcher] fetch];
}

- (void)modelsFetched:(NSArray*)jsons replaceExistingContents:(BOOL)replaceExistingContents
{
    NSMutableArray * unused = [NSMutableArray arrayWithArray: _cacheArray];
    
    for (NSDictionary * json in jsons) {
        NSString * ID = [json objectForKey: @"id"];
        if ([ID isKindOfClass: [NSString class]] == NO)
            ID = [(NSNumber*)ID stringValue];
        
        MModel * model = nil;

		for (MModel * obj in unused) {
			if ([[obj ID] isEqualToString: ID]) {
				model = obj;
				break;
			}
		}
		
        if (model) {
            [model updateWithResourceJSON: json];
            [unused removeObject: model];
            [model setParent: self];
            if (![_cacheArray containsObject: model])
                [_cacheArray addObject: model];
        } else {
            model = [[self.collectionClass alloc] initWithDictionary: json];
            [model setParent: self];
            [_cacheArray addObject: model];
        }
    }
    
    if (replaceExistingContents) {
        [unused makeObjectsPerformSelector:@selector(setParent:) withObject: nil];
        [_cacheArray removeObjectsInArray: unused];
    }
    
    [_cacheArray sortUsingSelector: @selector(sort:)];
    [self rebuildDictionaryCache];

    _refreshDate = [NSDate date];
    _refreshInProgress = NO;
    [[MAPIClient shared] updateDiskCache: NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:CHANGE_NOTIF_FOR(_collectionName) object:self];

    if (_refreshCallback)
        _refreshCallback(YES);
    _refreshCallback = nil;
}

- (void)modelsFetchFailed
{
    // we set the refresh date to prevent another refresh from being triggered
    // immediately, and failing again.
    _refreshDate = [NSDate date];
    _refreshInProgress = NO;
    if (_refreshCallback)
        _refreshCallback(NO);
    _refreshCallback = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:CHANGE_NOTIF_FOR(_collectionName) object:self];
}

#pragma mark Additional Cache for Fast ID Lookup

- (BOOL)supportsDictionaryCache
{
    return YES;
}

- (void)rebuildDictionaryCache
{
    _cacheDictionary = [NSMutableDictionary dictionary];
    for (MModel * model in _cacheArray)
        [_cacheDictionary setObject:model forKey:[model ID]];
}


@end
