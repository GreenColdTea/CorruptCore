package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.transition.TransitionData;
import flixel.input.keyboard.FlxKey;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;

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
    
    private static var initialized:Bool = false;
    private static var pluginsInitialized:Bool = false;
    
    private static var onGameResizedHandler:(Int, Int)->Void;

    override function create()
    {
        if (!initialized) {
            performInitialInit();
            initialized = true;
        }
        
        performResetInit();
			
        FlxG.switchState(() -> new game.states.TitleState());
    }
    
    private function performInitialInit():Void {
        game.backend.PlayerSettings.init();

        FlxG.save.bind('ccengine', CoolUtil.getSavePath());
		ClientPrefs.init();
		game.backend.Highscore.load();

		#if MODS_ALLOWED
		game.backend.system.Mods.pushGlobalMods();
		WeekData.loadTheFirstEnabledMod();
		#end

		fpsVar = new FPSCounterPlugin(10, 3, 0xFFFFFF);
		Lib.current.addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

		if(fpsVar != null) fpsVar.visible = ClientPrefs.showFPS;

		onGameResizedHandler = (w:Int, h:Int) -> {
            if (fpsVar != null)
                fpsVar.positionFPS(10, 3, Math.min(w / FlxG.width, h / FlxG.height));

            if (FlxG.cameras?.list != null) {
                for (cam in FlxG.cameras.list) {
                    if (cam != null)
                        resetSpriteCache(cam.flashSprite);
                }
            }

            if (FlxG.game != null)
                resetSpriteCache(FlxG.game);
        };
        
		FlxG.signals.gameResized.add(onGameResizedHandler);

        #if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if DISCORD_ALLOWED
		api.Discord.DiscordClient.prepare();
		#end

		#if (FEATURE_DEBUG_TRACY && !macro)
		FlxG.stage.addEventListener(openfl.events.Event.EXIT_FRAME, (e:openfl.events.Event) ->
			cpp.vm.tracy.TracyProfiler.frameMark());
		
		cpp.vm.tracy.TracyProfiler.setThreadName("main");
		#end

		if (!pluginsInitialized) {
		    pluginsLessGo();
		    pluginsInitialized = true;
		}

		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init();
		#end

		#if GLOBAL_SCRIPTS
		if(!game.scripting.HScriptGlobal.globalScriptActive) game.scripting.HScriptGlobal.addGlobalScript();
		#end
    }
    
    private function performResetInit():Void 
	{
        if (FlxG.save.data != null) {
            if(FlxG.save.data.fullscreen != null)
                FlxG.fullscreen = FlxG.save.data.fullscreen;

            if (FlxG.save.data.weekCompleted != null)
                StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
        }
        
        if(fpsVar != null)
            fpsVar.visible = ClientPrefs.showFPS;

		FlxTransitionableState.defaultTransIn = new TransitionData(FADE, FlxColor.BLACK, 0.6);
		FlxTransitionableState.defaultTransOut = new TransitionData(FADE, FlxColor.BLACK, 0.6);

		#if desktop
		FlxG.mouse.visible = false;
    	FlxG.mouse.useSystemCursor = true;
		#end
    }

	private function pluginsLessGo()
	{
		HotReloadPlugin.init();
		DebugConsolePlugin.init();
	}
    
	//for future stuff
    public static function fullReset() 
	{
        initialized = false;
        pluginsInitialized = false;
        
        if (fpsVar != null && Lib.current.contains(fpsVar)) {
            Lib.current.removeChild(fpsVar);
            fpsVar = null;
        }
        
        if (onGameResizedHandler != null) {
            FlxG.signals.gameResized.remove(onGameResizedHandler);
            onGameResizedHandler = null;
        }
        
        FlxG.resetGame();
    }

	@:noCompletion
	private static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
			if (sprite != null) {
		   		sprite.__cacheBitmapData = null;
				sprite.__cacheBitmapData2 = null;
				sprite.__cacheBitmapData3 = null;
				sprite.__cacheBitmapColorTransform = null;
			}
		}
    }
}