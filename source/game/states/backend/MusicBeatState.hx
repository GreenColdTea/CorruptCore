package game.states.backend;

import game.backend.FunkinCamera;
import game.backend.Conductor.BPMChangeEvent;
import game.scripting.FunkinLua;

import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.FlxCamera;
import flixel.FlxBasic;
#if sys
import sys.FileSystem;
#end
#if SCRIPTABLE_STATES
import game.scripting.FunkinHScript;
import game.scripting.FunkinRuleScript;
import game.scripting.HScriptGlobal;
#end

import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;

class MusicBeatState extends FlxState
{
	#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
	public var menuScriptArray:Array<FunkinRuleScript> = [];
	private var excludeStates:Array<Dynamic>;
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

	private var menuScriptPath:String;

	/**
	 * Function, that returns is this state softcoded or not
	 * Kinda like in NVE but with Global Scripts
	 */
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

	// (WStaticInitOrder) Warning : maybe loop in static generation of MusicBeatState
	private static function initExcludeStates():Array<Dynamic> {
		return [
			game.PlayState, 
			game.scripting.HScriptState, 
			MusicBeatState,
			game.states.editors.CharacterEditorState,
			game.states.editors.ChartEditorState,
			game.states.editors.DialogueCharacterEditorState,
			game.states.editors.DialogueEditorState,
			game.states.editors.EditorPlayState,
			game.states.editors.MasterEditorMenu,
			game.states.editors.MenuCharacterEditorState,
			game.states.editors.WeekEditorState,
		];
	}

	public function new() {
		super();
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		excludeStates = initExcludeStates();
		#end
	}

