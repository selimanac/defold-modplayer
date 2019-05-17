#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_ANDROID)
#include <android/native_window_jni.h>

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
    JNIEnv *jni_env = attacher.env;

    jclass cls_Env = jni_env->FindClass("android/app/NativeActivity");
    jmethodID mid_getExtStorage = jni_env->GetMethodID(cls_Env, "getFilesDir", "()Ljava/io/File;");
    const char *activityClass = "com/dynamo/android/DefoldActivity";
    jclass clazz = jni_env->FindClass(activityClass);
    jobject obj_File = jni_env->CallObjectMethod(clazz, mid_getExtStorage);

    jclass cls_File = jni_env->FindClass("java/io/File");
    jmethodID mid_getPath = jni_env->GetMethodID(cls_File, "getPath", "()Ljava/lang/String;");
    jstring obj_Path = (jstring)jni_env->CallObjectMethod(obj_File, mid_getPath);
    const char *path = jni_env->GetStringUTFChars(obj_Path, NULL);
    dmLogInfo("INTERNAL PATH = %s\n", path);
    jni_env->ReleaseStringUTFChars(obj_Path, path);
    //char *path2 = (char*)path;
    return path;
}

#endif