![ModPlayer](https://github.com/selimanac/defold-modplayer/blob/master/assets/screenshots/defoldheader.png?raw=true)



This is chiptune player native extension for [Defold Engine](https://www.defold.com/). ModPlayer can load and play .XM and .MOD file formats. Extension supported MacOS, Windows, Linux*, Android, iOS and [HTML5](#html5-bundle).  

**Caution:** This extension is not battle tested yet and you should consider it as alpha release. It may contain bugs.


## Installation

Installation requires a few steps. 

#### 1- Add Dependency

You can use the ModPlayer extension in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/).  
Open your game.project file and in the dependencies field under project add:

>https://github.com/selimanac/defold-modplayer/archive/master.zip

#### 2- Bundle Resources Path

Open your game.project file and in the [Bundle Resources](https://www.defold.com/manuals/project-settings/) field under project add:

>/res

![Bundle](https://github.com/selimanac/defold-modplayer/blob/master/assets/screenshots/bundle.png?raw=true)

#### 3- Create Folders

Create `/res/common/assets` folders in your project root. Then you can place your .xm and .mod files here. You can add subfolders as you like; `/res/common/assets/musics`

![Bundle](https://github.com/selimanac/defold-modplayer/blob/master/assets/screenshots/folders.png?raw=true)


## Notes & Known Issues

* Loading and parsing is blocker. It will block the main thread (UI thread). Since the mod files are small it is better to load them when bootstraping or preloading. It may cause a pause on UI.
* Loading and parsing XM files much more faster then mod files. Use XM if possible. (Tested with same tracker file as .mod and .xm) 
* Not %100 compatible with every MOD or XM files. 
* I couldn't find a way to retrieve build path when developing on Defold Editor. You have to provide a full path to `player.build_path("<FULL_PATH>/res/common/assets/")` function for **working on Defold Editor only**. It doesn't required when bundling.
* Different platform bundles didn't tested very well.
	* MacOS: Long run.
	* iOS: Long run. 
	* Windows: Short run. Tested on [Wine](https://www.winehq.org/) 
	* Android: Short run. 
	* Linux: I couldn't manage to have sound on my VMs. But app is successfully load the files and run on Debian and Ubuntu	
* Hashtable is limited to 10 elements. I think it is more than enough. It is a bad practice to load or play more than two music files at the same time. 
* Currently, it is not possible to Build HTML5 on the Defold Editor with mod music. You can build it for testing, but can't load the the musics.
	
## Example

See the [example folder](https://github.com/selimanac/defold-modplayer/tree/master/example) for simple usage.   
For more examples: [https://github.com/selimanac/defold-modplayer-examples](https://github.com/selimanac/defold-modplayer-examples)  
Nanowar game example: [https://github.com/selimanac/nanowar-modplayer](https://github.com/selimanac/nanowar-modplayer)


```lua

	player.master_volume(1.0) -- Set master volume for musics ( 0.0 -> 1.0 is max level)
	local music = player.load_music("bb.xm") -- Load mod file and assign it is ID
	player.play_music(music) -- Play mod file
	player.music_volume(music, 0.5) -- Set volume for music ( 0.0 -> 1.0 is max level)
	player.music_pitch(music, 1.0) -- Set pitch for a music (1.0 is base level)
	print("Music length: ", player.music_lenght(music)) -- Get music time length (in seconds)
	
```

## HTML5 Bundle

Unfortunately, it is not possible to build HTML5 on the Defold Editor with mod music(You can build it for testing, but can't load the musics). But you can bundle as HTML5 from the Editor with mod music.

Bundling for HTML5 is require editing of `archive_files.json` file manually. [More info about the issue is here.](https://forum.defold.com/t/reading-files-from-res-common-folder-with-emscripten/55056). 

* Bundle you project as usual by using `Project > Bundle > HTML5` from the Defold Editor
* Open `archive/archive_files.json` file from bundled folder 
* Add your music files into `archive_files.json` file with their names and sizes.

```
{
    "name": "level_1.xm", 	<- Name of your file for loading from Defold
    "size": 42940,			<- Actual size of the file (bytes) 
    "pieces": [
        {
            "name": "../assets/audio/level_1.xm", <- Relative path to your mod files
            "offset": 0
        }
    ]
}
```        

Example HTML5 project is [here](https://github.com/selimanac/modplayer-html5-example) and example archive_files.json is [here](https://github.com/selimanac/modplayer-html5-example/blob/master/archive/archive_files.json).

## API

#### player.build_path(full_path:string)

Only required when developing on Defold Editor.   
! Don't set this when bundling !  

```lua
player.build_path("<FULL_PATH>/res/common/assets/") -- Set build path when working on Editor only 
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

#### player.resume_music(id:int)

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

Check if music is playing. Also returns `false` if music is not loaded or unloaded.

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

Only for XM files. You can change the samples volume, but it may cause a clipping. You can balance it with amplification. Some bad modules may still clip. Default values; volume 1.0, amplification 0.25.
Use it with caution!

```lua
player.xm_volume(music, 2.5, 0.15)
```

## Dependencies

* [miniaudio](https://github.com/dr-soft/miniaudio) (slightly modified version)
* [raudio](https://github.com/raysan5/raylib/blob/master/src/raudio.c) (heavily modified version)
* [jar_mod](https://github.com/kd7tck/jar/blob/master/jar_mod.h) (slightly modified version)
* [jar_xm](https://github.com/kd7tck/jar/blob/master/jar_xm.h) (slightly modified version)
* [hashtable](https://github.com/JCash/containers/blob/master/src/jc/hashtable.h)

**Thanks to all Defold team for their great support.**