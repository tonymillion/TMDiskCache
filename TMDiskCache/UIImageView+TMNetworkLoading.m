//
//  UIImageView+TMNetworkLoading.m
//  imagedownloadqueue
//
//  Created by Tony Million on 31/12/2012.
//  Copyright (c) 2012 tonymillion. All rights reserved.
//

#import <objc/runtime.h>

#import "UIImageView+TMNetworkLoading.h"
#import "UIImage+ForceLoad.h"

static char * const kImageURLKey	= "kURLAssociationKey";


@implementation UIImageView (TMNetworkLoading)

@dynamic imageURL;

-(void)setImageURL:(NSURL *)imageURL
{
    objc_setAssociatedObject(self,
                             kImageURLKey,
                             imageURL,
                             OBJC_ASSOCIATION_RETAIN);
}

-(NSURL*)imageURL
{
    return objc_getAssociatedObject(self, kImageURLKey);
}


-(NSOperationQueue*)decodeOperationQueue
{
    static NSOperationQueue * downloadQueue;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadQueue = [[NSOperationQueue alloc] init];
        downloadQueue.name = @"com.tonymillion.UIImageViewDecodeQueue";
		downloadQueue.maxConcurrentOperationCount = 2;
    });
    
    return downloadQueue;
}

+(NSCache*)downloadCache
{
    static NSCache * downloadCache;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadCache = [[NSCache alloc] init];
        downloadCache.name = @"com.tonymillion.UIImageViewNetworkLoadCache";
    });
    
    return downloadCache;
}



-(void)setImageAnimated:(UIImage *)image
{
    CATransition *animation = [CATransition animation];
    animation.duration = 0.188;
    animation.type = kCATransitionFade;
    [[self layer] addAnimation:animation forKey:@"imageFade"];
    [self setImage:image];
}


-(void)loadFromURL:(NSURL *)url
  placeholderImage:(UIImage *)placeholderImage
		 fromCache:(TMDiskCache*)diskCache
{
    [[TMDownloadManager sharedInstance] cancelCallbacksForSender:self];
    
    // if we dont pass a URL then just set the
    // place holder image and dtop the hell out!
    if(!url || [url isKindOfClass:[NSNull class]])
    {
        self.imageURL       = nil;
        [self setImage:placeholderImage];
        return;
    }
    
    ///////////////////////////////////////////////////
    //
    // next see if we have this in the cache
    // already decoded as an UIImage
    //
    UIImage * cachedImage = [[UIImageView downloadCache] objectForKey:url.absoluteString];
    if(cachedImage)
    {
        if([cachedImage isKindOfClass:[UIImage class]])
        {
            // make sure we dont get called
            self.imageURL       = url;
            // Dont animate here, we can set the image immediately and haven't even loaded the placeholder
            [self setImage:cachedImage];
            return;
        }
    }
    
    // if we dont have it cached then we should set the placeholder here!
    self.image = placeholderImage;
    
    if(!diskCache)
    {
        diskCache = [TMDiskCache sharedInstance];
    }
    
    
    
    [diskCache checkCacheForURL:url
                        success:^(NSURL *localURL) {
                            UIImage * temp = [UIImage imageWithContentsOfFile:localURL.path];
                            if(temp)
                            {
                                self.imageURL = url;
                                [self setImageFromImage:temp];
                                
                                [[UIImageView downloadCache] setObject:temp
                                                                forKey:url.absoluteString
                                                                  cost:50];
                            }
                        }
                        failure:^(NSURL *localURL, NSError *error) {
                            [[TMDownloadManager sharedInstance] getDataForURL:url
                                                               saveToLocalURL:localURL
                                                                       sender:self
                                                                      success:^(NSURL * localURL) {
                                                                          /*
                                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                                              [self loadFromURL:url
                                                                               placeholderImage:placeholderImage
                                                                                      fromCache:diskCache];
                                                                              
                                                                          });
                                                                           */
                                                                          
                                                                          UIImage * temp = [UIImage imageWithContentsOfFile:localURL.path];
                                                                          if(temp)
                                                                          {
                                                                              self.imageURL = url;
                                                                              [self setImageFromImage:temp];
                                                                              
                                                                              [[UIImageView downloadCache] setObject:temp
                                                                                                              forKey:url.absoluteString
                                                                                                                cost:50];
                                                                          }

                                                                      }
                                                                      failure:^(NSError *error) {
                                                                          self.imageURL = url;
                                                                      }];
                        }];
    /*
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURL * ourlocalURL = [diskCache localFileNameForURL:url];
        UIImage * temp = [UIImage imageWithContentsOfFile:ourlocalURL.path];
        if(temp)
        {
            self.imageURL = url;
            [self setImageFromImage:temp];
            
            [[UIImageView downloadCache] setObject:temp
                                            forKey:url.absoluteString
                                              cost:50];
        }
        else
        {
            [[TMDownloadManager sharedInstance] getDataForURL:url
                                               saveToLocalURL:ourlocalURL
                                                       sender:self
                                                      success:^(NSURL * localURL) {
                                                          
                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              [self loadFromURL:url
                                                               placeholderImage:placeholderImage
                                                                      fromCache:diskCache];

                                                          });
                                                      }
                                                      failure:^(NSError *error) {
                                                          self.imageURL = url;
                                                      }];
        }
    });
     */
}

-(UIImage*)setImageFromImage:(UIImage*)theImage
{
    [theImage forceLoad];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self setImageAnimated:theImage];
    });
    
    return theImage;
}

@end



/*
 // might need this for some reason
 if(!url || [url isKindOfClass:[NSNull class]])
 {
 self.imageURL       = nil;
 [self setImage:placeholderImage];
 return;
 }
 
 if([url isEqual:self.imageURL])
 {
 return;
 }
 
 ///////////////////////////////////////////////////
 //
 // see if we have this in the cache as a UIImage
 //
 UIImage * cachedImage = [[UIImageView downloadCache] objectForKey:url.absoluteString];
 if(cachedImage)
 {
 if([cachedImage isKindOfClass:[UIImage class]])
 {
 // make sure we dont get called
 self.imageURL       = url;
 // Dont animate here, we can set the image immediately and haven't even loaded the placeholder
 [self setImage:cachedImage];
 return;
 }
 }
 
 if(placeholderImage)
 {
 self.image = placeholderImage;
 }
 
 [[TMDownloadManager sharedInstance] cancelCallbacksForSender:self];
 
 [[TMDownloadManager sharedInstance] getDataForURL:url
 sender:self
 fromCache:cache
 success:^(NSData *data) {
 
 NSLog(@"success loadFromURL: %@", url);
 
 if(self.imageURL && (![self.imageURL isEqual:url]))
 {
 //TODO: store data anyway
 NSLog(@"IMAGEURL IS NOT THE SAME %@ / %@", self.imageURL, url);
 return;
 }
 
 self.imageURL = url;
 
 UIImage * theImage = [UIImage imageWithData:data];
 [theImage forceLoad];
 [[NSOperationQueue mainQueue] addOperationWithBlock:^{
 //self.image = theImage;
 [self setImageAnimated:theImage];
 }];
 
 [[UIImageView downloadCache] setObject:theImage
 forKey:url.absoluteString
 cost:50];
 
 }
 failure:^(NSError *error) {
 
 NSLog(@"failure loadFromURL: %@", error);
 self.imageURL = nil;
 
 }];
 
 */