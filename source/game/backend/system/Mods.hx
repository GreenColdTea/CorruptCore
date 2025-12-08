package game.backend.system;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.io.Bytes;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.Json;

import game.Paths;

class Mods
{
    @:unreflective
    inline public static final MODS_FOLDER = "contents";
    
    public static var debugMode:Bool = #if DEBUG_MODS true #else false #end;
    
    public static var ignoreModFolders:Array<String> = [
        'characters',
        'custom_events',
        'custom_notetypes',
        'data',
        'fonts',
        'images',
        'music',
        'ndlls',
        'scripts',
        'songs',
        'sounds',
        'source',
        'shaders',
        'stages',
        'videos',
        'weeks',
    ];

    public static var currentModDirectory:String = '';
    public static var globalMods:Array<String> = [];
    
    public static var zipModsCache:Map<String, Map<String, Bytes>> = new Map();
    public static var tempExtractedFolders:Array<String> = [];

    inline public static function getModPath(key:String = ''):String
    {
        #if MODS_ALLOWED
        return '$MODS_FOLDER/$key';
        #else
        return '';
        #end
    }

    public static function normalizePath(path:String):String {
        #if MODS_ALLOWED
        if (path == null) return path;

        while (path.indexOf("//") != -1) {
            path = path.replace("//", "/");
        }
        if (path.startsWith("/")) {
            path = path.substr(1);
        }
        #end

        return path;
    }

    public static function modExists(mod:String):Bool {
        #if MODS_ALLOWED
        var modPath = getModPath(mod);
        return FileSystem.exists(modPath) || FileSystem.exists('$modPath.zip');
        #else
        return false;
        #end
    }

    public static function isZipMod(mod:String):Bool
    {
        #if MODS_ALLOWED
        var modPath = getModPath(mod);
        return FileSystem.exists('$modPath.zip');
        #else
        return false;
        #end
    }

    public static function getModFileContent(path:String):Null<Bytes>
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        
        if (currentModDirectory != null && currentModDirectory.length > 0) {
            var content = getFileFromMod(currentModDirectory, path);
            if (content != null) return content;
        }

        for (mod in getGlobalMods()) {
            var content = getFileFromMod(mod, path);
            if (content != null) return content;
        }
        #end
        
