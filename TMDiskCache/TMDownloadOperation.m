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


#import "TMDownloadOperation.h"

#import "TMNetworkActivityIndicatorManager.h"


@interface TMDownloadOperation ()

@property(strong) NSURLConnection       *connection;
@property(strong) NSHTTPURLResponse     *response;

@property(strong) NSOutputStream        *outputStream;

@property(readonly) NSMutableArray      *requesters;
@property(strong) NSURL                 *tempFileURL;

@end



@implementation TMDownloadOperation

-(id)init
{
    self = [super init];
    if(self)
    {
        _requesters = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

-(void)notifyRequesters
{
    // by the time we've reached this point, theres no going back on the requesters array
    // so we make a copy in order to avoid any locks

    NSArray * requestersCopy = nil;
    @synchronized(_requesters)
    {
        requestersCopy = [_requesters copy];
    }

    [requestersCopy enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary * mapDict = obj;

        void (^sucess_handler)(NSURL * localURL);
        void (^failure_handler)(NSError * error);

        sucess_handler = mapDict[@"success"];
        failure_handler = mapDict[@"failure"];

        if(!self.error)
        {
            // file has hit the disk!
            if(sucess_handler)
            {
                sucess_handler(self.localFileURL);
            }
        }
        else
        {
            if(failure_handler)
            {
                failure_handler(self.error);
            }
        }
    }];
}

-(void)main
{
    NSError * err;
    if([_localFileURL checkResourceIsReachableAndReturnError:&err])
    {
        [self notifyRequesters];
        return;
    }

    ////////////////////////////////////////////////////////////////////////////////
    //
    // HOLD UP: we download into the temp dir as a random filename.
    // This is so we can't accidently load the data as its partially downloaded
    // the data is fully downloaded & verified before its moved into place
    // in the request success handler!
    _tempFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];


    //[[TMNetworkActivityIndicatorManager sharedManager] incrementActivityCount];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_remoteURL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30];

    [request setValue:@"gzip"
   forHTTPHeaderField:@"Accept-Encoding"];

    self.loading    = YES;


    self.connection = [[NSURLConnection alloc] initWithRequest:request
                                                      delegate:self
                                              startImmediately:NO];

    [self.connection setDelegateQueue:[NSOperationQueue currentQueue]];

    [self.connection start];


    while(self.loading)
    {
        @autoreleasepool
        {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
        }
    }

    if(!self.error && ![self isCancelled])
    {
        //TODO: Call completion handler here
        [self notifyRequesters];
    }

    //[[TMNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
}

-(void)cancel
{
    [super cancel];
    [self.connection cancel];

    self.loading = NO;
}

-(void)addRequester:(id)object
            success:(void(^)(NSURL * localURL))success
            failure:(void(^)(NSError * error))failure
{
    void (^sucess_handler)(NSURL * localURL);
    void (^failure_handler)(NSError * error);

    sucess_handler = [success copy];
    failure_handler = [failure copy];

    @synchronized(_requesters)
    {
        __block BOOL found = NO;

        [_requesters enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary * mapDict = obj;
            if(mapDict[@"sender"] == object)
            {
                found = YES;
                *stop = YES;
            }
        }];

        if(!found)
        {
            [_requesters addObject:@{
             @"sender":object,
             @"success":sucess_handler,
             @"failure":failure_handler}];
        }
    }
}

-(void)removeRequester:(id)object
{
    @synchronized(_requesters)
    {
        NSMutableIndexSet * mindex = [NSMutableIndexSet indexSet];

        [_requesters enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary * mapDict = obj;
            if(mapDict[@"sender"] == object)
            {
                [mindex addIndex:idx];
            }
        }];

        if(mindex.count)
        {
            [_requesters removeObjectsAtIndexes:mindex];
        }
    }
}











#pragma mark - NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)aResponse
{
	self.response = aResponse;

    if(_outputStream)
    {
        [_outputStream close];
        _outputStream = nil;
    }

    // we alloc a new data here cos uh apple say so
    _outputStream = [NSOutputStream outputStreamWithURL:_tempFileURL
                                                 append:NO];

    [_outputStream open];
    NSError * err = nil;

    if(err)
    {
        [connection cancel];

        self.error = err;
        self.loading = NO;
    }
}

-(void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)theData
{
    if ([self isCancelled])
    {
        [aConnection cancel];
        self.loading = NO;

        //TODO: delete the file?
        [_outputStream close];
        _outputStream = nil;

        //if the download failed delete whatever we had downloaded!
        [[NSFileManager defaultManager] removeItemAtURL:_tempFileURL
                                                  error:nil];
    }
    else
    {
        NSUInteger left = [theData length];
        NSUInteger nwr = 0;

        const uint8_t * bytes = [theData bytes];

        do {

            nwr = [_outputStream write:bytes + (theData.length - left)
                             maxLength:left];
            if (-1 == nwr)
                break;

            left -= nwr;

        } while (left > 0);

        if(left)
        {
        }
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)aError
{
    [_outputStream close];
    _outputStream = nil;

    //if the download failed delete whatever we had downloaded!
    [[NSFileManager defaultManager] removeItemAtURL:_tempFileURL
                                              error:nil];

	self.error = aError;
	self.loading = NO;
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{

    [_outputStream close];
    _outputStream = nil;

    NSError * error = nil;

    if(![[NSFileManager defaultManager] moveItemAtURL:_tempFileURL
                                                toURL:_localFileURL
                                                error:&error])
    {
        self.error = error;
        return;
    }

    id value = 0;
    // Key for the file’s size in bytes, returned as an NSNumber object:
    NSString * key = NSURLFileSizeKey;
    BOOL result = [_localFileURL getResourceValue:&value
                                           forKey:key
                                            error:&error];

    if(result)
    {
        NSNumber * filelength = value;

        if([filelength unsignedIntegerValue] != _response.expectedContentLength)
        {
            //if the download failed delete whatever we had downloaded!
            [[NSFileManager defaultManager] removeItemAtURL:_localFileURL
                                                      error:nil];

            self.error = [NSError errorWithDomain:@"com.tmdownload" code:-45 userInfo:nil];
        }
        else
        {
        }
    }
    else
    {
        self.error = error;
    }

	self.loading = NO;
}


@end
