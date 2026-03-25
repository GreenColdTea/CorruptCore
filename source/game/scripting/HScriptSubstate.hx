package game.scripting;

import game.substates.backend.MusicBeatSubstate;
import game.scripting.haxe.ScriptableHelper;

import openfl.utils.Assets as OpenFlAssets;

class HScriptSubstate extends MusicBeatSubstate
{
    public var originalClassName:String = "";
    public var substateName:String = "";
    
    public function new(className:String) {
        this.originalClassName = className;
        
        var parts = className.split(".");
        substateName = parts[parts.length - 1];

        super();
    }

    override function create() {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (substateName != null && substateName != "" && scriptHelper == null) {
            final scriptPaths = ScriptableHelper.collectScriptPaths(substateName, Paths.getSubstateScripts);
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