        return null;
    }

    public static function getFileFromMod(mod:String, path:String):Null<Bytes>
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        var modPath = getModPath(mod);
        
        if (isZipMod(mod)) {
            return getFileFromZipMod(mod, path);
        }
        
        var filePath = normalizePath('$modPath/$path');
        if (FileSystem.exists(filePath) && !FileSystem.isDirectory(filePath)) {
            return File.getBytes(filePath);
        }
        #end
        
        return null;
    }

    public static function getFileFromZipMod(mod:String, path:String):Null<Bytes>
    {
        #if MODS_ALLOWED
        path = normalizePath(path);
        var zipPath = '${getModPath(mod)}.zip';
        
        if (!zipModsCache.exists(mod)) {
            if (!loadZipMod(mod)) {
                return null;
            }
        }
        
        var modCache = zipModsCache.get(mod);
        if (modCache == null) return null;
        
        if (modCache.exists(path)) {
            return modCache.get(path);
        }
        
        var pathVariants = getPathVariants(mod, path);
        
        for (variant in pathVariants) {
            variant = normalizePath(variant);
            if (modCache.exists(variant)) {
                if (debugMode) trace('Found file with variant: $variant (original: $path)');
                return modCache.get(variant);
            }
        }

        var fileName = path.split('/').pop();
        if (fileName != null && fileName.length > 0) {
            for (key in modCache.keys()) {
                if (key.endsWith('/' + fileName) || key == fileName) {
                    if (debugMode) trace('Found file by name: $key (looking for: $path)');
                    return modCache.get(key);
                }
            }
        }
        
        if (debugMode) {
            trace('File not found in ZIP: $path');
            trace('Tried variants: $pathVariants');
            trace('Available files in mod $mod:');
            
            var allKeys = [for (key in modCache.keys()) key];
            var totalFileCount = allKeys.length;
            
            var relevantFiles = [];
            for (key in allKeys) {
                if (key.toLowerCase().indexOf(path.toLowerCase()) != -1 || 
                    path.toLowerCase().indexOf(key.toLowerCase()) != -1 ||
                    key.indexOf(mod) != -1 ||
                    (fileName != null && key.endsWith('/' + fileName))) {
                    relevantFiles.push(key);
                }
            }
            
            if (relevantFiles.length > 0) {
                for (key in relevantFiles) {
                    trace('  $key');
                }
            } else {
                var maxFiles = Std.int(Math.min(20, totalFileCount));
                for (i in 0...maxFiles) {
                    trace('  ${allKeys[i]}');
                }
                if (totalFileCount > 20) {
                    trace('  ... and ${totalFileCount - 20} more files');
                }
            }
        }
        #end
        
        return null;
    }

    private static function getPathVariants(mod:String, path:String):Array<String> {
        #if MODS_ALLOWED
        var variants = [
            path,
            '$mod/$path',
            path.toLowerCase(),
            path.toUpperCase(),
            path.startsWith('$mod/') ? path.substring(mod.length + 1) : path,
            path.replace('$mod/', ''),
            path.replace(' ', '_'),
            path.replace('_', ' ')
        ];
        
        /*if (path.startsWith("songs/")) {
            var songPath = path.substring(6);
            variants.push('$mod/songs/$songPath');
            variants.push('songs/$mod/$songPath');
            variants.push(songPath);
            variants.push('data/$songPath');
            variants.push('$mod/data/$songPath');
        }
        
        if (path.startsWith("data/")) {
            var dataPath = path.substring(5);
            variants.push('$mod/data/$dataPath');
            variants.push('data/$mod/$dataPath');
            variants.push(dataPath);
            
            if (dataPath.endsWith('.json')) {
                variants.push('songs/${dataPath.replace(".json", "")}/$dataPath');
                variants.push('$mod/songs/${dataPath.replace(".json", "")}/$dataPath');
            }
        }
        
        if (path.startsWith("images/")) {
            var imagePath = path.substring(7);
            variants.push('$mod/images/$imagePath');
            variants.push('images/$mod/$imagePath');
            variants.push(imagePath);
        }
        
        if (path.startsWith("music/")) {
            var musicPath = path.substring(6);
            variants.push('$mod/music/$musicPath');
            variants.push('music/$mod/$musicPath');
            variants.push('sounds/$musicPath');
            variants.push('$mod/sounds/$musicPath');
            variants.push(musicPath);
        }
        
        if (path.startsWith("sounds/")) {
            var soundPath = path.substring(7);
            variants.push('$mod/sounds/$soundPath');
            variants.push('sounds/$mod/$soundPath');
            variants.push('music/$soundPath');
            variants.push('$mod/music/$soundPath');
            variants.push(soundPath);
        }*/
        
        var uniqueVariants = new Map<String, Bool>();
        var result = [];
        for (v in variants) {
            if (v != null && !uniqueVariants.exists(v)) {
                uniqueVariants.set(v, true);
                result.push(v);
            }
        }
        return result;
        #else
        return [];
        #end
    }

    public static function loadZipMod(mod:String):Bool
    {
        #if MODS_ALLOWED
        var zipPath = '${getModPath(mod)}.zip';
        
        if (!FileSystem.exists(zipPath)) {
            if (debugMode) trace('ZIP mod not found: $zipPath');
            return false;
        }
        
        try {
            var bytes = File.getBytes(zipPath);
            var input = new haxe.io.BytesInput(bytes);
            var entries:List<Entry> = Reader.readZip(input);
            var fileMap:Map<String, Bytes> = new Map();
            
            if (debugMode) trace('Loading ZIP mod: $mod');
            var fileCount:Int = 0;
            
            var hasModFolder = false;
            var rootFiles = new Map<String, Bool>();
            
            for (entry in entries) {
                var fileName = entry.fileName;
                if (!fileName.endsWith("/")) {
                    var data = Reader.unzip(entry);
                    var normalizedFileName = normalizePath(fileName);
                    fileMap.set(normalizedFileName, data);
                    fileCount++;
                    
                    if (normalizedFileName.startsWith('$mod/')) {
                        hasModFolder = true;
                    }
                    
                    var firstSlash = normalizedFileName.indexOf("/");
                    if (firstSlash == -1) {
                        rootFiles.set(normalizedFileName, true);
                    } else {
                        var rootFolder = normalizedFileName.substring(0, firstSlash);
                        rootFiles.set(rootFolder, true);
                    }
                }
            }
            
            zipModsCache.set(mod, fileMap);
            if (debugMode) {
                trace('ZIP mod $mod loaded successfully with $fileCount files');
                trace('ZIP structure analysis:');
                trace('  - Has mod folder structure: $hasModFolder');
                var rootKeys = [for (k in rootFiles.keys()) k];
                trace('  - Root folders/files: [${rootKeys.join(", ")}]');
            }
            return true;
        } catch (e:Dynamic) {
            if (debugMode) trace('Error loading ZIP mod $mod: $e');
        }
        #end

        return false;
    }

    public static function modFileExists(path:String):Bool
    {
        return getModFileContent(path) != null;
    }

    #if SCRIPTABLE_STATES
    public static function modsStates(key:String, state:String)
        return modFolders('scripts/states/$state/$key.hx');
    #end

    public static function modsFont(key:String) {
        return modFolders('fonts/$key');
    }

    public static function modsJson(key:String) {
        return modFolders('data/$key.json');
    }

    public static function modsVideo(key:String, ext:String) {
        return modFolders('videos/$key.$ext');
    }

    public static function modsNdll(key:String) {
        #if (NDLL_ALLOWED && MODS_ALLOWED)
        if (currentModDirectory != null && currentModDirectory.length > 0) {
            var fileToCheck:String = getModPath(currentModDirectory + '/ndlls/$key');
            if (FileSystem.exists(fileToCheck)) {
                return fileToCheck;
            }
            
            if (isZipMod(currentModDirectory)) {
                var tempPath = extractFileFromZipMod(currentModDirectory, 'ndlls/$key', 'ndlls');
                if (tempPath != null) return tempPath;
            }
        }

        for (mod in getGlobalMods()) {
            var fileToCheck:String = getModPath(mod + '/ndlls/$key');
            if (FileSystem.exists(fileToCheck))
                return fileToCheck;

            if (isZipMod(mod)) {
                var tempPath = extractFileFromZipMod(mod, 'ndlls/$key', 'ndlls');
                if (tempPath != null) return tempPath;
            }
        }
        return '$MODS_FOLDER/ndlls/' + key;
        #else
        return '';
        #end
    }

    public static function modsSounds(path:String, key:String, ?ext:String = null) {
        if (ext == null) ext = Paths.SOUND_EXT;
        var fullPath = normalizePath('$path/$key.$ext');
        return modFolders(fullPath);
    }

    public static function modsImages(key:String, ?imgFormat:String = "png") {
        return modFolders('images/$key.$imgFormat');
    }

    public static function modsImagesJson(key:String) {
        return modFolders('images/$key.json');
    }

    public static function modsXml(key:String) {
        return modFolders('images/$key.xml');
    }

    public static function modsTxt(key:String) {
        return modFolders('images/$key.txt');
    }

    public static function modsShaderFragment(key:String, ?library:String)
    {
        return modFolders('shaders/$key.frag');
    }
    
    public static function modsShaderVertex(key:String, ?library:String)
    {
        return modFolders('shaders/$key.vert');
    }

    static public function modFolders(key:String) {
        #if MODS_ALLOWED
        key = normalizePath(key);
        
        if (currentModDirectory != null && currentModDirectory.length > 0) {
            var fileToCheck:String = getModPath(currentModDirectory + '/' + key);
            
            if (FileSystem.exists(fileToCheck)) {
                return fileToCheck;
            }
            
            if (isZipMod(currentModDirectory) && modFileExists(key)) {
                return 'zip://$currentModDirectory/$key';
            }
        }

        for (mod in getGlobalMods()) {
            var fileToCheck:String = getModPath(mod + '/' + key);
            if (FileSystem.exists(fileToCheck))
                return fileToCheck;

            if (isZipMod(mod) && getFileFromMod(mod, key) != null) {
                return 'zip://$mod/$key';
            }
        }
        return '$MODS_FOLDER/' + key;
        #else
        return '';
        #end
    }

    static public function extractFileFromZipMod(mod:String, filePath:String, category:String):String {
        #if MODS_ALLOWED
        filePath = normalizePath(filePath);
        var content = getFileFromZipMod(mod, filePath);
        if (content == null) return null;
        
        var tempDir = 'temp/$mod/$category';
        if (!FileSystem.exists(tempDir)) {
            FileSystem.createDirectory(tempDir);
        }
        
        var fileName = filePath.split('/').pop();
        var tempPath = '$tempDir/$fileName';
        
        File.saveBytes(tempPath, content);
        tempExtractedFolders.push(tempDir);
        
        return tempPath;
        #else
        return '';
        #end
    }

    public static function extractZipMod(mod:String):Bool {
        #if MODS_ALLOWED
        if (!isZipMod(mod)) {
            if (debugMode) trace('Mod $mod is not a ZIP mod or does not exist');
            return false;
        }

        var zipPath = '${getModPath(mod)}.zip';
        var extractPath = getModPath(mod);

        if (FileSystem.exists(extractPath)) {
            if (debugMode) trace('Extraction path already exists: $extractPath');
            return false;
        }

        try {
            FileSystem.createDirectory(extractPath);

            var bytes = File.getBytes(zipPath);
            var input = new haxe.io.BytesInput(bytes);
            var entries:List<Entry> = Reader.readZip(input);
            var extractedFiles = 0;

            if (debugMode) trace('Extracting ZIP mod: $mod to $extractPath');

            var hasRootFolder = true;
            var rootFolderName = null;
            
            for (entry in entries) {
                var fileName = entry.fileName;
                var parts = fileName.split('/');
                
                if (rootFolderName == null && parts.length > 0 && parts[0] != '') {
                    rootFolderName = parts[0];
                }
                
                if (parts.length == 1 && !fileName.endsWith('/')) {
                    hasRootFolder = false;
                    break;
                }
            }

            if (hasRootFolder && rootFolderName != null && rootFolderName == mod) {
                if (debugMode) trace('ZIP has root folder matching mod name, stripping it: $rootFolderName');
            } else {
                hasRootFolder = false;
                if (debugMode) trace('ZIP does not have matching root folder, extracting as-is');
            }

            for (entry in entries) {
                var fileName = entry.fileName;
                
                if (fileName.endsWith("/")) continue;

                var targetFileName = fileName;
                
                if (hasRootFolder && rootFolderName != null) {
                    if (fileName.startsWith(rootFolderName + '/')) {
                        targetFileName = fileName.substring(rootFolderName.length + 1);
                    }
                }

                var fullPath = extractPath + "/" + targetFileName;
                
                var dirPath = haxe.io.Path.directory(fullPath);
                if (!FileSystem.exists(dirPath))
                    FileSystem.createDirectory(dirPath);
                
                var data = Reader.unzip(entry);
                File.saveBytes(fullPath, data);
                extractedFiles++;

                if (debugMode && extractedFiles % 10 == 0) {
                    trace('  Extracted $extractedFiles files...');
                }
            }

            zipModsCache.remove(mod);

            trace('Successfully extracted mod $mod: $extractedFiles files');
            return true;

        } catch (e:Dynamic) {
            trace('Error extracting ZIP mod $mod: $e');
            
            try {
                if (FileSystem.exists(extractPath)) {
                    deleteDirectory(extractPath);
                }
            } catch (cleanupError:Dynamic) {
                trace('Error cleaning up after failed extraction: $cleanupError');
            }
        }
        #end

        return false;
    }

    public static function getZipModInfo(mod:String):{size:Int, fileCount:Int} {
        #if MODS_ALLOWED
        if (!isZipMod(mod)) {
            return {size: 0, fileCount: 0};
        }

        var zipPath = '${getModPath(mod)}.zip';
        
        try {
            var bytes = File.getBytes(zipPath);
            var input = new haxe.io.BytesInput(bytes);
            var entries:List<Entry> = Reader.readZip(input);
            
            var fileCount = 0;
            for (entry in entries) {
                if (!entry.fileName.endsWith("/")) {
                    fileCount++;
                }
            }
            
            return {
                size: bytes.length,
                fileCount: fileCount
            };
        } catch (e:Dynamic) {
            if (debugMode) trace('Error getting ZIP mod info for $mod: $e');
        }
        #end

        return {size: 0, fileCount: 0};
    }

    public static function clearTempFiles() {
        #if MODS_ALLOWED
        for (tempDir in tempExtractedFolders) {
            if (FileSystem.exists(tempDir)) {
                deleteDirectory(tempDir);
            }
        }
        tempExtractedFolders = [];
        zipModsCache.clear();
        #end
    }

    public static function deleteDirectory(path:String) {
        #if MODS_ALLOWED
        if (FileSystem.exists(path)) {
            for (entry in FileSystem.readDirectory(path)) {
                var entryPath = path + "/" + entry;
                if (FileSystem.isDirectory(entryPath)) {
                    deleteDirectory(entryPath);
                } else {
                    FileSystem.deleteFile(entryPath);
                }
            }
            FileSystem.deleteDirectory(path);
        }
        #end
    }

    public static function deleteZipMod(mod:String):Bool {
        #if MODS_ALLOWED
        var zipPath = '${getModPath(mod)}.zip';
        if (FileSystem.exists(zipPath)) {
            try {
                FileSystem.deleteFile(zipPath);
                if (debugMode) trace('Deleted ZIP file: $zipPath');
                return true;
            } catch (e:Dynamic) {
                trace('Error deleting ZIP file $zipPath: $e');
                return false;
            }
        }
        #end
        return false;
    }

    static public function getGlobalMods()
        return globalMods;

    static public function pushGlobalMods():Array<String> {
        #if MODS_ALLOWED
        globalMods = [];
        var path:String = Paths.txt('modsList');
        if (FileSystem.exists(path)) {
            var list:Array<String> = CoolUtil.coolTextFile(path);
            for (i in list) {
                var dat = i.split("|");
                if (dat[1] == "1") {
                    var folder = dat[0];
                    var jsonPath = Mods.getModPath(folder + '/pack.json');
                    var zipJsonPath = '${Mods.getModPath(folder)}.zip';
                    
                    var packJsonContent:Null<Bytes> = null;
                    
                    if (FileSystem.exists(jsonPath)) {
                        packJsonContent = File.getBytes(jsonPath);
                    } else if (FileSystem.exists(zipJsonPath)) {
                        packJsonContent = getFileFromZipMod(folder, 'pack.json');
                    }
                    
                    if (packJsonContent != null) {
                        try {
                            var rawJson:String = packJsonContent.toString();
                            if (rawJson != null && rawJson.length > 0) {
                                var stuff:Dynamic = Json.parse(rawJson);
                                var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
                                if (global) globalMods.push(dat[0]);
                            }
                        } catch (e:Dynamic) {
                            trace(e);
                        }
                    }
                }
            }
        }
        return globalMods;
        #else
        return [];
        #end
    }

    static public function getModDirectories():Array<String> {
        #if MODS_ALLOWED
        var list:Array<String> = [];
        var modsFolder:String = getModPath();
        if (FileSystem.exists(modsFolder)) {
            for (folder in FileSystem.readDirectory(modsFolder)) {
                var path = haxe.io.Path.join([modsFolder, folder]);
                
                if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder)) {
                    list.push(folder);
                } else if (folder.endsWith('.zip')) {
                    var modName = folder.substr(0, folder.length - 4);
                    if (!ignoreModFolders.contains(modName) && !list.contains(modName)) {
                        list.push(modName);
                    }
                }
            }
        }
        return list;
        #else
        return [];
        #end
    }

    public static function debugZipMod(mod:String):Void {
        #if MODS_ALLOWED
        if (!isZipMod(mod)) {
            trace('$mod is not a ZIP mod');
            return;
        }
        
        if (!zipModsCache.exists(mod)) {
            loadZipMod(mod);
        }
        
        var modCache = zipModsCache.get(mod);
        if (modCache == null) {
            trace('Failed to load ZIP mod: $mod');
            return;
        }
        
        trace('=== DEBUG ZIP MOD: $mod ===');
        
        var allKeys = [for (key in modCache.keys()) key];
        var totalFileCount = allKeys.length;
        
        for (key in allKeys) {
            trace('  $key (${modCache.get(key).length} bytes)');
        }
        
        trace('Total files: $totalFileCount');
        trace('=== END DEBUG ===');
        #end
    }

    public static function analyzeZipStructure(mod:String):Void {
        #if MODS_ALLOWED
        if (!isZipMod(mod)) {
            trace('$mod is not a ZIP mod');
            return;
        }
        
        if (!zipModsCache.exists(mod)) {
            loadZipMod(mod);
        }
        
        var modCache = zipModsCache.get(mod);
        if (modCache == null) {
            trace('Failed to load ZIP mod: $mod');
            return;
        }
        
        var allKeys = [for (key in modCache.keys()) key];
        
        trace('=== ZIP STRUCTURE ANALYSIS: $mod ===');
        
        var fileTypes = new Map<String, Int>();
        var folders = new Map<String, Int>();
        
        for (key in allKeys) {
            var parts = key.split('/');
            var fileName = parts.pop();
            var extension = fileName.split('.').pop().toLowerCase();

            if (!fileTypes.exists(extension)) fileTypes.set(extension, 0);
            fileTypes.set(extension, fileTypes.get(extension) + 1);
            
            for (i in 0...parts.length) {
                var folderPath = parts.slice(0, i + 1).join('/');
                if (!folders.exists(folderPath)) {
                    folders.set(folderPath, 0);
                }
                folders.set(folderPath, folders.get(folderPath) + 1);
            }
        }
        
        trace('File types:');
        for (ext in fileTypes.keys()) {
            trace('  .$ext: ${fileTypes.get(ext)} files');
        }
        
        trace('Folder structure:');
        var folderList = [for (f in folders.keys()) f];
        folderList.sort(function(a, b) return a.length - b.length);
        for (folder in folderList) {
            trace('  $folder/ (${folders.get(folder)} files)');
        }
        
        var hasModFolder = false;
        for (key in allKeys) {
            if (key.startsWith('$mod/')) {
                hasModFolder = true;
                break;
            }
        }
        trace('Has mod folder structure: $hasModFolder');
        
        trace('=== END ANALYSIS ===');
        #end
    }
}

