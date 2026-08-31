package;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.input.keyboard.FlxKey;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import openfl.filters.ColorMatrixFilter;
import openfl.events.UncaughtErrorEvent;
import openfl.errors.Error;

//crash handler stuff
#if CRASH_HANDLER
import game.backend.CrashHandler;
#end

import game.objects.FunkinSoundTray;

#if MODS_ALLOWED
import game.backend.system.Mods;
#end

using StringTools;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && cpp && !debug)
@:cppInclude('./_external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

class Main extends Sprite
{
	public static final game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: Init, // initial game state
        zoom: -1, // If -1, zoom is automatically calculated to fit the window dimensions.
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	//for colorblind mode
	public static var colorblindMode:Int = -1;
	public static var colorblindIntensity:Float = 1.0;
	private static var currentColorblindFilter:ColorMatrixFilter = null;

	// You can pretty much ignore everything from here on - your code should go in your game.states.
	public static function main():Void
	{
		#if CRASH_HANDLER
	    CrashHandler.init();
	    #end
		
		Lib.current.addChild(new Main());

		MemoryUtil.enableGC();
	}

	public function new()
	{
		super();

        Application.current.onExit.add((_) -> {
			#if MODS_ALLOWED
			Mods.clearTempFiles();
			#end
			#if VIDEOS_ALLOWED
			hxvlc.util.Handle.dispose();
			#end
		});
        
		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}

		FlxG.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, (e) ->
		{
			if (e.keyCode == FlxKey.F11) FlxG.fullscreen = !FlxG.fullscreen;
			if (e.keyCode == FlxKey.ENTER && e.altKey) e.stopImmediatePropagation();
		}, false, 100);
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		#if (openfl < '9.2.0')
        final stageWidth:Int = FlxG.stage.stageWidth;
	    final stageHeight:Int = FlxG.stage.stageHeight;

	    if (game.zoom == -1)
	    {
		    final ratioX:Float = stageWidth / game.width;
		    final ratioY:Float = stageHeight / game.height;
			
		    game.zoom = Math.min(ratioX, ratioY);
		    game.width = Math.ceil(stageWidth / game.zoom);
		    game.height = Math.ceil(stageHeight / game.zoom);
	    }
        #elseif (openfl >= '9.2.0')
        if (game.zoom == -1) {
            game.zoom = 1;
        }
	    #end

		lime.RawKeyboard.init();

		lime.Native.registerAsGame();

		#if sl_windows_api
		WindowsAPI.disableWindowsReport();
		WindowsAPI.disableWindowsGhosting();
		WindowsAPI.setConsoleOutputToUTF8();
		#end

		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init();
		hxvlc.util.Handle.initAsync();
		#end

		initHaxeUI();

		FlxG.save.bind('ccengine', CoolUtil.getSavePath());

		final push:FlxGame = new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen);
		@:privateAccess
        push._customSoundTray = FunkinSoundTray;

		FlxG.fixedTimestep = false;
		FlxG.cameras.useBufferLocking = true;
	    FlxG.game.focusLostFramerate = #if mobile 30 #else 60 #end;
        FlxG.keys.preventDefaultKeys = [TAB];

		addChild(push);

		//memory shit
		if (!FlxG.signals.preStateCreate.has(memoryClean))
            FlxG.signals.preStateCreate.add(memoryClean);

		/*#if desktop
		if(CoolUtil.hasVersion("Windows 10")) {
			FlxG.stage.window.borderless = true;
			FlxG.stage.window.borderless = false;
		}
		#end*/
	}

	private static function memoryClean(newState:FlxState) {
        final isPlay = (newState is game.PlayState || newState is game.states.options.OptionsState);
        
        if (!isPlay) FunkinCache.freeGraphicsFromMemory();

        FunkinCache.clearUnusedMemory(!isPlay);
        if (!isPlay) FunkinCache.clearStoredMemory();
    }

	/**
	 * Colorblind mode stuff
	 *
	 * Applies a colorblind filter to the game.
	 * @param type - The type of colorblindness (0-7, -1 for no filter).
	 * @param intensity - The intensity of the filter (0-1, 1 being full intensity).
	 */
	public static function applyColorblindFilterToGame(type:Int, intensity:Float = 1) {
		if (FlxG.game == null) return;

		if (currentColorblindFilter != null) {
			@:privateAccess
			var filters = FlxG.game._filters?.copy() ?? [];
			filters = filters.filter(f -> f != currentColorblindFilter);
			FlxG.game.setFilters(filters);
			currentColorblindFilter = null;
		}

		if (type == -1) return;

		currentColorblindFilter = new ColorMatrixFilter(getColorblindMatrix(type, intensity));

		@:privateAccess
		var newFilters = FlxG.game._filters?.copy() ?? [];
		newFilters.push(currentColorblindFilter);
		FlxG.game.setFilters(newFilters);
	}

	private static function getColorblindMatrix(type:Int, intensity:Float):Array<Float> {
		var matrixShit:Array<Float> = [];
		switch (type) {
			// colorblindness types
			case 0: // Deuteranopia
				matrixShit = [
					0.625, 0.375, 0, 0, 0,
					0.700, 0.300, 0, 0, 0,
					0,     0.300, 0.700, 0, 0,
					0, 0, 0, 1, 0];

			case 1: // Protanopia
				matrixShit = [
					0.567, 0.433, 0, 0, 0,
					0.558, 0.442, 0, 0, 0,
					0,     0.242, 0.758, 0, 0,
					0, 0, 0, 1, 0];

			case 2: // Tritanopia
				matrixShit = [
					0.950, 0.050, 0, 0, 0,
					0,     0.433, 0.567, 0, 0,
					0,     0.475, 0.525, 0, 0,
					0, 0, 0, 1, 0];

			case 3: // Protanomaly
				matrixShit = [
					0.817, 0.183, 0, 0, 0,
					0.333, 0.667, 0, 0, 0,
					0,     0.125, 0.875, 0, 0,
					0, 0, 0, 1, 0];

			case 4: // Deuteranomaly
				matrixShit = [
					0.800, 0.200, 0, 0, 0,
					0.258, 0.742, 0, 0, 0,
					0,     0.142, 0.858, 0, 0,
					0, 0, 0, 1, 0];

			case 5: // Tritanomaly
				matrixShit = [
					0.967, 0.033, 0, 0, 0,
					0,     0.733, 0.267, 0, 0,
					0,     0.183, 0.817, 0, 0,
					0, 0, 0, 1, 0];

			case 6: // Rod monochromacy
				matrixShit = [
					0.2126, 0.7152, 0.0722, 0, 0,
					0.2126, 0.7152, 0.0722, 0, 0,
					0.2126, 0.7152, 0.0722, 0, 0,
					0,      0,      0,      1, 0];

			case 7: // Cone monochromacy
				matrixShit = [
					0.299, 0.587, 0.114, 0, 0,
					0.299, 0.587, 0.114, 0, 0,
					0.299, 0.587, 0.114, 0, 0,
					0,     0,     0,     1, 0];
		}

		if (intensity < 1) {
			final identity = [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];
			for (i in 0...matrixShit.length)
				matrixShit[i] = matrixShit[i] * intensity + identity[i] * (1 - intensity);
		}
		return matrixShit;
	}

	public static function updateColorblindFilter(type:Int = -1, intensity:Float = 1) {
		colorblindMode = type;
		colorblindIntensity = intensity;

		applyColorblindFilterToGame(type, intensity);

		ClientPrefs.colorBlindMode = switch (type) {
			case -1: 'None';
			case 0: 'Deutranopia';
			case 1: 'Protanopia';
			case 2: 'Tritanopia';
			case 3: 'Protanomaly';
			case 4: 'Deuteranomaly';
			case 5: 'Tritanomaly';
			case 6: 'Rod monochromacy';
			case 7: 'Cone monochromacy';
			default: 'None';
		};
		ClientPrefs.colorBlindIntensity = intensity;
		ClientPrefs.saveSettings();
	}

	private function initHaxeUI():Void
	{
		haxe.ui.Toolkit.init();
		haxe.ui.Toolkit.theme = 'dark';
		haxe.ui.Toolkit.autoScale = false;
		haxe.ui.focus.FocusManager.instance.autoFocus = false;
		haxe.ui.tooltips.ToolTipManager.defaultDelay = 200;

		final extra = new haxe.ui.styles.StyleSheet();
		extra.parse(openfl.utils.Assets.getText("assets/ui/editor.css"));
		haxe.ui.Toolkit.styleSheet.addStyleSheet(extra);
	}
}