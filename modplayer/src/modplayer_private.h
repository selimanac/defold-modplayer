#pragma once

#include <dmsdk/sdk.h>

#include "raudio.h" // raylib audio library
#include <stdio.h>  // Required for: printf()
#include <string.h>
//#include <pthread.h>
#include "jc/hashtable.h"

static const char *path;

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

static Music *music;

extern char *miniaudio_init();