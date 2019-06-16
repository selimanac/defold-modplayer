#include <dmsdk/sdk.h>
#if defined(DM_PLATFORM_ANDROID)

#include <android/asset_manager_jni.h>
#include "android_fopen.h"

static jobject android_java_asset_manager = NULL;

struct ThreadAttacher
{
    JNIEnv *env;
    bool has_attached;
    ThreadAttacher() : env(NULL), has_attached(false)
    {
        if (dmGraphics::GetNativeAndroidJavaVM()->GetEnv((void **)&env, JNI_VERSION_1_6) != JNI_OK)
        {
            dmGraphics::GetNativeAndroidJavaVM()->AttachCurrentThread(&env, NULL);
            has_attached = true;
        }
    }
    ~ThreadAttacher()
    {
        if (has_attached)
        {
            if (env->ExceptionCheck())
            {
                env->ExceptionDescribe();
            }
            env->ExceptionClear();
            dmGraphics::GetNativeAndroidJavaVM()->DetachCurrentThread();
        }
    }
};

const char *modplayer_init()
{
    ThreadAttacher attacher;
    JNIEnv *env = attacher.env;

    jclass contextClass = env->FindClass("android/content/Context");
    jmethodID activity_class_getAssets = env->GetMethodID(contextClass, "getAssets", "()Landroid/content/res/AssetManager;");
    jobject activity = (jobject)dmGraphics::GetNativeAndroidActivity();
    jobject asset_manager = env->CallObjectMethod(activity, activity_class_getAssets);
    android_java_asset_manager = env->NewGlobalRef(asset_manager);
    android_fopen_set_asset_manager(AAssetManager_fromJava(env, android_java_asset_manager));

    //Not using the path for Android
    const char *directory_path = "";
    return directory_path;
}

#endif