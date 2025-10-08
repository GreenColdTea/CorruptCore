package game.scripting;

import flixel.FlxG;
#if sys
import sys.FileSystem;
#end
using StringTools;
using Lambda;

class HScriptGlobal {
    public static var globalScript:FunkinHScript;
    public static var globalScriptActive:Bool = false;
    public static var stateRedirectMap:Map<String, Bool> = new Map();
    
    public static function addGlobalScript() {
        var scriptContent:String = null;
        var scriptPath:String = null;
        
        #if sys
        var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/') #if MODS_ALLOWED , Mods.getModPath('scripts/') #end];
        #if MODS_ALLOWED
        if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) 
            foldersToCheck.insert(0, Mods.getModPath('${Mods.currentModDirectory}/scripts/'));
        for(mod in Mods.getGlobalMods()) 
            foldersToCheck.insert(0, Mods.getModPath('$mod/scripts/states/'));
        #end
        
        for (folder in foldersToCheck) {
            if(FileSystem.exists(folder)) {
                for (file in FileSystem.readDirectory(folder)) {
                    #if HSCRIPT_ALLOWED
                    if (file.endsWith('Global.hx') || file.endsWith('global.hx')) {
                        scriptPath = folder + file;
                        break;
                    }
                    #end
                }
                if (scriptPath != null) break;
            }
        }
        #else
        var resourceNames = haxe.Resource.listNames();
        for (name in resourceNames) {
            if (name.endsWith('_global_hx') || name.endsWith('_Global_hx')) {
                scriptContent = haxe.Resource.getString(name);
                scriptPath = "resource:" + name;
                break;
            }
        }
        #end
        
        if (scriptPath != null || scriptContent != null) {
            #if sys
            globalScript = new FunkinHScript(scriptPath);
            #else
            globalScript = createScriptFromContent(scriptContent, scriptPath);
            #end
            
            globalScriptActive = true;            
            setupGlobalScriptEvents();

            globalScript?.call("onCreatePost", []);
        }
    }
    
    #if !sys
    private static function createScriptFromContent(content:String, path:String):FunkinHScript {
        var script = Type.createEmptyInstance(FunkinHScript);
        script.scriptName = path;
        script.active = true;
        
        script.set("FlxG", flixel.FlxG);
        script.set("Paths", game.Paths);
        script.set("CoolUtil", game.backend.utils.CoolUtil);
        
        try {
            var executeMethod = Reflect.field(script, "execute");
            if (executeMethod != null) {
                Reflect.callMethod(script, executeMethod, [content, false]);
            } else {
                var parser = new HScriptParser();
                parser.allowAll();
                parser.preprocesorValues = FunkinHScript.getHScriptPreprocessors();

                var ruleScript = new rulescript.RuleScript(new FunkinRScript.RuleScriptInterpEx(), parser);
                ruleScript.execute(content);
                
                for (key in ruleScript.variables.keys()) {
                    script.set(key, ruleScript.variables.get(key));
                }
            }
        } catch (e:Dynamic) {
            trace('Failed to execute global script: ${e.message}');
            return null;
        }
        
        return script;
    }
    #end
    
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