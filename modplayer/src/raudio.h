/**********************************************************************************************
*
*   raudio - A simple and easy-to-use audio library based on mini_al
*   
*   
*   DEPENDENCIES:
*       miniaudio.h  - Audio device management lib (https://github.com/dr-soft/miniaudio)
*       jar_xm.h     - XM module file loading
*       jar_mod.h    - MOD audio file loading
*
*   CONTRIBUTORS:
*       David Reid (github: @mackron) (Nov. 2017):
*           - Complete port to mini_al library
*
*       Joshua Reisenauer (github: @kd7tck) (2015)
*           - XM audio module support (jar_xm)
*           - MOD audio module support (jar_mod)
*
*   LICENSE: zlib/libpng
*
*   Copyright (c) 2014-2019 Ramon Santamaria (@raysan5)
*
*   This software is provided "as-is", without any express or implied warranty. In no event
*   will the authors be held liable for any damages arising from the use of this software.
*
*   Permission is granted to anyone to use this software for any purpose, including commercial
*   applications, and to alter it and redistribute it freely, subject to the following restrictions:
*
*     1. The origin of this software must not be misrepresented; you must not claim that you
*     wrote the original software. If you use this software in a product, an acknowledgment
*     in the product documentation would be appreciated but is not required.
*
*     2. Altered source versions must be plainly marked as such, and must not be misrepresented
*     as being the original software.
*
*     3. This notice may not be removed or altered from any source distribution.
*
**********************************************************************************************/

#include <stdbool.h>

#ifndef RAUDIO_H
#define RAUDIO_H

//----------------------------------------------------------------------------------
// Defines and Macros
//----------------------------------------------------------------------------------
// Allow custom memory allocators
#ifndef RL_MALLOC
#define RL_MALLOC(sz) malloc(sz)
#endif
#ifndef RL_CALLOC
#define RL_CALLOC(n, sz) calloc(n, sz)
#endif
#ifndef RL_FREE
#define RL_FREE(p) free(p)
#endif

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------
#ifndef __cplusplus
// Boolean type
#if !defined(_STDBOOL_H)
//typedef enum { false, true } bool;
#define _STDBOOL_H
#endif
#endif

// Music type (file streaming from memory)
// NOTE: Anything longer than ~10 seconds should be streamed
typedef struct MusicData *Music;

// Audio stream type
// NOTE: Useful to create custom audio streams not bound to a specific file
typedef struct AudioStream
{
    unsigned int sampleRate; // Frequency (samples per second)
    unsigned int sampleSize; // Bit depth (bits per sample): 8, 16, 32 (24 not supported)
    unsigned int channels;   // Number of channels (1-mono, 2-stereo)

    void *audioBuffer; // Pointer to internal data used by the audio system.

    int format;              // Audio format specifier
    unsigned int source;     // Audio source id
    unsigned int buffers[2]; // Audio buffers (double buffering)
} AudioStream;

#ifdef __cplusplus
extern "C"
{ // Prevents name mangling of functions
#endif

    //----------------------------------------------------------------------------------
    // Module Functions Declaration
    //----------------------------------------------------------------------------------
    void InitAudioDevice(void);         // Initialize audio device and context
    void CloseAudioDevice(void);        // Close the audio device and context
    bool IsAudioDeviceReady(void);      // Check if audio device has been initialized successfully
    void SetMasterVolume(float volume); // Set master volume (listener)

    Music LoadMusicStream(const char *fileName); // Load music stream from file
    void UnloadMusicStream(Music music);         // Unload music stream
    void PlayMusicStream(Music music);           // Start music playing
    void UpdateVolume(Music music, float volume, float amplification);
    void UpdateMusicStream(Music music);            // Updates buffers for music streaming
    void StopMusicStream(Music music);              // Stop music playing
    void PauseMusicStream(Music music);             // Pause music playing
    void ResumeMusicStream(Music music);            // Resume playing paused music
    bool IsMusicPlaying(Music music);               // Check if music is playing
    void SetMusicVolume(Music music, float volume); // Set volume for music (1.0 is max level)
    void SetMusicPitch(Music music, float pitch);   // Set pitch for a music (1.0 is base level)
    void SetMusicLoopCount(Music music, int count); // Set music loop count (loop repeats)
    float GetMusicTimeLength(Music music);          // Get music time length (in seconds)
    float GetMusicTimePlayed(Music music);          // Get current music time played (in seconds)

    // AudioStream management functions
    AudioStream InitAudioStream(unsigned int sampleRate, unsigned int sampleSize, unsigned int channels); // Init audio stream (to stream raw audio pcm data)
    void UpdateAudioStream(AudioStream stream, const void *data, int samplesCount);                       // Update audio stream buffers with data
    void CloseAudioStream(AudioStream stream);                                                            // Close audio stream and free memory
    bool IsAudioBufferProcessed(AudioStream stream);                                                      // Check if any audio stream buffers requires refill
    void PlayAudioStream(AudioStream stream);                                                             // Play audio stream
    void PauseAudioStream(AudioStream stream);                                                            // Pause audio stream
    void ResumeAudioStream(AudioStream stream);                                                           // Resume audio stream
    bool IsAudioStreamPlaying(AudioStream stream);                                                        // Check if audio stream is playing
    void StopAudioStream(AudioStream stream);                                                             // Stop audio stream
    void SetAudioStreamVolume(AudioStream stream, float volume);                                          // Set volume for audio stream (1.0 is max level)
    void SetAudioStreamPitch(AudioStream stream, float pitch);                                            // Set pitch for audio stream (1.0 is base level)

#ifdef __cplusplus
}
#endif

#endif // RAUDIO_H
