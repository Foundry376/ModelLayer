//
//  MModelCollectionPaginatingFetcher.m
//  Endorsee
//
//  Created by Ben Gotow on 3/30/14.
//  Copyright (c) 2014 Foundry376. All rights reserved.
//

#import "MModelCollectionPaginatingFetcher.h"

@implementation MModelCollectionPaginatingFetcher

- (void)fetch
{
    _fetched = 0;
    _fetchedFewerThanRequested = NO;
    
    [[MAPIClient shared] arrayAtPath:[self.delegate resourcePath] userTriggered:NO success:^(id responseObject) {
        _fetched += [responseObject count];
        _fetchedFewerThanRequested = ([responseObject count] < _pageSize);
        [self.delegate modelsFetched: responseObject replaceExistingContents:YES];
        
    } failure:^(NSError *err) {
        [self.delegate modelsFetchFailed];
    }];
}

- (void)fetchMore
{
    if (_fetchedFewerThanRequested)
        return;
    
    int page = floorf(_fetched / _pageSize) + 1;
    NSString * path = [[self.delegate resourcePath] stringByAppendingFormat:@"?page=%d&count=%d", page, _pageSize];
    [[MAPIClient shared] arrayAtPath:path userTriggered:NO success:^(id responseObject) {
        _fetched += [responseObject count];
        _fetchedFewerThanRequested = ([responseObject count] < _pageSize);
        [self.delegate modelsFetched: responseObject replaceExistingContents:NO];
        
    } failure:^(NSError *err) {
        [self.delegate modelsFetchFailed];
    }];
}


@end
