//
//  TMDownloadManager.h
//
//  Created by Tony Million on 22/12/2012.
//  Copyright (c) 2012 tonymillion. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TMDiskCache.h"

@interface TMDownloadManager : NSObject

+(TMDownloadManager*)sharedInstance;

-(void)getDataForURL:(NSURL*)url
      saveToLocalURL:localFileURL
              sender:(id)sender
             success:(void(^)(NSURL * localURL))success
             failure:(void(^)(NSError * error))failure;

-(void)cancelCallbacksForSender:(id)sender;

@end
