package game.scripting;

import game.states.backend.MusicBeatState;
import game.scripting.haxe.ScriptableHelper;

import openfl.utils.Assets as OpenFlAssets;

class HScriptState extends MusicBeatState
{
    public var originalClassName:String = "";
    public var stateName:String = "";
    
    public function new(className:String) {
        this.originalClassName = className;
        
        var parts = className.split(".");
        stateName = parts[parts.length - 1];

        super();
    }

    override function create() {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (stateName != null && stateName != "" && scriptHelper == null) {
            final scriptPaths = ScriptableHelper.collectScriptPaths(stateName, Paths.getStateScripts);
            if (scriptPaths.length > 0)
                scriptHelper = new ScriptableHelper(this, scriptPaths);
        }
        #end

        super.create();

        if (scriptHelper != null) {
            scriptHelper.quickSetOnMenuScripts('this', this);
            scriptHelper.quickCallMenuScript("onCreatePost", []);
        }
    }

    override function destroy() {
        scriptHelper?.destroy();
        super.destroy();
    }
}