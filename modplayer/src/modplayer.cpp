#define LIB_NAME "modplayer"
#define MODULE_NAME "audio"

// include the Defold SDK
#include "modplayer_private.h"

//bool is_playing = false;

static int buildpath(lua_State *L)
{
    int top = lua_gettop(L);
    path = luaL_checkstring(L, 1);

    return 0;
}

static int unloadmusic(lua_State *L)
{
    int top = lua_gettop(L);
    //Check if playing. If so stop it girst

    

    return 0;
}

static int loadmusic(lua_State *L)
{
    int top = lua_gettop(L);
    const char *str = luaL_checkstring(L, 1);
    char *three = new char[strlen(path) + strlen(str) + 1];
    strcpy(three, path);
    strcat(three, str);
    dmLogInfo("PATH: %s \n", three);
    music = LoadMusicStream(three);

    // music = LoadMusicStream("/Users/selimanac/Development/Defold/Native Extension/defold-raudio/res/common/audio/djb_sdm.xm");

    return 0;
}

static int playmusic(lua_State *L)
{

    int top = lua_gettop(L);
    is_playing = true;

    PlayMusicStream(music);
    //  music = LoadMusicStream(str);
    // PlayMusicStream(music);

    /*
    uint8_t* bytes = 0x0;
uint32_t size = 0;




    dmScript::LuaHBuffer* sourceLuaBuffer = dmScript::CheckBuffer(L, 1);
    dmBuffer::Result r = dmBuffer::GetBytes(sourceLuaBuffer->m_Buffer, (void**)&bytes, &size);
  //  music = LoadMusicStream(&sourceLuaBuffer->m_Buffer);
    //PlayMusicStream(music);
   Sound fxWav = LoadWaveEx(r);
    PlaySound(fxWav);
    */
    return 0;
}

static int stopmusic(lua_State *L)
{
    int top = lua_gettop(L);
    is_playing = false;
    StopMusicStream(music);

    return 0;
}

static int resumemusic(lua_State *L)
{
    int top = lua_gettop(L);
    ResumeMusicStream(music);
    return 0;
}

static int pausemusic(lua_State *L)
{
    int top = lua_gettop(L);
    PauseMusicStream(music);
    return 0;
}

static int mastervolume(lua_State *L)
{
    int top = lua_gettop(L);
    double volume = luaL_checknumber(L, 1);
    SetMasterVolume(volume);
    return 0;
}

static int musicvolume(lua_State *L)
{
    int top = lua_gettop(L);
    double volume = luaL_checknumber(L, 1);
    SetMusicVolume(music, volume);
    return 0;
}

static int musicpitch(lua_State *L)
{
    int top = lua_gettop(L);
    double volume = luaL_checknumber(L, 1);
    SetMusicPitch(music, volume);
    return 0;
}

static int musicloop(lua_State *L)
{
    int top = lua_gettop(L);
    int count = luaL_checkint(L, 1);
    //SetMusicLoopCount(Music music, int count);
    SetMusicLoopCount(music, count);
    return 0;
}

static int ismusicplaying(lua_State *L)
{
    int top = lua_gettop(L);
    bool playing = IsMusicPlaying(music);
    lua_pushboolean(L, playing);
    assert(top + 1 == lua_gettop(L));
    return 1;
}

static int musiclenght(lua_State *L)
{
    int top = lua_gettop(L);
    double length = GetMusicTimeLength(music);

    lua_pushnumber(L, length);
    assert(top + 1 == lua_gettop(L));
    return 1;
}

static int musicplayed(lua_State *L)
{
    int top = lua_gettop(L);
    double length = GetMusicTimePlayed(music);

    lua_pushnumber(L, length);
    assert(top + 1 == lua_gettop(L));
    return 1;
}

// Functions exposed to Lua
static const luaL_reg Module_methods[] =
    {

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

    // Register lua names
    luaL_register(L, MODULE_NAME, Module_methods);

    lua_pop(L, 1);
    assert(top == lua_gettop(L));
}

dmExtension::Result AppInitializeModPlayer(dmExtension::AppParams *params)
{
    dmLogInfo("AppInitializeModPlayer\n");
    ht.Create(numelements, mem);
    InitAudioDevice();
    return dmExtension::RESULT_OK;
}

dmExtension::Result InitializeModPlayer(dmExtension::Params *params)
{
    LuaInit(params->m_L);
    dmLogInfo("Registered %s Extension\n", MODULE_NAME);

    path = modplayer_init();
    dmLogInfo("Audio Path: %s\n", path);

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
    return dmExtension::RESULT_OK;
}

DM_DECLARE_EXTENSION(modplayer, LIB_NAME, AppInitializeModPlayer, AppFinalizeModPlayer, InitializeModPlayer, UpdateModPlayer, 0, FinalizeModPlayer)
