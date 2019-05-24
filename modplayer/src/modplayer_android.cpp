#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_ANDROID)

//#include <android/native_window_jni.h>

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

// Dynamic Java class loading.
struct ClassLoader
{
private:
    JNIEnv *env;
    jobject class_loader_object;
    jmethodID load_class;

public:
    ClassLoader(JNIEnv *env) : env(env)
    {
        jclass activity_class = env->FindClass("android/app/NativeActivity");
        jclass class_loader_class = env->FindClass("java/lang/ClassLoader");
        jmethodID get_class_loader = env->GetMethodID(activity_class, "getClassLoader", "()Ljava/lang/ClassLoader;");
        load_class = env->GetMethodID(class_loader_class, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
        class_loader_object = env->CallObjectMethod(dmGraphics::GetNativeAndroidActivity(), get_class_loader);
    }
    jclass load(const char *class_name)
    {
        jstring class_name_string = env->NewStringUTF(class_name);
        jclass loaded_class = (jclass)env->CallObjectMethod(class_loader_object, load_class, class_name_string);
        env->DeleteLocalRef(class_name_string);
        return loaded_class;
    }
};

const char *modplayer_init()
{

    ThreadAttacher attacher;
    JNIEnv *env = attacher.env;
    ClassLoader class_loader = ClassLoader(env);
    jclass string_class = class_loader.load("java/lang/String");
    jmethodID string_concat = env->GetMethodID(string_class, "concat", "(Ljava/lang/String;)Ljava/lang/String;");
    jclass file_class = class_loader.load("java/io/File");
    jclass activity_class = env->FindClass("android/app/NativeActivity");
    jmethodID activity_get_package_resource_path = env->GetMethodID(activity_class, "getPackageResourcePath", "()Ljava/lang/String;");

    jstring directory_path_string = NULL;
    
    directory_path_string = (jstring)env->CallObjectMethod(dmGraphics::GetNativeAndroidActivity(), activity_get_package_resource_path);
    const char *directory_path = env->GetStringUTFChars(directory_path_string, 0);
   // char full_path[strlen(directory_path) + strlen(file_path) + 1];
    env->ReleaseStringUTFChars(directory_path_string, directory_path);
    dmLogInfo("Android path: %s", directory_path);
    return directory_path;
    /*
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
*/

    /*
    jclass activity_class = env->FindClass("android/app/NativeActivity");
    jmethodID get_class_loader = env->GetMethodID(activity_class, "getClassLoader", "()Ljava/lang/ClassLoader;");
    jobject cls = env->CallObjectMethod(dmGraphics::GetNativeAndroidActivity(), get_class_loader);
    jclass class_loader = env->FindClass("java/lang/ClassLoader");
    jmethodID find_class = env->GetMethodID(class_loader, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

    jstring str_class_name = env->NewStringUTF(classname);
    jclass outcls = (jclass)env->CallObjectMethod(cls, find_class, str_class_name);
    env->DeleteLocalRef(str_class_name);
return outcls;
*/
}

#endif