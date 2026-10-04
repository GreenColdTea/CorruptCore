package game.backend.system;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.io.Bytes;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.Json;

import flixel.util.FlxColor;

using StringTools;

typedef ModPackJson = {
    var ?name:String;
    var ?description:String;
    var ?color:Array<Int>;
    var ?restart:Bool;
    var ?discordClientID:String;
    var ?version:String;
    var ?dependencies:Array<String>;
    var ?conflicts:Array<String>;
    var ?gameVersion:String;
    var ?runsGlobally:Bool;
}

class Mods
{
    public static final MODS_FOLDER = "contents";
    public static var debugMode:Bool = #if DEBUG_MODS true #else false #end;
    
    public static final ignoreModFolders:Array<String> = [
        'custom_events', 'custom_notetypes', 'data', 'fonts', 
        'images', 'music', 'ndlls', 'scripts', 'songs', 
        'sounds', 'source', 'shaders', 'stages', 'videos'
    ];

    public static var currentModDirectory:String = '';
    public static var globalMods:Array<String> = [];
    public static var enabledMods:Array<String> = [];
    
    public static var zipModsCache:Map<String, Map<String, Bytes>> = [];
    public static var tempExtractedFolders:Array<String> = [];
    public static var activeModsMetadata:Array<ModMetadata> = [];

    private static final _pathRegex = ~/\/+/g;

    inline public static function getModPath(key:String = ''):String
    {
        #if MODS_ALLOWED
        return key.length > 0 ? '$MODS_FOLDER/$key' : MODS_FOLDER;
        #else
        return '';
        #end
    }

    public static function normalizePath(path:String):Null<String> 
    {
        #if MODS_ALLOWED
        if (path == null) return null;
        
        path = _pathRegex.replace(path, "/");
        return path.charCodeAt(0) == '/'.code ? path.substr(1) : path;
        #else
        return path;
        #end
    }

    inline public static function modExists(mod:String):Bool 
    {
        #if MODS_ALLOWED
        final modPath = getModPath(mod);
        return FileSystem.exists(modPath) || FileSystem.exists('$modPath.zip');
        #else
        return false;
        #end
    }

    inline public static function isZipMod(mod:String):Bool
    {
        #if MODS_ALLOWED
        return FileSystem.exists('${getModPath(mod)}.zip');
        #else
        return false;
        #end
    }

    public static function getModFileContent(path:String):Null<Bytes>
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        
        if (currentModDirectory?.length > 0) {
            final content = getFileFromMod(currentModDirectory, path);
            if (content != null) return content;
        }

