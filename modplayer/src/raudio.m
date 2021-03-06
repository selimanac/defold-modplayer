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

#if defined(DM_PLATFORM_OSX) || defined(DM_PLATFORM_IOS)

#include "raudio.h"
#include <stdarg.h> // Required for: va_list, va_start(), vfprintf(), va_end()

#define MA_NO_JACK
#define MINIAUDIO_IMPLEMENTATION
#include "external/miniaudio.h" // miniaudio library

#include <stdlib.h> // Required for: malloc(), free()
#include <string.h> // Required for: strcmp(), strncmp()
#include <stdio.h>  // Required for: FILE, fopen(), fclose(), fread()

#define JAR_XM_IMPLEMENTATION
#include "external/jar_xm.h" // XM loading functions

#define JAR_MOD_IMPLEMENTATION
#include "external/jar_mod.h" // MOD loading functions

#if defined(_MSC_VER)
#undef bool
#endif

//----------------------------------------------------------------------------------
// Defines and Macros
//----------------------------------------------------------------------------------
#define MAX_STREAM_BUFFERS 2 // Number of buffers for each audio stream

// NOTE: Music buffer size is defined by number of samples, independent of sample size and channels number
// After some math, considering a sampleRate of 48000, a buffer refill rate of 1/60 seconds
// and double-buffering system, I concluded that a 4096 samples buffer should be enough
// In case of music-stalls, just increase this number
#define AUDIO_BUFFER_SIZE 4096 // PCM data samples (i.e. 16bit, Mono: 8Kb)

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

typedef enum
{
    MUSIC_MODULE_XM,
    MUSIC_MODULE_MOD
} MusicContextType;

// Music type (file streaming from memory)
typedef struct MusicData
{
    MusicContextType ctxType; // Type of music context
    jar_xm_context_t *ctxXm;  // XM chiptune context
    jar_mod_context_t ctxMod; // MOD chiptune context
    AudioStream stream;       // Audio stream (double buffering)

    int loopCount;             // Loops count (times music repeats), -1 means infinite loop
    unsigned int totalSamples; // Total number of samples
    unsigned int samplesLeft;  // Number of samples left to end
} MusicData;

typedef enum
{
    LOG_ALL,
    LOG_TRACE,
    LOG_DEBUG,
    LOG_INFO,
    LOG_WARNING,
    LOG_ERROR,
    LOG_FATAL,
    LOG_NONE
} TraceLogType;

//----------------------------------------------------------------------------------
// Module specific Functions Declaration
//----------------------------------------------------------------------------------

bool IsFileExtension(const char *fileName, const char *ext); // Check file extension
void TraceLog(int msgType, const char *text, ...);           // Show trace log messages (LOG_INFO, LOG_WARNING, LOG_ERROR, LOG_DEBUG)

//----------------------------------------------------------------------------------
// miniaudio AudioBuffer Functionality
//----------------------------------------------------------------------------------
#define DEVICE_FORMAT ma_format_f32
#define DEVICE_CHANNELS 2
#define DEVICE_SAMPLE_RATE 44100

typedef enum
{
    AUDIO_BUFFER_USAGE_STATIC = 0,
    AUDIO_BUFFER_USAGE_STREAM
} AudioBufferUsage;

// Audio buffer structure
// NOTE: Slightly different logic is used when feeding data to the playback device depending on whether or not data is streamed
typedef struct rAudioBuffer rAudioBuffer;
struct rAudioBuffer
{
    ma_pcm_converter dsp; // Required for format conversion
    float volume;
    float pitch;
    bool playing;
    bool paused;
    bool looping; // Always true for AudioStreams
    int usage;    // AudioBufferUsage type
    bool isSubBufferProcessed[2];
    unsigned int frameCursorPos;
    unsigned int bufferSizeInFrames;
    rAudioBuffer *next;
    rAudioBuffer *prev;
    unsigned char buffer[1];
};

// HACK: To avoid CoreAudio (macOS) symbol collision
// NOTE: This system should probably be redesigned
#define AudioBuffer rAudioBuffer

// miniaudio global variables
static ma_context context;
static ma_device device;
static ma_mutex audioLock;
static bool isAudioInitialized = MA_FALSE;
static float masterVolume = 1.0f;

// Audio buffers are tracked in a linked list
static AudioBuffer *firstAudioBuffer = NULL;
static AudioBuffer *lastAudioBuffer = NULL;

// miniaudio functions declaration
static void OnLog(ma_context *pContext, ma_device *pDevice, ma_uint32 logLevel, const char *message);
static void OnSendAudioDataToDevice(ma_device *pDevice, void *pFramesOut, const void *pFramesInput, ma_uint32 frameCount);
static ma_uint32 OnAudioBufferDSPRead(ma_pcm_converter *pDSP, void *pFramesOut, ma_uint32 frameCount, void *pUserData);
static void MixAudioFrames(float *framesOut, const float *framesIn, ma_uint32 frameCount, float localVolume);

