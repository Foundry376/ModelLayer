//
//  NSError+MErrors.m
//  Advocate
//
//  Created by Ben Gotow on 6/29/13.
//  Copyright (c) 2013 Bloganizer Inc. All rights reserved.
//

#import "NSError+MErrors.h"

@implementation NSError (MErrors)

+ (NSError*)errorWithExpectationFailure:(Class)actualClass
{
    NSDictionary * d = nil;
    if (actualClass) {
        d = @{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"The JSON response of type %@ did not match the expected class.", NSStringFromClass(actualClass)]};
    } else {
        d = @{NSLocalizedDescriptionKey: @"The server's response was empty. Please try again!"};
    }
    return [NSError errorWithDomain:@"advocate" code:500 userInfo:d];
}

@end
