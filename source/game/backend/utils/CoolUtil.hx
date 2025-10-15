package game.backend.utils;

import flixel.FlxG;
import flixel.sound.FlxSound;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

import haxe.io.Bytes;

#if sl_windows_api
import winapi.WindowsAPI;
import winapi.WindowsAPI.MessageBoxIcon;
import winapi.WindowsAPI.MessageBoxType;
#end

import lime.media.AudioBuffer;
import lime.media.AudioSource;
import lime.media.vorbis.VorbisFile;
import lime.utils.UInt8Array;
import lime.utils.Assets;

import openfl.media.Sound;

using StringTools;

class CoolUtil
{
	public static var defaultDifficulties:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];
	public static var defaultDifficulty:String = 'Normal'; //The chart that has no suffix and starting difficulty on Freeplay/Story Mode

	public static var difficulties:Array<String> = [];

	public static function getBuildTarget():String {
		#if windows
		return "Windows";
		#elseif linux
		return "Linux";
		#elseif mac
		return "Mac";
		#elseif android
		return "Android";
		#elseif ios
		return "iOS";
		#elseif html5
		return "HTML5";
		#else
		return "Unknown";
		#end
	}
	
	public static function getDifficultyFilePath(num:Null<Int> = null)
	{
		num ??= PlayState.storyDifficulty;

		var fileSuffix:String = difficulties[num];
		if(fileSuffix != defaultDifficulty)
		{
			fileSuffix = '-' + fileSuffix;
		}
		else
		{
			fileSuffix = '';
		}
		return Paths.formatToSongPath(fileSuffix);
	}

	public static function difficultyString():String
	{
		return difficulties[PlayState.storyDifficulty].toUpperCase();
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var daList:Array<String> = [];
		#if sys
		if(FileSystem.exists(path)) daList = File.getContent(path).trim().split('\n');
		#else
		if(Assets.exists(path)) daList = Assets.getText(path).trim().split('\n');
		#end

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}

	public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}
	
	inline public static function dominantColor(sprite:flixel.FlxSprite):Int
	{
		var countByColor:Map<Int, Int> = [];
		for(col in 0...sprite.frameWidth)
		{
			for(row in 0...sprite.frameHeight)
			{
				var colorOfThisPixel:FlxColor = sprite.pixels.getPixel32(col, row);
				if(colorOfThisPixel.alphaFloat > 0.05)
				{
					colorOfThisPixel = FlxColor.fromRGB(colorOfThisPixel.red, colorOfThisPixel.green, colorOfThisPixel.blue, 255);
					var count:Int = countByColor.exists(colorOfThisPixel) ? countByColor[colorOfThisPixel] : 0;
					countByColor[colorOfThisPixel] = count + 1;
				}
			}
		}

		var maxCount = 0;
		var maxKey:Int = 0; //after the loop this will store the max color
		countByColor[FlxColor.BLACK] = 0;
		for(key => count in countByColor)
		{
			if(count >= maxCount)
			{
				maxCount = count;
				maxKey = key;
			}
		}
		countByColor = [];
		return maxKey;
	}

	public static dynamic function hxTrace(text:Dynamic, color:FlxColor) {
		if(FlxG.state is PlayState) PlayState.instance.addTextToDebug(Std.string(text), color);
		else trace(text);
	}

	public static function getModSetting(saveTag:String, ?modName:String = null)
	{
		#if MODS_ALLOWED
		if(FlxG.save.data.modSettings == null) FlxG.save.data.modSettings = new Map<String, Dynamic>();
		var settings:Map<String, Dynamic> = FlxG.save.data.modSettings.get(modName);
		
		var path:String = Mods.getModPath('$modName/data/settings.json');
		if(FileSystem.exists(path))
		{
			if(settings == null || !settings.exists(saveTag))
			{
				if(settings == null) settings = new Map<String, Dynamic>();
				try
				{
					var parsedJson:Dynamic = haxe.Json.parse(#if sys File.getContent(path) #else Assets.getText(path) #end);
					for (i in 0...parsedJson.length)
					{
						var sub:Dynamic = parsedJson[i];
						if(sub != null && sub.save != null && !settings.exists(sub.save))
						{
							if(sub.type != 'keybind' && sub.type != 'key')
							{
								if(sub.value != null)
								{
									//FunkinLua.luaTrace('getModSetting: Found unsaved value "${sub.save}" in Mod: "$modName"');
									settings.set(sub.save, sub.value);
								}
							}
							else
							{
								//FunkinLua.luaTrace('getModSetting: Found unsaved keybind "${sub.save}" in Mod: "$modName"');
								settings.set(sub.save, {keyboard: (sub.keyboard != null ? sub.keyboard : 'NONE'), gamepad: (sub.gamepad != null ? sub.gamepad : 'NONE')});
							}
						}
					}
					FlxG.save.data.modSettings.set(modName, settings);
				} catch(e:Dynamic) {
					var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
					var errorMsg = 'An error occurred: $e';

					showPopUp(errorMsg, errorTitle);
				}
			}
		}
		else
		{
			FlxG.save.data.modSettings.remove(modName);
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			CoolUtil.hxTrace('getModSetting: $path could not be found!', 0xFFFF0000);
			#else
			FlxG.log.warn('getModSetting: $path could not be found!');
			#end
			return null;
		}

		if(settings.exists(saveTag)) return settings.get(saveTag);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		CoolUtil.hxTrace('getModSetting: "$saveTag" could not be found inside $modName\'s settings!', 0xFFFF0000);
		#else
		FlxG.log.warn('getModSetting: "$saveTag" could not be found inside $modName\'s settings!');
		#end
		#end
		return null;
	}

	//for the future updates
	inline public static function unzipFile(srcZip:String, dstDir:String, ignoreRootFolder:Bool = false) {
		#if sys
        trace("Unzipping archive...");
		
        FileSystem.createDirectory(dstDir);
        
        var inFile = sys.io.File.read(srcZip);
        var entries = haxe.zip.Reader.readZip(inFile);
        inFile.close();

        for(entry in entries) {
            var fileName = entry.fileName;
            if (fileName.charAt(0) != "/" && fileName.charAt(0) != "\\" && fileName.split("..").length <= 1) {
                var dirs = ~/[\/\\]/g.split(fileName);
                if ((ignoreRootFolder != false && dirs.length > 1) || ignoreRootFolder == false) {
                    if (ignoreRootFolder != false) {
                        dirs.shift();
                    }
                
                    var path = "";
                    var file = dirs.pop();
                    for (d in dirs) {
                        path += d;
                        sys.FileSystem.createDirectory(dstDir + "/" + path);
                        path += "/";
                    }
                
                    if (file == "")
                        continue;

                    path += file;
                
                    var data = haxe.zip.Reader.unzip(entry);
                    var f = File.write(dstDir + "/" + path, true);
                    f.write(data);
                    f.close();
                }
            }
        } //_entry

        var contents = sys.FileSystem.readDirectory(dstDir);
        if (contents.length > 0) {
            trace('Unzipped successfully to ${dstDir}: (${contents.length} top level items found)');
        } else {
            throw 'No contents found in "${dstDir}"';
        }
		#end
    }

	inline public static function setWindowDarkMode(title:String, enable:Bool) {
		#if windows
		title ??= lime.app.Application.current.window.title;
		lime.Native.setWindowDarkMode(title, enable);
		#end
	}

	//uhhhh does this even work at all? i'm starting to doubt
	inline public static function precacheSound(sound:String, ?library:String = null):Void {
		Paths.sound(sound, library);
	}

	inline public static function precacheMusic(sound:String, ?library:String = null):Void {
		Paths.music(sound, library);
	}

	inline public static function hasVersion(vers:String) {
		return lime.system.System.platformLabel.toLowerCase().indexOf(vers.toLowerCase()) != -1;
	}

	inline public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	inline public static function showPopUp(message:String, title:String #if sl_windows_api, ?icon:MessageBoxIcon, ?type:MessageBoxType #end, showScrollableMSG:Bool = false):Void
	{
		#if android
		AndroidTools.showAlertDialog(title, message, {name: "OK", func: null}, null);
		#elseif linux
		Sys.command("zenity", ["--info", "--title=" + title, "--text=" + message]);
		#elseif sl_windows_api
		if (showScrollableMSG)
			WindowsAPI.showScrollableMessage(message, title);
		else
			WindowsAPI.showMessageBox(message, title, icon, type);
		#else
		lime.app.Application.current.window.alert(message, title);
		#end
	}

	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String {
		final company:String = FlxG.stage.application.meta.get('company');
		// #if (flixel < "5.0.0") return company; #else
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
		// #end
	}

	public static function recursivelyReadFolders(path:String)
	{
		#if sys
		var ret:Array<String> = [];
		for (i in FileSystem.readDirectory(path))
			returnFileName(i, ret, path);

		
		path += '/';
		for (i in 0...ret.length)
			ret[i] = ret[i].replace(path, '');

		return ret;
		#end
	}

	static function returnFileName(path:String, toAdd:Array<String>, full:String) {
		#if sys
		if (FileSystem.isDirectory('$full/$path')) {
			for (i in FileSystem.readDirectory('$full/$path')) {
				returnFileName(i, toAdd, '$full/$path');
			}
		} else {
			toAdd.push(('$full/$path'));
		}
		#end
	}

	public static inline function readRecursive(path:String):Array<String>
	{
		#if sys
		var result:Array<String> = [];
		for (directory in Paths.listDirectory(path))
		{
			for (file in recursivelyReadFolders(directory))
			{
				if (!result.contains(file))
					result.push(file);
			}
		}

		return result;
		#else
		return [];
		#end
	}

	public static function loadHighBitrateWav(key:String, path:String):Sound 
	{
		#if (sys && !web)
		try {
			var tempPath = '${Paths.getPreloadPath("temp")}/$key.converted.wav';
			
			if (FileSystem.exists(tempPath)) {
				trace('Using existing converted WAV file: $key');
				return Sound.fromFile(tempPath);
			}
			
			var bytes = File.getBytes(path);
			var buffer = AudioBuffer.fromBytes(bytes);
			
			if (buffer.sampleRate > 44100 || buffer.bitsPerSample > 16) {
				trace('Converting high bitrate WAV: $key');
				
				if (!FileSystem.exists(Paths.getPreloadPath('temp')))
					FileSystem.createDirectory(Paths.getPreloadPath('temp'));
				
				if (!FileSystem.exists(tempPath)) {
					//yea yea it will work if you have ffmpeg on your desktop
					//if not then it wont work lel
					var cmd = 'ffmpeg -i "$path" -ar 44100 -ac ${buffer.channels} -sample_fmt s16 "$tempPath"';
					var result = Sys.command(cmd);
					
					if (result == 0 && FileSystem.exists(tempPath)) {
						trace('Successfully converted WAV file: $key');
						return Sound.fromFile(tempPath);
					} else {
						trace('FFmpeg conversion failed for $key, using original file');
					}
				}
			}
		} catch (e:Dynamic) {
			trace('Error processing WAV file $key: $e');
		}
		#end
		
		return Sound.fromFile(path);
	}

	/*
	* Helper function to write a WAV file
	* Was commented due to this converter works like ass lmao
	*/
	/*private static function writeWavFile(path:String, data:Bytes, sampleRate:Int, channels:Int, bitsPerSample:Int):Void
	{
		var output = File.write(path, true);
		
		//calculate values for the WAV header
		var byteRate = Std.int(sampleRate * channels * bitsPerSample / 8);
		var blockAlign = Std.int(channels * bitsPerSample / 8);
		var dataSize = data.length;
		
		//write WAV header
		output.writeString("RIFF"); //chunk ID
		output.writeInt32(36 + dataSize); //chunk size (file size = 8)
		output.writeString("WAVE"); //format
		
		output.writeString("fmt "); //subchunk 1 ID
		output.writeInt32(16); //subchunk 1 size (16 for PCM)
		output.writeInt16(1); //audio format (1 = PCM)
		output.writeInt16(channels); //num of channels
		output.writeInt32(sampleRate); //sample rate
		output.writeInt32(byteRate); //byte rate
		output.writeInt16(blockAlign); //block align
		output.writeInt16(bitsPerSample); //bits per sample
		
		output.writeString("data"); //subchunk 2 ID
		output.writeInt32(dataSize); //subchunk 2 size (data size)
		
		//write audio data
		output.write(data);
		output.close();
	}*/
}
