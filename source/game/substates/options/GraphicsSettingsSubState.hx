package game.substates.options;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import openfl.text.TextField;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.ui.WindowVSyncMode;
import lime.utils.Assets;
import flixel.FlxSubState;
import openfl.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import game.backend.Controls;
import openfl.Lib;

import game.substates.backend.Option;

using StringTools;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	private var framerateOption:Option;
	private var unlimitedFPSOption:Option;

	public function new()
	{
		title = 'Graphics';
		rpcTitle = 'Graphics Settings Menu';

		var option:Option = new Option('Low Quality',
            'If checked, disables some background details,\ndecreases loading times and improves performance.',
            'lowQuality',
            'bool',
            false);
        addOption(option);
        option.onChange = onChangeLowQuality;

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'globalAntialiasing',
			'bool',
			true);
		option.showBoyfriend = true;
		option.onChange = () -> FlxSprite.defaultAntialiasing = ClientPrefs.globalAntialiasing;
		addOption(option);

		var option:Option = new Option('Shaders',
			'If unchecked, disables shaders.\nIt\'s used for some visual effects, and also CPU intensive for weaker PCs.',
			'shaders',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('VSync',
			'If checked, enables V-Sync.\nHelps with screen tearing, but can introduce input lag.',
			'vsync',
			'bool',
			false);
		addOption(option);
		option.onChange = () -> {
			final vsyncMode:WindowVSyncMode = ClientPrefs.vsync ? WindowVSyncMode.ON : WindowVSyncMode.OFF;
			Lib.application.window.setVSyncMode(vsyncMode);

			if (ClientPrefs.vsync) {
				final targetFPS = Lib.application.window.displayMode.refreshRate ?? 60;
				FlxG.drawFramerate = targetFPS;
				FlxG.updateFramerate = targetFPS;
			} else {
				onChangeUnlimitedFPS();
			}

			FlxG.save.flush();
			
			updateFramerateVisibility();
		}

		var option:Option = new Option('Unlimited FPS',
			'If checked, removes FPS cap for maximum performance.\nMay cause high CPU/GPU usage.',
			'unlimitedFPS',
			'bool',
			false);
		addOption(option);
		unlimitedFPSOption = option;
		option.onChange = onChangeUnlimitedFPS;

		var option:Option = new Option('Framerate:',
			"Pretty self explanatory, isn't it?",
			'framerate',
			'int',
			60);
		addOption(option);
		framerateOption = option;

		option.minValue = 30;
		option.maxValue = 360;
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;

		super();
		
		updateFramerateVisibility();
	}

	function onChangeLowQuality()
    {
        FlxG.stage.quality = ClientPrefs.lowQuality ? LOW : BEST;
    }

	private function updateFramerateVisibility():Void
	{
		var shouldHide:Bool = ClientPrefs.vsync || ClientPrefs.unlimitedFPS;
		framerateOption.visible = !shouldHide;
		framerateOption.active = !shouldHide;

		unlimitedFPSOption.visible = !ClientPrefs.vsync;
		unlimitedFPSOption.active = !ClientPrefs.vsync;
		
		refreshOptions();
	}

	function onChangeUnlimitedFPS()
	{
		if (ClientPrefs.unlimitedFPS)
		{
			FlxG.drawFramerate = 0;
			FlxG.updateFramerate = 0;
		}
		else
		{
			onChangeFramerate();
		}
		
		updateFramerateVisibility();
		ClientPrefs.saveSettings();
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = ClientPrefs.framerate;
			FlxG.drawFramerate = ClientPrefs.framerate;
		}
		else
		{
			FlxG.drawFramerate = ClientPrefs.framerate;
			FlxG.updateFramerate = ClientPrefs.framerate;
		}
	}
}