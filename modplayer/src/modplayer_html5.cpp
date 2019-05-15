#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_HTML5)
#include <emscripten.h>
#include <stdlib.h>

char *modplayer_init()
{
     char*bundlePath = (char*)EM_ASM_INT({
        var jsString = location.href.substring(0, location.href.lastIndexOf("/"));
        var lengthBytes = lengthBytesUTF8(jsString)+1; // 'jsString.length' would return the length of the string as UTF-16 units, but Emscripten C strings operate as UTF-8.
        var stringOnWasmHeap = _malloc(lengthBytes);
        stringToUTF8(jsString, stringOnWasmHeap, lengthBytes+1);
        return stringOnWasmHeap;
    },0);
    return bundlePath;
}

#endif