// AudioBuffer management functions declaration
// NOTE: Those functions are not exposed by raylib... for the moment
AudioBuffer *CreateAudioBuffer(ma_format format, ma_uint32 channels, ma_uint32 sampleRate, ma_uint32 bufferSizeInFrames, AudioBufferUsage usage);
void DeleteAudioBuffer(AudioBuffer *audioBuffer);
bool IsAudioBufferPlaying(AudioBuffer *audioBuffer);
void PlayAudioBuffer(AudioBuffer *audioBuffer);
void StopAudioBuffer(AudioBuffer *audioBuffer);
void PauseAudioBuffer(AudioBuffer *audioBuffer);
void ResumeAudioBuffer(AudioBuffer *audioBuffer);
void SetAudioBufferVolume(AudioBuffer *audioBuffer, float volume);
void SetAudioBufferPitch(AudioBuffer *audioBuffer, float pitch);
void TrackAudioBuffer(AudioBuffer *audioBuffer);
void UntrackAudioBuffer(AudioBuffer *audioBuffer);

// Log callback function
static void OnLog(ma_context *pContext, ma_device *pDevice, ma_uint32 logLevel, const char *message)
{
    (void)pContext;
    (void)pDevice;

    TraceLog(LOG_ERROR, message); // All log messages from miniaudio are errors
}

// Sending audio data to device callback function
static void OnSendAudioDataToDevice(ma_device *pDevice, void *pFramesOut, const void *pFramesInput, ma_uint32 frameCount)
{
    // This is where all of the mixing takes place.
    (void)pDevice;

    // Mixing is basically just an accumulation. We need to initialize the output buffer to 0.
    memset(pFramesOut, 0, frameCount * pDevice->playback.channels * ma_get_bytes_per_sample(pDevice->playback.format));

    // Using a mutex here for thread-safety which makes things not real-time. This is unlikely to be necessary for this project, but may
    // want to consider how you might want to avoid this.
    ma_mutex_lock(&audioLock);
    {
        for (AudioBuffer *audioBuffer = firstAudioBuffer; audioBuffer != NULL; audioBuffer = audioBuffer->next)
        {
            // Ignore stopped or paused sounds.
            if (!audioBuffer->playing || audioBuffer->paused)
                continue;

            ma_uint32 framesRead = 0;
            for (;;)
            {
                if (framesRead > frameCount)
                {
                    TraceLog(LOG_DEBUG, "Mixed too many frames from audio buffer");
                    break;
                }

                if (framesRead == frameCount)
                    break;

                // Just read as much data as we can from the stream.
                ma_uint32 framesToRead = (frameCount - framesRead);
                while (framesToRead > 0)
                {
                    float tempBuffer[1024]; // 512 frames for stereo.

                    ma_uint32 framesToReadRightNow = framesToRead;
                    if (framesToReadRightNow > sizeof(tempBuffer) / sizeof(tempBuffer[0]) / DEVICE_CHANNELS)
                    {
                        framesToReadRightNow = sizeof(tempBuffer) / sizeof(tempBuffer[0]) / DEVICE_CHANNELS;
                    }

                    ma_uint32 framesJustRead = (ma_uint32)ma_pcm_converter_read(&audioBuffer->dsp, tempBuffer, framesToReadRightNow);
                    if (framesJustRead > 0)
                    {
                        float *framesOut = (float *)pFramesOut + (framesRead * device.playback.channels);
                        float *framesIn = tempBuffer;
                        MixAudioFrames(framesOut, framesIn, framesJustRead, audioBuffer->volume);

                        framesToRead -= framesJustRead;
                        framesRead += framesJustRead;
                    }

                    // If we weren't able to read all the frames we requested, break.
                    if (framesJustRead < framesToReadRightNow)
                    {
                        if (!audioBuffer->looping)
                        {
                            StopAudioBuffer(audioBuffer);
                            break;
                        }
                        else
                        {
                            // Should never get here, but just for safety,
                            // move the cursor position back to the start and continue the loop.
                            audioBuffer->frameCursorPos = 0;
                            continue;
                        }
                    }
                }

                // If for some reason we weren't able to read every frame we'll need to break from the loop.
                // Not doing this could theoretically put us into an infinite loop.
                if (framesToRead > 0)
                    break;
            }
        }
    }

    ma_mutex_unlock(&audioLock);
}

