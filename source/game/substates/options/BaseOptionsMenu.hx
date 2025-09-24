package game.substates.options;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import openfl.text.TextField;
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

import game.objects.Character;
import game.objects.CheckboxThingie;
import game.objects.AttachedText;

import game.substates.backend.Option;

using StringTools;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var boyfriend:Character = null;
	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	private var visibleOptions:Array<Option> = [];

	private var savedSelectedIndex:Int = 0;
	private var savedOptionName:String = "";

	public function new()
	{
		super();

		title ??= 'Options';
		rpcTitle ??= 'Options Menu';
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end
		
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		var titleText:Alphabet = new Alphabet(75, 40, title, true);
		titleText.scaleX = 0.6;
		titleText.scaleY = 0.6;
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		updateVisibleOptions();
		
		createOptions();

		changeSelection();
		reloadCheckboxes();
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
	}

	private function updateVisibleOptions():Void
	{
		visibleOptions = [];
		if (optionsArray != null) {
			for (option in optionsArray) {
				if (option.visible) {
					visibleOptions.push(option);
				}
			}
		}
	}

	public function refreshOptions():Void
	{
		saveSelection();
		
		grpOptions?.clear();
		grpTexts?.clear();
		checkboxGroup?.clear();
		
		updateVisibleOptions();
		
		createOptions();
		
		restoreSelection();
		
		reloadCheckboxes();
	}

	private function createOptions():Void
	{
		for (i in 0...visibleOptions.length)
		{
			var option = visibleOptions[i];
			var optionText:Alphabet = new Alphabet(290, 260, option.name, false);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(option.type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, option.getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
				
				if (!option.active) {
					checkbox.alpha = 0.6;
				}
			} else {
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				var valueText:AttachedText = new AttachedText('' + option.getValue(), optionText.width + 80);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[optionsArray.indexOf(option)].setChild(valueText);
				
				if (!option.active) {
					valueText.alpha = 0.6;
					optionText.alpha = 0.6;
				}
			}

			if(option.showBoyfriend && boyfriend == null)
			{
				reloadBoyfriend();
			}
			updateTextFrom(option);
		}
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0)
		{
			if (curOption != null && !curOption.active) {
				// lol
			} else {
				var usesCheckbox = true;
				if(curOption != null && curOption.type != 'bool')
				{
					usesCheckbox = false;
				}

				if(usesCheckbox)
				{
					if(controls.ACCEPT)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'));
						curOption.setValue((curOption.getValue() == true) ? false : true);
						curOption.change();
						reloadCheckboxes();
					}
				} else {
					if(controls.UI_LEFT || controls.UI_RIGHT) {
						var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
						if(holdTime > 0.5 || pressed) {
							if(pressed) {
								var add:Dynamic = null;
								if(curOption.type != 'string') {
									add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
								}

								switch(curOption.type)
								{
									case 'int' | 'float' | 'percent':
										holdValue = curOption.getValue() + add;
										if(holdValue < curOption.minValue) holdValue = curOption.minValue;
										else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

										switch(curOption.type)
										{
											case 'int':
												holdValue = Math.round(holdValue);
												curOption.setValue(holdValue);

											case 'float' | 'percent':
												holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
												curOption.setValue(holdValue);
										}

									case 'string':
										var num:Int = curOption.curOption;
										if(controls.UI_LEFT_P) --num;
										else num++;

										if(num < 0) {
											num = curOption.options.length - 1;
										} else if(num >= curOption.options.length) {
											num = 0;
										}

										curOption.curOption = num;
										curOption.setValue(curOption.options[num]);
								}
								updateTextFrom(curOption);
								curOption.change();
								FlxG.sound.play(Paths.sound('scrollMenu'));
							} else if(curOption.type != 'string') {
								holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
								if(holdValue < curOption.minValue) holdValue = curOption.minValue;
								else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

								switch(curOption.type)
								{
									case 'int':
										curOption.setValue(Math.round(holdValue));
									
									case 'float' | 'percent':
										curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
								}
								updateTextFrom(curOption);
								curOption.change();
							}
						}

						if(curOption.type != 'string') {
							holdTime += elapsed;
						}
					} else if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
						clearHold();
					}
				}

				if(controls.RESET)
				{
					for (i in 0...optionsArray.length)
					{
						var leOption:Option = optionsArray[i];
						leOption.setValue(leOption.defaultValue);
						if(leOption.type != 'bool')
						{
							if(leOption.type == 'string')
							{
								leOption.curOption = leOption.options.indexOf(leOption.getValue());
							}
							updateTextFrom(leOption);
						}
						leOption.change();
					}
					FlxG.sound.play(Paths.sound('cancelMenu'));
					reloadCheckboxes();
				}
			}
		}

		if(boyfriend != null && boyfriend.animation.curAnim.finished) {
			boyfriend.dance();
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function updateTextFrom(option:Option) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == 'percent') val *= 100;
		var def:Dynamic = option.defaultValue;
		
		function formatValue(v:Dynamic):String {
			if (Std.isOfType(v, Bool)) {
				return v ? "On" : "Off";
			}
			return Std.string(v);
		}
		
		option.text = text.replace('%v', formatValue(val)).replace('%d', formatValue(def));
	}

	function clearHold()
	{
		if(holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		holdTime = 0;
	}

	private function saveSelection():Void
	{
		if (visibleOptions.length > 0 && curSelected < visibleOptions.length) {
			savedOptionName = visibleOptions[curSelected].name;
		} else {
			savedOptionName = "";
		}
	}

	private function restoreSelection():Void
	{
		var newIndex:Int = 0;
		
		if (savedOptionName != "") {
			for (i in 0...visibleOptions.length) {
				if (visibleOptions[i].name == savedOptionName) {
					newIndex = i;
					break;
				}
			}
		}
		
		curSelected = newIndex;
		changeSelection(0, false);
	}
	
	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = visibleOptions.length - 1;
		if (curSelected >= visibleOptions.length)
			curSelected = 0;

		var visibleOption = visibleOptions[curSelected];
		var mainIndex = optionsArray.indexOf(visibleOption);
		
		if (mainIndex != -1) {
			descText.text = optionsArray[mainIndex].description;
			curOption = optionsArray[mainIndex];
		} else {
			descText.text = "";
			curOption = null;
		}
		
		descText.screenCenter(Y);
		descText.y += 270;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}
		for (text in grpTexts) {
			text.alpha = 0.6;
			if(text.ID == curSelected) {
				text.alpha = 1;
			}
		}

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		if(boyfriend != null)
		{
			boyfriend.visible = visibleOption.showBoyfriend ?? false;
		}
		
		if (playSound) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}

	public function reloadBoyfriend()
	{
		var wasVisible:Bool = false;
		if(boyfriend != null) {
			wasVisible = boyfriend.visible;
			boyfriend.kill();
			remove(boyfriend);
			boyfriend.destroy();
		}

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		insert(1, boyfriend);
		boyfriend.visible = wasVisible;
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			if (checkbox.ID < visibleOptions.length) {
				var option = visibleOptions[checkbox.ID];
				checkbox.daValue = (option.getValue() == true);
				
				checkbox.alpha = option.active ? 1 : 0.6;
			}
		}
		
		for (text in grpTexts) {
			if (text.ID < visibleOptions.length) {
				var option = visibleOptions[text.ID];
				text.alpha = option.active ? 1 : 0.6;
				
				var optionText = grpOptions.members[text.ID];
				if (optionText != null) {
					optionText.alpha = option.active ? 1 : 0.6;
				}
			}
		}
	}
}