#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_OSX) || defined(DM_PLATFORM_IOS)

// This code is from DefOS: https://github.com/subsoap/defos

#import <Foundation/Foundation.h>

const char *modplayer_init()
{
    const char *bundlePath = [[[NSBundle mainBundle] bundlePath] UTF8String];
    char *path = (char *)malloc(strlen(bundlePath) + 1);
    strcpy(path, bundlePath);
    return path;
}
#endif