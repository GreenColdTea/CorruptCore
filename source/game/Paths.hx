package game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

#if flxgif
import flxgif.FlxGifAsset;
#end

import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;

import haxe.Json;
import haxe.xml.Access;

import lime.utils.Assets;

#if flixel_animate
import animate.FlxAnimateFrames.SpritemapInput;
import animate.FlxAnimateFrames.FilterQuality;
import game.backend.AtlasSpriteSettings;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

@:access(openfl.display.BitmapData)
class Paths
{
    public static final SOUND_EXTS:Array<String> = [#if !flash "ogg", "wav", #if (hxflac || web) "flac", #end #if hxopus "opus", #end #end "mp3"];
    public static final VIDEO_EXTS:Array<String> = ["mp4", "avi", "mkv", "mov", "wmv", "flv", "webm"];
    public static final IMAGE_EXTS:Array<String> = ["png", "jpg", "jpeg"];
    public static final HSCRIPT_EXTS:Array<String> = ["hx", "hscript", "hxs"];

    //for backward compatibility
    public static final SOUND_EXT = SOUND_EXTS[0];
    public static final VIDEO_EXT = VIDEO_EXTS[0];

    public static function excludeAsset(key:String) {
        if (!dumpExclusions.contains(key))
            dumpExclusions.push(key);
    }

    public static var dumpExclusions:Array<String> =
    [
        'assets/music/freakyMenu.$SOUND_EXT',
    ];

    public static var localTrackedAssets:Array<String> = [];
    public static function clearUnusedMemory(cleanMajor:Bool = true) {
        if (FlxG.state is PlayState) cleanMajor = false; // dont do major cleans ingame

        for (key in currentTrackedAssets.keys())
        {
            if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
            {
                destroyGraphic(currentTrackedAssets.get(key));
                currentTrackedAssets.remove(key);
            }
        }
        MemoryUtil.forceGC(cleanMajor);
    }

    @:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
    public static function clearStoredMemory() {
        // its buggy for haxeui
        /*for (key in FlxG.bitmap._cache.keys())
        {
            if (!currentTrackedAssets.exists(key))
                destroyGraphic(FlxG.bitmap.get(key));
        }*/

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
                    for (member in grp)
                        checkForGraphics(member);
                    return;
                }
            }

