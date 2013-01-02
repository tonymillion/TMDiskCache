TMDiskCache
===========

A disk cache with network loading and UIImage category

The main active parts of this are TMDiskCache and TMDownload manager.

#basic usage of TMDiskCache

The main parts you'll want to use are the UIImage category which allows you to set the image to load from a URL.

At its simplest the UIImage category will use the "default" TMDiskCache singleton, however a better implementation is for you to alloc you own instances of TMDiskCache with their own cache sizes, e.g. if you were writing an app.net client you could do something like 

appDelegate.h
```
@property(strong,readonly) TMDiskCache							*postImageCache;
@property(strong,readonly) TMDiskCache							*coverImageCache;
@property(strong,readonly) TMDiskCache							*avatarImageCache;
```

in the .m 
```
	_userPictureImageCache	= [[TMDiskCache alloc] initWithCacheName:@"profilePictureCache" andCacheSize:5];
    _postListImageCache		= [[TMDiskCache alloc] initWithCacheName:@"postImageCache" andCacheSize:50];
	_coverArtImageCache		= [[TMDiskCache alloc] initWithCacheName:@"coverArtCache" andCacheSize:20];
```

The cacheSize is always defined in megabytes.

Next, the TMDiskCache has a built-in cache trim algorithm, this is called like ```[_coverArtImageCache trimCache];```

You should call this in your applications ```- (void)applicationDidEnterBackground:(UIApplication *)application``` method e.g:
```
	[self.userPictureImageCache trimCache];
	[self.postListImageCache trimCache];
	[self.coverArtImageCache trimCache];
```


To determine if an item is in the cache you call:

```
-(void)checkCacheForURL:(NSURL*)remoteURL
                success:(void(^)(NSURL * localURL))success
                failure:(void(^)(NSURL * localURL, NSError * error))failure
```

This will check if the item for the remote URL exists in the cache, if it does the URL to the item is passed as a parameter to the success block, if not the failure block is called (and again what *WOULD* be the local URL is passed in, along with an error).

# Basic usage of TMDownloadManager

**to be written**