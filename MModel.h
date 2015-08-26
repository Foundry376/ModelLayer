//
//  MDictionaryBackedObject.h
//  Mib.io
//
//  Created by Ben Gotow on 6/7/12.
//  Copyright (c) 2012 Foundry376. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRestfulObject.h"
#import "MAPITransaction.h"


typedef enum SaveState {
    Unsaved = 0,
    UnsavedChanges = 1,
    Synced = 2,
    Partial = 3
} SaveState;

@interface MModel : NSObject <NSCoding, MRestfulObject>
{
}

@property (nonatomic, strong) NSString * ID;
@property (nonatomic, strong) NSString * resourcePathOverride;
@property (nonatomic, strong) NSDate * createdAt;
@property (nonatomic, strong) NSDate * updatedAt;
@property (atomic, assign) SaveState state;
@property (atomic, weak) NSObject<MRestfulObject> * parent;

+ (NSMutableDictionary *)resourceKeysForPropertyKeys;

- (id)initWithDictionary:(NSDictionary*)json;
- (id)initWithCoder:(NSCoder *)aDecoder;

- (void)encodeWithCoder:(NSCoder *)aCoder;

- (void)setup;

- (NSComparisonResult)sort:(MModel*)other;

- (NSString*)ID;
- (BOOL)isEqual:(id)object;
- (BOOL)isSaved;
- (BOOL)isUnsaved;
- (NSString*)description;

- (NSMutableDictionary*)resourceJSON;
- (void)updateWithResourceJSON:(NSDictionary*)json;

- (void)save:(MAPITransactionCallback)callback;
- (void)reload:(MAPITransactionCallback)callback;


@end