            try
            {
                var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
                if(gfx != null) protectedGfx.push(gfx);
            }
        }

        for (member in FlxG.state.members) checkForGraphics(member);

        if(FlxG.state.subState != null)
            for (member in FlxG.state.subState.members)
                checkForGraphics(member);

        for (key in currentTrackedAssets.keys())
        {
            if (!dumpExclusions.contains(key))
            {
                var graphic:FlxGraphic = currentTrackedAssets.get(key);
                if(!protectedGfx.contains(graphic))
                {
                    destroyGraphic(graphic);
                    currentTrackedAssets.remove(key);
                }
            }
        }
    }

    inline static function destroyGraphic(graphic:FlxGraphic)
    {
        graphic?.bitmap?.__texture?.dispose();
        FlxG.bitmap?.remove(graphic);
    }

    public static var currentLevel:String;
    public static function setCurrentLevel(name:String)
    {
        currentLevel = name.toLowerCase();
    }

    public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
    {
        #if MODS_ALLOWED
        if(modsAllowed)
        {
            var modded:String = Mods.modFolders(file);
            if(FileSystem.exists(modded)) return modded;
        }
        #end

        //for backward compatibility
        if (library != null && library != "preload" && library != "default")
        {
            var libraryPath = getLibraryPath(file, library);
            if (#if sys FileSystem.exists(libraryPath) || #end OpenFlAssets.exists(libraryPath))
                return libraryPath;
        }

        if (currentLevel != null)
        {
            var levelPath:String = '';
            if(currentLevel != 'shared') {
                levelPath = getLibraryPathForce(file, 'week_assets', currentLevel);

                #if sys
                if (FileSystem.exists(levelPath))
                    return levelPath;
                #end

                if (OpenFlAssets.exists(levelPath))
                    return levelPath;
            }

            levelPath = getLibraryPathForce(file, "shared");

            #if sys
            if (FileSystem.exists(levelPath))
                return levelPath;
            #end

            if (OpenFlAssets.exists(levelPath))
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
        return 'assets/$level/$file';
    }

    inline public static function getPreloadPath(file:String = '')
    {
        return 'assets/$file';
    }

    #if SCRIPTABLE_STATES
    static public function getStateScripts(statePath:String):Array<String> {
        var foldersToCheck:Array<String> = [];
        var scriptPaths:Array<String> = [];
        
        foldersToCheck.push(Paths.getPreloadPath('scripts/states/$statePath/'));
        #if MODS_ALLOWED
        foldersToCheck.push(Mods.getModPath('scripts/states/$statePath/'));
        if (Mods.currentModDirectory?.length > 0) {
            foldersToCheck.insert(0, Mods.getModPath('${Mods.currentModDirectory}/scripts/states/$statePath/'));
        }
        for (mod in Mods.getGlobalMods()) {
            foldersToCheck.insert(0, Mods.getModPath('$mod/scripts/states/$statePath/'));
        }
        #end
        
        for (exts in HSCRIPT_EXTS)
        {
            scriptPaths.push(Paths.getPreloadPath('scripts/states/$statePath.$exts'));
            #if MODS_ALLOWED
            scriptPaths.push(Mods.getModPath('scripts/states/$statePath.$exts'));
            if (Mods.currentModDirectory?.length > 0)
                scriptPaths.push(Mods.getModPath('${Mods.currentModDirectory}/scripts/states/$statePath.$exts'));

            for (mod in Mods.getGlobalMods())
                scriptPaths.push(Mods.getModPath('$mod/scripts/states/$statePath.$exts'));
            #end
        }
        
        return foldersToCheck.concat(scriptPaths);
    }

    static public function getSubstateScripts(statePath:String):Array<String> {
        var foldersToCheck:Array<String> = [];
        var scriptPaths:Array<String> = [];
        
        foldersToCheck.push(Paths.getPreloadPath('scripts/substates/$statePath/'));
        #if MODS_ALLOWED
        foldersToCheck.push(Mods.getModPath('scripts/substates/$statePath/'));
        if (Mods.currentModDirectory?.length > 0) {
            foldersToCheck.insert(0, Mods.getModPath('${Mods.currentModDirectory}/scripts/substates/$statePath/'));
        }
        for (mod in Mods.getGlobalMods()) {
            foldersToCheck.insert(0, Mods.getModPath('$mod/scripts/substates/$statePath/'));
        }
        #end
        
        for (exts in HSCRIPT_EXTS)
        {
            scriptPaths.push(Paths.getPreloadPath('scripts/substates/$statePath.$exts'));
            #if MODS_ALLOWED
            scriptPaths.push(Mods.getModPath('scripts/substates/$statePath.$exts'));
            if (Mods.currentModDirectory?.length > 0)
                scriptPaths.push(Mods.getModPath('${Mods.currentModDirectory}/scripts/substates/$statePath.$exts'));

            for (mod in Mods.getGlobalMods())
                scriptPaths.push(Mods.getModPath('$mod/scripts/substates/$statePath.$exts'));
            #end
        }
        
        return foldersToCheck.concat(scriptPaths);
    }
    #end

    inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
    {
        return getPath(file, type, library);
    }

    inline static public function txt(key:String, ?library:String, ?modsAllowed:Bool = true)
    {
        return getPath('data/$key.txt', TEXT, library, modsAllowed);
    }

    inline static public function xml(key:String, ?library:String, ?modsAllowed:Bool = true)
    {
        return getPath('data/$key.xml', TEXT, library, modsAllowed);
    }

    inline static public function json(key:String, ?library:String, ?modsAllowed:Bool = true)
    {
        return getPath('data/$key.json', TEXT, library, modsAllowed);
    }

    inline static public function shaderFragment(key:String, ?library:String, ?modsAllowed:Bool = true)
    {
        return getPath('shaders/$key.frag', TEXT, library, modsAllowed);
    }
    inline static public function shaderVertex(key:String, ?library:String, ?modsAllowed:Bool = true)
    {
        return getPath('shaders/$key.vert', TEXT, library, modsAllowed);
    }
    inline static public function lua(key:String, ?library:String, ?modsAllowed:Bool = true)
    {
        return getPath('$key.lua', TEXT, library, modsAllowed);
    }

    static public function video(key:String, ?ignoreMods:Bool = false):String
    {
        #if MODS_ALLOWED
        for (ext in VIDEO_EXTS) {
            if (ignoreMods) continue;

            final file:String = Mods.modFolders('videos/$key.$ext');
            if(file.startsWith('zip://')) {
                var parts = file.substr(6).split('/');
                var mod = parts[0];
                var filePath = parts.slice(1).join('/');
                var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'videos');
                if(tempPath != null) return tempPath;
            }

            if(FileSystem.exists(file))
                return file;
        }
        #end
        
        for (ext in VIDEO_EXTS) {
            final testPath = getPreloadPath('videos/$key.$ext');
            if (#if sys FileSystem.exists(testPath) || #end OpenFlAssets.exists(testPath))
                return testPath;
        }
        
        return getPreloadPath('videos/$key.${VIDEO_EXTS[0]}');
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
        var file:String = Mods.modsNdll(key + "-" + game.backend.utils.NdllUtil.os + ".ndll");
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
        var modsList:Array<String> = [Mods.currentModDirectory];
        modsList = modsList.concat(Mods.getGlobalMods());

        for (mod in modsList)
        {
            if (mod == null || mod.length == 0) continue;

            var modPath = Mods.getModPath('$mod/$path');
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
        #if sys
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

        if (OpenFlAssets.exists(assetsPath))
        {
            var prefix = assetsPath + "/";
            for (asset in OpenFlAssets.list())
            {
                if (asset.startsWith(prefix) && asset != prefix)
                    result.push(asset);
            }
        }

        return result;
    }

    public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
    static public function image(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxGraphic
    {
        if (currentTrackedAssets.exists(key))
        {
            localTrackedAssets.push(key);
            return currentTrackedAssets.get(key);
        }
        return cacheBitmap(key, library, null, allowGPU);
    }

    static public function cacheBitmap(key:String, ?library:String = null, ?bitmap:BitmapData = null, ?allowGPU:Bool = true)
    {
        if (bitmap == null)
        {
            for (ext in IMAGE_EXTS)
            {
                var file:String = getPath('images/$key.$ext', IMAGE, library, true);
                #if MODS_ALLOWED
                if (file.startsWith('zip://'))
                {
                    var parts = file.substr(6).split('/');
                    var mod = parts[0];
                    var filePath = parts.slice(1).join('/');
                    var content = Mods.getFileFromMod(mod, filePath);
                    if (content != null)
                    {
                        bitmap = BitmapData.fromBytes(content);
                        break;
                    }
                }
                else #end
                #if sys
                if (FileSystem.exists(file))
                {
                    bitmap = BitmapData.fromFile(file);
                    break;
                }
                #end
                if (OpenFlAssets.exists(file, IMAGE))
                {
                    bitmap = OpenFlAssets.getBitmapData(file);
                    break;
                }
            }

            if (bitmap == null)
            {
                trace('Bitmap not found for key: $key (tried: ${IMAGE_EXTS.join(", ")})');
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

    static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
    {
        var path:String = getPath(key, TEXT, !ignoreMods);
        #if MODS_ALLOWED
        if (path.startsWith('zip://')) {
            var parts = path.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            return (content != null) ? content.toString() : null;
        }
        #end

        #if sys
        if (FileSystem.exists(path)) return File.getContent(path);
        #end

        return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
    }

    static public function font(key:String, ?ignoreMods:Bool = false):String
    {
        #if MODS_ALLOWED
        if (!ignoreMods) {
            var file:String = Mods.modFolders('fonts/$key');
            if(file.startsWith('zip://')) {
                var parts = file.substr(6).split('/');
                var mod = parts[0];
                var filePath = parts.slice(1).join('/');
                var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'fonts');
                if(tempPath != null) return tempPath;
            }

            if(FileSystem.exists(file)) return file;
        }
        #end
        return 'assets/fonts/$key';
    }

    public static function fileExists(key:String, ?type:AssetType, ?ignoreMods:Bool = false, ?library:String = null)
	{
		#if MODS_ALLOWED
		if(!ignoreMods)
		{
			for(mod in Mods.getGlobalMods())
				if (FileSystem.exists(Mods.getModPath('$mod/$key')))
					return true;

			if (FileSystem.exists(Mods.getModPath(Mods.currentModDirectory + '/' + key)) || FileSystem.exists(Mods.getModPath(key)))
				return true;

			if (FileSystem.exists(Mods.getModPath('$key')))
				return true;
		}
		#end

        #if sys
        if(FileSystem.exists(getPath(key, type, library))) {
			return true;
		}
        #end

		if(OpenFlAssets.exists(getPath(key, type, library))) {
			return true;
		}
		return false;
	}

    static public function getAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
    {
        var imageLoaded:FlxGraphic = image(key, library, allowGPU);

        var myXml:Dynamic = getPath('images/$key.xml', TEXT, library, true);
        #if MODS_ALLOWED
        if(myXml.startsWith('zip://')) {
            var parts = myXml.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) {
                return FlxAtlasFrames.fromSparrow(imageLoaded, content.toString());
            }
        }
        else #end if(OpenFlAssets.exists(myXml) #if sys || (FileSystem.exists(myXml)) #end )
        {
            return FlxAtlasFrames.fromSparrow(imageLoaded, (#if sys (FileSystem.exists(myXml) ? File.getContent(myXml) : myXml) #else myXml #end));
        }
        else
        {
            var myJson:Dynamic = getPath('images/$key.json', TEXT, library, true);
            #if MODS_ALLOWED
            if(myJson.startsWith('zip://')) {
                var parts = myJson.substr(6).split('/');
                var mod = parts[0];
                var filePath = parts.slice(1).join('/');
                var content = Mods.getFileFromMod(mod, filePath);
                if (content != null) {
                    return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, content.toString());
                }
            }
            else #end if(OpenFlAssets.exists(myJson) #if sys || (FileSystem.exists(myJson)) #end )
            {
                return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (#if sys (FileSystem.exists(myJson) ? File.getContent(myJson) : myJson) #else myJson #end));
            }
        }
        return getPackerAtlas(key, library);
    }

    static public function getSparrowAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
    {
        allowGPU = ClientPrefs.cacheOnGPU;
        
        var imageLoaded:FlxGraphic = image(key, library, allowGPU);
        #if MODS_ALLOWED
        var xml:String = Mods.modFolders('images/$key.xml');
        if(xml.startsWith('zip://')) {
            var parts = xml.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) return FlxAtlasFrames.fromSparrow(imageLoaded, content.toString());
        }
        else if(FileSystem.exists(xml)) {
            return FlxAtlasFrames.fromSparrow(imageLoaded, File.getContent(xml));
        }
        #end

        return FlxAtlasFrames.fromSparrow(imageLoaded, getPath('images/$key.xml', library));
    }

    static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
    {
        allowGPU = ClientPrefs.cacheOnGPU;

        var imageLoaded:FlxGraphic = image(key, library, allowGPU);
        #if MODS_ALLOWED
        var txt:String = Mods.modFolders('images/$key.txt');
        if(txt.startsWith('zip://')) {
            var parts = txt.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, content.toString());
        }
        else if(FileSystem.exists(txt)) {
            return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, File.getContent(txt));
        }
        #end

        return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath('images/$key.txt', library));
    }

    static public function getAsepriteAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
    {
        var imageLoaded:FlxGraphic = image(key, library, allowGPU);
        #if MODS_ALLOWED
        var json:String = Mods.modFolders('images/$key.json');
        if(json.startsWith('zip://')) {
            var parts = json.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, content.toString());
        }
        else if(FileSystem.exists(json)) {
            return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, File.getContent(json));
        }
        #end

        return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath('images/$key.json', library));
    }

    inline static public function getAnimateAtlas(key:String, ?library:String = null, ?settings:AtlasSpriteSettings):FlxAnimateFrames
    {
        final validatedSettings:AtlasSpriteSettings =
        {
            swfMode: settings?.swfMode ?? false,
            cacheOnLoad: settings?.cacheOnLoad ?? (ClientPrefs.cacheOnGPU || ClientPrefs.adaptiveCache),
            filterQuality: settings?.filterQuality ?? (!ClientPrefs.lowQuality ? MEDIUM : LOW),
            spritemaps: settings?.spritemaps ?? null,
            metadataJson: settings?.metadataJson ?? null,
            cacheKey: settings?.cacheKey ?? null,
            uniqueInCache: settings?.uniqueInCache ?? false,
            onSymbolCreate: settings?.onSymbolCreate ?? null,
            applyStageMatrix: settings?.applyStageMatrix ?? false,
            useRenderTexture: settings?.useRenderTexture ?? false
        };

        #if flixel_animate
        return FlxAnimateFrames.fromAnimate(getPath('images/$key', TEXT, library, true), validatedSettings.spritemaps, validatedSettings.metadataJson, validatedSettings.cacheKey,
            validatedSettings.uniqueInCache, {
                swfMode: validatedSettings.swfMode,
                cacheOnLoad: validatedSettings.cacheOnLoad,
                filterQuality: validatedSettings.filterQuality,
                onSymbolCreate: validatedSettings.onSymbolCreate
            }
        );
        #end
    }

    inline static public function gif(key:String, ?library:String = null):FlxGifAsset
    {
        return getPath('images/$key.gif', IMAGE, library, true);
    }

    inline static public function formatToSongPath(path:String) {
        var invalidChars = ~/[~&\\;:<>#]/;
        var hideChars = ~/[.,'"%?!]/;

        var path = invalidChars.split(path.replace(' ', '-')).join("-");
        return hideChars.split(path).join("").toLowerCase();
    }

    public static function getRelativePath(absPath:String):String
    {
        #if sys
        if (absPath == null) return null;
        var cwd = Sys.getCwd().replace('\\', '/');
        var normalized = absPath.replace('\\', '/');
        if (normalized.indexOf(cwd) == 0)
        {
            return normalized.substr(cwd.length);
        }
        #end
        return absPath;
    }

    public static function getAbsolutePath(assetPath:String):String {
        #if sys
        var cleanPath = assetPath;
        if (cleanPath.indexOf("assets/") == 0) {
            cleanPath = cleanPath.substring(7);
        }
        return Sys.getCwd() + getPreloadPath(cleanPath);
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

        for (ext in SOUND_EXTS) {
            var file:String = Mods.modsSounds(modLibPath, key, ext);
            if(file.startsWith('zip://')) {
                var parts = file.substr(6).split('/');
                var mod = parts[0];
                var filePath = parts.slice(1).join('/');
                var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'sounds');
                if(tempPath != null) {
                    if(!currentTrackedSounds.exists(file)) {
                        #if hxopus
                        if (ext == "opus") {
                            var bytes = File.getBytes(tempPath);
                            currentTrackedSounds.set(file, hxopus.Opus.toOpenFL(bytes));
                        } else #end if (ext == "wav") {
                            #if (sys && !web)
                            if (FileSystem.exists(tempPath))
                                currentTrackedSounds.set(file, CoolUtil.loadHighBitrateWav(key, tempPath));
                            else
                                currentTrackedSounds.set(file, Sound.fromFile(tempPath));
                            #else
                            currentTrackedSounds.set(file, Sound.fromFile(tempPath));
                            #end
                        #if hxflac
                        } else if (ext == "flac") {
                            var bytes = File.getBytes(tempPath);
                            currentTrackedSounds.set(file, hxflac.FLACHelper.toOpenFL(bytes));
                        #end
                        } else {
                            currentTrackedSounds.set(file, Sound.fromFile(tempPath));
                        }
                    }
                    localTrackedAssets.push(file);
                    return currentTrackedSounds.get(file);
                }
            }
            else if(FileSystem.exists(file)) {
                if(!currentTrackedSounds.exists(file)) {
                    #if hxopus
                    if (ext == "opus") {
                        var bytes = File.getBytes(file);
                        currentTrackedSounds.set(file, hxopus.Opus.toOpenFL(bytes));
                    } else #end if (ext == "wav") {
                        currentTrackedSounds.set(file, CoolUtil.loadHighBitrateWav(key, file));
                    #if hxflac
                    } else if (ext == "flac") {
                        var bytes = File.getBytes(file);
                        currentTrackedSounds.set(file, hxflac.FLACHelper.toOpenFL(bytes));
                    #end
                    } else {
                        currentTrackedSounds.set(file, Sound.fromFile(file));
                    }
                }
                localTrackedAssets.push(file);
                return currentTrackedSounds.get(file);
            }
        }
        #end

        for (ext in SOUND_EXTS) {
            var soundPath:String = getPath((path != null ? '$path/' : '') + '$key.$ext', SOUND, library);
            if(OpenFlAssets.exists(soundPath)) {
                if(!currentTrackedSounds.exists(soundPath)) {
                    #if hxopus
                    if (ext == "opus") {
                        var bytes = OpenFlAssets.getBytes(soundPath);
                        currentTrackedSounds.set(soundPath, hxopus.Opus.toOpenFL(bytes));
                    } else #end if (ext == "wav") {
                        #if (sys && !web)
                        var absolutePath = getAbsolutePath(soundPath);
                        if (FileSystem.exists(absolutePath))
                            currentTrackedSounds.set(soundPath, CoolUtil.loadHighBitrateWav(key, absolutePath));
                        else
                            currentTrackedSounds.set(soundPath, OpenFlAssets.getSound(soundPath));
                        #else
                        currentTrackedSounds.set(soundPath, OpenFlAssets.getSound(soundPath));
                        #end
                    #if hxflac
                    } else if (ext == "flac") {
                        currentTrackedSounds.set(soundPath, hxflac.FLACHelper.toOpenFLFromFile(soundPath));
                    #end
                    } else {
                        currentTrackedSounds.set(soundPath, OpenFlAssets.getSound(soundPath));
                    }
                }
                localTrackedAssets.push(soundPath);
                return currentTrackedSounds.get(soundPath);
            }
        }

        if(beepOnNull) {
            trace('SOUND NOT FOUND: $key, PATH: $path');
            return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
        }
        return null;
    }
}