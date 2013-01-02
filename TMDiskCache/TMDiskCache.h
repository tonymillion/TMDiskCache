//
//  TMDiskCache.h
//
//  Created by Tony Million on 22/12/2012.
//  Copyright (c) 2012 tonymillion. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TMDiskCache : NSObject

@property(readonly) NSUInteger cacheSize;

+(TMDiskCache*)sharedInstance;

-(id)initWithCacheSize:(NSUInteger)size;
-(id)initWithCacheName:(NSString*)directoryName;
-(id)initWithCacheName:(NSString*)directoryName andCacheSize:(NSUInteger)size;

//cache control
-(void)setCacheSize:(NSUInteger)cacheSizeInMegs;

-(void)trimCache;
-(void)emptyCache;

// accessors for the cache!
-(void)setData:(NSData*)data
        forURL:(NSURL*)url
    completion:(void (^)(NSError * error))completion;

-(void)dataForURL:(NSURL*)url
          success:(void(^)(NSData * data))success
          failure:(void(^)(NSError * error))failure;

-(void)checkCacheForURL:(NSURL*)remoteURL
                success:(void(^)(NSURL * localURL))success
                failure:(void(^)(NSURL * localURL, NSError * error))failure;

-(NSURL*)localFileNameForURL:(NSURL*)url;

@end
