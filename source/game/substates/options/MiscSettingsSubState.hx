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

class MiscSettingsSubState extends BaseOptionsMenu
{
	private var adaptiveCacheOption:Option;
	private var gpuCacheOption:Option;

	public function new()
	{
		title = 'Misc';
		rpcTitle = 'Misc Settings Menu';

		#if mobile
		var option:Option = new Option('Borderless Screen', //Name
			'If checked, the game window will be resized to remove black borders(16:9)', //Description
			'noBordersScreen', //Save data variable name
			'bool', //Variable type
			false); //Default value
		option.onChange = () -> FlxG.scaleMode = ClientPrefs.noBordersScreen ? new flixel.system.scaleModes.BaseScaleMode() : new flixel.system.scaleModes.RatioScaleMode();
		addOption(option);
		#end

		var option:Option = new Option('Streaming Audio',
			"If enabled, all sounds loaded via string paths will use streaming (OGG/Vorbis only).\nRequires restart to take full effect.\nReduces RAM usage but may cause slight CPU load.",
			'useStreamingAudio',
			'bool',
			false);
		addOption(option);
		option.onChange = () -> FlxG.sound.useStreamingForAll = ClientPrefs.useStreamingAudio;

		var option:Option = new Option('Adaptive Caching',
			"If checked, it will use your GPU with RAM to cache sprites.\nTurn it on, if you have a good GPU.",
			'adaptiveCache',
			'bool',
			false);
		addOption(option);
		adaptiveCacheOption = option;
		option.onChange = updateCacheOptionsVisibility;

		var option:Option = new Option('GPU Caching',
			"The same as above but GPU only.",
			'cacheOnGPU',
			'bool',
			false);
		addOption(option);
		gpuCacheOption = option;
		option.onChange = updateCacheOptionsVisibility;

		var option:Option = new Option('Colorblind Mode:',
			"What type of colorblind are you?",
			'colorBlindMode',
			'string',
			'None',
			['None', 'Deutranopia', 'Protanopia', 'Tritanopia', 'Protanomaly', 'Deuteranomaly', 'Tritanomaly', 'Rod monochromacy', 'Cone monochromacy']);
		addOption(option);
		option.onChange = onChangeColorBlind;

		var option:Option = new Option('Colorblind Intensity:',
			'How intense should the colorblind filter be?',
			'colorBlindIntensity',
			'percent',
			1);
		addOption(option);
		option.onChange = onChangeColorBlind;

		super();

		updateCacheOptionsVisibility();
	}

	private function updateCacheOptionsVisibility():Void
	{
		gpuCacheOption.visible = !ClientPrefs.adaptiveCache;
		gpuCacheOption.active = !ClientPrefs.adaptiveCache;

		adaptiveCacheOption.visible = !ClientPrefs.cacheOnGPU;
		adaptiveCacheOption.active = !ClientPrefs.cacheOnGPU;
		
		refreshOptions();
	}

	function onChangeColorBlind()
	{
		var index = ['Deutranopia', 'Protanopia', 'Tritanopia', 'Protanomaly', 'Deuteranomaly', 'Tritanomaly', 'Rod monochromacy', 'Cone monochromacy'].indexOf(ClientPrefs.colorBlindMode);
		Main.updateColorblindFilter(index, ClientPrefs.colorBlindIntensity);
	}
}