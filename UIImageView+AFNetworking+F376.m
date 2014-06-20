// UIImageView+AFNetworking.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "UIImageView+AFNetworking+F376.h"

@interface AFDiskImageCache : NSCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request preferredSize:(CGSize)preferredSize;
- (void)cacheImageToDisk:(UIImage *)image forRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image forRequest:(NSURLRequest *)request atSize:(CGSize)size;
@end

#pragma mark -

static char kAFImageRequestOperationObjectKey;

@interface UIImageView (_AFNetworkingF376)
@property (readwrite, nonatomic, strong, setter = f376_setImageRequestOperation:) AFImageRequestOperation *f376_imageRequestOperation;
@end

@implementation UIImageView (_AFNetworkingF376)
@dynamic f376_imageRequestOperation;
@end

#pragma mark -

@implementation UIImageView (AFNetworkingF376)

- (AFHTTPRequestOperation *)f376_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}

- (void)f376_setImageRequestOperation:(AFImageRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSOperationQueue *)f376_sharedImageRequestOperationQueue {
    static NSOperationQueue *_f376_imageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _f376_imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_f376_imageRequestOperationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    });

    return _f376_imageRequestOperationQueue;
}

+ (AFDiskImageCache *)f376_sharedImageCache {
    static AFDiskImageCache *_f_imageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _f_imageCache = [[AFDiskImageCache alloc] init];
    });

    return _f_imageCache;
}

#pragma mark -

- (void)setDiskCachedImageWithURL:(NSURL *)url {
    [self setDiskCachedImageWithURL:url placeholderImage:nil];
}

- (void)setDiskCachedImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setDiskCachedImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setDiskCachedImageWithURLRequest:(NSURLRequest *)urlRequest placeholderImage:(UIImage *)placeholderImage success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelImageRequestOperation];
    
    // resize the image to be the size we need
    CGSize desiredSize = self.bounds.size;
    desiredSize.width *= [[UIScreen mainScreen] scale];
    desiredSize.height *= [[UIScreen mainScreen] scale];
    
    UIImage *cachedImage = [[[self class] f376_sharedImageCache] cachedImageForRequest:urlRequest preferredSize: desiredSize];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            self.image = cachedImage;
        }

        self.f376_imageRequestOperation = nil;
    } else {
        self.image = placeholderImage;

        AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:urlRequest];
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([urlRequest isEqual:[self.f376_imageRequestOperation request]]) {

                // cache the image on disk at it's full size
                [[[self class] f376_sharedImageCache] cacheImageToDisk:responseObject forRequest:urlRequest];
                
                // scale it and cache it in memory for display
                responseObject = [[self class] scaleImage: responseObject toFill: desiredSize];
                [[[self class] f376_sharedImageCache] cacheImage:responseObject forRequest:urlRequest atSize: desiredSize];

                if (success) {
                    success(operation.request, operation.response, responseObject);
                } else if (responseObject) {
                    self.image = responseObject;
                }

                if (self.f376_imageRequestOperation == operation) {
                    self.f376_imageRequestOperation = nil;
                }
            }

        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([urlRequest isEqual:[self.f376_imageRequestOperation request]]) {
                if (failure) {
                    failure(operation.request, operation.response, error);
                }

                if (self.f376_imageRequestOperation == operation) {
                    self.f376_imageRequestOperation = nil;
                }
            }
        }];

        self.f376_imageRequestOperation = requestOperation;

        [[[self class] f376_sharedImageRequestOperationQueue] addOperation:self.f376_imageRequestOperation];
    }
}

- (void)cancelImageRequestOperation {
    [self.f376_imageRequestOperation cancel];
    self.f376_imageRequestOperation = nil;
}

+ (UIImage*)scaleImage:(UIImage*)image toFill:(CGSize)dSize
{
    dSize = CGSizeMake(ceilf(dSize.width), ceilf(dSize.height));
    UIGraphicsBeginImageContext(dSize);
    CGSize imSize = [image size];
    float scale = fmaxf(dSize.width/imSize.width, dSize.height/imSize.height);
    CGRect rect = CGRectMake((dSize.width - imSize.width * scale)/2, (dSize.height - imSize.height * scale)/2, imSize.width * scale, imSize.height * scale);
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1, -1);
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0, -dSize.height);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), rect, [image CGImage]);
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
    
}
@end

#pragma mark -

static inline NSString * AFDiskImageFilePathFromURLRequest(NSURLRequest *request) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%@", [[request URL] absoluteString]]];
}

static inline NSString * AFDiskImageCacheKeyFromURLRequest(NSURLRequest *request, CGSize size) {
    return [NSString stringWithFormat: @"%@-%fx%f", [[request URL] absoluteString], size.width, size.height];
}

@implementation AFDiskImageCache

- (void)cacheImageToDisk:(UIImage *)image forRequest:(NSURLRequest *)request
{
    NSString * path = AFDiskImageFilePathFromURLRequest(request);
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    [UIImageJPEGRepresentation(image, 0.8) writeToFile: path atomically:NO];
}

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request preferredSize:(CGSize)preferredSize
{
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }

    UIImage * preferred = [self objectForKey:AFDiskImageCacheKeyFromURLRequest(request, preferredSize)];
    if (preferred)
        return preferred;
    else {
        UIImage * full = [UIImage imageWithContentsOfFile: AFDiskImageFilePathFromURLRequest(request)];
        if (full) {
            UIImage * smaller = [UIImageView scaleImage:full toFill:preferredSize];
            [self cacheImage:smaller forRequest:request atSize:preferredSize];
            return smaller;
        }
    }
    return nil;
}

- (void)cacheImage:(UIImage *)image forRequest:(NSURLRequest *)request atSize:(CGSize)size
{
    if (image && request) {
        [self setObject:image forKey:AFDiskImageCacheKeyFromURLRequest(request, size)];
    }
}

@end

#endif
