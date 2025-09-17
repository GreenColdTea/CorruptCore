package game.scripting;

import rulescript.parsers.HxParser;
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

        rule.parser = new HxParser();
        rule.getParser(HxParser).allowAll();

        var scriptToRun:String = loadScriptContent(path);
        execute(scriptToRun, skipCreate);
    }
}