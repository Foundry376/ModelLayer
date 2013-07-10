//
//  MDictionaryBackedObject.m
//  Mib.io
//
//  Created by Ben Gotow on 6/7/12.
//  Copyright (c) 2012 Foundry376. All rights reserved.
//

#import "MModel.h"
#import "MAPIClient.h"
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
}

- (void)setup
{
    
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
            *value = [[json objectForKey: jsonKey] dateValueWithFormat: API_TIMESTAMP_FORMAT];
        
        } else if ([type isEqualToString: @"T@\"MModelCollection\""]) {
            MModelCollection * collection = (MModelCollection *)*value;
            [collection updateWithResourceJSON: [json objectForKey: jsonKey]];
            [collection setRefreshDate: [NSDate date]];
            
        } else {
            *value = [json objectForKey: jsonKey];
        }
        return YES;
    }];
}

- (void)save:(MAPITransactionCallback)callback
{
    MAPITransaction * t = [MAPITransaction transactionForPerforming:TRANSACTION_SAVE of:self];
    if (callback) [t setCallback: callback];
    [[MAPIClient shared] queueAPITransaction: t];
    
}

# pragma mark Getting and Setting Resource Properties

+ (NSMutableDictionary *)resourceKeysForPropertyKeys
{
    return [@{ @"ID": @"id", @"createdAt": @"created_at" } mutableCopy];
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
                else
                    [self setValue:nil forKey:key];
            } else {
                if ([type isEqualToString: @"T@\"NSString\""] && [value isKindOfClass: [NSNumber class]])
                    value = [(NSNumber*)value stringValue];
                [self setValue:value forKey:key];
            }
        }
    }
}

@end