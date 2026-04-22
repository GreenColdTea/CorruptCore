package game.scripting;

import game.scripting.RuleScriptParserEx as HxParser;
import game.scripting.RuleScriptInterpEx as Interp;
#if sys
import sys.io.File;
#end
using StringTools;

class FunkinHScript extends FunkinRuleScript
{
    public function new(path:String, parentInstance:Dynamic = null, skipCreate:Bool = false) {
        super(path, parentInstance, skipCreate);

        set("FunkinHScript", FunkinHScript);

        var hxParser = new HxParser();
        rule.parser = hxParser;
        
        hxParser.allowAll();
        
        hxParser.setParserParameters({
            strictMode: true,
            reportWarnings: true
        });
        hxParser.scriptPath = path;

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
}