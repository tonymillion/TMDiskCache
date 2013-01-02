TMDiskCache
===========

A disk cache with network loading and UIImage category

The main active parts of this are TMDiskCache and TMDownload manager.

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

Next, the TMDiskCache has a built-in cache trim algorithm, this is called like ```[_coverArtImageCache trimCache];```

You should call this in your applications ```- (void)applicationDidEnterBackground:(UIApplication *)application``` method e.g:
```
	[self.userPictureImageCache trimCache];
	[self.postListImageCache trimCache];
	[self.coverArtImageCache trimCache];
```


