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

import openfl.utils.Assets as OpenFlAssets;

class MusicBeatSubstate extends FlxSubState
{
	#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
	public var menuScriptArray:Array<FunkinHScript> = [];
	private var excludeSubStates:Array<Dynamic>;
	#end

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
		
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		if (!excludeSubStates.contains(Type.getClass(this)))
		{
			var substatePath = Type.getClassName(Type.getClass(this)).split(".");
			var substateString = substatePath[substatePath.length - 1];

			var scriptFiles:Array<String> = [];
			var folders:Array<String> = Paths.getSubstateScripts(substateString);
			
			for (folder in folders) {
				#if sys
				if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
					for (file in FileSystem.readDirectory(folder)) {
						if (file.endsWith('.hx')) {
							var fullPath = haxe.io.Path.join([folder, file]);
							scriptFiles.push(fullPath);
						}
					}
				}
				#else
				var prefix = folder.replace("_append", "");
				for (asset in OpenFlAssets.list(TEXT)) {
					if (asset.startsWith(prefix) && asset.endsWith('.hx')) {
						scriptFiles.push(asset);
					}
				}
				#end
			}

			for (path in scriptFiles) {
				menuScriptArray.push(new FunkinHScript(path, this));
				if (path.contains('contents/'))
					trace('Loaded mod substate script: $path');
				else
					trace('Loaded base game substate script: $path');
			}
		}
		#end
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
		super.create();
		quickCallMenuScript("onCreate", []);
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