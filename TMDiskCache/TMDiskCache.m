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


#import <CommonCrypto/CommonDigest.h>


#import "TMDiskCache.h"

@interface TMDiskCache ()

@property(strong) NSURL             *diskCacheURL;
@property(strong) NSOperationQueue  *downloadOperationQueue;

@property(strong) dispatch_queue_t  trimQueue;

@end


@implementation TMDiskCache

+(TMDiskCache*)sharedInstance
{
    __strong static TMDiskCache * _sharedObject = nil;

    static dispatch_once_t pred = 0;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });

    return _sharedObject;
}

-(NSString *)md5:(NSString *)str
{
	const char *cStr = [str UTF8String];
	unsigned char result[16];
	CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
	return [NSString stringWithFormat:
			@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			result[0], result[1], result[2], result[3],
			result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11],
			result[12], result[13], result[14], result[15]
			];
}

-(id)init
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    self = [self initWithCacheName:bundleID];
    return self;
}

-(id)initWithCacheSize:(NSUInteger)size
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    self = [self initWithCacheName:bundleID andCacheSize:size];
    return self;
}


-(id)initWithCacheName:(NSString*)directoryName
{
	// default 10MB Cache!
	return [self initWithCacheName:directoryName
                      andCacheSize:10];
}

-(id)initWithCacheName:(NSString*)directoryName andCacheSize:(NSUInteger)size
{
    self = [super init];

    if(self)
    {
        NSURL * cacheURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory
                                                                   inDomains:NSUserDomainMask] lastObject];

        self.diskCacheURL   = [cacheURL URLByAppendingPathComponent:directoryName];
        NSError * error;
        if(![self.diskCacheURL checkResourceIsReachableAndReturnError:&error])
        {
            [[NSFileManager defaultManager] createDirectoryAtURL:self.diskCacheURL
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:NULL];
        }

        // create a serial queue on which we deliver touch/trim stuff
        self.trimQueue        = dispatch_queue_create("com.tonymillion.trimqueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(self.trimQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));

        // create a download operation queue!
        self.downloadOperationQueue         = [[NSOperationQueue alloc] init];
        self.downloadOperationQueue.name    = @"TMDiskCacheDownloadQueue";

        // default cache size is 10megs
        [self setCacheSize:size];
    }

    return self;
}

-(NSURL*)localFileNameForURL:(NSURL*)url
{
    if(url == nil)
        return nil;
    
    NSString *cachename = [self md5:[url absoluteString]];

    // in a *REAL* implementation of this you should probably do that.
    NSURL * fullthing = [self.diskCacheURL URLByAppendingPathComponent:cachename];
    return fullthing;
}

-(void)touchCachedURL:(NSURL*)url
{
    dispatch_async(_trimQueue, ^{
        NSError * error;

        NSURL * cacheURL = [self localFileNameForURL:url];
        // we have to use the created time, as iOS doesn't honour the last accessed flag
        // update the access time (really the created time but meh)
        if(![cacheURL setResourceValue:[NSDate date]
                                forKey:NSURLCreationDateKey
                                 error:&error])
        {
            // we dont care if it errors - it probably will!
        }
    });
}

-(void)setData:(NSData*)data forURL:(NSURL*)url completion:(void (^)(NSError * error))completion
{
    [_downloadOperationQueue addOperationWithBlock:^{
        //save the data to disk!

        NSURL * localURL = [self localFileNameForURL:url];
        NSError *writeError = nil;

        if(![data writeToURL:localURL
                     options:(NSDataWritingAtomic)
                       error:&writeError])
        {
        }

        if(completion)
            completion(writeError);
    }];
}

-(void)checkCacheForURL:(NSURL*)remoteURL
                success:(void(^)(NSURL * localURL))success
                failure:(void(^)(NSURL * localURL, NSError * error))failure
{
    if(remoteURL == nil)
    {
        return;
    }

    [_downloadOperationQueue addOperationWithBlock:^{

        NSURL * localURL = [self localFileNameForURL:remoteURL];

        NSError *error = nil;
        if(![localURL checkResourceIsReachableAndReturnError:&error])
        {
            if(failure)
            {
                failure(localURL, error);
            }
        }
        else
        {
            if(success)
            {
                success(localURL);
            }

            [self touchCachedURL:remoteURL];
        }
    }];
}


