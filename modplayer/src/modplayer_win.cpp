#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_WINDOWS)

// This code is from DefOS: https://github.com/subsoap/defos

#include <Windows.h>

const char *modplayer_init()
{
    char *bundlePath = (char *)malloc(MAX_PATH);
    size_t ret = GetModuleFileNameA(GetModuleHandle(NULL), bundlePath, MAX_PATH);
    if (ret > 0 && ret < MAX_PATH)
    {
        // Remove the last path component
        size_t i = strlen(bundlePath);
        do
        {
            i -= 1;
            if (bundlePath[i] == '\\')
            {
                bundlePath[i] = 0;
                break;
            }
        } while (i);
    }
    else
    {
        bundlePath[0] = 0;
    }
    return bundlePath;
}

#endif