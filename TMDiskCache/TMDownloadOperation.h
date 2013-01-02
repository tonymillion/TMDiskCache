//
//  TMDownloadOperation.h
//
//  Created by Tony Million on 23/12/2012.
//  Copyright (c) 2012 tonymillion. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TMDownloadOperation : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property(nonatomic, strong) NSURL          *remoteURL;
@property(nonatomic, strong) NSURL          *localFileURL;

@property(nonatomic, strong) NSError        *error;

@property(nonatomic, assign) BOOL           loading;

-(void)addRequester:(id)object
            success:(void(^)(NSURL * localURL))success
            failure:(void(^)(NSError * error))failure;


-(void)removeRequester:(id)object;

@end
