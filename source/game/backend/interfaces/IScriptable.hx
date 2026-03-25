package game.backend.interfaces;

interface IScriptable {
    public var scriptHelper(default, null):game.scripting.haxe.ScriptableHelper;
    
    public function quickCallMenuScript(func:String, ?args:Dynamic):Dynamic;
    public function quickSetOnMenuScripts(variable:String, arg:Dynamic):Void;
    public function callOnMenuScript(event:String, args:Array<Dynamic>, ignoreStops:Bool = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic;
}