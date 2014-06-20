//
//  MDictionaryBackedObject.m
//  Mib.io
//
//  Created by Ben Gotow on 6/7/12.
//  Copyright (c) 2012 Foundry376. All rights reserved.
//

#import "MModel.h"
#import "MAPIClient.h"
#import "MModelCollection.h"
#import "NSObject+Properties.h"
#import "NSString+FormatConversion.h"

@implementation MModel


- (id)initWithDictionary:(NSDictionary*)json
{
    self = [super init];
    if (self) {
        [self setup];
        [self updateWithResourceJSON: json];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self){
        NSDictionary * mapping = [[self class] resourceKeysForPropertyKeys];
        NSArray * properties = [mapping allKeys];
        
        _resourcePathOverride = [aDecoder decodeObjectForKey:@"resourcePathOverride"];
        
        [self setup];
        [self setEachPropertyInSet:properties withValueProvider:^BOOL(id key, NSObject ** value, NSString * type) {
            if (![aDecoder containsValueForKey: key])
                return NO;
            *value = [aDecoder decodeObjectForKey: key];
            return YES;
        }];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSDictionary * mapping = [[self class] resourceKeysForPropertyKeys];
    NSArray * properties = [mapping allKeys];
    [self getEachPropertyInSet:properties andInvoke:^(id key, NSString *type, id value) {
        if ([value isKindOfClass: [NSCache class]])
            return;
        if (value == nil)
            return;
        [aCoder encodeObject:value forKey:key];
    }];
    
    if (_resourcePathOverride)
        [aCoder encodeObject:_resourcePathOverride forKey: @"resourcePathOverride"];
}

- (void)setup
{
    
}

- (NSComparisonResult)sort:(MModel*)other
{
    return [[self createdAt] compare: [other createdAt]];
}

- (BOOL)isSaved
{
    return [self ID] != nil;
}

- (BOOL)isUnsaved
{
    return [self ID] == nil;
}

- (NSString*)description
{
    return [NSString stringWithFormat: @"%@ <%p> - Data: %@", NSStringFromClass([self class]), self, [self resourceJSON]];
}

- (NSString*)resourcePath
{
    if (_resourcePathOverride)
        return _resourcePathOverride;
    
    if (![self ID])
        @throw @"MModel does not have a resource path. Add it to a collection before saving it!";
    return [[_parent resourcePath] stringByAppendingPathComponent: [self ID]];
}

- (NSMutableDictionary*)resourceJSON
{
    NSDictionary * mapping = [[self class] resourceKeysForPropertyKeys];
    NSArray * properties = [mapping allKeys];
    NSMutableDictionary * json = [NSMutableDictionary dictionary];

    [self getEachPropertyInSet:properties andInvoke: ^(id key, NSString * type, id value) {
        if ([value isKindOfClass: [MModelCollection class]] || [value isKindOfClass: [MModel class]])
            return;
        
        if ([value isKindOfClass: [NSDate class]])
            value = [NSString stringWithDate: (NSDate*)value format: API_TIMESTAMP_FORMAT];
        
        if ([value isKindOfClass: [NSArray class]])
            value = [value componentsJoinedByString: @","];
        
        NSString * jsonKey = [mapping objectForKey: key];
        if (value)
            [json setObject:value forKey:jsonKey];
        else
            [json setObject:[NSNull null] forKey:jsonKey];
    }];
    
    return json;
}

- (void)updateWithResourceJSON:(NSDictionary*)json
{
    NSDictionary * mapping = [[self class] resourceKeysForPropertyKeys];
    NSArray * properties = [mapping allKeys];

    if ([json isKindOfClass: [NSDictionary class]] == NO) {
        NSLog(@"updateWithResourceJSON called with json that is not a dictionary");
        return;
    }
    
    [self setEachPropertyInSet: properties withValueProvider:^BOOL(id key, NSObject ** value, NSString * type) {
        NSString * jsonKey = [mapping objectForKey: key];
        if (![json objectForKey: jsonKey])
            return NO;
        
        if ([type isEqualToString: @"float"]) {
            *value = [NSNumber numberWithFloat: [[json objectForKey: jsonKey] floatValue]];
        
        } else if ([type isEqualToString: @"int"]) {
            *value = [NSNumber numberWithInt: [[json objectForKey: jsonKey] intValue]];
        
        } else if ([type isEqualToString: @"T@\"NSDate\""]) {
            NSString * timestamp = [json objectForKey: jsonKey];
            if ([timestamp isKindOfClass: [NSString class]] == NO)
                timestamp = @"";
                
            if ([timestamp hasSuffix: @"Z"])
                timestamp = [[timestamp substringToIndex:[timestamp length] - 1] stringByAppendingString:@"-0000"];
            
            *value = [timestamp dateValueWithFormat: API_TIMESTAMP_FORMAT];
            if (timestamp && !*value) {
                NSLog(@"Date parsing failed for %@ with format %@", timestamp, API_TIMESTAMP_FORMAT);
            }
        } else if ([type isEqualToString: @"T@\"MModelCollection\""]) {
            MModelCollection * collection = (MModelCollection *)*value;
            [collection updateWithResourceJSON: [json objectForKey: jsonKey] discardMissingModels: YES];
            [collection setRefreshDate: [NSDate date]];
            
        } else {
            *value = [json objectForKey: jsonKey];
        }
        return YES;
    }];

    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_MODEL_CHANGED object:self];
}

