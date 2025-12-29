package game.scripting;

import flixel.FlxG;
#if sys
import sys.FileSystem;
#end
import openfl.utils.Assets as OpenFlAssets;
using StringTools;
using Lambda;

class HScriptGlobal {
    public static var globalScript:FunkinHScript;
    public static var globalScriptActive:Bool = false;
    public static var stateRedirectMap:Map<String, Bool> = new Map();
    
    public static function addGlobalScript() {
        var scriptPath:String = null;
        var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/')];
        
        #if MODS_ALLOWED
        foldersToCheck.insert(0, Mods.getModPath('data/'));
        if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) 
            foldersToCheck.insert(0, Mods.getModPath('${Mods.currentModDirectory}/data/'));
        for(mod in Mods.getGlobalMods()) 
            foldersToCheck.insert(0, Mods.getModPath('$mod/data/'));
        #end
        
        for (folder in foldersToCheck) {
            #if sys
            if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
                for (file in FileSystem.readDirectory(folder)) {
                    var fullPath = haxe.io.Path.join([folder, file]);
                    if (!FileSystem.isDirectory(fullPath)) {
                        #if HSCRIPT_ALLOWED
                        if (file.toLowerCase() == 'global.hx') {
                            scriptPath = fullPath;
                            break;
                        }
                        #end
                    }
                }
                if (scriptPath != null) break;
            }
            #end

            var possiblePaths:Array<String> = [
                folder + "Global.hx",
                folder + "global.hx"
            ];
            
            for (path in possiblePaths) {
                if (OpenFlAssets.exists(path)) {
                    scriptPath = path;
                    break;
                }
            }
            if (scriptPath != null) break;
        }
        
        if (scriptPath != null) {
            globalScript = new FunkinHScript(scriptPath);
            globalScriptActive = true;            
            setupGlobalScriptEvents();
            globalScript?.call("onCreatePost", []);
        }
    }
    
    private static function setupGlobalScriptEvents():Void {
        FlxG.signals.postGameStart.add(() -> globalScript?.call("onGameStart", []));
        FlxG.signals.preGameReset.add(() -> globalScript?.call("onGameReset", []));
        FlxG.signals.postGameReset.add(() -> globalScript?.call("onGameResetPost", []));
        FlxG.signals.preStateSwitch.add(() -> globalScript?.call("onStateSwitch", []));
        FlxG.signals.postStateSwitch.add(() -> globalScript?.call("onStateSwitchPost", []));
        FlxG.signals.preStateCreate.add((state:flixel.FlxState) -> globalScript?.call("onStateCreate", [state]));
        FlxG.signals.preDraw.add(() -> globalScript?.call("onDraw", []));
        FlxG.signals.postDraw.add(() -> globalScript?.call("onDrawPost", []));
        FlxG.signals.preUpdate.add(() -> globalScript?.call("onUpdate", [flixel.FlxG.elapsed]));
        FlxG.signals.postUpdate.add(() -> globalScript?.call("onUpdatePost", [flixel.FlxG.elapsed]));
        FlxG.signals.focusGained.add(() -> globalScript?.call("onFocusGained", []));
        FlxG.signals.focusLost.add(() -> globalScript?.call("onFocusLost", []));
        FlxG.signals.gameResized.add((w:Int, h:Int) -> globalScript?.call("onGameResized", [w, h]));
    }
    
    public static function setSoftcodedState(stateClassName:String, value:Bool):Void {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (globalScriptActive && globalScript != null) {
            callGlobalScript("setSoftcodedState", [stateClassName, value]);
        }
        #end
    }
    
    public static function callGlobalScript(callback:String, args:Array<Dynamic>):Dynamic {
        if(globalScriptActive) return globalScript?.call(callback, args);
        return null;
    }
    
    public static function destroyModScript() {
        if(globalScriptActive) {
            globalScript?.call("onDestroy", []);
            globalScript?.stop();
            globalScript = null;
            
            globalScriptActive = false;
        }
    }
}