-(void)dataForURL:(NSURL*)url success:(void (^)(NSData * data))success failure:(void(^)(NSError * error))failure
{
    if(url == nil)
    {
        return;
    }

    [_downloadOperationQueue addOperationWithBlock:^{

        NSURL * localURL = [self localFileNameForURL:url];

        NSError *error = nil;
        if(![localURL checkResourceIsReachableAndReturnError:&error])
        {
            if(failure)
            {
                failure(error);
            }

            return;
        }

        NSError *readError = nil;

        NSData * fileData = [NSData dataWithContentsOfURL:localURL
                                                  options:NSDataReadingMappedIfSafe
                                                    error:&readError];
        if(fileData)
        {
            if(success)
                success(fileData);
        }
        else
        {
            if(failure)
                failure(readError);
        }

        dispatch_async(_trimQueue, ^{
            [self touchCachedURL:url];
        });
    }];
}

-(void)setCacheSize:(NSUInteger)cacheSize
{
    _cacheSize = cacheSize * 1024 * 1024;
}

-(void)trimCache
{
    __block UIBackgroundTaskIdentifier trimCacheTask;

    trimCacheTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		if(trimCacheTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:trimCacheTask];
			trimCacheTask = UIBackgroundTaskInvalid;
		}
	}];

    // we do the nasty stuff on a background thread
    // what we do here is iterate over the folder pull out the last access (created) date
    // then sort by that
    // while the cache on disk is bigger than the set size we start deleting items
    // then we're done!

    // all of this is done on a serial dispatch queue, so it'll never interact with itself!
    dispatch_async(self.trimQueue, ^{

        // this implements a LRU algorithm
        NSMutableArray * temp = [NSMutableArray arrayWithCapacity:5];
        NSArray *keys = [NSArray arrayWithObjects:NSURLFileSizeKey, NSURLCreationDateKey, nil];

        NSDirectoryEnumerator * enumerator = [[NSFileManager defaultManager] enumeratorAtURL:self.diskCacheURL
                                                                  includingPropertiesForKeys:keys
                                                                                     options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants
                                                                                errorHandler:^BOOL(NSURL *url, NSError *error) {
                                                                                    return YES;
                                                                                }];

        for (NSURL *url in enumerator)
        {
            [temp addObject:url];
        }

        // sort based on the creation date
        [temp sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSURL *url1 = (NSURL*)obj1;
            NSURL *url2 = (NSURL*)obj2;

            NSDate *date1;
            NSDate *date2;

            [url1 getResourceValue:&date1 forKey:NSURLCreationDateKey error:nil];
            [url2 getResourceValue:&date2 forKey:NSURLCreationDateKey error:nil];

            return [date1 compare:date2];
        }];


        // calculate total size of cache
        NSUInteger totalSize = 0;

        if(temp.count)
        {
            for (NSURL * file in temp)
            {
                NSNumber * size;
                [file getResourceValue:&size
                                forKey:NSURLFileSizeKey error:nil];

                totalSize += [size unsignedIntegerValue];
            }

            // while we have more files than cache
            // delete the file, subtract the size
            while(totalSize > self.cacheSize)
            {
                NSURL * topItem = [temp objectAtIndex:0];

                NSError * error;
                if(![[NSFileManager defaultManager] removeItemAtURL:topItem
                                                              error:&error])
                {
                }

                NSNumber * size;
                [topItem getResourceValue:&size
                                   forKey:NSURLFileSizeKey error:nil];

                totalSize -= [size unsignedIntegerValue];

                [temp removeObjectAtIndex:0];
            }
        }
        else
        {
        }

		if(trimCacheTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:trimCacheTask];
			trimCacheTask = UIBackgroundTaskInvalid;
		}
    });

}

-(void)emptyCache
{
    __block UIBackgroundTaskIdentifier emptyCacheTask = UIBackgroundTaskInvalid;

	emptyCacheTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		if(emptyCacheTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:emptyCacheTask];
			emptyCacheTask = UIBackgroundTaskInvalid;
		}
	}];

	// all of this is done on a serial dispatch queue, so it'll never interact with itself!
    dispatch_async(self.trimQueue, ^{

        // this implements a LRU algorithm
        NSArray *keys = [NSArray arrayWithObjects:NSURLFileSizeKey, NSURLCreationDateKey, nil];

        NSDirectoryEnumerator * enumerator = [[NSFileManager defaultManager] enumeratorAtURL:self.diskCacheURL
                                                                  includingPropertiesForKeys:keys
                                                                                     options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants
                                                                                errorHandler:^BOOL(NSURL *url, NSError *error) {
                                                                                    return YES;
                                                                                }];

        for (NSURL *topItem in enumerator)
        {
			NSError * error;
			if(![[NSFileManager defaultManager] removeItemAtURL:topItem
														  error:&error])
			{
			}
        }

		if(emptyCacheTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:emptyCacheTask];
			emptyCacheTask = UIBackgroundTaskInvalid;
		}

    });
}

@end
