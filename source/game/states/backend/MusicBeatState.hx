package game.states.backend;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.addons.transition.Transition;
import flixel.math.FlxRect;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxTimer;

import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;

import game.backend.Conductor.BPMChangeEvent;
import game.backend.FunkinCamera;

#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
import game.scripting.FunkinHScript;
import game.scripting.FunkinRuleScript;
import game.scripting.HScriptGlobal;
import game.scripting.haxe.ScriptableHelper;
#end

class MusicBeatState extends FlxTransitionableState #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES) implements game.backend.interfaces.IScriptable #end
{
    #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
    public var scriptHelper(default, null):ScriptableHelper;
    #end

    private var curSection:Int = 0;
    private var stepsToDo:Int = 0;

    private var curStep:Int = 0;
    private var curBeat:Int = 0;

    private var curDecStep:Float = 0;
    private var curDecBeat:Float = 0;
    private var controls(get, never):Controls;

    inline function get_controls():Controls
        return PlayerSettings.player1.controls;

    var _FunkinCameraInitialized:Bool = false;

    public static var timePassedOnState:Float = 0;

    private var excludeStates:Array<Class<MusicBeatState>> = [];

    private static function initExcludeStates():Array<Class<MusicBeatState>> {
        return [
            game.PlayState, 
            game.scripting.HScriptState, 
            MusicBeatState,
            game.states.editors.CharacterEditorState,
            game.states.editors.ChartEditorState,
            game.states.editors.DialogueCharacterEditorState,
            game.states.editors.DialogueEditorState,
            game.states.editors.MasterEditorMenu,
            game.states.editors.MenuCharacterEditorState,
            game.states.editors.WeekEditorState,
        ];
    }

