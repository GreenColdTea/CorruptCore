package game.substates.backend;

import game.backend.Conductor.BPMChangeEvent;
import game.scripting.FunkinLua;

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.FlxBasic;
import flixel.FlxSprite;
#if sys
import sys.FileSystem;
#end
#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
import game.scripting.FunkinHScript;
#end

import openfl.filters.BitmapFilter;
import openfl.utils.Assets as OpenFlAssets;

class MusicBeatSubstate extends FlxSubState
{
	#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
	public var menuScriptArray:Array<FunkinHScript> = [];
	private var excludeSubStates:Array<Dynamic>;
	#end

	public var camSubState:FlxCamera;

	public var useCustomCamera:Bool = false;
	public var freezeParentState:Bool = true;
	
	public var parentState:MusicBeatState;

	// (WStaticInitOrder) Warning : maybe loop in static generation of MusicBeatSubstate
	private static function initExcludeSubStates():Array<Dynamic> {
		return [game.scripting.HScriptSubstate];
	}

	public function new()
	{
		super();

		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		excludeSubStates = initExcludeSubStates();
		#end
		
		parentState = cast FlxG.state;
		
		initializeSubStateCamera();
		
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		var substatePath = Type.getClassName(Type.getClass(this)).split(".");
		var substateString = substatePath[substatePath.length - 1];
		
		var scriptFiles:Array<String> = [];
		var folders:Array<String> = Paths.getSubstateScripts(substateString);
		var processedFiles:Map<String, Bool> = new Map();
		
		for (path in folders) {
			var isDirectory:Bool = false;
			var isFile:Bool = false;
			
			#if sys
			if (FileSystem.exists(path)) {
				if (FileSystem.isDirectory(path)) {
					isDirectory = true;
					for (file in FileSystem.readDirectory(path)) {
						if (file.endsWith('.hx')) {
							var fullPath = haxe.io.Path.join([path, file]);
							if (!processedFiles.exists(fullPath)) {
								scriptFiles.push(fullPath);
								processedFiles.set(fullPath, true);
							}
						}
					}
				} else if (path.endsWith('.hx')) {
					isFile = true;
					if (!processedFiles.exists(path)) {
						scriptFiles.push(path);
						processedFiles.set(path, true);
					}
				}
			}
			#end
			
			if (!isDirectory && !isFile) {
				if (OpenFlAssets.exists(path)) {
					if (path.endsWith('.hx')) {
						if (!processedFiles.exists(path)) {
							scriptFiles.push(path);
							processedFiles.set(path, true);
						}
					} else {
						var prefix = path.endsWith('/') ? path : path + '/';
						for (file in OpenFlAssets.list(TEXT)) {
							if (file.startsWith(prefix) && file.endsWith('.hx') && !processedFiles.exists(file)) {
								scriptFiles.push(file);
								processedFiles.set(file, true);
							}
						}
					}
				}
			}
		}
		
		for (path in scriptFiles) {
			menuScriptArray.push(new FunkinHScript(path, this));
			if (path.contains('${Mods.MODS_FOLDER}/'))
				trace('Loaded mod substate script: $path');
			else
				trace('Loaded base game substate script: $path');
		}
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
		
		camSubState ??= cameras != null && cameras.length > 0 ? cameras[0] : FlxG.camera;
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
		
		quickCallMenuScript("onCreate", []);

		super.create();

		quickCallMenuScript("onCreatePost", []);
	}

	override function update(elapsed:Float)
	{
		quickCallMenuScript("onUpdate", [elapsed]);
		
		var oldStep:Int = curStep;

		if(!persistentUpdate) MusicBeatState.timePassedOnState += elapsed;

		updateCurStep();
		curBeat = Math.floor(curStep / 4);

		if (oldStep != curStep && curStep > 0) stepHit();

		super.update(elapsed);
		quickCallMenuScript("onUpdatePost", [elapsed]);
	}

	override function openSubState(SubState:FlxSubState)
	{
		showSubStateCamera();
		quickCallMenuScript("onOpenSubState", []);
		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		hideSubStateCamera();
		quickCallMenuScript("onCloseSubState", []);
		super.closeSubState();
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		curStep = lastChange.stepTime + Math.floor((Conductor.songPosition - lastChange.songTime) / Conductor.stepCrochet);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
			
		quickCallMenuScript("onStepHit", []);
	}

	public function beatHit():Void
	{
		quickCallMenuScript("onBeatHit", []);
	}

	override function destroy()
	{
		hideSubStateCamera();
		
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		for (sc in menuScriptArray)
		{
			sc.call("onDestroy", []);
			sc.stop();
		}
		menuScriptArray = [];
		#end
		
		super.destroy();
	}

	public function quickCallMenuScript(func:String, ?args:Dynamic):Dynamic
	{
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		var returnThing:Dynamic = FunkinLua.Function_Continue;
		for (script in menuScriptArray)
		{
			var scriptThing = script.call(func, args);
			if (scriptThing == FunkinLua.Function_Stop) returnThing = scriptThing;
		}
		return returnThing;
		#else
		return FunkinLua.Function_Continue;
		#end
	}
}