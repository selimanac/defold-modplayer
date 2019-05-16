#define LIB_NAME "modplayer"
#define MODULE_NAME "player"

#include "modplayer_private.h"

static int buildpath(lua_State *L)
{
    path = luaL_checkstring(L, 1);
    dmLogInfo("Audio Path for Defold Build: %s", path);
    return 0;
}

static iPod *get_vals(lua_State *L)
{
    key = luaL_checkint(L, 1);
    return ht.Get(key);
}

static int unloadmusic(lua_State *L)
{
    vals = get_vals(L);

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

    music_count++;

    music = new Music();

    iPod music_values = {false, music};
    ht.Put(music_count, music_values);

    iPod *vals = ht.Get(music_count);
    *vals->music = LoadMusicStream(bundlePath);

    lua_pushinteger(L, music_count);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static int playmusic(lua_State *L)
{
    vals = get_vals(L);
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
    ResumeMusicStream(*vals->music);
    return 0;
}

static int pausemusic(lua_State *L)
{
    vals = get_vals(L);
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
    double volume = luaL_checknumber(L, 2);
    SetMusicVolume(*vals->music, volume);
    return 0;
}

static int musicpitch(lua_State *L)
{
    vals = get_vals(L);
    double pitch = luaL_checknumber(L, 2);
    SetMusicPitch(*vals->music, pitch);
    return 0;
}

static int musicloop(lua_State *L)
{
    vals = get_vals(L);
    int count = luaL_checkint(L, 2);
    SetMusicLoopCount(*vals->music, count);
    return 0;
}

static int ismusicplaying(lua_State *L)
{
    int top = lua_gettop(L);
    vals = get_vals(L);
    bool playing = IsMusicPlaying(*vals->music);

    lua_pushboolean(L, playing);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static int musiclenght(lua_State *L)
{
    int top = lua_gettop(L);
    vals = get_vals(L);

    double length = GetMusicTimeLength(*vals->music);

    lua_pushnumber(L, length);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static int musicplayed(lua_State *L)
{
    int top = lua_gettop(L);
    vals = get_vals(L);
    double length = GetMusicTimePlayed(*vals->music);

    lua_pushnumber(L, length);
    assert(top + 1 == lua_gettop(L));

    return 1;
}

static const luaL_reg Module_methods[] =
    {

        {"music_played", musicplayed},        // *
        {"music_lenght", musiclenght},        // *
        {"music_loop", musicloop},            // *
        {"music_pitch", musicpitch},          // *
        {"music_volume", musicvolume},        // *
        {"is_music_playing", ismusicplaying}, // *
        {"stop_music", stopmusic},            // *
        {"resume_music", resumemusic},        // *
        {"pause_music", pausemusic},          // *
        {"play_music", playmusic},            // *
        {"load_music", loadmusic},            // *
        {"unload_music", unloadmusic},
        {"master_volume", mastervolume}, // *
        {"build_path", buildpath},       // *
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
    dmLogInfo("AppInitializeModPlayer");
    ht.Create(numelements, mem);
    InitAudioDevice();
    return dmExtension::RESULT_OK;
}

dmExtension::Result InitializeModPlayer(dmExtension::Params *params)
{
    LuaInit(params->m_L);
    dmLogInfo("Registered %s Extension", MODULE_NAME);

    path = modplayer_init();
    dmLogInfo("Audio Path: %s", path);

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
