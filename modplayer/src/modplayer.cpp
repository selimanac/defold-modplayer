#define LIB_NAME "modplayer"
#define MODULE_NAME "player"

#include "modplayer_private.h"

static void patch_path()
{
#if defined(DM_PLATFORM_LINUX) || defined(DM_PLATFORM_WINDOWS) || defined(DM_PLATFORM_OSX) || defined(DM_PLATFORM_IOS) // #ifndef DM_PLATFORM_ANDROID
    char *bundlePath = new char[strlen(path) + strlen(asset_path) + 1];
    strcpy(bundlePath, path);
    strcat(bundlePath, asset_path);
    path = bundlePath;
    dmLogInfo("Patched: %s", path);
#endif
}

static void null_error(const char *fn)
{
    dmLogError(" %s: Music file is not available.", fn);
}

static int buildpath(lua_State *L)
{
    const char *build_path = luaL_checkstring(L, 1);
    if (build_path != NULL && build_path[0] != '\0')
    {
        path = build_path;
        dmLogInfo("Music Base Path for Defold Editor: %s", path);
        return 0;
    }
    else
    {
        dmLogError("build_path cannot be empty. Please provide a full path of your project folder when building on Defold Editor.");
        return 0;
    }
}

static iPod *get_vals(lua_State *L)
{
    key = luaL_checkint(L, 1);
    return ht.Get(key);
}

static int xmvolume(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("xm_volume");
        return 0;
    }

    double volume = 1.0;
    double amplification = 0.25;
    volume = luaL_checknumber(L, 2);
    amplification = luaL_checknumber(L, 3);

    UpdateVolume(*vals->music, volume, amplification);

    return 0;
}

static int unloadmusic(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("unload_music");
        return 0;
    }

    if (vals->is_playing)
    {
        StopMusicStream(*vals->music);
        vals->is_playing = false;
    }

    UnloadMusicStream(*vals->music);
    delete vals->music;
    ht.Erase(key);

    return 0;
}

static int loadmusic(lua_State *L)
{
    int top = lua_gettop(L);

    const char *str = luaL_checkstring(L, 1);
    char *bundlePath = new char[strlen(path) + strlen(str) + 1];
    strcpy(bundlePath, path);
    strcat(bundlePath, str);

#if defined(DM_PLATFORM_HTML5)
    std::regex pattern(".*(?=\/)[/]");
    std::string result = std::regex_replace(bundlePath, pattern, "");
    char *cstr = new char[result.length() + 1];
    strcpy(cstr, result.c_str());
    bundlePath = cstr;
    dmLogInfo("File for HTML: %s", bundlePath);
#endif

    music_count++;
    music = new Music();
    *music = LoadMusicStream(bundlePath);
    if (music == NULL)
    {
        delete music;
        return 0;
    }
    else
    {
        iPod music_values = {false, music};
        ht.Put(music_count, music_values);

        lua_pushinteger(L, music_count);
        assert(top + 1 == lua_gettop(L));
        return 1;
    }

    return 0;
}

static int playmusic(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("play_music");
        return 0;
    }

    if (!vals->is_playing)
    {
        PlayMusicStream(*vals->music);
        vals->is_playing = true;
    }

    return 0;
}

static int stopmusic(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("stop_music");
        return 0;
    }

    if (vals->is_playing)
    {
        StopMusicStream(*vals->music);
        vals->is_playing = false;
    }
    return 0;
}

static int resumemusic(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("resume_music");
        return 0;
    }

    ResumeMusicStream(*vals->music);
    return 0;
}

static int pausemusic(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("pause_music");
        return 0;
    }

    PauseMusicStream(*vals->music);
    return 0;
}

static int mastervolume(lua_State *L)
{
    double volume = luaL_checknumber(L, 1);
    SetMasterVolume(volume);
    return 0;
}

static int musicvolume(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("music_volume");
        return 0;
    }

    double volume = luaL_checknumber(L, 2);
    SetMusicVolume(*vals->music, volume);
    return 0;
}

static int musicpitch(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("music_pitch");
        return 0;
    }

    double pitch = luaL_checknumber(L, 2);
    SetMusicPitch(*vals->music, pitch);
    return 0;
}

static int musicloop(lua_State *L)
{
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("music_loop");
        return 0;
    }

    int count = luaL_checkint(L, 2);
    SetMusicLoopCount(*vals->music, count);
    return 0;
}

static int ismusicplaying(lua_State *L)
{
    int top = lua_gettop(L);
    vals = get_vals(L);
    bool playing = false;

    if (vals == NULL)
    {
        null_error("is_music_playing");
    }
    else
    {
        playing = IsMusicPlaying(*vals->music);
    }

    lua_pushboolean(L, playing);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static int musiclenght(lua_State *L)
{
    int top = lua_gettop(L);
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("music_lenght");
        return 0;
    }

    double length = GetMusicTimeLength(*vals->music);

    lua_pushnumber(L, length);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static int musicplayed(lua_State *L)
{
    int top = lua_gettop(L);
    vals = get_vals(L);

    if (vals == NULL)
    {
        null_error("music_played");
        return 0;
    }

    double length = GetMusicTimePlayed(*vals->music);

    lua_pushnumber(L, length);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static const luaL_reg Module_methods[] =
    {
        {"xm_volume", xmvolume},
        {"music_played", musicplayed},
        {"music_lenght", musiclenght},
        {"music_loop", musicloop},
        {"music_pitch", musicpitch},
        {"music_volume", musicvolume},
        {"is_music_playing", ismusicplaying},
        {"stop_music", stopmusic},
        {"resume_music", resumemusic},
        {"pause_music", pausemusic},
        {"play_music", playmusic},
        {"load_music", loadmusic},
        {"unload_music", unloadmusic},
        {"master_volume", mastervolume},
        {"build_path", buildpath},
        {0, 0}};

static void LuaInit(lua_State *L)
{
    int top = lua_gettop(L);

    luaL_register(L, MODULE_NAME, Module_methods);

    lua_pop(L, 1);
    assert(top == lua_gettop(L));
}

dmExtension::Result AppInitializeModPlayer(dmExtension::AppParams *params)
{
    ht.Create(numelements, mem);
    InitAudioDevice();
    return dmExtension::RESULT_OK;
}

dmExtension::Result InitializeModPlayer(dmExtension::Params *params)
{
    LuaInit(params->m_L);
    dmLogInfo("Registered %s Extension", MODULE_NAME);

    path = modplayer_init();
    patch_path();
    dmLogInfo("Music Base Path: %s", path);
    return dmExtension::RESULT_OK;
}

dmExtension::Result UpdateModPlayer(dmExtension::Params *params)
{
    it = ht.Begin();
    itend = ht.End();
    for (; it != itend; ++it)
    {
        if (it.GetValue()->is_playing)
        {
            UpdateMusicStream(*it.GetValue()->music);
        }
    }

    return dmExtension::RESULT_OK;
}

dmExtension::Result AppFinalizeModPlayer(dmExtension::AppParams *params)
{
    return dmExtension::RESULT_OK;
}

dmExtension::Result FinalizeModPlayer(dmExtension::Params *params)
{
    CloseAudioDevice();
    free(mem);
    return dmExtension::RESULT_OK;
}

DM_DECLARE_EXTENSION(modplayer, LIB_NAME, AppInitializeModPlayer, AppFinalizeModPlayer, InitializeModPlayer, UpdateModPlayer, 0, FinalizeModPlayer)
