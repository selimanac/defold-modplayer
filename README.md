![ModPlayer](https://github.com/selimanac/defold-modplayer/blob/master/assets/modplayer_logo.png?raw=true)

# Defold ModPlayer

This is chiptune player native extension for [Defold Engine](https://www.defold.com/). ModPlayer can load and play .XM and .MOD file formats. Extension supported MacOS, Windows, Linux, Android and iOS. Html 5 is not supported yet.

**Caution:** This extension is not battle tested yet and you should consider it as alpha release. It may contain bugs.


## Installation

Installation require a few steps. 

#### Add Dependency

You can use the ModPlayer extension in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/).
Open your game.project file and in the dependencies field under project add:

>https://github.com/selimanac/defold-modplayer/archive/master.zip

#### Bundle Resources

Open your game.project file and in the [Bundle Resources](https://www.defold.com/manuals/project-settings/) field under project add:

>/res

![Bundle](https://github.com/selimanac/defold-modplayer/blob/master/assets/screenshots/bundle.png?raw=true)

#### Create Folders

Create `/res/common/assets` folder in your project root. Then you can place you .xm and .mod files here.

![Bundle](https://github.com/selimanac/defold-modplayer/blob/master/assets/screenshots/folders.png?raw=true)


## Notes & Known Issues

* Loading and parsing is blocker. It will block the main thread (UI thread). Since the mod files are small it is better to load them when bootstraping or at preloading stage.
* XM files are loading much faster then mod files. (Tested with same tracker file) 
* I couldn't find a way to retrive build path when developing on Defold Editor. You have to provide a full path to `player.build_path("<FULL_PATH>/res/common/assets/")` function for **working on Defold Editor only**. It doesn't required when bundling.

## Example

See the [example folder](https://github.com/selimanac/defold-modplayer/tree/master/example) for simple usage. For more examples: [https://github.com/selimanac/defold-modplayer-examples](https://github.com/selimanac/defold-modplayer-examples)

```lua

	player.master_volume(1.0) -- Set master volume for musics ( 0.0 -> 1.0 is max level)
	local music = player.load_music("bb.xm") -- Load mod file and assign it is ID
	player.play_music(music) -- Play mod file
	player.music_volume(music, 0.5) -- Set volume for music ( 0.0 -> 1.0 is max level)
	player.music_pitch(music, 1.0) -- Set pitch for a music (1.0 is base level)
	print("Music length: ", player.music_lenght(music)) -- Get music time length (in seconds)
	
```

## API

#### player.build_path(full_path:string)

Only required when developing on Defold. Don't set it when bundling. Passing empty string may cause crash.


```lua
player.build_path("<FULL_PATH>/res/common/assets/") -- Set build path for working on Editor only 
```

#### player.master_volume(volume:double)

Set master volume for musics ( 0.0 -> 1.0 is max level)

```lua
player.master_volume(1.0)
```

#### player.load_music(file_name:string)

Load and parse mod file into memory.
Returns ID.

```lua
local music = player.load_music("your_file_name.xm") -- Load mod file and assign it is ID[int] 
```

#### player.play_music(id:int)

Start music playing.

```lua
player.play_music(music) 
```

#### player.pause_music(id:int)

Pause music playing.

```lua
player.pause_music(music) 
```

#### resume_music(id:int)

Resume playing "paused" music

```lua
player.resume_music(music)
```

#### player.music_volume(id:int, volume:double)

Set volume for music ( 0.0 -> 1.0 is max level)

```lua
player.music_volume(music, 0.5)
```

#### player.music_pitch(id:int, pitch:double)

Set pitch for a music (1.0 is base level). 

```lua
player.music_pitch(music, 1.0) 
```

#### player.music_lenght(id:int)

Get music time length (in seconds)

```lua
print("Music length: ", player.music_lenght(music))
```

#### player.music_played(id:int)

Get current music time played (in seconds)

```lua
print("Played : ", player.music_played(music))
```

#### player.music_loop(loop:int)

Set music loop count (loop repeats) NOTE: If set to -1, means infinite loop. Default is -1 (infinite)

```lua
player.music_loop(music, 1)
```

#### player.is_music_playing(id:int)

Check if music is playing

```lua
print("is Playing:", player.is_music_playing(music)) 
```

#### player.stop_music(id:int)

Stop music playing

```lua
player.stop_music(music) 
```

#### player.unload_music(id:int)

Unload music from memory

```lua
player.unload_music(music)
```

#### player.xm_volume(id:int, volume:double, amplification:double)

Only for XM files. You can change the samples volume but it may cause a clipping. You can balance it with amplification. Some bad modules may still clip. Default values; volume 1.0, amplification 0.25.
Use it with caution!

```lua
player.xm_volume(music, 2.5, 0.15)
```

## Dependencies

* [miniaudio](https://github.com/dr-soft/miniaudio) (slightly modified version)
* [raudio](https://github.com/raysan5/raylib/blob/master/src/raudio.h) (heavily modified custom version)
* [jar_mod](https://github.com/kd7tck/jar/blob/master/jar_mod.h) (slightly modified version)
* [jar_xm](https://github.com/kd7tck/jar/blob/master/jar_xm.h) (slightly modified version)
* [hashtable](https://github.com/JCash/containers/blob/master/src/jc/hashtable.h)

Thanks to all Defold team for their great support. 