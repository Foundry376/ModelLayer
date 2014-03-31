//
//  MModelCollectionPaginatingFetcher.h
//  Endorsee
//
//  Created by Ben Gotow on 3/30/14.
//  Copyright (c) 2014 Foundry376. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MModelCollectionFetcher.h"

@interface MModelCollectionPaginatingFetcher : MModelCollectionFetcher
{
    BOOL _fetchedFewerThanRequested;
    int  _fetched;
}

@property (nonatomic, assign) int pageSize;

- (void)fetch;
- (void)fetchMore;

@end
