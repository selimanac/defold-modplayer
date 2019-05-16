#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_OSX) || defined(DM_PLATFORM_IOS)

#import <Foundation/Foundation.h>

char *modplayer_init()
{
    const char *bundlePath = [[[NSBundle mainBundle] bundlePath] UTF8String];
    char *bundlePath_lua = (char *)malloc(strlen(bundlePath) + 1);
    strcpy(bundlePath_lua, bundlePath);
    return bundlePath_lua;
}
#endif