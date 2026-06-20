package game.scripting;

class FunkinHScript extends FunkinRuleScript
{
    public function new(path:String, parentInstance:Dynamic = null, skipCreate:Bool = false) {
        super(path, parentInstance, skipCreate, false);

        set("FunkinHScript", FunkinHScript);

        final hxParser = new rulescript.parsers.HxParser();
        rule.parser = hxParser;
        
        hxParser.allowAll();

        final scriptToRun:String = loadScriptContent(path);
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