// DSP read from audio buffer callback function
static ma_uint32 OnAudioBufferDSPRead(ma_pcm_converter *pDSP, void *pFramesOut, ma_uint32 frameCount, void *pUserData)
{
    AudioBuffer *audioBuffer = (AudioBuffer *)pUserData;

    ma_uint32 subBufferSizeInFrames = (audioBuffer->bufferSizeInFrames > 1) ? audioBuffer->bufferSizeInFrames / 2 : audioBuffer->bufferSizeInFrames;
    ma_uint32 currentSubBufferIndex = audioBuffer->frameCursorPos / subBufferSizeInFrames;

    if (currentSubBufferIndex > 1)
    {
        TraceLog(LOG_DEBUG, "Frame cursor position moved too far forward in audio stream");
        return 0;
    }

    // Another thread can update the processed state of buffers so we just take a copy here to try and avoid potential synchronization problems.
    bool isSubBufferProcessed[2];
    isSubBufferProcessed[0] = audioBuffer->isSubBufferProcessed[0];
    isSubBufferProcessed[1] = audioBuffer->isSubBufferProcessed[1];

    ma_uint32 frameSizeInBytes = ma_get_bytes_per_sample(audioBuffer->dsp.formatConverterIn.config.formatIn) * audioBuffer->dsp.formatConverterIn.config.channels;

    // Fill out every frame until we find a buffer that's marked as processed. Then fill the remainder with 0.
    ma_uint32 framesRead = 0;
    for (;;)
    {
        // We break from this loop differently depending on the buffer's usage. For static buffers, we simply fill as much data as we can. For
        // streaming buffers we only fill the halves of the buffer that are processed. Unprocessed halves must keep their audio data in-tact.
        if (audioBuffer->usage == AUDIO_BUFFER_USAGE_STATIC)
        {
            if (framesRead >= frameCount)
                break;
        }
        else
        {
            if (isSubBufferProcessed[currentSubBufferIndex])
                break;
        }

        ma_uint32 totalFramesRemaining = (frameCount - framesRead);
        if (totalFramesRemaining == 0)
            break;

        ma_uint32 framesRemainingInOutputBuffer;
        if (audioBuffer->usage == AUDIO_BUFFER_USAGE_STATIC)
        {
            framesRemainingInOutputBuffer = audioBuffer->bufferSizeInFrames - audioBuffer->frameCursorPos;
        }
        else
        {
            ma_uint32 firstFrameIndexOfThisSubBuffer = subBufferSizeInFrames * currentSubBufferIndex;
            framesRemainingInOutputBuffer = subBufferSizeInFrames - (audioBuffer->frameCursorPos - firstFrameIndexOfThisSubBuffer);
        }

        ma_uint32 framesToRead = totalFramesRemaining;
        if (framesToRead > framesRemainingInOutputBuffer)
            framesToRead = framesRemainingInOutputBuffer;

        memcpy((unsigned char *)pFramesOut + (framesRead * frameSizeInBytes), audioBuffer->buffer + (audioBuffer->frameCursorPos * frameSizeInBytes), framesToRead * frameSizeInBytes);
        audioBuffer->frameCursorPos = (audioBuffer->frameCursorPos + framesToRead) % audioBuffer->bufferSizeInFrames;
        framesRead += framesToRead;

        // If we've read to the end of the buffer, mark it as processed.
        if (framesToRead == framesRemainingInOutputBuffer)
        {
            audioBuffer->isSubBufferProcessed[currentSubBufferIndex] = true;
            isSubBufferProcessed[currentSubBufferIndex] = true;

            currentSubBufferIndex = (currentSubBufferIndex + 1) % 2;

            // We need to break from this loop if we're not looping.
            if (!audioBuffer->looping)
            {
                StopAudioBuffer(audioBuffer);
                break;
            }
        }
    }

    // Zero-fill excess.
    ma_uint32 totalFramesRemaining = (frameCount - framesRead);
    if (totalFramesRemaining > 0)
    {
        memset((unsigned char *)pFramesOut + (framesRead * frameSizeInBytes), 0, totalFramesRemaining * frameSizeInBytes);

        // For static buffers we can fill the remaining frames with silence for safety, but we don't want
        // to report those frames as "read". The reason for this is that the caller uses the return value
        // to know whether or not a non-looping sound has finished playback.
        if (audioBuffer->usage != AUDIO_BUFFER_USAGE_STATIC)
            framesRead += totalFramesRemaining;
    }

    return framesRead;
}

// This is the main mixing function. Mixing is pretty simple in this project - it's just an accumulation.
// NOTE: framesOut is both an input and an output. It will be initially filled with zeros outside of this function.
static void MixAudioFrames(float *framesOut, const float *framesIn, ma_uint32 frameCount, float localVolume)
{
    for (ma_uint32 iFrame = 0; iFrame < frameCount; ++iFrame)
    {
        for (ma_uint32 iChannel = 0; iChannel < device.playback.channels; ++iChannel)
        {
            float *frameOut = framesOut + (iFrame * device.playback.channels);
            const float *frameIn = framesIn + (iFrame * device.playback.channels);

            frameOut[iChannel] += (frameIn[iChannel] * masterVolume * localVolume);
        }
    }
}