    public function isSoftcodedState():Bool
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES && GLOBAL_SCRIPTS)
        if (HScriptGlobal.globalScriptActive && HScriptGlobal.globalScript != null)
        {
            var result = HScriptGlobal.callGlobalScript("isStateSoftcoded", [Type.getClassName(Type.getClass(this))]);
            if (result != null && Std.isOfType(result, Bool))
                return result;
        }
        #end
        return false;
    }

    public function new() {
        super();

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        excludeStates = initExcludeStates();
        #end
    }

    override function create() {
        if(!_FunkinCameraInitialized) initFunkinCamera();

        var index = ['Deutranopia', 'Protanopia', 'Tritanopia', 'Protanomaly', 'Deuteranomaly', 'Tritanomaly', 'Rod monochromacy', 'Cone monochromacy'].indexOf(ClientPrefs.colorBlindMode);
		Main.updateColorblindFilter(index, ClientPrefs.colorBlindIntensity);

        timePassedOnState = 0;

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (!excludeStates.contains(Type.getClass(this)))
        {
            final statePath = Type.getClassName(Type.getClass(this)).split(".");
            final stateString = statePath[statePath.length - 1];
            final scriptPaths = ScriptableHelper.collectScriptPaths(stateString, Paths.getStateScripts);

            if (scriptPaths.length > 0)
                scriptHelper = new ScriptableHelper(this, scriptPaths);
        }
        #end

        super.create();

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (scriptHelper != null) {
            scriptHelper.quickSetOnMenuScripts('this', this);
            scriptHelper.quickCallMenuScript("onCreatePost", []);
        }
        #end
    }

    public function initFunkinCamera():FunkinCamera
    {
        final camera = new FunkinCamera();
        FlxG.cameras.reset(camera);
        FlxG.cameras.setDefaultDrawTarget(camera, true);
        _FunkinCameraInitialized = true;
        return camera;
    }

    override function update(elapsed:Float)
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onUpdate", [elapsed]);
        #end

        final oldStep:Int = curStep;
        timePassedOnState += elapsed;

        updateCurStep();
        updateBeat();

        if (oldStep != curStep)
        {
            if(curStep > 0)
                stepHit();

            if(PlayState.SONG != null)
            {
                if (oldStep < curStep)
                    updateSection();
                else
                    rollbackSection();
            }
        }

        if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;

        FlxG.watch.addQuick("decStepShit", curDecStep);
        FlxG.watch.addQuick("decBeatShit", curDecBeat);

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (scriptHelper != null) {
            scriptHelper.quickSetOnMenuScripts('curBpm', Conductor.bpm);
            scriptHelper.quickSetOnMenuScripts('crochet', Conductor.crochet);
            scriptHelper.quickSetOnMenuScripts('stepCrochet', Conductor.stepCrochet);
            scriptHelper.quickSetOnMenuScripts('curStep', curStep);
            scriptHelper.quickSetOnMenuScripts('curBeat', curBeat);
            scriptHelper.quickSetOnMenuScripts('curDecStep', curDecStep);
            scriptHelper.quickSetOnMenuScripts('curDecBeat', curDecBeat);
        }
        #end

        stagesFunc((stage:BaseStage) -> stage.update(elapsed));

        super.update(elapsed);

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onUpdatePost", [elapsed]);
        #end
    }

    private function updateSection():Void
    {
        if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
        while(curStep >= stepsToDo)
        {
            curSection++;
            var beats:Float = getBeatsOnSection();
            stepsToDo += Math.round(beats * 4);
            sectionHit();
        }
    }

    private function rollbackSection():Void
    {
        if(curStep < 0) return;

        final lastSection:Int = curSection;
        curSection = 0;
        stepsToDo = 0;
        for (i in 0...PlayState.SONG.notes.length)
        {
            if (PlayState.SONG.notes[i] != null)
            {
                stepsToDo += Math.round(getBeatsOnSection() * 4);
                if(stepsToDo > curStep) break;
                
                curSection++;
            }
        }

        if(curSection > lastSection) sectionHit();
    }

    private function updateBeat():Void
    {
        curBeat = Math.floor(curStep / 4);
        curDecBeat = curDecStep / 4;
    }

    private function updateCurStep():Void
    {
        final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

        final stepCrochet:Float = (lastChange.stepCrochet != null && lastChange.stepCrochet > 0) ? lastChange.stepCrochet : Conductor.stepCrochet;
        final shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / stepCrochet;
        curDecStep = lastChange.stepTime + shit;
        curStep = lastChange.stepTime + Math.floor(shit);
    }

    public static function getState():MusicBeatState {
        return cast (FlxG.state, MusicBeatState);
    }

    public var stages:Array<BaseStage> = [];
    public function stepHit():Void
    {
        stagesFunc(function(stage:BaseStage) {
            stage.curStep = curStep;
            stage.curDecStep = curDecStep;
            stage.stepHit();
        });

        if (curStep % 4 == 0) beatHit();

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onStepHit", []);
        #end
    }

    public function beatHit():Void
    {
        stagesFunc(function(stage:BaseStage) {
            stage.curBeat = curBeat;
            stage.curDecBeat = curDecBeat;
            stage.beatHit();
        });

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onBeatHit", []);
        #end
    }

    public function sectionHit():Void
    {
        stagesFunc(function(stage:BaseStage) {
            stage.curSection = curSection;
            stage.sectionHit();
        });

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onSectionHit", []);
        #end
    }

    function stagesFunc(func:BaseStage->Void)
    {
        for (stage in stages)
            if(stage != null && stage.exists && stage.active)
                func(stage);
    }

    function getBeatsOnSection()
    {
        var val:Null<Float> = 4;
        if(PlayState.SONG?.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
        return val ?? 4;
    }

    override public function openSubState(subState:FlxSubState) 
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if(scriptHelper == null || scriptHelper.quickCallMenuScript("onOpenSubState", [subState]) != ScriptResult.Function_Stop)
        #end
            super.openSubState(subState);
    }

    override public function closeSubState()
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if(scriptHelper == null || scriptHelper.quickCallMenuScript("onCloseSubState", []) != ScriptResult.Function_Stop)
        #end
            super.closeSubState();
    }
    
    override public function onResize(w:Int, h:Int) {
        super.onResize(w, h);
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onResize", [w, h]);
        #end
    }
    
    override public function draw() 
    {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if(scriptHelper == null || scriptHelper.quickCallMenuScript("onDraw", []) != ScriptResult.Function_Stop)
        #end
            super.draw();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onDrawPost", []);
        #end
    }
    
    override public function onFocus() {
        super.onFocus();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onFocus", []);
        #end
    }

    override public function onFocusLost() {
        super.onFocusLost();
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        scriptHelper?.quickCallMenuScript("onFocusLost", []);
        #end
    }
    
    override function destroy() {
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