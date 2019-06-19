#pragma once

#include <dmsdk/sdk.h>
#include "raudio.h"
#include <stdlib.h>

#if defined(DM_PLATFORM_HTML5)
#include <regex>
#endif

#include "jc/hashtable.h"

// Hash table
struct iPod
{
    bool is_playing;
    Music *music;
};
typedef jc::HashTable<uint32_t, iPod> hashtable_t;

static uint32_t numelements = 10; // The maximum number of entries to store
static uint32_t load_factor = 50; // percent
static uint32_t tablesize = uint32_t(numelements / (load_factor / 100.0f));
static uint32_t sizeneeded = hashtable_t::CalcSize(tablesize);
static void *mem = malloc(sizeneeded);
static hashtable_t ht;
static hashtable_t::Iterator it = ht.Begin();
static hashtable_t::Iterator itend = ht.End();

// Music
static Music *music;
static iPod *vals;
static int music_count = 0;
static int key = 0;

//Paths
static const char *path;
static const char *asset_path = "/assets/";

extern const char *modplayer_init();