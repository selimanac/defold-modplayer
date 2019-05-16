#include <dmsdk/sdk.h>

// TODO...

#if defined(DM_PLATFORM_ANDROID)
#include "jni.h"
char *modplayer_init()
{
    // getPath() - java
    JNIEnv *jni_env = Core::HAZEOS::GetJNIEnv();
    jclass cls_Env = jni_env->FindClass("android/app/NativeActivity");
    jmethodID mid_getExtStorage = jni_env->GetMethodID(cls_Env, "getFilesDir", "()Ljava/io/File;");
    jobject obj_File = jni_env->CallObjectMethod(gstate->activity->clazz, mid_getExtStorage);
    jclass cls_File = jni_env->FindClass("java/io/File");
    jmethodID mid_getPath = jni_env->GetMethodID(cls_File, "getPath", "()Ljava/lang/String;");
    jstring obj_Path = (jstring)jni_env->CallObjectMethod(obj_File, mid_getPath);
    const char *path = jni_env->GetStringUTFChars(obj_Path, NULL);
    FHZ_PRINTF("INTERNAL PATH = %s\n", path);
    jni_env->ReleaseStringUTFChars(obj_Path, path);
     char* aa = "jhk";
    return aa;
}

#endif