//----------------------------------------------------------------------------------
// Module Functions Definition - Audio Device initialization and Closing
//----------------------------------------------------------------------------------
// Initialize audio device
void InitAudioDevice(void)
{
    // Context.
    ma_context_config contextConfig = ma_context_config_init();
    contextConfig.logCallback = OnLog;
    ma_result result = ma_context_init(NULL, 0, &contextConfig, &context);
    if (result != MA_SUCCESS)
    {
        TraceLog(LOG_ERROR, "Failed to initialize audio context");
        return;
    }

    // Device. Using the default device. Format is floating point because it simplifies mixing.
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.pDeviceID = NULL; // NULL for the default playback device.
    config.playback.format = DEVICE_FORMAT;
    config.playback.channels = DEVICE_CHANNELS;
    config.capture.pDeviceID = NULL; // NULL for the default capture device.
    config.capture.format = ma_format_s16;
    config.capture.channels = 1;
    config.sampleRate = DEVICE_SAMPLE_RATE;
    config.dataCallback = OnSendAudioDataToDevice;
    config.pUserData = NULL;

    result = ma_device_init(&context, &config, &device);
    if (result != MA_SUCCESS)
    {
        TraceLog(LOG_ERROR, "Failed to initialize audio playback device");
        ma_context_uninit(&context);
        return;
    }

    // Keep the device running the whole time. May want to consider doing something a bit smarter and only have the device running
    // while there's at least one sound being played.
    result = ma_device_start(&device);
    if (result != MA_SUCCESS)
    {
        TraceLog(LOG_ERROR, "Failed to start audio playback device");
        ma_device_uninit(&device);
        ma_context_uninit(&context);
        return;
    }

    // Mixing happens on a seperate thread which means we need to synchronize. I'm using a mutex here to make things simple, but may
    // want to look at something a bit smarter later on to keep everything real-time, if that's necessary.
    if (ma_mutex_init(&context, &audioLock) != MA_SUCCESS)
    {
        TraceLog(LOG_ERROR, "Failed to create mutex for audio mixing");
        ma_device_uninit(&device);
        ma_context_uninit(&context);
        return;
    }

    TraceLog(LOG_INFO, "Audio device initialized successfully");
    TraceLog(LOG_INFO, "Audio backend: miniaudio / %s", ma_get_backend_name(context.backend));
    TraceLog(LOG_INFO, "Audio format: %s -> %s", ma_get_format_name(device.playback.format), ma_get_format_name(device.playback.internalFormat));
    TraceLog(LOG_INFO, "Audio channels: %d -> %d", device.playback.channels, device.playback.internalChannels);
    TraceLog(LOG_INFO, "Audio sample rate: %d -> %d", device.sampleRate, device.playback.internalSampleRate);
    TraceLog(LOG_INFO, "Audio buffer size: %d", device.playback.internalBufferSizeInFrames);

    isAudioInitialized = MA_TRUE;
}

// Close the audio device for all contexts
void CloseAudioDevice(void)
{
    if (!isAudioInitialized)
    {
        TraceLog(LOG_WARNING, "Could not close audio device because it is not currently initialized");
        return;
    }

    ma_mutex_uninit(&audioLock);
    ma_device_uninit(&device);
    ma_context_uninit(&context);

    TraceLog(LOG_INFO, "Audio device closed successfully");
}

// Check if device has been initialized successfully
bool IsAudioDeviceReady(void)
{
    return isAudioInitialized;
}

// Set master volume (listener)
void SetMasterVolume(float volume)
{
    if (volume < 0.0f)
        volume = 0.0f;
    else if (volume > 1.0f)
        volume = 1.0f;

    masterVolume = volume;
}

//----------------------------------------------------------------------------------
// Module Functions Definition - Audio Buffer management
//----------------------------------------------------------------------------------

// Create a new audio buffer. Initially filled with silence
AudioBuffer *CreateAudioBuffer(ma_format format, ma_uint32 channels, ma_uint32 sampleRate, ma_uint32 bufferSizeInFrames, AudioBufferUsage usage)
{
    AudioBuffer *audioBuffer = (AudioBuffer *)RL_CALLOC(sizeof(*audioBuffer) + (bufferSizeInFrames * channels * ma_get_bytes_per_sample(format)), 1);
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "CreateAudioBuffer() : Failed to allocate memory for audio buffer");
        return NULL;
    }

    // We run audio data through a format converter.
    ma_pcm_converter_config dspConfig;
    memset(&dspConfig, 0, sizeof(dspConfig));
    dspConfig.formatIn = format;
    dspConfig.formatOut = DEVICE_FORMAT;
    dspConfig.channelsIn = channels;
    dspConfig.channelsOut = DEVICE_CHANNELS;
    dspConfig.sampleRateIn = sampleRate;
    dspConfig.sampleRateOut = DEVICE_SAMPLE_RATE;
    dspConfig.onRead = OnAudioBufferDSPRead;
    dspConfig.pUserData = audioBuffer;
    dspConfig.allowDynamicSampleRate = MA_TRUE; // <-- Required for pitch shifting.
    ma_result result = ma_pcm_converter_init(&dspConfig, &audioBuffer->dsp);

    if (result != MA_SUCCESS)
    {
        TraceLog(LOG_ERROR, "CreateAudioBuffer() : Failed to create data conversion pipeline");
        RL_FREE(audioBuffer);
        return NULL;
    }

    audioBuffer->volume = 1.0f;
    audioBuffer->pitch = 1.0f;
    audioBuffer->playing = false;
    audioBuffer->paused = false;
    audioBuffer->looping = false;
    audioBuffer->usage = usage;
    audioBuffer->bufferSizeInFrames = bufferSizeInFrames;
    audioBuffer->frameCursorPos = 0;

    // Buffers should be marked as processed by default so that a call to UpdateAudioStream() immediately after initialization works correctly.
    audioBuffer->isSubBufferProcessed[0] = true;
    audioBuffer->isSubBufferProcessed[1] = true;

    TrackAudioBuffer(audioBuffer);

    return audioBuffer;
}

// Delete an audio buffer
void DeleteAudioBuffer(AudioBuffer *audioBuffer)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "DeleteAudioBuffer() : No audio buffer");
        return;
    }

    UntrackAudioBuffer(audioBuffer);
    RL_FREE(audioBuffer);
}

// Check if an audio buffer is playing
bool IsAudioBufferPlaying(AudioBuffer *audioBuffer)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "IsAudioBufferPlaying() : No audio buffer");
        return false;
    }

    return audioBuffer->playing && !audioBuffer->paused;
}

