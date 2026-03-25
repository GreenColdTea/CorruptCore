#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
package game.scripting.haxe;

import flixel.FlxBasic;

import game.scripting.FunkinHScript;
import game.scripting.ScriptResult;
#if sys
import sys.FileSystem;
#end
import openfl.utils.Assets as OpenFlAssets;

class ScriptableHelper {
    private var owner:FlxBasic;
    public var menuScriptArray:Array<FunkinHScript> = [];

    public function new(owner:FlxBasic, scriptPaths:Array<String>) {
        this.owner = owner;
        for (path in scriptPaths) {
            var script = new FunkinHScript(path, owner);
            menuScriptArray.push(script);
            if (path.contains('${Mods.MODS_FOLDER}/'))
                trace('Loaded mod script: $path');
            else
                trace('Loaded base game script: $path');
        }
    }

    public function quickCallMenuScript(func:String, ?args:Dynamic):Dynamic {
        var returnThing:Dynamic = ScriptResult.Function_Continue;
        for (script in menuScriptArray) {
            var scriptThing = script.call(func, args);
            if (scriptThing == null) continue;
            if (scriptThing == ScriptResult.Function_Stop) returnThing = scriptThing;
        }
        return returnThing;
    }

    public function quickSetOnMenuScripts(variable:String, arg:Dynamic):Void {
        for (script in menuScriptArray) {
            script.set(variable, arg);
        }
    }

    public function callOnMenuScript(event:String, args:Array<Dynamic>, ignoreStops:Bool = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
        var returnVal = ScriptResult.Function_Continue;
        exclusions ??= [];
        excludeValues ??= [];

        for (sc in menuScriptArray) {
            if (exclusions.contains(sc.scriptName)) continue;

            var myValue = sc.call(event, args);
            if (myValue == ScriptResult.Function_Stop_Lua && !ignoreStops) break;
            
            if (myValue != ScriptResult.Function_Continue) returnVal = myValue;
        }
        return returnVal;
    }

    public function destroy():Void {
        for (sc in menuScriptArray) {
            sc.call("onDestroy", []);
            sc.stop();
        }
        menuScriptArray = [];
    }

    public static function collectScriptPaths(name:String, pathGetter:String->Array<String>):Array<String> {
        var folders:Array<String> = pathGetter(name);
        var scriptFiles:Array<String> = [];
        var processedFiles:Map<String, Bool> = new Map();

        for (path in folders) {
            var isDirectory:Bool = false;
            var isFile:Bool = false;

            #if sys
            if (FileSystem.exists(path)) {
                if (FileSystem.isDirectory(path)) {
                    isDirectory = true;
                    for (file in FileSystem.readDirectory(path)) {
                        if (file.endsWith('.hx')) {
                            var fullPath = haxe.io.Path.join([path, file]);
                            if (!processedFiles.exists(fullPath)) {
                                scriptFiles.push(fullPath);
                                processedFiles.set(fullPath, true);
                            }
                        }
                    }
                } else if (path.endsWith('.hx')) {
                    isFile = true;
                    if (!processedFiles.exists(path)) {
                        scriptFiles.push(path);
                        processedFiles.set(path, true);
                    }
                }
            }
            #end

            if (!isDirectory && !isFile) {
                if (OpenFlAssets.exists(path)) {
                    if (path.endsWith('.hx')) {
                        if (!processedFiles.exists(path)) {
                            scriptFiles.push(path);
                            processedFiles.set(path, true);
                        }
                    } else {
                        var prefix = path.endsWith('/') ? path : path + '/';
                        for (file in OpenFlAssets.list(TEXT)) {
                            if (file.startsWith(prefix) && file.endsWith('.hx') && !processedFiles.exists(file)) {
                                scriptFiles.push(file);
                                processedFiles.set(file, true);
                            }
                        }
                    }
                }
            }
        }

        return scriptFiles;
    }
}
#end