        for (mod in globalMods) {
            if (mod == currentModDirectory) continue;
            
            final content = getFileFromMod(mod, path);
            if (content != null) return content;
        }
        #end
        return null;
    }

    public static function getFileFromMod(mod:String, path:String):Null<Bytes>
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        
        if (isZipMod(mod))
            return getFileFromZipMod(mod, path);
        
        final filePath = normalizePath('${getModPath(mod)}/$path');
        if (FileSystem.exists(filePath) && !FileSystem.isDirectory(filePath)) 
            return File.getBytes(filePath);
        #end
        
        return null;
    }

    public static function getFileFromZipMod(mod:String, path:String):Null<Bytes>
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        
        if (!zipModsCache.exists(mod) && !loadZipMod(mod))
            return null;
        
        final modCache = zipModsCache.get(mod);
        if (modCache == null) return null;
        
        if (modCache.exists(path)) return modCache.get(path);
        
        final variants = getPathVariants(mod, path);
        for (variant in variants) {
            if (modCache.exists(variant)) {
                if (debugMode) trace('Found file with variant: $variant');
                return modCache.get(variant);
            }
        }

        final fileName = path.split('/').pop();
        if (fileName?.length > 0) {
            for (key => bytes in modCache) {
                if (key == fileName || key.endsWith('/$fileName')) {
                    if (debugMode) trace('Found file by name: $key');
                    return bytes;
                }
            }
        }
        
        if (debugMode) trace('File not found in ZIP: $path');
        #end
        
        return null;
    }

    private static function getPathVariants(mod:String, path:String):Array<String> 
    {
        #if MODS_ALLOWED
        final variants = [
            path,
            '$mod/$path',
            path.toLowerCase(),
            path.toUpperCase()
        ];
        
        if (path.startsWith('$mod/')) 
            variants.push(path.substring(mod.length + 1));
        else 
            variants.push(path.replace('$mod/', ''));

        variants.push(path.replace(' ', '_'));
        variants.push(path.replace('_', ' '));
        
        final unique = new Map<String, Bool>();
        return variants.filter(v -> {
            if (v == null || unique.exists(v)) return false;
            unique.set(v, true);
            return true;
        });
        #else
        return [];
        #end
    }

    public static function loadZipMod(mod:String):Bool
    {
        #if MODS_ALLOWED
        final zipPath = '${getModPath(mod)}.zip';
        if (!FileSystem.exists(zipPath)) return false;
        
        try {
            final input = new haxe.io.BytesInput(File.getBytes(zipPath));
            final entries = Reader.readZip(input);
            final fileMap = new Map<String, Bytes>();
            
            var fileCount = 0;
            for (entry in entries) {
                if (entry.fileName.endsWith("/")) continue;
                
                final normalizedFileName = normalizePath(entry.fileName);
                fileMap.set(normalizedFileName, Reader.unzip(entry));
                fileCount++;
            }
            
            zipModsCache.set(mod, fileMap);
            if (debugMode) trace('ZIP mod $mod loaded successfully with $fileCount files');
            return true;
        } catch (e:Dynamic) {
            if (debugMode) trace('Error loading ZIP mod $mod: $e');
        }
        #end
        return false;
    }

    public static function modFileExists(path:String):Bool
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        
        if (currentModDirectory?.length > 0 && _checkFileExists(currentModDirectory, path))
            return true;

        for (mod in globalMods) {
            if (mod == currentModDirectory) continue;
            if (_checkFileExists(mod, path)) return true;
        }
        #end
        return false;
    }

    private static inline function _checkFileExists(mod:String, path:String):Bool {
        #if MODS_ALLOWED
        if (isZipMod(mod)) {
            if (!zipModsCache.exists(mod)) loadZipMod(mod);
            return zipModsCache.get(mod)?.exists(path) ?? false;
        }
        return FileSystem.exists(normalizePath('${getModPath(mod)}/$path'));
        #else
        return false;
        #end
    }

    public static function modsNdll(key:String):String 
    {
        #if (NDLL_ALLOWED && MODS_ALLOWED)
        final pathToCheck = 'ndlls/$key';

        if (currentModDirectory?.length > 0) {
            final file = _resolveFilePath(currentModDirectory, pathToCheck, 'ndlls');
            if (file != null) return file;
        }

        for (mod in globalMods) {
            if (mod == currentModDirectory) continue;
            final file = _resolveFilePath(mod, pathToCheck, 'ndlls');
            if (file != null) return file;
        }
        return '$MODS_FOLDER/$pathToCheck';
        #else
        return '';
        #end
    }

    private static function _resolveFilePath(mod:String, path:String, category:String = ''):Null<String> {
        final physicalPath = getModPath('$mod/$path');
        if (FileSystem.exists(physicalPath)) return physicalPath;

        if (isZipMod(mod)) {
            final tempPath = extractFileFromZipMod(mod, path, category);
            if (tempPath != null) return tempPath;
        }
        return null;
    }

    public static function modsSounds(path:String, key:String, ?ext:String = null):String 
    {
        return modFolders(normalizePath('$path/$key.${ext ?? Paths.SOUND_EXT}'));
    }

    static public function modFolders(key:String):String 
    {
        #if MODS_ALLOWED
        key = normalizePath(key);
        
        if (currentModDirectory?.length > 0) {
            final physicalPath = getModPath('$currentModDirectory/$key');
            if (FileSystem.exists(physicalPath)) return physicalPath;
            if (isZipMod(currentModDirectory) && _checkFileExists(currentModDirectory, key)) return 'zip://$currentModDirectory/$key';
        }

        for (mod in globalMods) {
            if (mod == currentModDirectory) continue;
            
            final physicalPath = getModPath('$mod/$key');
            if (FileSystem.exists(physicalPath)) return physicalPath;
            if (isZipMod(mod) && _checkFileExists(mod, key)) return 'zip://$mod/$key';
        }
        return '$MODS_FOLDER/$key';
        #else
        return '';
        #end
    }

    static public function extractFileFromZipMod(mod:String, filePath:String, category:String):Null<String> 
    {
        #if MODS_ALLOWED
        final content = getFileFromZipMod(mod, filePath);
        if (content == null) return null;
        
        final tempDir = 'temp/$mod/$category';
        if (!FileSystem.exists(tempDir)) FileSystem.createDirectory(tempDir);
        
        final tempPath = '$tempDir/${filePath.split("/").pop()}';
        File.saveBytes(tempPath, content);
        
        if (!tempExtractedFolders.contains(tempDir))
            tempExtractedFolders.push(tempDir);
        
        return tempPath;
        #else
        return null;
        #end
    }

    public static function getZipModInfo(mod:String):{size:Int, fileCount:Int} {
        #if MODS_ALLOWED
        if (!isZipMod(mod)) return {size: 0, fileCount: 0};

        final zipPath = '${getModPath(mod)}.zip';
        try {
            final bytes = File.getBytes(zipPath);
            final input = new haxe.io.BytesInput(bytes);
            final entries = Reader.readZip(input);
            var fileCount = 0;
            for (entry in entries) if (!entry.fileName.endsWith("/")) fileCount++;
            
            return { size: bytes.length, fileCount: fileCount };
        } catch (e:Dynamic) {
            if (debugMode) trace('Error getting ZIP mod info for $mod: $e');
        }
        #end
        return {size: 0, fileCount: 0};
    }

    public static function deleteZipMod(mod:String):Bool {
        #if MODS_ALLOWED
        final zipPath = '${getModPath(mod)}.zip';
        if (FileSystem.exists(zipPath)) {
            try {
                FileSystem.deleteFile(zipPath);
                if (debugMode) trace('Deleted ZIP file: $zipPath');
                return true;
            } catch (e:Dynamic) {
                trace('Error deleting ZIP file $zipPath: $e');
            }
        }
        #end
        return false;
    }

    public static function clearTempFiles() 
    {
        #if MODS_ALLOWED
        for (tempDir in tempExtractedFolders)
            if (FileSystem.exists(tempDir))
                deleteDirectory(tempDir);
                
        tempExtractedFolders = [];
        zipModsCache.clear();
        #end
    }

    public static function deleteDirectory(path:String) 
    {
        #if MODS_ALLOWED
        if (!FileSystem.exists(path)) return;
        
        for (entry in FileSystem.readDirectory(path)) {
            final entryPath = '$path/$entry';
            if (FileSystem.isDirectory(entryPath)) deleteDirectory(entryPath);
            else FileSystem.deleteFile(entryPath);
        }
        FileSystem.deleteDirectory(path);
        #end
    }

    static public function getGlobalMods():Array<String> return globalMods;

    static public function pushGlobalMods():Array<String> 
    {
        #if MODS_ALLOWED
        globalMods = [];
        enabledMods = [];
        final path = Paths.txt('modsList', false);
        
        if (!FileSystem.exists(path)) return globalMods;

        final list = CoolUtil.coolTextFile(path);
        for (i in list) {
            final dat = i.split("|");
            
            if (dat.length < 2 || dat[1].trim() != "1") continue;
            
            final folder = dat[0].trim();
            enabledMods.push(folder);
            
            final jsonBytes = getFileFromMod(folder, 'pack.json');
            
            if (jsonBytes != null) {
                try {
                    final json:ModPackJson = Json.parse(jsonBytes.toString());
                    if (json.runsGlobally ?? false) globalMods.push(folder);
                } catch (e:Dynamic) {
                    trace('Error parsing global mod json for $folder: $e');
                }
            }
        }
        
        refreshActiveModsMetadata();
        return globalMods;
        #else
        return [];
        #end
    }

    static public function getModDirectories():Array<String> 
    {
        #if MODS_ALLOWED
        final list = [];
        final modsFolder = getModPath();
        if (!FileSystem.exists(modsFolder)) return list;

        for (folder in FileSystem.readDirectory(modsFolder)) {
            final path = haxe.io.Path.join([modsFolder, folder]);
            
            if (FileSystem.isDirectory(path)) {
                if (!ignoreModFolders.contains(folder) && !list.contains(folder)) list.push(folder);
            } else if (folder.endsWith('.zip')) {
                final modName = folder.substr(0, folder.length - 4);
                if (!ignoreModFolders.contains(modName) && !list.contains(modName)) list.push(modName);
            }
        }
        return list;
        #else
        return [];
        #end
    }

    public static function refreshActiveModsMetadata()
    {
        activeModsMetadata = [for (mod in globalMods) if (modExists(mod)) new ModMetadata(mod)];
        updateDiscordClientID();
    }

    public static function getEffectiveDiscordClientID():Null<String>
    {
        for (mod in activeModsMetadata)
            if (mod.discordClientID?.length > 0) return mod.discordClientID;
        return null;
    }

    public static function updateDiscordClientID()
    {
        #if DISCORD_ALLOWED
        final newId = getEffectiveDiscordClientID();
        @:privateAccess {
            if (newId != null && newId != DiscordClient.clientID)
                DiscordClient.clientID = newId;
            else if (newId == null && DiscordClient.clientID != DiscordClient._defaultID)
                DiscordClient.clientID = DiscordClient._defaultID;
        }
        #end
    }
}

