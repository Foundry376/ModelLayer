//
//  MModelCollectionParser.h
//  Endorsee
//
//  Created by Ben Gotow on 3/30/14.
//  Copyright (c) 2014 Foundry376. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ModelFetchedBlock)(NSArray * modelJSON);

@protocol MModelCollectionFetcherDelegate <NSObject>

- (NSString*)resourcePath;
- (void)modelsFetched:(NSArray*)jsons replaceExistingContents:(BOOL)replaceExistingContents;
- (void)modelsFetchFailed;

@end

@interface MModelCollectionFetcher : NSObject

@property (nonatomic, weak) NSObject<MModelCollectionFetcherDelegate>* delegate;

- (void)fetch;

@end
