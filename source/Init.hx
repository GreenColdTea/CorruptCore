package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;

import game.backend.PlayerSettings;
import game.backend.WeekData;
import game.backend.utils.CoolUtil;
import game.states.StoryMenuState;

class Init extends FlxState
{
    public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

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
			
        #if (LUA_ALLOWED && MODS_ALLOWED)
		Paths.pushGlobalMods();
		WeekData.loadTheFirstEnabledMod();
		#end

        FlxG.fixedTimestep = false;
	    FlxG.game.focusLostFramerate = #if mobile 30 #else 60 #end;
        FlxG.keys.preventDefaultKeys = [TAB];

        #if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if FEATURE_DEBUG_TRACY
		openfl.Lib.current.stage.addEventListener(openfl.events.Event.EXIT_FRAME, (e:openfl.events.Event) ->
			cpp.vm.tracy.TracyProfiler.frameMark());
		
		cpp.vm.tracy.TracyProfiler.setThreadName("main");
		#end

		FlxG.switchState(() -> new game.states.TitleState());
    }
}