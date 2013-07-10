//
//  NSError+MErrors.h
//  Advocate
//
//  Created by Ben Gotow on 6/29/13.
//  Copyright (c) 2013 Bloganizer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (MErrors)

+ (NSError*)errorWithExpectationFailure:(Class)expected;

@end