// Play an audio buffer
// NOTE: Buffer is restarted to the start.
// Use PauseAudioBuffer() and ResumeAudioBuffer() if the playback position should be maintained.
void PlayAudioBuffer(AudioBuffer *audioBuffer)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "PlayAudioBuffer() : No audio buffer");
        return;
    }

    audioBuffer->playing = true;
    audioBuffer->paused = false;
    audioBuffer->frameCursorPos = 0;
}

// Stop an audio buffer
void StopAudioBuffer(AudioBuffer *audioBuffer)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "StopAudioBuffer() : No audio buffer");
        return;
    }

    // Don't do anything if the audio buffer is already stopped.
    if (!IsAudioBufferPlaying(audioBuffer))
        return;

    audioBuffer->playing = false;
    audioBuffer->paused = false;
    audioBuffer->frameCursorPos = 0;
    audioBuffer->isSubBufferProcessed[0] = true;
    audioBuffer->isSubBufferProcessed[1] = true;
}

// Pause an audio buffer
void PauseAudioBuffer(AudioBuffer *audioBuffer)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "PauseAudioBuffer() : No audio buffer");
        return;
    }

    audioBuffer->paused = true;
}

// Resume an audio buffer
void ResumeAudioBuffer(AudioBuffer *audioBuffer)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "ResumeAudioBuffer() : No audio buffer");
        return;
    }

    audioBuffer->paused = false;
}

// Set volume for an audio buffer
void SetAudioBufferVolume(AudioBuffer *audioBuffer, float volume)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_WARNING, "SetAudioBufferVolume() : No audio buffer");
        return;
    }

    audioBuffer->volume = volume;
}

// Set pitch for an audio buffer
void SetAudioBufferPitch(AudioBuffer *audioBuffer, float pitch)
{
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_WARNING, "SetAudioBufferPitch() : No audio buffer");
        return;
    }

    float pitchMul = pitch / audioBuffer->pitch;

    // Pitching is just an adjustment of the sample rate. Note that this changes the duration of the sound - higher pitches
    // will make the sound faster; lower pitches make it slower.
    ma_uint32 newOutputSampleRate = (ma_uint32)((float)audioBuffer->dsp.src.config.sampleRateOut / pitchMul);
    audioBuffer->pitch *= (float)audioBuffer->dsp.src.config.sampleRateOut / newOutputSampleRate;

    ma_pcm_converter_set_output_sample_rate(&audioBuffer->dsp, newOutputSampleRate);
}

// Track audio buffer to linked list next position
void TrackAudioBuffer(AudioBuffer *audioBuffer)
{
    ma_mutex_lock(&audioLock);

    {
        if (firstAudioBuffer == NULL)
            firstAudioBuffer = audioBuffer;
        else
        {
            lastAudioBuffer->next = audioBuffer;
            audioBuffer->prev = lastAudioBuffer;
        }

        lastAudioBuffer = audioBuffer;
    }

    ma_mutex_unlock(&audioLock);
}

// Untrack audio buffer from linked list
void UntrackAudioBuffer(AudioBuffer *audioBuffer)
{
    ma_mutex_lock(&audioLock);

    {
        if (audioBuffer->prev == NULL)
            firstAudioBuffer = audioBuffer->next;
        else
            audioBuffer->prev->next = audioBuffer->next;

        if (audioBuffer->next == NULL)
            lastAudioBuffer = audioBuffer->prev;
        else
            audioBuffer->next->prev = audioBuffer->prev;

        audioBuffer->prev = NULL;
        audioBuffer->next = NULL;
    }

    ma_mutex_unlock(&audioLock);
}

//----------------------------------------------------------------------------------
// Module Functions Definition - Music loading and stream playing (.OGG)
//----------------------------------------------------------------------------------
void jar_xm_reset(jar_xm_context_t* ctx)
{
    ctx->current_table_index = 0;//ctx->module.restart_position;
    ctx->current_row = 0;
    for (uint16_t i = 0; i < jar_xm_get_number_of_channels(ctx); i++)
    {
        jar_xm_cut_note(&ctx->channels[i]);
        jar_xm_key_off(&ctx->channels[i]);
      
    }
}

