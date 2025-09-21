package game;

import flixel.system.FlxAssets;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import flixel.FlxSprite;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;

#if flixel_animate
import animate.FlxAnimateFrames.SpritemapInput;
import animate.FlxAnimateFrames.FilterQuality;
#end

import openfl.media.Sound;

using StringTools;

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";
	inline public static var WAV_EXT = "wav";


	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		#if NDLL_ALLOWED 'ndlls', #end
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
	];
	#end

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> =
	[
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];
	public static var localTrackedAssets:Array<String> = [];	 
	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory(cleanMajor:Bool = true) {
		if (FlxG.state is PlayState) cleanMajor = false; // dont do major cleans ingame

		// clear non local assets in the tracked assets list
					  
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}						   
		// run the garbage collector for good measure lmfao
		MemoryUtil.forceGC(cleanMajor);
	}

	// define the locally tracked assets

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory() {
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		FlxG.bitmap.clearUnused();
		MemoryUtil.compact();
		
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets.resize(0);
		openfl.Assets.cache.clear("songs");
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					//trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null) protectedGfx.push(gfx);
			}
			//catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members) checkForGraphics(member);

		if(FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		graphic?.bitmap?.__texture?.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var modded:String = modFolders(file);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, 'week_assets', currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String, ?level:String)
	{
		level ??= library;
		var returnPath = '$library:assets/$level/$file';
		return returnPath;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	#if SCRIPTABLE_STATES
	static public function getStateScripts(statePath:String):Array<String> {
		var foldersToCheck:Array<String> = [
			Paths.getPreloadPath('scripts/states/$statePath/'),
			#if MODS_ALLOWED 
			Paths.mods('scripts/states/$statePath/'),
			#end
		];

		#if MODS_ALLOWED
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0) {
			foldersToCheck.unshift(Paths.mods('${Paths.currentModDirectory}/scripts/states/$statePath/'));
		}
		
		for (mod in Paths.getGlobalMods()) {
			foldersToCheck.unshift(Paths.mods('$mod/scripts/states/$statePath/'));
		}
		#end

		foldersToCheck.push(Paths.getPreloadPath('scripts/states/$statePath.hx'));
		#if MODS_ALLOWED
		foldersToCheck.push(Paths.mods('scripts/states/$statePath.hx'));
		foldersToCheck.push(Paths.mods('${Paths.currentModDirectory}/scripts/states/$statePath.hx'));
		for (mod in Paths.getGlobalMods()) {
			foldersToCheck.push(Paths.mods('$mod/scripts/states/$statePath.hx'));
		}
		#end

		return foldersToCheck;
	}


	//same as above but for substates
	static public function getSubstateScripts(statePath:String):Array<String> {
		var foldersToCheck:Array<String> = [
			Paths.getPreloadPath('scripts/substates/$statePath/'),
			#if MODS_ALLOWED 
			Paths.mods('scripts/substates/$statePath/'),
			#end
		];

		#if MODS_ALLOWED
		if (currentModDirectory != null && currentModDirectory.length > 0) {
			foldersToCheck.unshift(Paths.mods('${currentModDirectory}/scripts/substates/$statePath/'));
		}
		
		for (mod in getGlobalMods()) {
			foldersToCheck.unshift(Paths.mods('$mod/scripts/substates/$statePath/'));
		}
		#end

		foldersToCheck.push(Paths.getPreloadPath('scripts/substates/$statePath.hx'));
		#if MODS_ALLOWED
		foldersToCheck.push(Paths.mods('scripts/substates/$statePath.hx'));
		foldersToCheck.push(Paths.mods('${currentModDirectory}/scripts/substates/$statePath.hx'));
		for (mod in getGlobalMods()) {
			foldersToCheck.push(Paths.mods('$mod/scripts/substates/$statePath.hx'));
		}
		#end

		return foldersToCheck;
	}
	#end

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}
	inline static public function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}
	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
		return sound(key + FlxG.random.int(min, max), library);

	inline static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline static public function voices(song:String, postfix:String = null):Sound
	{
		var songKey:String = '${formatToSongPath(song)}/voices';
		if (postfix != null) songKey += '-' + postfix;
	
		var snd = returnSound(null, songKey, 'songs', false);
		if (snd == null) {
			songKey = '${formatToSongPath(song)}/Voices';
			if (postfix != null) songKey += '-' + postfix;
			snd = returnSound(null, songKey, 'songs', false);
		}
	
		return snd;
	}
	
	inline static public function inst(song:String):Any {
		var songKey:String = '${formatToSongPath(song)}/inst';
		
		var snd = returnSound(null, songKey, 'songs', false);
		if (snd == null) {
			songKey = '${formatToSongPath(song)}/Inst';
			snd = returnSound(null, songKey, 'songs', false);
		}
	
		return snd;
	}

	#if NDLL_ALLOWED
	inline static public function ndll(key:String) {
		#if MODS_ALLOWED
		var file:String = modsNdll(key + "-" + game.backend.utils.NdllUtil.os + ".ndll");
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/$key';
	}
	#end

	public static function listDirectory(path:String):Array<String>
	{
		var result:Array<String> = [];
		
		#if MODS_ALLOWED
		var modsList:Array<String> = [currentModDirectory];
		modsList = modsList.concat(getGlobalMods());
		
		for (mod in modsList)
		{
			if (mod == null || mod.length == 0) continue;
			
			var modPath = mods('$mod/$path');
			if (FileSystem.exists(modPath) && FileSystem.isDirectory(modPath))
			{
				for (file in FileSystem.readDirectory(modPath))
				{
					var fullPath = haxe.io.Path.join([modPath, file]);
					if (!FileSystem.isDirectory(fullPath))
						result.push(fullPath);
				}
			}
		}
		#end

		var assetsPath = getPreloadPath(path);
		if (OpenFlAssets.exists(assetsPath))
		{
			// some shits for web targets(for the future mb)
			#if web
			var prefix = assetsPath + "/";
			for (asset in OpenFlAssets.list(ALL))
			{
				if (asset.startsWith(prefix) && asset != prefix)
					result.push(asset);
			}
			#else
			if (FileSystem.exists(assetsPath) && FileSystem.isDirectory(assetsPath))
			{
				for (file in FileSystem.readDirectory(assetsPath))
				{
					var fullPath = haxe.io.Path.join([assetsPath, file]);
					if (!FileSystem.isDirectory(fullPath))
						result.push(fullPath);
				}
			}
			#end
		}

		return result;
	}
		
	// completely rewritten asset loading? fuck!
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?library:String = null, ?allowGPU:Bool = true, ?imgFormat:String = "png"):FlxGraphic
	{
		var bitmap:BitmapData = null;
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return cacheBitmap(key, library, bitmap, allowGPU, imgFormat);

		trace('oh no its returning null NOOOO ($file)');
		return null;
	}

	static public function cacheBitmap(key:String, ?library:String = null, ?bitmap:BitmapData = null, ?allowGPU:Bool = true, ?imgFormat:String)
	{
		if (bitmap == null)
		{
			var file:String = getPath('images/$key.$imgFormat', IMAGE, library, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && (ClientPrefs.cacheOnGPU || ClientPrefs.adaptiveCache) && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, !ignoreMods);
		#if MODS_ALLOWED
		return (FileSystem.exists(path)) ? File.getContent(path) : null;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String = null)
	{
		#if MODS_ALLOWED
		if(FileSystem.exists(getPath(key, type, library, !ignoreMods))) {
		#else
		if(OpenFlAssets.exists(getPath(key, type, library, !ignoreMods))) {
		#end
			return true;
		}
		return false;
	}

	static public function getAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, library, true);
		if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
		{
			#if MODS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', TEXT, library, true);
			if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
			{
				#if MODS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}
		return getPackerAtlas(key, library);
	}

	inline static public function getSparrowAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
	{
		if (ClientPrefs.cacheOnGPU) {
			allowGPU = true;
		}
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		#if MODS_ALLOWED
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;

		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath('images/$key.xml', library)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath('images/$key.xml', library));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
	{
		if (ClientPrefs.cacheOnGPU) {
			allowGPU = true;
		} else {
			allowGPU = false;
		}
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		#if MODS_ALLOWED
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if(FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath('images/$key.txt', library));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, library, allowGPU);
		#if MODS_ALLOWED
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if(FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? File.getContent(json) : getPath('images/$key.json', library)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath('images/$key.json', library));
		#end
	}

	#if flixel_animate
	inline static public function getAnimateAtlas(key:String, ?library:String = null):FlxAnimateFrames
	{
		return FlxAnimateFrames.fromAnimate(getPath('images/$key', TEXT, library, true));
	}
	#end

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?!]/;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	public static function getAbsolutePath(assetPath:String):String {
		#if sys
		var cleanPath = assetPath;
		if (cleanPath.indexOf("assets/") == 0) {
			cleanPath = cleanPath.substring(7);
		}
		return Sys.getCwd() + "assets/" + cleanPath;
		#else
		return assetPath;
		#end
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:Null<String>, key:String, ?library:String, ?beepOnNull:Bool = true) {
		#if MODS_ALLOWED
		var modLibPath:String = '';
		if (library != null) modLibPath = '$library/';
		if (path != null) modLibPath += '$path';

		var file:String = modsSounds(modLibPath, key, WAV_EXT);
		if(FileSystem.exists(file)) {
			if(!currentTrackedSounds.exists(file)) {
				currentTrackedSounds.set(file, CoolUtil.loadHighBitrateWav(key, file));
			}
			localTrackedAssets.push(file);
			return currentTrackedSounds.get(file);
		}

		file = modsSounds(modLibPath, key);
		if(FileSystem.exists(file)) {
			if(!currentTrackedSounds.exists(file)) {
				currentTrackedSounds.set(file, Sound.fromFile(file));
			}
			localTrackedAssets.push(file);
			return currentTrackedSounds.get(file);
		}
		#end

		// checking wav files for existing
		var wavPath:String = getPath((path != null ? '$path/' : '') + '$key.$WAV_EXT', SOUND, library);
		if(OpenFlAssets.exists(wavPath, SOUND)) {
			if(!currentTrackedSounds.exists(wavPath)) {
				//for web only mp3 lel
				#if (sys && !web)
				var absolutePath = getAbsolutePath(wavPath);
				if (FileSystem.exists(absolutePath))
					currentTrackedSounds.set(wavPath, CoolUtil.loadHighBitrateWav(key, absolutePath));
				else
					currentTrackedSounds.set(wavPath, OpenFlAssets.getSound(wavPath));
				#else
				currentTrackedSounds.set(wavPath, OpenFlAssets.getSound(wavPath));
				#end
			}
			localTrackedAssets.push(wavPath);
			return currentTrackedSounds.get(wavPath);
		}

		var standardPath:String = getPath((path != null ? '$path/' : '') + '$key.$SOUND_EXT', SOUND, library);
		if(OpenFlAssets.exists(standardPath, SOUND)) {
			if(!currentTrackedSounds.exists(standardPath)) {
				currentTrackedSounds.set(standardPath, OpenFlAssets.getSound(standardPath));
			}
			localTrackedAssets.push(standardPath);
			return currentTrackedSounds.get(standardPath);
		}

		if(beepOnNull) {
			trace('SOUND NOT FOUND: $key, PATH: $path');
			return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
		}
		return null;
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '') {
		return 'contents/$key';
	}

	#if SCRIPTABLE_STATES
	inline static public function modsStates(key:String, state:String)
		return modFolders('scripts/states/$state/$key.hx');
	#end

	inline static public function modsFont(key:String) {
		return modFolders('fonts/$key');
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/$key.json');
	}

	inline static public function modsVideo(key:String) {
		return modFolders('videos/$key.$VIDEO_EXT');
	}

	#if NDLL_ALLOWED
	public static function modsNdll(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = "contents/" + currentModDirectory + '/' + key;
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		for(mod in getGlobalMods()) {
			var fileToCheck:String = "contents/" + mod + '/' + key;
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;

		}
		return 'contents/' + key;
	}
	#end

	inline static public function modsSounds(path:String, key:String, ?ext:String = null) {
		ext ??= SOUND_EXT;
		return modFolders('$path/$key.$ext');
	}

	inline static public function modsImages(key:String, ?imgFormat:String = "png") {
		return modFolders('images/$key.$imgFormat');
	}

	inline static public function modsImagesJson(key:String) {
		return modFolders('images/$key.json');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/$key.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/$key.txt');
	}

	inline static public function modsShaderFragment(key:String, ?library:String)
	{
		return modFolders('shaders/$key.frag');
	}
	inline static public function modsShaderVertex(key:String, ?library:String)
	{
		return modFolders('shaders/$key.vert');
	}

	/* Goes unused for now
	inline static public function modsAchievements(key:String) {
		return modFolders('achievements/' + key + '.json');
	}*/

	static public function modFolders(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		for(mod in getGlobalMods()){
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;

		}
		return 'contents/' + key;
	}

	public static var globalMods:Array<String> = [];

	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if(FileSystem.exists(path)) {
						try{
							var rawJson:String = File.getContent(path);
							if(rawJson != null && rawJson.length > 0) {
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if(global)globalMods.push(dat[0]);
							}
						} catch(e:Dynamic){
							trace(e);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