- (void)save:(MAPITransactionCallback)callback
{
    MAPITransaction * t = [MAPITransaction transactionForPerforming:TRANSACTION_SAVE of:self];
    if (callback) [t setCallback: callback];
    [[MAPIClient shared] queueAPITransaction: t];
}

- (void)reload:(MAPITransactionCallback)callback
{
    [[MAPIClient shared] getModelAtPath:[self resourcePath] userTriggered:NO success:^(id responseObject) {
        [self updateWithResourceJSON: responseObject];
        if (callback) callback(YES);
        
    } failure:^(NSError *err) {
        if (callback) callback(NO);
    }];
}

# pragma mark Getting and Setting Resource Properties

+ (NSMutableDictionary *)resourceKeysForPropertyKeys
{
    return [@{ @"ID": @"id", @"createdAt": @"created_at", @"updatedAt": @"updated_at" } mutableCopy];
}

- (void)getEachPropertyInSet:(NSArray*)properties andInvoke:(void (^)(id key, NSString * type, id value))block
{
    for (NSString * key in properties) {
        if (![self hasPropertyNamed: key]) {
            NSLog(@"No getter available for property %@", key);
            return;
        }
        
        NSString * type = [NSString stringWithCString:[self typeOfPropertyNamed: key] encoding: NSUTF8StringEncoding];
        id val = [self valueForKey: key];
        
        block(key, type, val);
    }
}

- (void)setEachPropertyInSet:(NSArray*)properties withValueProvider:(BOOL (^)(id key, NSObject ** value, NSString * type))block
{
    for (NSString * key in properties) {
        SEL setter = [self setterForPropertyNamed: key];
        if (setter == NULL) {
            NSLog(@"No setter available for property %@", key);
            continue;
        }
        NSString * type = [NSString stringWithCString:[self typeOfPropertyNamed: key] encoding: NSUTF8StringEncoding];
        NSObject * value = [self valueForKey: key];
        
        if (block(key, &value, type)) {
            if ([value isKindOfClass: [NSNull class]]) {
                if ([type isEqualToString:@"Ti"] || [type isEqualToString:@"Tf"])
                    [self setValue:[NSNumber numberWithInt: 0] forKey:key];
                else if ([type isEqualToString: @"Tc"])
                    value = [NSNumber numberWithBool: NO];
                else
                    [self setValue:nil forKey:key];
            } else {
                if ([type isEqualToString: @"T@\"NSString\""] && [value isKindOfClass: [NSNumber class]])
                    value = [(NSNumber*)value stringValue];
                if ([type isEqualToString: @"Tc"]) {
                    if ([value isKindOfClass: [NSString class]])
                        value = [NSNumber numberWithChar: [(NSString*)value characterAtIndex: 0]];
                }
                [self setValue:value forKey:key];
            }
        }
    }
}

@end
