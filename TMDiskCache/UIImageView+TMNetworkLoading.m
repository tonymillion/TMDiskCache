/*
 Copyright (c) 2013, Tony Million.
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */


#import <objc/runtime.h>

#import "UIImageView+TMNetworkLoading.h"
#import "UIImage+ForceLoad.h"

static char * const kImageURLKey	= "kURLAssociationKey";


@implementation UIImageView (TMNetworkLoading)

@dynamic imageURL;

// FOR FUTURE IMPLEMENTATION TO FIX setImage

+ (void)load
{
    SEL originalSelector = @selector(setImage:);
    SEL overrideSelector = @selector(newSetImage:);
    Method originalMethod = class_getInstanceMethod(self, originalSelector);
    Method overrideMethod = class_getInstanceMethod(self, overrideSelector);
    if (class_addMethod(self, originalSelector, method_getImplementation(overrideMethod), method_getTypeEncoding(overrideMethod)))
    {
        class_replaceMethod(self, overrideSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    }
    else
    {
        method_exchangeImplementations(originalMethod, overrideMethod);
    }
}

-(void)newSetImage:(UIImage*)image
{
    [self newSetImage:image];
    self.imageURL       = nil;
}

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
    NSURL* oldurl = self.imageURL;
    
    CATransition *animation = [CATransition animation];
    animation.duration = 0.188;
    animation.type = kCATransitionFade;
    [[self layer] addAnimation:animation forKey:@"imageFade"];
    [self newSetImage:image];
    
    self.imageURL = oldurl;
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
        [self newSetImage:placeholderImage];
        return;
    }
    
    NSURL * currentURL = self.imageURL;
    
    if([url isEqual:currentURL])
    {
        DLog(@"URLS Match, image is alredy set!");
        return;
    }

    [self.decodeOperationQueue cancelAllOperations];

    
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
            [self newSetImage:cachedImage];
            
            self.imageURL       = url;

            //TODO: touch the file in the cache?
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
                                [self setImageFromImage:temp forURL:url];

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
                                                                          UIImage * temp = [UIImage imageWithContentsOfFile:localURL.path];
                                                                          if(temp)
                                                                          {
                                                                              self.imageURL = url;
                                                                              [self setImageFromImage:temp forURL:url];

                                                                          }

                                                                      }
                                                                      failure:^(NSError *error) {
                                                                          self.imageURL = url;
                                                                      }];
                        }];
}

-(UIImage*)setImageFromImage:(UIImage*)theImage forURL:(NSURL*)url
{
    __block NSOperation * blockOp;
    blockOp = [NSBlockOperation blockOperationWithBlock:^{
        [theImage forceLoad];
        
        if(!blockOp.isCancelled)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                // test fromCurrentURL == self.imageURL and if not, drop out
                [self setImageAnimated:theImage];
            });
        }
        else
        {
            DLog(@"image setoperation was cancelled before image was set");
        }
        
        [[UIImageView downloadCache] setObject:theImage
                                        forKey:url.absoluteString
                                          cost:50];
    }];
    
    [self.decodeOperationQueue addOperation:blockOp];

    return theImage;
}

@end
