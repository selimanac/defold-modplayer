#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_LINUX)

// This code is from DefOS: https://github.com/subsoap/defos

#include <stdlib.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/auxv.h>

static char* copy_string(const char * s)
{
    char *newString = (char*)malloc(strlen(s) + 1);
    strcpy(newString, s);
    return newString;
}

const char *modplayer_init()
{
    const char *result;
    char *path = (char *)malloc(PATH_MAX + 2);
    ssize_t ret = readlink("/proc/self/exe", path, PATH_MAX + 2);
    if (ret >= 0 && ret <= PATH_MAX + 1)
    {
        result = copy_string(dirname(path));
    }
    else
    {
        const char *path2 = (const char *)getauxval(AT_EXECFN);
        if (!path2)
        {
            result = copy_string(".");
        }
        else if (!realpath(path2, path))
        {
            result = copy_string(".");
        }
        else
        {
            result = copy_string(dirname(path));
        }
    }
    free(path);
    return result;
}

#endif