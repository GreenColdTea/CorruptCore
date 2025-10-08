package game.backend.system;

#if MODS_ALLOWED
import sys.FileSystem;

import haxe.Json;

import game.Paths;

class Mods
{
    inline public static final MODS_FOLDER = "contents";

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

    inline public static function getModPath(key:String = ''):String
    {
        return '$MODS_FOLDER/$key';
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
        return modFolders('videos/$key.${Paths.VIDEO_EXT}');
    }

    #if NDLL_ALLOWED
    public static function modsNdll(key:String) {
        if(currentModDirectory != null && currentModDirectory.length > 0) {
            var fileToCheck:String = '$MODS_FOLDER/$currentModDirectory/$key';
            if(FileSystem.exists(fileToCheck)) {
                return fileToCheck;
            }
        }

        for(mod in getGlobalMods()) {
            var fileToCheck:String = '$MODS_FOLDER/$mod/$key';
            if(FileSystem.exists(fileToCheck))
                return fileToCheck;

        }
        return '$MODS_FOLDER/' + key;
    }
    #end

    inline static public function modsSounds(path:String, key:String, ?ext:String = null) {
        ext ??= Paths.SOUND_EXT;
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

    static public function modFolders(key:String) {
        if(currentModDirectory != null && currentModDirectory.length > 0) {
            var fileToCheck:String = getModPath(currentModDirectory + '/' + key);
            if(FileSystem.exists(fileToCheck)) {
                return fileToCheck;
            }
        }

        for(mod in getGlobalMods()){
            var fileToCheck:String = getModPath(mod + '/' + key);
            if(FileSystem.exists(fileToCheck))
                return fileToCheck;

        }
        return '$MODS_FOLDER/' + key;
    }

    static public function getGlobalMods()
        return globalMods;

    static public function pushGlobalMods() // prob a better way to do this but idc
    {
        globalMods = [];
        var path:String = Paths.txt('modsList');
        if(FileSystem.exists(path))
        {
            var list:Array<String> = CoolUtil.coolTextFile(path);
            for (i in list)
            {
                var dat = i.split("|");
                if (dat[1] == "1")
                {
                    var folder = dat[0];
                    var path = Mods.getModPath(folder + '/pack.json');
                    if(FileSystem.exists(path)) {
                        try{
                            var rawJson:String = File.getContent(path);
                            if(rawJson != null && rawJson.length > 0) {
                                var stuff:Dynamic = Json.parse(rawJson);
                                var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
                                if(global) globalMods.push(dat[0]);
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
        var modsFolder:String = getModPath();
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
}
#end