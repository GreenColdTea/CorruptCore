package game.substates.backend;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxSubState;

import openfl.filters.BitmapFilter;
import openfl.utils.Assets as OpenFlAssets;

import game.backend.Conductor.BPMChangeEvent;

#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
import game.scripting.FunkinHScript;
import game.scripting.haxe.ScriptableHelper;
#end

class MusicBeatSubstate extends FlxSubState #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES) implements game.backend.interfaces.IScriptable #end
{
    #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
    public var scriptHelper(default, null):ScriptableHelper;
    #end

    public var camSubState:FlxCamera;
    public var useCustomCamera:Bool = false;
    public var freezeParentState:Bool = true;
    public var parentState:MusicBeatState;

    private static var excludeSubStates:Array<Class<MusicBeatSubstate>> = [];

	private static function initExcludeSubStates():Array<Class<MusicBeatSubstate>> {
        return [
			MusicBeatSubstate,
			game.scripting.HScriptSubstate
		];
    }

    public function new()
    {
        super();
        
        parentState = cast FlxG.state;
        initializeSubStateCamera();

		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        excludeSubStates = initExcludeSubStates();
        #end
    }

    private function initializeSubStateCamera():Void
    {
        if (Type.getClass(FlxG.state) == PlayState)
        {
            var playState:PlayState = cast FlxG.state;
            if (playState.camSubState != null)
            {
                camSubState = playState.camSubState;
                this.camera = camSubState;
            }
        }
        
        camSubState ??= cameras?.length > 0 ? cameras[0] : FlxG.camera;
    }

    public function showSubStateCamera():Void
    {
        if (useCustomCamera && camSubState != null)
        {
            camSubState.visible = true;
            camSubState.active = true;
        }
    }

    public function hideSubStateCamera():Void
    {
        if (useCustomCamera && camSubState != null)
        {
            camSubState.visible = false;
            camSubState.active = false;
        }
    }

    public function setSubStateCameraEffects(?filters:Array<BitmapFilter>):Void
    {
        if(camSubState != null) camSubState.filters = filters;
    }

    public function resetSubStateCameraEffects():Void
    {
        if(camSubState != null) camSubState.filters = [];
    }

    private var lastBeat:Float = 0;
    private var lastStep:Float = 0;
    private var curStep:Int = 0;
    private var curBeat:Int = 0;

    private var controls(get, never):Controls;
    inline function get_controls():Controls
        return PlayerSettings.player1.controls;

    override function create()
    {
        if (!freezeParentState)
            parentState.persistentUpdate = parentState.persistentDraw = true;
        
        showSubStateCamera();

		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (!excludeSubStates.contains(Type.getClass(this)))
        {
            final substatePath = Type.getClassName(Type.getClass(this)).split(".");
            final substateString = substatePath[substatePath.length - 1];
            final scriptPaths = ScriptableHelper.collectScriptPaths(substateString, Paths.getSubstateScripts);

            if (scriptPaths.length > 0)
                scriptHelper = new ScriptableHelper(this, scriptPaths);
        }
        #end
        
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onCreate", []);
        #end
        
        super.create();
        
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (scriptHelper != null) {
            scriptHelper.quickSetOnMenuScripts('this', this);
            scriptHelper.quickCallMenuScript("onCreatePost", []);
        }
        #end
    }

    override function update(elapsed:Float)
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onUpdate", [elapsed]);
        #end
        
        final oldStep:Int = curStep;
        if(!persistentUpdate) MusicBeatState.timePassedOnState += elapsed;
        updateCurStep();
        curBeat = Math.floor(curStep / 4);

        if (oldStep != curStep && curStep > 0) stepHit();

        super.update(elapsed);

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onUpdatePost", [elapsed]);
        #end
    }

    override function openSubState(SubState:FlxSubState)
    {
        showSubStateCamera();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onOpenSubState", []);
        #end
        super.openSubState(SubState);
    }

    override function closeSubState()
    {
        hideSubStateCamera();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onCloseSubState", []);
        #end
        super.closeSubState();
    }

    private function updateCurStep():Void
    {
        curStep = Math.floor(Conductor.getStep(Conductor.songPosition - ClientPrefs.noteOffset));
    }

    public function stepHit():Void
    {
        if (curStep % 4 == 0) beatHit();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onStepHit", []);
        #end
    }

    public function beatHit():Void
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onBeatHit", []);
        #end
    }

    override function destroy()
    {
        hideSubStateCamera();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.destroy();
        #end
        super.destroy();
    }

    public function quickCallMenuScript(func:String, ?args:Dynamic):Dynamic {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        return scriptHelper?.quickCallMenuScript(func, args) ?? ScriptResult.Function_Continue;
        #else
        return ScriptResult.Function_Continue;
        #end
    }

    public function quickSetOnMenuScripts(variable:String, arg:Dynamic):Void {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickSetOnMenuScripts(variable, arg);
        #end
    }

    public function callOnMenuScript(event:String, args:Array<Dynamic>, ignoreStops:Bool = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        return scriptHelper?.callOnMenuScript(event, args, ignoreStops, exclusions, excludeValues) ?? ScriptResult.Function_Continue;
        #else
        return ScriptResult.Function_Continue;
        #end
    }
}