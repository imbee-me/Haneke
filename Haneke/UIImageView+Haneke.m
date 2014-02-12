//
//  UIImageView+Haneke.m
//  Haneke
//
//  Created by Hermes on 12/02/14.
//  Copyright (c) 2014 Hermes Pique. All rights reserved.
//

#import "UIImageView+Haneke.h"
#import <objc/runtime.h>

@interface HNKImageViewEntity : NSObject<HNKCacheEntity>

+ (HNKImageViewEntity*)entityWithImage:(UIImage*)image key:(NSString*)key;

@end

static NSString *NSStringFromHNKScaleMode(HNKScaleMode scaleMode)
{
    switch (scaleMode) {
        case HNKScaleModeFill:
            return @"fill";
        case HNKScaleModeAspectFill:
            return @"aspectfill";
        case HNKScaleModeAspectFit:
            return @"aspectfit";
    }
}

@implementation UIImageView (Haneke)

- (void)hnk_setImageFromFile:(NSString*)path
{
    self.hnk_lastCacheId = path;
    HNKCacheFormat *format = self.hnk_cacheFormat;
    __block BOOL animated = NO;
    [[HNKCache sharedCache] retrieveImageFromCacheWithId:path formatName:format.name completionBlock:^(NSString *cacheId, NSString *formatName, UIImage *image) {
        if (![self.hnk_lastCacheId isEqualToString:cacheId]) return;
        
        if (image)
        {
            [self hnk_setImage:image animated:animated];
            return;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *originalData = [NSData dataWithContentsOfFile:path];
            UIImage *originalImage = [UIImage imageWithData:originalData scale:[UIScreen mainScreen].scale];
            dispatch_sync(dispatch_get_main_queue(), ^{
                HNKImageViewEntity *entity = [HNKImageViewEntity entityWithImage:originalImage key:path];
                [self hnk_retrieveImageFromEntity:entity];
            });
        });
    }];
    animated = YES;
}

- (void)hnk_setImage:(UIImage*)originalImage withKey:(NSString*)key
{
    HNKImageViewEntity *entity = [HNKImageViewEntity entityWithImage:originalImage key:key];
    [self hnk_setImageFromEntity:entity];
}

- (void)hnk_setImageFromEntity:(id<HNKCacheEntity>)entity
{
    self.hnk_lastCacheId = entity.cacheId;
    [self hnk_retrieveImageFromEntity:entity];
}

#pragma mark Private

- (HNKCacheFormat*)hnk_cacheFormat
{
    CGSize viewSize = self.bounds.size;
    NSAssert(viewSize.width > 0 && viewSize.height > 0, @"%s: UImageView size is zero. Set its frame, call sizeToFit or force layout first.", __PRETTY_FUNCTION__);
    HNKScaleMode scaleMode = self.hnk_scaleMode;
    NSString *scaleModeName = NSStringFromHNKScaleMode(scaleMode);
    NSString *name = [NSString stringWithFormat:@"auto-%ldx%ld-%@", (long)viewSize.width, (long)viewSize.height, scaleModeName];
    HNKCache *cache = [HNKCache sharedCache];
    HNKCacheFormat *format = cache.formats[name];
    if (!format)
    {
        format = [[HNKCacheFormat alloc] initWithName:name];
        format.size = viewSize;
        format.diskCapacity = 10 * 1024 * 1024;
        format.allowUpscaling = YES;
        format.compressionQuality = 0.75;
        format.scaleMode = scaleMode;
        [cache registerFormat:format];
    }
    return format;
}

- (void)hnk_retrieveImageFromEntity:(id<HNKCacheEntity>)entity
{
    HNKCacheFormat *format = self.hnk_cacheFormat;
    __block BOOL animated = NO;
    [[HNKCache sharedCache] retrieveImageForEntity:entity formatName:format.name completionBlock:^(id<HNKCacheEntity> entity, NSString *formatName, UIImage *image) {
        if (![self.hnk_lastCacheId isEqualToString:entity.cacheId]) return;
        
        [self hnk_setImage:image animated:animated];
    }];
    animated = YES;
}

- (void)hnk_setImage:(UIImage*)image animated:(BOOL)animated
{
    const NSTimeInterval duration = animated ? 0.2 : 0;
    [UIView transitionWithView:self duration:duration options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.image = image;
    } completion:nil];
}

- (HNKScaleMode)hnk_scaleMode
{
    switch (self.contentMode) {
        case UIViewContentModeScaleToFill:
            return HNKScaleModeFill;
        case UIViewContentModeScaleAspectFit:
            return HNKScaleModeAspectFit;
        case UIViewContentModeScaleAspectFill:
            return HNKScaleModeAspectFill;
        case UIViewContentModeRedraw:
        case UIViewContentModeCenter:
        case UIViewContentModeTop:
        case UIViewContentModeBottom:
        case UIViewContentModeLeft:
        case UIViewContentModeRight:
        case UIViewContentModeTopLeft:
        case UIViewContentModeTopRight:
        case UIViewContentModeBottomLeft:
        case UIViewContentModeBottomRight:
            return HNKScaleModeFill;
    }
}

- (NSString*)hnk_lastCacheId
{
    return (NSString *)objc_getAssociatedObject(self, @selector(hnk_lastCacheId));
}

- (void)setHnk_lastCacheId:(NSString*)cacheId
{
    objc_setAssociatedObject(self, @selector(hnk_lastCacheId), cacheId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation HNKImageViewEntity {
    NSString *_key;
    UIImage *_image;
}

+ (HNKImageViewEntity*)entityWithImage:(UIImage*)image key:(NSString*)key
{
    HNKImageViewEntity *entity = [[HNKImageViewEntity alloc] init];
    entity->_key = key.copy;
    entity->_image = image;
    return entity;
}

- (NSString*)cacheId
{
    return _key;
}

- (UIImage*)cacheOriginalImage
{
    return _image;
}

- (NSData*)cacheOriginalData
{
    return nil;
}

@end