class ModMetadata
{
    public var folder:String;
    public var name:String;
    public var description:String;
    public var color:FlxColor;
    public var restart:Bool;
    public var alphabet:Alphabet;
    public var icon:AttachedSprite;

    #if MODS_ALLOWED
    public function new(folder:String)
    {
        this.folder = folder;
        this.name = folder;
        this.description = "No description provided.";
        this.color = ModsMenuState.defaultColor;
        this.restart = false;

        var jsonBytes:Bytes = Mods.getFileFromMod(folder, 'pack.json');
        if(jsonBytes != null) {
            try {
                var rawJson:String = jsonBytes.toString();
                if(rawJson != null && rawJson.length > 0) {
                    var stuff:Dynamic = Json.parse(rawJson);
                    
                    var colors:Array<Int> = Reflect.getProperty(stuff, "color");
                    var description:String = Reflect.getProperty(stuff, "description");
                    var name:String = Reflect.getProperty(stuff, "name");
                    var restart:Bool = Reflect.getProperty(stuff, "restart");

                    if(name != null && name.length > 0)
                    {
                        this.name = name;
                    }
                    if(description != null && description.length > 0)
                    {
                        this.description = description;
                    }
                    if(name == 'Name')
                    {
                        this.name = folder;
                    }
                    if(description == 'Description')
                    {
                        this.description = "No description provided.";
                    }
                    if(colors != null && colors.length > 2)
                    {
                        this.color = FlxColor.fromRGB(colors[0], colors[1], colors[2]);
                    }

                    this.restart = restart;
                }
            } catch(e:Dynamic) {
                trace('Error parsing pack.json for mod $folder: $e');
            }
        }
    }
    #end
}