// Load music stream from file
Music LoadMusicStream(const char *fileName)
{
    Music music = (MusicData *)RL_MALLOC(sizeof(MusicData));
    bool musicLoaded = true;

    if (IsFileExtension(fileName, ".xm"))
    {
        int result = jar_xm_create_context_from_file(&music->ctxXm, 48000, fileName);

        if (!result) // XM context created successfully
        {

            jar_xm_set_max_loop_count(music->ctxXm, 0); // Set infinite number of loops

            // NOTE: Only stereo is supported for XM
            music->stream = InitAudioStream(48000, 16, 2);
            music->totalSamples = (unsigned int)jar_xm_get_remaining_samples(music->ctxXm);
            music->samplesLeft = music->totalSamples;
            music->ctxType = MUSIC_MODULE_XM;
            music->loopCount = -1; // Infinite loop by default
            
            jar_xm_reset(music->ctxXm);

            TraceLog(LOG_INFO, "[%s] XM number of samples: %i", fileName, music->totalSamples);
            TraceLog(LOG_INFO, "[%s] XM track length: %11.6f sec", fileName, (float)music->totalSamples / 48000.0f);
        }
        else
        {
            musicLoaded = false;
        }
    }
    else if (IsFileExtension(fileName, ".mod"))
    {
        jar_mod_init(&music->ctxMod);

        if (jar_mod_load_file(&music->ctxMod, fileName))
        {

            // NOTE: Only stereo is supported for MOD
            music->stream = InitAudioStream(48000, 16, 2);
            music->totalSamples = (unsigned int)jar_mod_max_samples(&music->ctxMod);
            music->samplesLeft = music->totalSamples;
            music->ctxType = MUSIC_MODULE_MOD;
            music->loopCount = -1; // Infinite loop by default

            TraceLog(LOG_INFO, "[%s] MOD number of samples: %i", fileName, music->samplesLeft);
            TraceLog(LOG_INFO, "[%s] MOD track length: %11.6f sec", fileName, (float)music->totalSamples / 48000.0f);
        }
        else
        {
            musicLoaded = false;
        }
    }

    else
    {
        musicLoaded = false;
    }

    if (!musicLoaded)
    {
        if (IsFileExtension(fileName, ".xm"))
        {

            jar_xm_free_context(&music->ctxXm);
        }
        else if (IsFileExtension(fileName, ".mod"))
        {
            jar_mod_unload(&music->ctxMod);
        }

        RL_FREE(music);
        music = NULL;

        TraceLog(LOG_WARNING, " Music file could not be opened [%s]", fileName);
    }

    return music;
}

// Unload music stream
void UnloadMusicStream(Music music)
{
    if (music == NULL)
        return;

    CloseAudioStream(music->stream);

    if (music->ctxType == MUSIC_MODULE_XM)
    {
        jar_xm_free_context(music->ctxXm);
    }
    else if (music->ctxType == MUSIC_MODULE_MOD)
    {
        jar_mod_unload(&music->ctxMod);
    }

    RL_FREE(music);
}

void UpdateVolume(Music music, float volume, float amplification)
{

    if (music != NULL)
    {
        if (music->ctxType == MUSIC_MODULE_XM)
        {

            music->ctxXm->global_volume = volume;
            music->ctxXm->amplification = amplification; /* XXX: some bad modules may still clip. Find out something better. */
        }
    }
}

// Start music playing (open stream)
void PlayMusicStream(Music music) //, float volume, float amplification
{
    if (music != NULL)
    {
        AudioBuffer *audioBuffer = (AudioBuffer *)music->stream.audioBuffer;

        if (audioBuffer == NULL)
        {
            TraceLog(LOG_ERROR, "PlayMusicStream() : No audio buffer");
            return;
        }

        // For music streams, we need to make sure we maintain the frame cursor position. This is hack for this section of code in UpdateMusicStream()
        //     // NOTE: In case window is minimized, music stream is stopped,
        //     // just make sure to play again on window restore
        //     if (IsMusicPlaying(music)) PlayMusicStream(music);
        ma_uint32 frameCursorPos = audioBuffer->frameCursorPos;

        // if (music->ctxType == MUSIC_MODULE_XM)
        // {

        //     music->ctxXm->global_volume = volume;
        //     music->ctxXm->amplification = amplification; /* XXX: some bad modules may still clip. Find out something better. */
        // }
        PlayAudioStream(music->stream); // <-- This resets the cursor position.

        audioBuffer->frameCursorPos = frameCursorPos;
    }
}

// Pause music playing
void PauseMusicStream(Music music)
{
    if (music != NULL)
        PauseAudioStream(music->stream);
}

// Resume music playing
void ResumeMusicStream(Music music)
{
    if (music != NULL)
        ResumeAudioStream(music->stream);
}

// Stop music playing (close stream)
// TODO: To clear a buffer, make sure they have been already processed!
void StopMusicStream(Music music)
{
    if (music == NULL)
        return;

    StopAudioStream(music->stream);

    // Restart music context
    switch (music->ctxType)
    {

    case MUSIC_MODULE_XM: /* TODO: Restart XM context */
        jar_xm_reset(music->ctxXm);
        break;

    case MUSIC_MODULE_MOD:
        jar_mod_seek_start(&music->ctxMod);
        break;

    default:
        break;
    }

    music->samplesLeft = music->totalSamples;
}

