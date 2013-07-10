//
//  MRestfulObject.h
//  Packer
//
//  Created by Ben Gotow on 4/17/13.
//  Copyright (c) 2013 Mib.io. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MRestfulObject <NSObject, NSCoding>

- (NSObject<MRestfulObject>*)parent;
- (NSString*)resourcePath;

@end
