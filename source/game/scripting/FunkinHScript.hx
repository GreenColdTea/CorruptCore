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
        scriptType = "HScript";

        set("FunkinHScript", FunkinHScript);

        var hxParser = new HxParser();
        rule.parser = hxParser;
        
        hxParser.allowAll();
        hxParser.setPreprocessorValues(getHScriptPreprocessors());
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
        
        preprocessors.set("mobile", #if mobile true #else false #end);
        preprocessors.set("ENGINE_VER", Application.current.meta.get('version'));
        
        var staticDefines = game.backend.utils.MacroUtil.defines;
        for (key => value in staticDefines) {
            if (!preprocessors.exists(key)) {
                preprocessors.set(key, value);
            }
        }
        
        return preprocessors;
    }
}