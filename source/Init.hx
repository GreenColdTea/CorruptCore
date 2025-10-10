package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;

import lime.ui.WindowVSyncMode;

import game.backend.PlayerSettings;
import game.backend.WeekData;
import game.backend.utils.CoolUtil;
import game.states.StoryMenuState;

import game.backend.plugins.*;

class Init extends FlxState
{
    public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var fpsVar:FPSCounterPlugin;

    override function create()
    {
		game.backend.PlayerSettings.init();

        FlxG.save.bind('ccengine', CoolUtil.getSavePath());

		#if GLOBAL_SCRIPTS
		if(!game.scripting.HScriptGlobal.globalScriptActive) game.scripting.HScriptGlobal.addGlobalScript();
		#end

		ClientPrefs.init();

		game.backend.Highscore.load();

		if (FlxG.save.data != null)
		{
			if(FlxG.save.data.fullscreen)
				FlxG.fullscreen = FlxG.save.data.fullscreen;

			if (FlxG.save.data.weekCompleted != null)
				StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		applyGraphicsSettings();
			
        #if ((LUA_ALLOWED || HSCRIPT_ALLOWED) && MODS_ALLOWED)
		game.backend.system.Mods.pushGlobalMods();
		WeekData.loadTheFirstEnabledMod();
		#end

        FlxG.fixedTimestep = false;
	    FlxG.game.focusLostFramerate = #if mobile 30 #else 60 #end;
		FlxG.cameras.useBufferLocking = true;
        FlxG.keys.preventDefaultKeys = [TAB];

        #if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if (FEATURE_DEBUG_TRACY && !macro)
		openfl.Lib.current.stage.addEventListener(openfl.events.Event.EXIT_FRAME, (e:openfl.events.Event) ->
			cpp.vm.tracy.TracyProfiler.frameMark());
		
		cpp.vm.tracy.TracyProfiler.setThreadName("main");
		#end

		pluginsLessGo();

		#if desktop
		FlxG.mouse.visible = false;
    	FlxG.mouse.useSystemCursor = true;
		#end

		#if !html5
		FlxG.scaleMode = new flixel.FlxScaleMode();
		#end

		#if !mobile
		fpsVar = new FPSCounterPlugin(10, 3, 0xFFFFFF);
		Lib.current.addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.showFPS;
		}
		#end

		FlxG.switchState(() -> new game.states.TitleState());
    }

	public static function applyGraphicsSettings() {
		var vsyncMode:WindowVSyncMode = ClientPrefs.vsync ? WindowVSyncMode.ON : WindowVSyncMode.OFF;
		Lib.application.window.setVSyncMode(vsyncMode);
	}

	private function pluginsLessGo()
	{
		HotReloadPlugin.init();
		DebugConsolePlugin.init();
	}
}