// Update (re-fill) music buffers if data already processed
// TODO: Make sure buffers are ready for update... check music state
void UpdateMusicStream(Music music)
{
    if (music == NULL)
        return;

    bool streamEnding = false;

    unsigned int subBufferSizeInFrames = ((AudioBuffer *)music->stream.audioBuffer)->bufferSizeInFrames / 2;

    // NOTE: Using dynamic allocation because it could require more than 16KB
    void *pcm = RL_CALLOC(subBufferSizeInFrames * music->stream.channels * music->stream.sampleSize / 8, 1);

    int samplesCount = 0; // Total size of data steamed in L+R samples for xm floats, individual L or R for ogg shorts

    while (IsAudioBufferProcessed(music->stream))
    {
        if ((music->samplesLeft / music->stream.channels) >= subBufferSizeInFrames)
            samplesCount = subBufferSizeInFrames * music->stream.channels;
        else
            samplesCount = music->samplesLeft;

        // TODO: Really don't like ctxType thingy...
        switch (music->ctxType)
        {

        case MUSIC_MODULE_XM:
        {
            // NOTE: Internally this function considers 2 channels generation, so samplesCount/2
            jar_xm_generate_samples_16bit(music->ctxXm, (short *)pcm, samplesCount / 2);
        }
        break;

        case MUSIC_MODULE_MOD:
        {
            // NOTE: 3rd parameter (nbsample) specify the number of stereo 16bits samples you want, so sampleCount/2
            jar_mod_fillbuffer(&music->ctxMod, (short *)pcm, samplesCount / 2, 0);
        }
        break;

        default:
            break;
        }

        UpdateAudioStream(music->stream, pcm, samplesCount);
        if ((music->ctxType == MUSIC_MODULE_XM) || (music->ctxType == MUSIC_MODULE_MOD))
        {
            if (samplesCount > 1)
                music->samplesLeft -= samplesCount / 2;
            else
                music->samplesLeft -= samplesCount;
        }
        else
            music->samplesLeft -= samplesCount;

        if (music->samplesLeft <= 0)
        {
            streamEnding = true;
            break;
        }
    }

    // Free allocated pcm data
    RL_FREE(pcm);

    // Reset audio stream for looping
    if (streamEnding)
    {
        StopMusicStream(music); // Stop music (and reset)

        // Decrease loopCount to stop when required
        if (music->loopCount > 0)
        {
            music->loopCount--;     // Decrease loop count
            PlayMusicStream(music); // Play again
        }
        else
        {
            if (music->loopCount == -1)
                PlayMusicStream(music);
        }
    }
    else
    {
        // NOTE: In case window is minimized, music stream is stopped,
        // just make sure to play again on window restore
        if (IsMusicPlaying(music))
            PlayMusicStream(music);
    }
}

// Check if any music is playing
bool IsMusicPlaying(Music music)
{
    if (music == NULL)
        return false;
    else
        return IsAudioStreamPlaying(music->stream);
}

// Set volume for music
void SetMusicVolume(Music music, float volume)
{
    if (music != NULL)
        SetAudioStreamVolume(music->stream, volume);
}

// Set pitch for music
void SetMusicPitch(Music music, float pitch)
{
    if (music != NULL)
        SetAudioStreamPitch(music->stream, pitch);
}

// Set music loop count (loop repeats)
// NOTE: If set to -1, means infinite loop
void SetMusicLoopCount(Music music, int count)
{
    if (music != NULL)
        music->loopCount = count;
}

// Get music time length (in seconds)
float GetMusicTimeLength(Music music)
{
    float totalSeconds = 0.0f;

    if (music != NULL)
        totalSeconds = (float)music->totalSamples / (music->stream.sampleRate * music->stream.channels);

    return totalSeconds;
}

// Get current music time played (in seconds)
float GetMusicTimePlayed(Music music)
{
    float secondsPlayed = 0.0f;

    if (music != NULL)
    {
        unsigned int samplesPlayed = music->totalSamples - music->samplesLeft;
        secondsPlayed = (float)samplesPlayed / (music->stream.sampleRate * music->stream.channels);
    }

    return secondsPlayed;
}

// Init audio stream (to stream audio pcm data)
AudioStream InitAudioStream(unsigned int sampleRate, unsigned int sampleSize, unsigned int channels)
{
    AudioStream stream = {0};

    stream.sampleRate = sampleRate;
    stream.sampleSize = sampleSize;

    // Only mono and stereo channels are supported, more channels require AL_EXT_MCFORMATS extension
    if ((channels > 0) && (channels < 3))
        stream.channels = channels;
    else
    {
        TraceLog(LOG_WARNING, "Init audio stream: Number of channels not supported: %i", channels);
        stream.channels = 1; // Fallback to mono channel
    }

    ma_format formatIn = ((stream.sampleSize == 8) ? ma_format_u8 : ((stream.sampleSize == 16) ? ma_format_s16 : ma_format_f32));

    // The size of a streaming buffer must be at least double the size of a period.
    unsigned int periodSize = device.playback.internalBufferSizeInFrames / device.playback.internalPeriods;
    unsigned int subBufferSize = AUDIO_BUFFER_SIZE;
    if (subBufferSize < periodSize)
        subBufferSize = periodSize;

    AudioBuffer *audioBuffer = CreateAudioBuffer(formatIn, stream.channels, stream.sampleRate, subBufferSize * 2, AUDIO_BUFFER_USAGE_STREAM);
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "InitAudioStream() : Failed to create audio buffer");
        return stream;
    }

    audioBuffer->looping = true; // Always loop for streaming buffers.
    stream.audioBuffer = audioBuffer;

    TraceLog(LOG_INFO, "[AUD ID %i] Audio stream loaded successfully (%i Hz, %i bit, %s)", stream.source, stream.sampleRate, stream.sampleSize, (stream.channels == 1) ? "Mono" : "Stereo");

    return stream;
}

// Close audio stream and free memory
void CloseAudioStream(AudioStream stream)
{
    DeleteAudioBuffer((AudioBuffer *)stream.audioBuffer);

    TraceLog(LOG_INFO, "[AUD ID %i] Unloaded audio stream data", stream.source);
}

