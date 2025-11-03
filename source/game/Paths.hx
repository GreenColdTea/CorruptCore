package game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

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
#end

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

@:access(openfl.display.BitmapData)
class Paths
{
    inline public static final SOUND_EXT = #if web "mp3" #else "ogg" #end;
    inline public static final VIDEO_EXT = "mp4";
    
    @:unreflective
    inline public static final OPUS_EXT = "opus";

    @:unreflective
    inline public static final WAV_EXT = "wav";

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
        for (key in FlxG.bitmap._cache.keys())
        {
            if (!currentTrackedAssets.exists(key))
                destroyGraphic(FlxG.bitmap.get(key));
        }

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
            Mods.getModPath('scripts/states/$statePath/'),
            #end
        ];

        #if MODS_ALLOWED
        if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) {
            foldersToCheck.insert(0, Mods.getModPath('${Mods.currentModDirectory}/scripts/states/$statePath/'));
        }
        
        for (mod in Mods.getGlobalMods()) {
            foldersToCheck.insert(0, Mods.getModPath('$mod/scripts/states/$statePath/'));
        }
        #end

        foldersToCheck.push(Paths.getPreloadPath('scripts/states/$statePath.hx'));
        #if MODS_ALLOWED
        foldersToCheck.push(Mods.getModPath('scripts/states/$statePath.hx'));
        foldersToCheck.push(Mods.getModPath('${Mods.currentModDirectory}/scripts/states/$statePath.hx'));
        for (mod in Mods.getGlobalMods()) {
            foldersToCheck.push(Mods.getModPath('$mod/scripts/states/$statePath.hx'));
        }
        #end

        return foldersToCheck;
    }

    static public function getSubstateScripts(statePath:String):Array<String> {
        var foldersToCheck:Array<String> = [
            Paths.getPreloadPath('scripts/substates/$statePath/'),
            #if MODS_ALLOWED 
            Mods.getModPath('scripts/substates/$statePath/'),
            #end
        ];

        #if MODS_ALLOWED
        if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) {
            foldersToCheck.insert(0, Mods.getModPath('${Mods.currentModDirectory}/scripts/substates/$statePath/'));
        }
        
        for (mod in Mods.getGlobalMods()) {
            foldersToCheck.insert(0, Mods.getModPath('$mod/scripts/substates/$statePath/'));
        }
        #end

        foldersToCheck.push(Paths.getPreloadPath('scripts/substates/$statePath.hx'));
        #if MODS_ALLOWED
        foldersToCheck.push(Mods.getModPath('scripts/substates/$statePath.hx'));
        foldersToCheck.push(Mods.getModPath('${Mods.currentModDirectory}/scripts/substates/$statePath.hx'));
        for (mod in Mods.getGlobalMods()) {
            foldersToCheck.push(Mods.getModPath('$mod/scripts/substates/$statePath.hx'));
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
        var file:String = Mods.modsVideo(key);
        if(file.startsWith('zip://')) {
            var parts = file.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'videos');
            if(tempPath != null) return tempPath;
        }
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
        if (OpenFlAssets.exists(assetsPath))
        {
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
            if (file.startsWith('zip://')) {
                var parts = file.substr(6).split('/');
                var mod = parts[0];
                var filePath = parts.slice(1).join('/');
                var content = Mods.getFileFromMod(mod, filePath);
                if (content != null) bitmap = BitmapData.fromBytes(content);
            }
            else #end #if sys if (FileSystem.exists(file))
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
        if (path.startsWith('zip://')) {
            var parts = path.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            return (content != null) ? content.toString() : null;
        }
        return (FileSystem.exists(path)) ? File.getContent(path) : null;
        #else
        return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
        #end
    }

    static public function font(key:String)
    {
        #if MODS_ALLOWED
        var file:String = Mods.modsFont(key);
        if(file.startsWith('zip://')) {
            var parts = file.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'fonts');
            if(tempPath != null) return tempPath;
        }
        if(FileSystem.exists(file)) {
            return file;
        }
        #end
        return 'assets/fonts/$key';
    }

    public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String = null)
    {
        var path:String = getPath(key, type, library, !ignoreMods);
        
        #if MODS_ALLOWED
        if (path.startsWith('zip://')) {
            return true;
        }
        if(FileSystem.exists(path)) {
        #else
        if(OpenFlAssets.exists(path, type)) {
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
        else #end if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
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
            else #end if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
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

    static public function getSparrowAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
    {
        if (ClientPrefs.cacheOnGPU) {
            allowGPU = true;
        }
        var imageLoaded:FlxGraphic = image(key, library, allowGPU);
        #if MODS_ALLOWED
        var xmlExists:Bool = false;

        var xml:String = Mods.modsXml(key);
        if(xml.startsWith('zip://')) {
            var parts = xml.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) return FlxAtlasFrames.fromSparrow(imageLoaded, content.toString());
        }
        else if(FileSystem.exists(xml)) xmlExists = true;

        return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath('images/$key.xml', library)));
        #else
        return FlxAtlasFrames.fromSparrow(imageLoaded, getPath('images/$key.xml', library));
        #end
    }

    static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
    {
        if (ClientPrefs.cacheOnGPU) {
            allowGPU = true;
        } else {
            allowGPU = false;
        }
        var imageLoaded:FlxGraphic = image(key, library, allowGPU);
        #if MODS_ALLOWED
        var txtExists:Bool = false;
        
        var txt:String = Mods.modsTxt(key);
        if(txt.startsWith('zip://')) {
            var parts = txt.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, content.toString());
        }
        else if(FileSystem.exists(txt)) txtExists = true;

        return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath('images/$key.txt', library)));
        #else
        return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath('images/$key.txt', library));
        #end
    }

    static public function getAsepriteAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
    {
        var imageLoaded:FlxGraphic = image(key, library, allowGPU);
        #if MODS_ALLOWED
        var jsonExists:Bool = false;

        var json:String = Mods.modsImagesJson(key);
        if(json.startsWith('zip://')) {
            var parts = json.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var content = Mods.getFileFromMod(mod, filePath);
            if (content != null) return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, content.toString());
        }
        else if(FileSystem.exists(json)) jsonExists = true;

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

        var file:String = Mods.modsSounds(modLibPath, key, WAV_EXT);
        if(file.startsWith('zip://')) {
            var parts = file.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'sounds');
            if(tempPath != null) {
                if(!currentTrackedSounds.exists(file)) {
                    #if (sys && !web)
                    if (FileSystem.exists(tempPath))
                        currentTrackedSounds.set(file, CoolUtil.loadHighBitrateWav(key, tempPath));
                    else
                        currentTrackedSounds.set(file, Sound.fromFile(tempPath));
                    #else
                    currentTrackedSounds.set(file, Sound.fromFile(tempPath));
                    #end
                }
                localTrackedAssets.push(file);
                return currentTrackedSounds.get(file);
            }
        }
        else if(FileSystem.exists(file)) {
            if(!currentTrackedSounds.exists(file)) {
                currentTrackedSounds.set(file, CoolUtil.loadHighBitrateWav(key, file));
            }
            localTrackedAssets.push(file);
            return currentTrackedSounds.get(file);
        }

        file = Mods.modsSounds(modLibPath, key);
        if(file.startsWith('zip://')) {
            var parts = file.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'sounds');
            if(tempPath != null) {
                if(!currentTrackedSounds.exists(file)) {
                    currentTrackedSounds.set(file, Sound.fromFile(tempPath));
                }
                localTrackedAssets.push(file);
                return currentTrackedSounds.get(file);
            }
        }
        else if(FileSystem.exists(file)) {
            if(!currentTrackedSounds.exists(file)) {
                currentTrackedSounds.set(file, Sound.fromFile(file));
            }
            localTrackedAssets.push(file);
            return currentTrackedSounds.get(file);
        }

        #if (hxopus && sys)
        file = Mods.modsSounds(modLibPath, key, OPUS_EXT);
        if(file.startsWith('zip://')) {
            var parts = file.substr(6).split('/');
            var mod = parts[0];
            var filePath = parts.slice(1).join('/');
            var tempPath = Mods.extractFileFromZipMod(mod, filePath, 'sounds');
            if(tempPath != null) {
                if(!currentTrackedSounds.exists(file)) {
                    var bytes = File.getBytes(tempPath);
                    currentTrackedSounds.set(file, hxopus.Opus.toOpenFL(bytes));
                }
                localTrackedAssets.push(file);
                return currentTrackedSounds.get(file);
            }
        }
        else if(FileSystem.exists(file)) {
            if(!currentTrackedSounds.exists(file)) {
                var bytes = File.getBytes(file);
                currentTrackedSounds.set(file, hxopus.Opus.toOpenFL(bytes));
            }
            localTrackedAssets.push(file);
            return currentTrackedSounds.get(file);
        }
        #end
        #end

        var wavPath:String = getPath((path != null ? '$path/' : '') + '$key.$WAV_EXT', SOUND, library);
        if(OpenFlAssets.exists(wavPath, SOUND)) {
            if(!currentTrackedSounds.exists(wavPath)) {
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

        #if hxopus
        var opusPath:String = getPath((path != null ? '$path/' : '') + '$key.$OPUS_EXT', SOUND, library);
        if(OpenFlAssets.exists(opusPath, SOUND)) {
            if(!currentTrackedSounds.exists(opusPath)) {
                var bytes = OpenFlAssets.getBytes(opusPath);
                currentTrackedSounds.set(opusPath, hxopus.Opus.toOpenFL(bytes));
            }
            localTrackedAssets.push(opusPath);
            return currentTrackedSounds.get(opusPath);
        }
        #end

        if(beepOnNull) {
            trace('SOUND NOT FOUND: $key, PATH: $path');
            return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
        }
        return null;
    }
}