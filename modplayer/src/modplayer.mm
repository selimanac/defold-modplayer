#include <dmsdk/sdk.h>
#import <Foundation/Foundation.h>

char*  modplayer_init()
{
  
     const char *bundlePath = [[[NSBundle mainBundle] bundlePath] UTF8String];
    char *bundlePath_lua = (char*)malloc(strlen(bundlePath) + 1);
    strcpy(bundlePath_lua, bundlePath);
   // dmLogInfo("Registered %s Extension\n", bundlePath_lua);
    return bundlePath_lua;
}