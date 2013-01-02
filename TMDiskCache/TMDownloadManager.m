//
//  TMDownloadManager.m
//
//  Created by Tony Million on 22/12/2012.
//  Copyright (c) 2012 tonymillion. All rights reserved.
//

#import "TMDownloadManager.h"

#import "TMDownloadOperation.h"
#import "TMDiskCache.h"

@interface TMDownloadManager ()

@property(strong) NSOperationQueue  *downloadQueue;
@property(strong) NSMutableArray    *askerDownloaderMappingArray;
@property(assign) dispatch_queue_t  addNewDownloadSerialQueue;

@end



@implementation TMDownloadManager

+(TMDownloadManager*)sharedInstance
{
    __strong static TMDownloadManager * _sharedObject = nil;
    
    static dispatch_once_t pred = 0;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    
    return _sharedObject;
}

-(id)init
{
    self = [super init];
    if(self)
    {
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.name = @"DLMQ";
        //[_downloadQueue setMaxConcurrentOperationCount:8];
        
        _addNewDownloadSerialQueue  = dispatch_queue_create("", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

//TODO: put this all into a Synchronous dispatch queue (the adding/removing parts) which will protect the array from multithreading shenanigans

-(void)addDownloadForURL:(NSURL*)url
              toLocalURL:(NSURL*)localFileURL
               forSender:(id)sender
                 success:(void(^)(NSURL * localURL))success
                 failure:(void(^)(NSError * error))failure
{
    __block BOOL found = NO;
    
    NSArray * alloperations = [_downloadQueue operations];
    
    [alloperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TMDownloadOperation * dlop = obj;
        
        if(![obj isKindOfClass:[TMDownloadOperation class]])
            return;
        
        if([dlop.remoteURL isEqual:url] && [dlop.localFileURL isEqual:localFileURL])
        {
            [dlop addRequester:sender
                       success:success
                       failure:failure];
            
            found = YES;
            *stop = YES;
        }
    }];
    
    if(!found)
    {
        //start a new download operation
        TMDownloadOperation* operation = [[TMDownloadOperation alloc] init];
        
        operation.remoteURL     = url;
        operation.localFileURL  = localFileURL;
        
        [operation addRequester:sender
                        success:success
                        failure:failure];
        
        [_downloadQueue addOperation:operation];
    }
}

-(void)getDataForURL:(NSURL*)url
      saveToLocalURL:localFileURL
              sender:(id)sender
             success:(void(^)(NSURL * localURL))success
             failure:(void(^)(NSError * error))failure
{
    dispatch_sync(_addNewDownloadSerialQueue, ^{
        [self addDownloadForURL:url
                     toLocalURL:localFileURL
                      forSender:sender
                        success:success
                        failure:failure];
    });
}

-(void)cancelCallbacksForSender:(id)sender
{
    NSArray * alloperations = [_downloadQueue operations];
    
    [alloperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TMDownloadOperation * dlop = obj;
        
        if(![obj isKindOfClass:[TMDownloadOperation class]])
            return;

        [dlop removeRequester:sender];
    }];
}

@end