class ModMetadata
{
    public final folder:String;
    public var name:String;
    public var description:String;
    public var color:FlxColor;
    public var restart:Bool;
    
    public var alphabet:Alphabet;
    public var icon:AttachedSprite;

    public var discordClientID:Null<String>;
    public var version:Null<String>;
    public var dependencies:Array<String>;
    public var conflicts:Array<String>;
    public var gameVersion:Null<String>;

    #if MODS_ALLOWED
    public function new(folder:String)
    {
        this.folder = folder;
        this.name = folder;
        this.description = "No description provided.";
        this.color = 0xFF665AFF;
        this.restart = false;
        this.dependencies = [];
        this.conflicts = [];

        final jsonBytes = Mods.getFileFromMod(folder, 'pack.json');
        if (jsonBytes == null) return;

        try {
            final rawJson = jsonBytes.toString();
            if (rawJson?.length > 0) {
                final data:ModPackJson = Json.parse(rawJson);
                
                this.name = data.name ?? this.folder;
                this.description = data.description ?? this.description;
                
                if (data.color?.length >= 3)
                    this.color = FlxColor.fromRGB(data.color[0], data.color[1], data.color[2]);
                
                this.restart = data.restart ?? false;
                this.discordClientID = data.discordClientID;
                this.version = data.version;
                this.dependencies = data.dependencies ?? [];
                this.conflicts = data.conflicts ?? [];
                this.gameVersion = data.gameVersion;
            }
        } catch (e:Dynamic) {
            trace('Error parsing pack.json for mod $folder: $e');
        }
    }
    #end
    
    public inline function hasDependency(modName:String):Bool {
        return dependencies.contains(modName);
    }

    public inline function hasConflict(modName:String):Bool {
        return conflicts.contains(modName);
    }

    public function isCompatible(currentGameVersion:String):Bool {
        if (gameVersion == null) return true;
        return gameVersion == currentGameVersion; 
    }
}