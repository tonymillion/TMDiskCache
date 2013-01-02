TMDiskCache
===========

A disk cache with network loading and UIImageView category

The main active parts of this are TMDiskCache and TMDownloadManager.

The part you'll want to use is the UIImageView category which allows you to set the image to load from a URL.

# Using the UIImageView category


Very basically you call it like this

```
		[self.userPhoto loadFromURL:displayedPost.user.avatar.imageURL
				   placeholderImage:[UIImage imageNamed:@"noprofilepic"]
						  fromCache:[AppDelegate sharedAppDelegate].avatarImageCache];
```

*note: the url is passed as a ```NSString``` not a ```NSURL```*

In this example we are setting the image on a UIImageView called userPhoto the placeholder will be displayed while the image is downloaded & decoded, here we specifically use the avatarImageCache we created earlier, if you pass nil here the UIImageView will use the TMDiskCache singleton.

*CAVEAT*
Because of the Category there is a requrirement that if you wish to load a normal image into the imageview, you need to call

```
		[self.userPhoto loadFromURL:nil
				   placeholderImage:[UIImage imageNamed:@"myimage"]
						  fromCache:nil];
```

Because the Category caches the last set URL if you by-pass this by calling setImage ( or view.image=whatever; ) then it will not pick this up.


#basic usage of TMDiskCache

At its simplest the UIImageView category will use the "default" TMDiskCache singleton, however a better implementation is for you to alloc you own instances of TMDiskCache with their own cache sizes, e.g. if you were writing an app.net client you could do something like 

appDelegate.h
```
@property(strong,readonly) TMDiskCache							*postImageCache;
@property(strong,readonly) TMDiskCache							*coverImageCache;
@property(strong,readonly) TMDiskCache							*avatarImageCache;
```

in the .m 
```
	_avatarImageCache		= [[TMDiskCache alloc] initWithCacheName:@"profilePictureCache" andCacheSize:5];
    _postImageCache			= [[TMDiskCache alloc] initWithCacheName:@"postImageCache" andCacheSize:50];
	_coverImageCache		= [[TMDiskCache alloc] initWithCacheName:@"coverArtCache" andCacheSize:20];
```

The cacheSize is always defined in megabytes.

Next, the TMDiskCache has a built-in cache trim algorithm, this is called like ```[_coverArtImageCache trimCache];```

You should call this in your applications ```- (void)applicationDidEnterBackground:(UIApplication *)application``` method e.g:
```
	[_avatarImageCache trimCache];
	[_postImageCache trimCache];
	[_coverImageCache trimCache];
```


To determine if an item is in the cache you call:

```
-(void)checkCacheForURL:(NSURL*)remoteURL
                success:(void(^)(NSURL * localURL))success
                failure:(void(^)(NSURL * localURL, NSError * error))failure
```

This will check if the item for the remote URL exists in the cache, if it does the URL to the item is passed as a parameter to the success block, if not the failure block is called (and again what *WOULD* be the local URL is passed in, along with an error).

If the item is in the cache it will be 'touched' so that it wont be expired from the disk cache immediately.

There are other methods in this class (one to set a data blob for a URL and one to test for exsitence & load as a NSData blob). These operate on a background Queue for nice smooth operation.

# Basic usage of TMDownloadManager

**to be written**