// Update audio stream buffers with data
// NOTE 1: Only updates one buffer of the stream source: unqueue -> update -> queue
// NOTE 2: To unqueue a buffer it needs to be processed: IsAudioBufferProcessed()
void UpdateAudioStream(AudioStream stream, const void *data, int samplesCount)
{
    AudioBuffer *audioBuffer = (AudioBuffer *)stream.audioBuffer;
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "UpdateAudioStream() : No audio buffer");
        return;
    }

    if (audioBuffer->isSubBufferProcessed[0] || audioBuffer->isSubBufferProcessed[1])
    {
        ma_uint32 subBufferToUpdate;

        if (audioBuffer->isSubBufferProcessed[0] && audioBuffer->isSubBufferProcessed[1])
        {
            // Both buffers are available for updating. Update the first one and make sure the cursor is moved back to the front.
            subBufferToUpdate = 0;
            audioBuffer->frameCursorPos = 0;
        }
        else
        {
            // Just update whichever sub-buffer is processed.
            subBufferToUpdate = (audioBuffer->isSubBufferProcessed[0]) ? 0 : 1;
        }

        ma_uint32 subBufferSizeInFrames = audioBuffer->bufferSizeInFrames / 2;
        unsigned char *subBuffer = audioBuffer->buffer + ((subBufferSizeInFrames * stream.channels * (stream.sampleSize / 8)) * subBufferToUpdate);

        // Does this API expect a whole buffer to be updated in one go? Assuming so, but if not will need to change this logic.
        if (subBufferSizeInFrames >= (ma_uint32)samplesCount / stream.channels)
        {
            ma_uint32 framesToWrite = subBufferSizeInFrames;

            if (framesToWrite > ((ma_uint32)samplesCount / stream.channels))
                framesToWrite = (ma_uint32)samplesCount / stream.channels;

            ma_uint32 bytesToWrite = framesToWrite * stream.channels * (stream.sampleSize / 8);
            memcpy(subBuffer, data, bytesToWrite);

            // Any leftover frames should be filled with zeros.
            ma_uint32 leftoverFrameCount = subBufferSizeInFrames - framesToWrite;

            if (leftoverFrameCount > 0)
            {
                memset(subBuffer + bytesToWrite, 0, leftoverFrameCount * stream.channels * (stream.sampleSize / 8));
            }

            audioBuffer->isSubBufferProcessed[subBufferToUpdate] = false;
        }
        else
        {
            TraceLog(LOG_ERROR, "UpdateAudioStream() : Attempting to write too many frames to buffer");
            return;
        }
    }
    else
    {
        TraceLog(LOG_ERROR, "Audio buffer not available for updating");
        return;
    }
}

// Check if any audio stream buffers requires refill
bool IsAudioBufferProcessed(AudioStream stream)
{
    AudioBuffer *audioBuffer = (AudioBuffer *)stream.audioBuffer;
    if (audioBuffer == NULL)
    {
        TraceLog(LOG_ERROR, "IsAudioBufferProcessed() : No audio buffer");
        return false;
    }

    return audioBuffer->isSubBufferProcessed[0] || audioBuffer->isSubBufferProcessed[1];
}

// Play audio stream
void PlayAudioStream(AudioStream stream)
{
    PlayAudioBuffer((AudioBuffer *)stream.audioBuffer);
}

// Play audio stream
void PauseAudioStream(AudioStream stream)
{
    PauseAudioBuffer((AudioBuffer *)stream.audioBuffer);
}

// Resume audio stream playing
void ResumeAudioStream(AudioStream stream)
{
    ResumeAudioBuffer((AudioBuffer *)stream.audioBuffer);
}

// Check if audio stream is playing.
bool IsAudioStreamPlaying(AudioStream stream)
{
    return IsAudioBufferPlaying((AudioBuffer *)stream.audioBuffer);
}

// Stop audio stream
void StopAudioStream(AudioStream stream)
{
    StopAudioBuffer((AudioBuffer *)stream.audioBuffer);
}

void SetAudioStreamVolume(AudioStream stream, float volume)
{
    SetAudioBufferVolume((AudioBuffer *)stream.audioBuffer, volume);
}

void SetAudioStreamPitch(AudioStream stream, float pitch)
{
    SetAudioBufferPitch((AudioBuffer *)stream.audioBuffer, pitch);
}

//----------------------------------------------------------------------------------
// Module specific Functions Definition
//----------------------------------------------------------------------------------

// Some required functions for audio standalone module version

// Check file extension
bool IsFileExtension(const char *fileName, const char *ext)
{
    bool result = false;
    const char *fileExt;

    if ((fileExt = strrchr(fileName, '.')) != NULL)
    {
        if (strcmp(fileExt, ext) == 0)
            result = true;
    }

    return result;
}

// Show trace log messages (LOG_INFO, LOG_WARNING, LOG_ERROR, LOG_DEBUG)
void TraceLog(int msgType, const char *text, ...)
{
    va_list args;
    va_start(args, text);

    switch (msgType)
    {
    case LOG_INFO:
        fprintf(stdout, "INFO: ");
        break;
    case LOG_ERROR:
        fprintf(stdout, "ERROR: ");
        break;
    case LOG_WARNING:
        fprintf(stdout, "WARNING: ");
        break;
    case LOG_DEBUG:
        fprintf(stdout, "DEBUG: ");
        break;
    default:
        break;
    }

    vfprintf(stdout, text, args);
    fprintf(stdout, "\n");

    va_end(args);

    // if (msgType == LOG_ERROR)
    //     exit(1);
}

#undef AudioBuffer

#endif // END DM_PLATFORM