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


#import "UIImage+ForceLoad.h"
#import <ImageIO/ImageIO.h>

@implementation UIImage (ForceLoad)

+(UIImage*)immediateImageWithData:(NSData*)data
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)@{(id)kCGImageSourceShouldCacheImmediately: (id)kCFBooleanTrue});
    
    UIImage *temp = [UIImage imageWithCGImage:cgImage];

    CGImageRelease(cgImage);
    CFRelease(source);
    
    return temp;
}


// interesting trick, we force the UIImage to draw somewhere, then discard!
// this has the action of demanding that the UIImage actually decode the data.

// NB: there is probably a better way of doing this using ImageIO

-(void)forceLoad
{
    const CGImageRef cgImage = [self CGImage];

#if DEBUG
    if([[NSThread currentThread] isEqual:[NSThread mainThread]])
    {
        NSLog(@"DANGER FORCELOAD IS EXECUTING ON THE MAIN THREAD");
    }
#endif

	const CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();

	CGContextRef context = CGBitmapContextCreate(NULL,
												 1, 1,
												 CGImageGetBitsPerComponent(cgImage),
												 CGImageGetBytesPerRow(cgImage),
												 colorspace,
												 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorspace);

    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), cgImage);
    CGContextRelease(context);
    
}

@end

