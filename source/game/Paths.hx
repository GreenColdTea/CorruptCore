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
import haxe.io.Bytes;

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
    public static final SOUND_EXTS:Array<String> = [#if !flash "ogg", "wav", "flac", "opus", #end "mp3"];
    public static final VIDEO_EXTS:Array<String> = ["mp4", "avi", "mkv", "mov", "wmv", "flv", "webm"];
    public static final HSCRIPT_EXTS:Array<String> = ["hx", "hscript", "hxs"];
    public static final IMAGE_EXTS:Array<String> = [
        "png", "jpg", "jpeg", "bmp", "tga", "webp", "avif", "tif", "tiff", 
        "jxl", "pcx", "xcf", "xpm", "qoi", "lbm", "iff", "pnm", "ppm", "pgm", "pbm"
    ];

    //for backwards compatibility
    public static final SOUND_EXT = SOUND_EXTS[0];
    public static final VIDEO_EXT = VIDEO_EXTS[0];

    public static var currentLevel:String;

    inline public static function setCurrentLevel(name:String) {
        currentLevel = name.toLowerCase();
    }

    public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
    {
        #if MODS_ALLOWED
        if (modsAllowed) {
            final modded = Mods.modFolders(file);
            if (FileUtil.exists(modded)) return modded;
        }
        #end

        if (library != null && library != "preload" && library != "default") {
            final libraryPath = getLibraryPath(file, library);
            if (FileUtil.exists(libraryPath)) return libraryPath;
        }

        if (currentLevel != null) {
            if (currentLevel != 'shared') {
                final levelPath = getLibraryPathForce(file, 'week_assets', currentLevel);
                if (FileUtil.exists(levelPath)) return levelPath;
            }

            final sharedPath = getLibraryPathForce(file, "shared");
            if (FileUtil.exists(sharedPath)) return sharedPath;
        }

        return getPreloadPath(file);
    }

    inline static public function getLibraryPath(file:String, library = "preload"):String {
        return (library == "preload" || library == "default") ? getPreloadPath(file) : getLibraryPathForce(file, library);
    }

    inline static function getLibraryPathForce(file:String, library:String, ?level:String):String {
        #if MODS_ALLOWED
        final modLibrary = Mods.modFolders('${level ?? library}/$file');
        if (FileUtil.exists(modLibrary)) return modLibrary;
        #end
        return getPreloadPath('${level ?? library}/$file');
    }

    inline public static function getPreloadPath(file:String = ''):String {
        return 'assets/$file';
    }

    inline static private function getPhysicalModPath(virtualPath:String, category:String):Null<String> {
        #if MODS_ALLOWED
        if (virtualPath.startsWith('zip://')) {
            final parts = virtualPath.substr(6).split('/');
            return Mods.extractFileFromZipMod(parts.shift(), parts.join('/'), category);
        }
        if (FileUtil.exists(virtualPath)) return virtualPath;
        #end
        return null;
    }

    #if SCRIPTABLE_STATES
    static public function getStateScripts(statePath:String):Array<String> {
        return _getScriptsForPath('scripts/states/$statePath');
    }

    static public function getSubstateScripts(statePath:String):Array<String> {
        return _getScriptsForPath('scripts/substates/$statePath');
    }

    static private function _getScriptsForPath(basePath:String):Array<String> {
        final foldersToCheck = [getPreloadPath('$basePath/')];
        final scriptPaths = [];
        
        #if MODS_ALLOWED
        for (mod in Mods.globalMods) {
            final modPath = Mods.getModPath('$mod/$basePath/');
            if (!foldersToCheck.contains(modPath)) foldersToCheck.insert(0, modPath);
        }

        if (Mods.currentModDirectory?.length > 0) {
            final currentPath = Mods.getModPath('${Mods.currentModDirectory}/$basePath/');
            if (!foldersToCheck.contains(currentPath)) foldersToCheck.insert(0, currentPath);
        }
        #end
        
        for (ext in HSCRIPT_EXTS) {
            final fileTarget = '$basePath.$ext';
            scriptPaths.push(getPreloadPath(fileTarget));
            
            #if MODS_ALLOWED
            for (mod in Mods.globalMods) {
                final modFile = Mods.getModPath('$mod/$fileTarget');
                if (!scriptPaths.contains(modFile)) scriptPaths.push(modFile);
            }

            if (Mods.currentModDirectory?.length > 0) {
                final currentFile = Mods.getModPath('${Mods.currentModDirectory}/$fileTarget');
                if (!scriptPaths.contains(currentFile)) scriptPaths.push(currentFile);
            }
            #end
        }
        return foldersToCheck.concat(scriptPaths);
    }
    #end

    inline static public function txt(key:String, ?library:String, ?modsAllowed:Bool = true) return getPath('data/$key.txt', TEXT, library, modsAllowed);
    inline static public function xml(key:String, ?library:String, ?modsAllowed:Bool = true) return getPath('data/$key.xml', TEXT, library, modsAllowed);
    inline static public function json(key:String, ?library:String, ?modsAllowed:Bool = true) return getPath('data/$key.json', TEXT, library, modsAllowed);
    inline static public function shaderFragment(key:String, ?library:String, ?modsAllowed:Bool = true) return getPath('shaders/$key.frag', TEXT, library, modsAllowed);
    inline static public function shaderVertex(key:String, ?library:String, ?modsAllowed:Bool = true) return getPath('shaders/$key.vert', TEXT, library, modsAllowed);
    inline static public function lua(key:String, ?library:String, ?modsAllowed:Bool = true) return getPath('$key.lua', TEXT, library, modsAllowed);

    static public function video(key:String, ?ignoreMods:Bool = false):String
    {
        #if MODS_ALLOWED
        if (!ignoreMods) {
            for (ext in VIDEO_EXTS) {
                final physicalPath = getPhysicalModPath(Mods.modFolders('videos/$key.$ext'), 'videos');
                if (physicalPath != null) return physicalPath;
            }
        }
        #end
        
        for (ext in VIDEO_EXTS) {
            final testPath = getPreloadPath('videos/$key.$ext');
            if (FileUtil.exists(testPath)) return testPath;
        }
        return getPreloadPath('videos/$key.$VIDEO_EXT');
    }

    inline static public function sound(key:String, ?library:String):Any return returnSound('sounds', key, library);
    inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String):Any return sound(key + FlxG.random.int(min, max), library);
    inline static public function music(key:String, ?library:String):Any return returnSound('music', key, library);

    inline static public function voices(song:String, postfix:String = null):Any
    {
        final base = '${SongUtil.formatToSongPath(song)}/voices';
        final baseUpper = '${SongUtil.formatToSongPath(song)}/Voices';
        return returnSound(null, postfix != null ? '$base-$postfix' : base, 'songs', false) 
            ?? returnSound(null, postfix != null ? '$baseUpper-$postfix' : baseUpper, 'songs', false);
    }

    inline static public function inst(song:String):Any {
        final path = SongUtil.formatToSongPath(song);
        return returnSound(null, '$path/inst', 'songs', false) ?? returnSound(null, '$path/Inst', 'songs', false);
    }

    #if NDLL_ALLOWED
    inline static public function ndll(key:String) {
        final fileName = 'ndlls/$key-${game.backend.utils.NdllUtil.os}.ndll';
        #if MODS_ALLOWED
        final modNdll = Mods.modsNdll(fileName);
        if (FileUtil.exists(modNdll)) return modNdll;
        #end
        return getPreloadPath(fileName);
    }
    #end

    static public function image(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxGraphic
    {
        if (FunkinCache.currentTrackedAssets.exists(key)) {
            FunkinCache.localTrackedAssets.push(key);
            return FunkinCache.currentTrackedAssets.get(key);
        }
        return FunkinCache.cacheBitmap(key, library, null, allowGPU);
    }

    static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):Null<String>
    {
        #if MODS_ALLOWED
        if (!ignoreMods) {
            final modBytes = Mods.getModFileContent(key);
            if (modBytes != null) return modBytes.toString();
        }
        #end
        return FileUtil.getContent(getPath(key, TEXT, !ignoreMods));
    }

    static public function font(key:String, ?ignoreMods:Bool = false):String
    {
        #if MODS_ALLOWED
        if (!ignoreMods) {
            final physicalPath = getPhysicalModPath(Mods.modFolders('fonts/$key'), 'fonts');
            if (physicalPath != null) return physicalPath;
        }
        #end
        return getPreloadPath('fonts/$key');
    }

    public static function fileExists(key:String, ?type:AssetType, ?ignoreMods:Bool = false, ?library:String = null):Bool
    {
        #if MODS_ALLOWED
        if (!ignoreMods && Mods.modFileExists(key)) return true;
        #end
        return FileUtil.exists(getPath(key, type, library));
    }

    static public function getAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
    {
        final imageLoaded = image(key, library, allowGPU);
        final basePath = library == null ? 'images/$key' : '$library/images/$key';

        #if MODS_ALLOWED
        final xmlBytes = Mods.getModFileContent('$basePath.xml');
        if (xmlBytes != null) return FlxAtlasFrames.fromSparrow(imageLoaded, xmlBytes.toString());

        final jsonBytes = Mods.getModFileContent('$basePath.json');
        if (jsonBytes != null) return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, jsonBytes.toString());
        #end

        final xmlPath = getPath('$basePath.xml', TEXT, library, true);
        if (FileUtil.exists(xmlPath))
            return FlxAtlasFrames.fromSparrow(imageLoaded, FileUtil.getContent(xmlPath));
        
        final jsonPath = getPath('$basePath.json', TEXT, library, true);
        if (FileUtil.exists(jsonPath))
            return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, FileUtil.getContent(jsonPath));

        return getPackerAtlas(key, library);
    }

    static public function getSparrowAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
    {
        final imageLoaded = image(key, library, ClientPrefs.cacheOnGPU);
        final xmlPath = library == null ? 'images/$key.xml' : '$library/images/$key.xml';

        #if MODS_ALLOWED
        final modBytes = Mods.getModFileContent(xmlPath);
        if (modBytes != null) return FlxAtlasFrames.fromSparrow(imageLoaded, modBytes.toString());
        #end

        return FlxAtlasFrames.fromSparrow(imageLoaded, FileUtil.getContent(getPath(xmlPath, TEXT, library)));
    }

    static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = false):FlxAtlasFrames
    {
        final imageLoaded = image(key, library, ClientPrefs.cacheOnGPU);
        final txtPath = library == null ? 'images/$key.txt' : '$library/images/$key.txt';

        #if MODS_ALLOWED
        final modBytes = Mods.getModFileContent(txtPath);
        if (modBytes != null) return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, modBytes.toString());
        #end

        return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, FileUtil.getContent(getPath(txtPath, TEXT, library)));
    }

    static public function getAsepriteAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
    {
        final imageLoaded = image(key, library, allowGPU);
        final jsonPath = library == null ? 'images/$key.json' : '$library/images/$key.json';

        #if MODS_ALLOWED
        final modBytes = Mods.getModFileContent(jsonPath);
        if (modBytes != null) return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, modBytes.toString());
        #end

        return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, FileUtil.getContent(getPath(jsonPath, TEXT, library)));
    }

    inline static public function getAnimateAtlas(key:String, ?library:String = null, ?settings:AtlasSpriteSettings):FlxAnimateFrames
    {
        final validatedSettings:AtlasSpriteSettings = {
            swfMode: settings?.swfMode ?? false,
            cacheOnLoad: settings?.cacheOnLoad ?? (ClientPrefs.cacheOnGPU || ClientPrefs.adaptiveCache),
            filterQuality: settings?.filterQuality ?? (!ClientPrefs.lowQuality ? MEDIUM : LOW),
            spritemaps: settings?.spritemaps,
            metadataJson: settings?.metadataJson,
            cacheKey: settings?.cacheKey,
            uniqueInCache: settings?.uniqueInCache ?? false,
            onSymbolCreate: settings?.onSymbolCreate,
            applyStageMatrix: settings?.applyStageMatrix ?? false,
            useRenderTexture: settings?.useRenderTexture ?? false
        };

        #if flixel_animate
        var path = getPath('images/$key', TEXT, library, true);
        #if MODS_ALLOWED
        final modPath = Mods.modFolders((library != null ? '$library/' : '') + 'images/$key');
        if (FileUtil.exists(modPath)) path = modPath;
        #end

        return FlxAnimateFrames.fromAnimate(path, validatedSettings.spritemaps, validatedSettings.metadataJson, validatedSettings.cacheKey,
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
        var path = getPath('images/$key.gif', IMAGE, library, true);
        #if MODS_ALLOWED
        final modPath = Mods.modFolders((library != null ? '$library/' : '') + 'images/$key.gif');
        if (FileUtil.exists(modPath)) path = modPath;
        #end
        return path;
    }

    public static function returnSound(path:Null<String>, key:String, ?library:String, ?beepOnNull:Bool = true):Any {
        #if MODS_ALLOWED
        for (ext in SOUND_EXTS) {
            final modPathTarget = (library != null ? '$library/' : '') + (path != null ? '$path/' : '');
            final rawModPath = Mods.modsSounds(modPathTarget, key, ext);
            final physicalPath = getPhysicalModPath(rawModPath, 'sounds');
            
            if (physicalPath != null) {
                #if FLX_STREAM_SOUND
                if (FlxG.sound.useStreamingForAll) return physicalPath;
                #end
                
                if (!FunkinCache.currentTrackedSounds.exists(rawModPath))
                    FunkinCache.currentTrackedSounds.set(rawModPath, Sound.fromFile(physicalPath));
                    
                FunkinCache.localTrackedAssets.push(rawModPath);
                return FunkinCache.currentTrackedSounds.get(rawModPath);
            }
        }
        
        for (mod in Mods.globalMods) {
            if (mod == Mods.currentModDirectory) continue;
            for (ext in SOUND_EXTS) {
                final target = '$mod/' + (library != null ? '$library/' : '') + (path != null ? '$path/' : '') + '$key.$ext';
                final physicalPath = getPhysicalModPath(Mods.getModPath(target), 'sounds');
                
                if (physicalPath != null) {
                    #if FLX_STREAM_SOUND
                    if (FlxG.sound.useStreamingForAll) return physicalPath;
                    #end
                    
                    if (!FunkinCache.currentTrackedSounds.exists(target))
                        FunkinCache.currentTrackedSounds.set(target, Sound.fromFile(physicalPath));
                        
                    FunkinCache.localTrackedAssets.push(target);
                    return FunkinCache.currentTrackedSounds.get(target);
                }
            }
        }
        #end

        for (ext in SOUND_EXTS) {
            final soundPath = getPath((path != null ? '$path/' : '') + '$key.$ext', SOUND, library);
            if (OpenFlAssets.exists(soundPath)) {
                #if FLX_STREAM_SOUND
                if (FlxG.sound.useStreamingForAll) return soundPath;
                #end
                
                if (!FunkinCache.currentTrackedSounds.exists(soundPath))
                    FunkinCache.currentTrackedSounds.set(soundPath, OpenFlAssets.getSound(soundPath));
                    
                FunkinCache.localTrackedAssets.push(soundPath);
                return FunkinCache.currentTrackedSounds.get(soundPath);
            }
        }

        if (beepOnNull) {
            trace('SOUND NOT FOUND: $key, PATH: $path');
            return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
        }
        return null;
    }
}