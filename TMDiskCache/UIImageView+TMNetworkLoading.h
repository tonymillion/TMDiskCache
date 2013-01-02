//
//  UIImageView+TMNetworkLoading.h
//  imagedownloadqueue
//
//  Created by Tony Million on 31/12/2012.
//  Copyright (c) 2012 tonymillion. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TMDownloadManager.h"

@interface UIImageView (TMNetworkLoading)

@property(strong, nonatomic) NSURL			*imageURL;

-(void)loadFromURL:(NSURL *)url
  placeholderImage:(UIImage *)placeholderImage
		 fromCache:(TMDiskCache*)cache;

@end
