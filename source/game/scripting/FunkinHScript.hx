package game.scripting;

import game.scripting.HScriptParser as HxParser;
import game.scripting.FunkinRScript.RuleScriptInterpEx as Interp;
#if sys
import sys.io.File;
#end
using StringTools;

class FunkinHScript extends FunkinRScript
{
    public function new(path:String, parentInstance:Dynamic = null, skipCreate:Bool = false) {
        super(path, parentInstance, skipCreate);

        set("FunkinHScript", FunkinHScript);

        var hxParser = new HxParser();
        rule.parser = hxParser;
        
        hxParser.allowAll();
        
        var preprocessors = getHScriptPreprocessors();
        /*trace('HScript Preprocessors for $path:');
        for (key => value in preprocessors) {
            trace('  $key = $value (type: ${Type.typeof(value)})');
        }*/
        
        hxParser.setPreprocessorValues(preprocessors);
        hxParser.setParserParameters({
            strictMode: true,
            requireSemicolons: false,
            reportWarnings: true
        });

        var scriptToRun:String = loadScriptContent(path);
        execute(scriptToRun, skipCreate);
    }

    public function executeString(code:String):Dynamic {
        try {
            rule.execute(code);
            return null;
        } catch (e:Dynamic) {
            if (rule.errorHandler != null)
                rule.errorHandler(e);
            else
                trace('Error in executeString: ${e.message}');
            return null;
        }
    }

    public static dynamic function getHScriptPreprocessors() {
        var preprocessors:Map<String, Dynamic> = new Map();
        
        // I hate my life 💔
        preprocessors.set("mobile", #if mobile true #else false #end);
        preprocessors.set("desktop", #if desktop true #else false #end);
        preprocessors.set("web", #if web true #else false #end);
        preprocessors.set("debug", #if debug true #else false #end);
        preprocessors.set("release", #if !debug true #else false #end);
        
        preprocessors.set("cpp", #if cpp true #else false #end);
        preprocessors.set("hl", #if hl true #else false #end);
        preprocessors.set("neko", #if neko true #else false #end);
        preprocessors.set("js", #if js true #else false #end);
        preprocessors.set("lua", #if lua true #else false #end);
        preprocessors.set("php", #if php true #else false #end);
        preprocessors.set("java", #if java true #else false #end);
        preprocessors.set("cs", #if cs true #else false #end);
        preprocessors.set("python", #if python true #else false #end);
        
        preprocessors.set("windows", #if windows true #else false #end);
        preprocessors.set("mac", #if mac true #else false #end);
        preprocessors.set("linux", #if linux true #else false #end);
        preprocessors.set("html5", #if html5 true #else false #end);
        preprocessors.set("switch", #if switch true #else false #end);
        preprocessors.set("android", #if android true #else false #end);
        preprocessors.set("ios", #if ios true #else false #end);
        
        preprocessors.set("ENGINE_VER", Application.current.meta.get('version'));
        
        preprocessors.set("sys", #if sys true #else false #end);
        preprocessors.set("target.threaded", #if target.threaded true #else false #end);
        preprocessors.set("target.static", #if target.static true #else false #end);
        
        preprocessors.set("haxe4", #if (haxe_ver >= 4.0) true #else false #end);
        preprocessors.set("haxe3", #if (haxe_ver >= 3.0) true #else false #end);
        
        preprocessors.set("MODS_ALLOWED", #if MODS_ALLOWED true #else false #end);
        preprocessors.set("LUA_ALLOWED", #if LUA_ALLOWED true #else false #end);
        preprocessors.set("MODCHART_ALLOWED", #if MODCHART_ALLOWED true #else false #end);
        preprocessors.set("NDLL_ALLOWED", #if NDLL_ALLOWED true #else false #end);
        preprocessors.set("ACHIEVEMENTS_ALLOWED", #if ACHIEVEMENTS_ALLOWED true #else false #end);
        preprocessors.set("VIDEOS_ALLOWED", #if VIDEOS_ALLOWED true #else false #end);
        
        var staticDefines = game.backend.utils.MacroUtil.defines.copy();
        for (key => value in staticDefines) {
            if (!preprocessors.exists(key)) {
                preprocessors.set(key, value);
            }
        }
        
        return preprocessors;
    }
}