	override function create() {
		if(!_FunkinCameraInitialized) initFunkinCamera();

		var colorBlindType = ClientPrefs.colorBlindMode;
		var intensity = ClientPrefs.colorBlindIntensity;
		var index = ['None', 'Deutranopia', 'Protanopia', 'Tritanopia', 'Protanomaly', 'Deuteranomaly', 'Tritanomaly', 'Rod monochromacy', 'Cone monochromacy'].indexOf(colorBlindType);
		if (index <= -1) index = -1;
		Main.updateColorblindFilter(index - 1, intensity);

		if(!FlxTransitionableState.skipNextTransOut) {
			openSubState(new CustomFadeTransition(0.6, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;

		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		if (!excludeStates.contains(Type.getClass(this)))
		{
			final statePath = Type.getClassName(Type.getClass(this)).split(".");
			final stateString = statePath[statePath.length - 1];

			var scriptFiles:Array<String> = [];
			var folders:Array<String> = Paths.getStateScripts(stateString);
			var processedFiles:Map<String, Bool> = new Map();
			
			for (path in folders)
			{
				var isDirectory = false;
				var isFile = false;
				
				#if sys
				if (FileSystem.exists(path))
				{
					if (FileSystem.isDirectory(path))
					{
						isDirectory = true;
						for (file in FileSystem.readDirectory(path))
						{
							if (file.endsWith('.hx'))
							{
								var fullPath = haxe.io.Path.join([path, file]);
								if (!processedFiles.exists(fullPath))
								{
									scriptFiles.push(fullPath);
									processedFiles.set(fullPath, true);
								}
							}
						}
					}
					else if (path.endsWith('.hx'))
					{
						isFile = true;
						if (!processedFiles.exists(path))
						{
							scriptFiles.push(path);
							processedFiles.set(path, true);
						}
					}
				}
				#end

				if (!isDirectory && !isFile)
				{
					if (OpenFlAssets.exists(path))
					{
						if (path.endsWith('.hx'))
						{
							if (!processedFiles.exists(path))
							{
								scriptFiles.push(path);
								processedFiles.set(path, true);
							}
						}
						else
						{
							var prefix = path.endsWith('/') ? path : path + '/';
							for (file in OpenFlAssets.list(TEXT))
							{
								if (file.startsWith(prefix) && file.endsWith('.hx') && !processedFiles.exists(file))
								{
									scriptFiles.push(file);
									processedFiles.set(file, true);
								}
							}
						}
					}
				}
			}

			for (path in scriptFiles)
			{
				menuScriptArray.push(new FunkinHScript(path, this));
				if (path.contains('${Mods.MODS_FOLDER}/'))
					trace('Loaded mod state script: $path');
				else
					trace('Loaded base game state script: $path');
			}
		}
		#end

		super.create();

		quickSetOnMenuScripts('this', this);

		quickCallMenuScript("onCreatePost", []);
	}

	public function initFunkinCamera():FunkinCamera
	{
		var camera = new FunkinCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_FunkinCameraInitialized = true;
		//trace('initialized psych camera ' + Sys.cpuTime());
		/*if (Main.colorblindMode != -1) {
			Main.applyColorblindFilterToCamera(camera, Main.colorblindMode, Main.colorblindIntensity);
		}*/

		return camera;
	}

	override function update(elapsed:Float)
	{
		quickCallMenuScript("onUpdate", [elapsed]);

		var oldStep:Int = curStep;
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

		quickSetOnMenuScripts('curBpm', Conductor.bpm);
		quickSetOnMenuScripts('crochet', Conductor.crochet);
		quickSetOnMenuScripts('stepCrochet', Conductor.stepCrochet);

		quickSetOnMenuScripts('curStep', curStep);
		quickSetOnMenuScripts('curBeat', curBeat);

		quickSetOnMenuScripts('curDecStep', curDecStep);
		quickSetOnMenuScripts('curDecBeat', curDecBeat);

		stagesFunc((stage:BaseStage) -> stage.update(elapsed));

		super.update(elapsed);

		quickCallMenuScript("onUpdatePost", [elapsed]);
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

		var lastSection:Int = curSection;
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
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	override public function startOutro(onOutroComplete:()->Void)
	{
		function transitionAction()
		{
			onOutroComplete();
			FlxTransitionableState.skipNextTransIn = false;
		}

		if (FlxTransitionableState.skipNextTransIn)
		{
			transitionAction();
		}
		else
		{
			openSubState(new CustomFadeTransition(0.6, false));
			CustomFadeTransition.finishCallback = transitionAction;
			return;
		}

		FlxTransitionableState.skipNextTransIn = false;
		super.startOutro(onOutroComplete);
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

		quickCallMenuScript("onStepHit", []);
	}

	public function beatHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
		//trace('Beat: ' + curBeat);

		quickCallMenuScript("onBeatHit", []);
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});

		quickCallMenuScript("onSectionHit", []);
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
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}

	override public function openSubState(subState:FlxSubState) 
	{
		if(quickCallMenuScript("onOpenSubState", [subState]) != ScriptResult.Function_Stop) super.openSubState(subState);
	}

	override public function closeSubState()
	{
		if(quickCallMenuScript("onCloseSubState", []) != ScriptResult.Function_Stop) super.closeSubState();
	}
	
	override public function onResize(w:Int, h:Int) {
		super.onResize(w, h);
		quickCallMenuScript("onResize", [w, h]);
	}
	
	override public function draw() 
	{
		if(quickCallMenuScript("onDraw", []) != ScriptResult.Function_Stop) super.draw();
		quickCallMenuScript("onDrawPost", []);
	}
	
	override public function onFocus() {
		super.onFocus();
		quickCallMenuScript("onFocus", []);
	}

	override public function onFocusLost() {
		super.onFocusLost();
		quickCallMenuScript("onFocusLost", []);
	}
	
	override function destroy() {
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		for (sc in menuScriptArray) {
			sc.call("onDestroy", []);
			sc.stop();
		}
		menuScriptArray = [];
		#end
		
		super.destroy();
	}

	public function quickSetOnMenuScripts(variable:String, arg:Dynamic)
	{
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		for (script in menuScriptArray)
		{
			script.set(variable, arg);
		}
		#end
	}

	public function quickCallMenuScript(func:String, ?args:Dynamic):Dynamic
	{
		var returnThing:Dynamic = ScriptResult.Function_Continue;
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		for (script in menuScriptArray)
		{
			var scriptThing = script.call(func, args);
			if (scriptThing == null) continue;
			if (scriptThing == ScriptResult.Function_Stop) returnThing = scriptThing;
		}
		#end
		return returnThing;
	}

	public function callOnMenuScript(event:String, args:Array<Dynamic>, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal = ScriptResult.Function_Continue;
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		exclusions ??= [];
		excludeValues ??= [];

		for (sc in menuScriptArray) {
			if(exclusions.contains(sc.scriptName))
				continue;

			var myValue = sc.call(event, args);
			if(myValue == ScriptResult.Function_Stop_Lua && !ignoreStops)
				break;
			
			if(myValue != ScriptResult.Function_Continue)
				returnVal = myValue;
		}
		#end
		return returnVal;
	}
}