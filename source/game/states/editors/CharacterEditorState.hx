package game.states.editors;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.animation.FlxAnimation;

import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;

import openfl.utils.Assets as OpenFLAssets;

import haxe.Json;
import lime.system.Clipboard;

import game.objects.Character;
import game.objects.HealthIcon;
import psych.ui.PsychUITopMenu;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef HistoryStuff = {
    var animations:Array<AnimArray>;
    var position:Array<Float>;
    var scale:Float;
    var cameraPosition:Array<Float>;
    var healthColor:Array<Int>;
    var curAnim:Int;
}

@:bitmap("psych-ui/images/cursorCross.png")
class GraphicCursorCross extends openfl.display.BitmapData {}

class CharacterEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static inline final AUTO_SAVE_INTERVAL:Float = 60;

	var camEditor:FlxCamera;
	var camUI:FlxCamera;

	var char:Character;
	var ghostChar:Character;
	var bgLayer:FlxTypedGroup<FlxSprite>;
	var charLayer:FlxTypedGroup<Character>;
	var dumbTexts:FlxTypedGroup<FlxText>;
	var curAnim:Int = 0;
	var daAnim:String = 'spooky';
	var goToPlayState:Bool = true;

	var topMenu:PsychUITopMenu;
	var UI_box:PsychUIBox;
	var UI_characterbox:PsychUIBox;
	var UI_animList:PsychUIBox;

	var errorAnimText:FlxText;

	var grid:FlxBackdrop;
	var gridVisible:Bool = false;

	var copiedOffsets:Array<Int> = [0, 0];

	var undos:Array<Dynamic> = [];
	var redos:Array<Dynamic> = [];
	var maxHistorySteps:Int = 75;

	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];

	var cameraFollowPointer:FlxSprite;
	var healthBarBG:FlxSprite;

	var draggingCamera:Bool = false;
	var cameraSmoothness:Float = 0.2;
	var cameraDragSensitivity:Float = 0.5;
	var cameraScrollTarget:FlxPoint = FlxPoint.get(0, 0);

	var lastAutoSaveTime:Float = 0;

	var ghostAnim:String = '';
	var ghostAlpha:Float = 0.6;
	var ghostSingleAnimMode:Bool = false;

	var charDropDown:PsychUIDropDownMenu;

	var imageInputText:PsychUIInputText;
	var healthIconInputText:PsychUIInputText;
	var vocalsInputText:PsychUIInputText;

	var singDurationStepper:PsychUINumericStepper;
	var scaleStepper:PsychUINumericStepper;
	var positionXStepper:PsychUINumericStepper;
	var positionYStepper:PsychUINumericStepper;
	var positionCameraXStepper:PsychUINumericStepper;
	var positionCameraYStepper:PsychUINumericStepper;

	var flipXCheckBox:PsychUICheckBox;
	var noAntialiasingCheckBox:PsychUICheckBox;
	var check_player:PsychUICheckBox;

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationNameFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;

	public function new(daAnim:String = 'bf', goToPlayState:Bool = true)
	{
		super();
		this.daAnim = daAnim;
		this.goToPlayState = goToPlayState;
	}

	override function create()
	{
		camEditor = initMainCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;

		FlxG.cameras.add(camUI, false);

		bgLayer = new FlxTypedGroup<FlxSprite>();
		add(bgLayer);

		grid = new FlxBackdrop(FlxGridOverlay.createGrid(15, 15, FlxG.width, FlxG.height, true, 0xffe7e6e6, 0xffd9d5d5));
		grid.visible = gridVisible;
		grid.screenCenter();
		add(grid);

		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);

		cameraFollowPointer = new FlxSprite().loadGraphic(FlxGraphic.fromClass(GraphicCursorCross));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		cameraFollowPointer.antialiasing = false;
		add(cameraFollowPointer);

		loadChar(!daAnim.startsWith('bf'), false);

		healthBarBG = new FlxSprite(30, FlxG.height - 75).loadGraphic(Paths.image('healthBar'));
		healthBarBG.scrollFactor.set();
		healthBarBG.cameras = [camUI];
		add(healthBarBG);

		leHealthIcon = new HealthIcon(char.healthIcon, false);
		leHealthIcon.y = FlxG.height - 150;
		leHealthIcon.cameras = [camUI];
		add(leHealthIcon);

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camUI];
		add(dumbTexts);

		errorAnimText = new FlxText(300, 40, "ERROR ON LOADING ANIMATION");
		errorAnimText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorAnimText.scrollFactor.set();
		errorAnimText.borderSize = 1;
		errorAnimText.cameras = [camUI];
		errorAnimText.visible = false;
		add(errorAnimText);

		FlxG.camera.zoom = 1;
		FlxG.mouse.visible = true;

		createUIMenu();
		createTopMenu();

		genBoyOffsets();

		addSettingsUI();
		addCharacterUI();
		addAnimationsUI();

		UI_box.selectedName = 'Settings';
		UI_characterbox.selectedName = 'Character';

		reloadCharacterOptions();

		super.create();
	}

	function createTopMenu()
	{
		topMenu = new PsychUITopMenu();
		topMenu.cameras = [camUI];

		topMenu.addCategory("File", 
			["Save", "Save As...", "Load Template", "Exit"], 
			[
				(label) -> saveCharacter(false),
				(label) -> saveCharacter(true),
				(label) -> loadTemplateCharacter(),
				(label) -> handleExit(true)
			],
			["Ctrl+S", "Ctrl+Shift+S", "", "Esc"],
			[FlxColor.WHITE, FlxColor.WHITE, FlxColor.WHITE, FlxColor.RED]
		);

		topMenu.addCategory("View", 
			["Toggle Grid", "Reset Zoom", "Toggle Ghost", "Highlight Ghost"], 
			[
				(label) -> handleGridToggle(true),
				(label) -> FlxG.camera.zoom = 1,
				(label) -> toggleGhost(),
				(label) -> highlightGhost()
			],
			["G", "R", "", ""]
		);

		topMenu.addCategory("Help", 
			["Shortcuts"], 
			[
				(label) -> openSubState(new CharacterEditorTipsSubstate())
			],
			["F1"]
		);

		add(topMenu);
	}

	function createUIMenu()
	{
		UI_box = new PsychUIBox(FlxG.width - 275, 40, 250, 90, ['Settings']);
		UI_box.cameras = [camUI];

		UI_characterbox = new PsychUIBox(UI_box.x - 100, UI_box.y + UI_box.height + 10, 350, 280, ['Animations', 'Character']);
		UI_characterbox.cameras = [camUI];

		UI_animList = new PsychUIBox(10, 40, 280, 435, ['Offsets']);
		UI_animList.selectedTab.scrollable = true;
		UI_animList.cameras = [camUI];

		add(UI_characterbox);
		add(UI_box);
		add(UI_animList);
	}

	function reloadBGs() {
		var i:Int = bgLayer.members.length-1;
		while(i >= 0) {
			var memb:FlxSprite = bgLayer.members[i];
			if(memb != null) {
				memb.kill();
				bgLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		bgLayer.clear();

		var playerXDifference:Float = char.isPlayer ? 670 : 0;

		var bg:BGSprite = new BGSprite('stageback', -300- playerXDifference, -300, 0.9, 0.9);
		bgLayer.add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -350 - playerXDifference, 500, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		bgLayer.add(stageFront);
	}

	function toggleGhost() {
		ghostChar.visible = !ghostChar.visible;
		if (ghostChar.visible) {
			ghostAnim = char.getAnimationName();
			ghostSingleAnimMode = true;
		}
		reloadGhost();
	}

	var isGhostHighlighted = false;
	function highlightGhost() {
		isGhostHighlighted = !isGhostHighlighted;
		final value = isGhostHighlighted ? 125 : 0;
		ghostChar.colorTransform.redOffset = value;
		ghostChar.colorTransform.greenOffset = value;
		ghostChar.colorTransform.blueOffset = value;
	}

	function loadTemplateCharacter() {
		final parsedJson:CharacterFile = cast Json.parse(Character.templateCharacter);
		final characters:Array<Character> = [char, ghostChar];
		for (character in characters)
		{
			character.animOffsets.clear();
			character.animationsArray = parsedJson.animations;

			for (anim in character.animationsArray) {
				character.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			}

			if(character.animationsArray[0] != null) {
				character.playAnim(character.animationsArray[0].anim, true);
			}

			character.singDuration = parsedJson.sing_duration;
			character.positionArray = parsedJson.position;
			character.cameraPosition = parsedJson.camera_position;

			character.imageFile = parsedJson.image;
			character.jsonScale = parsedJson.scale;
			character.noAntialiasing = parsedJson.no_antialiasing;
			character.originalFlipX = parsedJson.flip_x;
			character.healthIcon = parsedJson.healthicon;
			character.healthColorArray = parsedJson.healthbar_colors;
			character.setPosition(character.positionArray[0] + 400, character.positionArray[1]);
		}

		reloadCharacterImage();
		reloadCharacterDropDown();
		reloadCharacterOptions();
		updatePointerPos();
		genBoyOffsets();
		saveHistoryStuff();
	}

	function addSettingsUI() {
		var tab_group = UI_box.getTab('Settings').menu;

		check_player = new PsychUICheckBox(10, 45, "Playable Character", 100);
		check_player.checked = daAnim.startsWith('bf');
		check_player.onClick = function()
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;
			updatePointerPos(false);
			reloadBGs();
			ghostChar.flipX = char.flipX;
		};

		charDropDown = new PsychUIDropDownMenu(10, 20, [''], function(index:Int, intended:String)
		{
			if(intended == null || intended.length < 1) return;

			final characterPath:String = 'data/characters/$intended.json';
			if (Paths.fileExists(characterPath, TEXT))
			{
				daAnim = intended;
				check_player.checked = daAnim.startsWith('bf');
				loadChar(!check_player.checked);
				reloadCharacterOptions();
				reloadCharacterDropDown();
				updatePointerPos();
			}
			else
			{
				reloadCharacterDropDown();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		});
		reloadCharacterDropDown();
		charDropDown.selectedLabel = daAnim;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tab_group.add(check_player);
		tab_group.add(charDropDown);
	}

	function addCharacterUI() {
		var tab_group = UI_characterbox.getTab('Character').menu;

		imageInputText = new PsychUIInputText(15, 30, 200, 'characters/BOYFRIEND', 8);
		imageInputText.onChange = (_, _) -> {
			char.imageFile = imageInputText.text;
			saveHistoryStuff();
		};

		var reloadImage:PsychUIButton = new PsychUIButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function()
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();
			if(!char.isAnimationNull()) {
				char.playAnim(char.getAnimationName(), true);
			}
		});

		healthIconInputText = new PsychUIInputText(15, imageInputText.y + 35, 75, leHealthIcon.getCharacter(), 8);
		healthIconInputText.onChange = (_, _) -> {
			leHealthIcon.changeIcon(healthIconInputText.text, false);
			char.healthIcon = healthIconInputText.text;
			updatePresence();
			saveHistoryStuff();
		};

		vocalsInputText = new PsychUIInputText(15, healthIconInputText.y + 35, 75, char.vocalsFile ?? '', 8);
		vocalsInputText.onChange = (_, _) -> {
			char.vocalsFile = vocalsInputText.text;
			saveHistoryStuff();
		};

		singDurationStepper = new PsychUINumericStepper(15, healthIconInputText.y + 75, 0.1, 4, 0, 999, 1);
		singDurationStepper.onValueChange = () -> {
			char.singDuration = singDurationStepper.value;
			saveHistoryStuff();
		};

		scaleStepper = new PsychUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);
		scaleStepper.onValueChange = () -> {
			reloadCharacterImage();

			char.jsonScale = scaleStepper.value;
			char.scale.set(char.jsonScale, char.jsonScale);
			char.updateHitbox();

			ghostChar.scale.set(char.jsonScale, char.jsonScale);
			ghostChar.updateHitbox();
			reloadGhost();

			updatePointerPos(false);

			if(!char.isAnimationNull()) {
				char.playAnim(char.getAnimationName(), true);
			}
			saveHistoryStuff();
		};

		flipXCheckBox = new PsychUICheckBox(singDurationStepper.x + 80, singDurationStepper.y, "Flip X", 50);
		flipXCheckBox.checked = char.flipX;
		if(char.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.onClick = function() {
			char.originalFlipX = !char.originalFlipX;
			char.flipX = char.originalFlipX;
			if(char.isPlayer) char.flipX = !char.flipX;

			ghostChar.flipX = char.flipX;
		};

		noAntialiasingCheckBox = new PsychUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = char.noAntialiasing;
		noAntialiasingCheckBox.onClick = function() {
			char.antialiasing = false;
			if(!noAntialiasingCheckBox.checked && ClientPrefs.globalAntialiasing) {
				char.antialiasing = true;
			}
			char.noAntialiasing = noAntialiasingCheckBox.checked;
			ghostChar.antialiasing = char.antialiasing;
		};

		positionXStepper = new PsychUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, char.positionArray[0]);
		positionXStepper.onValueChange = () -> {
			char.positionArray[0] = positionXStepper.value;
			char.x = char.positionArray[0] + 400;
			updatePointerPos();
			saveHistoryStuff();
		}

		positionYStepper = new PsychUINumericStepper(positionXStepper.x + 70, positionXStepper.y, 10, char.positionArray[1]);
		positionYStepper.onValueChange = () -> {
			char.positionArray[1] = positionYStepper.value;
			char.y = char.positionArray[1];
			updatePointerPos();
			saveHistoryStuff();
		}

		positionCameraXStepper = new PsychUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0]);
		positionCameraXStepper.onValueChange = () -> {
			char.cameraPosition[0] = positionCameraXStepper.value;
			updatePointerPos();
			saveHistoryStuff();
		};

		positionCameraYStepper = new PsychUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1]);
		positionCameraYStepper.onValueChange = () -> {
			char.cameraPosition[1] = positionCameraYStepper.value;
			updatePointerPos();
			saveHistoryStuff();
		};

		var healthColorButton:PsychUIButton = new PsychUIButton(singDurationStepper.x, noAntialiasingCheckBox.y + 40, "Health Bar Color", function() {
			openSubState(new ColorPickerSubstate(
				FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]),
				function(newColor:FlxColor) {
					char.healthColorArray[0] = newColor.red;
					char.healthColorArray[1] = newColor.green;
					char.healthColorArray[2] = newColor.blue;
					healthBarBG.color = newColor;
					saveHistoryStuff();
				},
				function():FlxColor {
					return FlxColor.fromInt(CoolUtil.dominantColor(leHealthIcon));
				},
				false,
				"Health Bar Color"
			));
		}, 140);
		healthColorButton.normalStyle.bgColor = FlxColor.fromRGB(0, 120, 180);
		healthColorButton.normalStyle.textColor = FlxColor.WHITE;

		tab_group.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tab_group.add(new FlxText(15, vocalsInputText.y - 18, 0, 'Vocals File Postfix:'));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tab_group.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(healthIconInputText);
		tab_group.add(vocalsInputText);
		tab_group.add(singDurationStepper);
		tab_group.add(scaleStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(healthColorButton);
	}

	function addAnimationsUI() {
		final tab_group = UI_characterbox.getTab('Animations').menu;

		animationInputText = new PsychUIInputText(15, 85, 80, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationNameFramerate = new PsychUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, "Should it Loop?", 100);

		animationDropDown = new PsychUIDropDownMenu(15, animationInputText.y - 55, null, (selectedAnimation:Int, pressed:String) -> {
			final anim:AnimArray = char.animationsArray[selectedAnimation];

			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationNameFramerate.value = anim.fps;
				
			if (anim.indices?.length > 0) 
				animationIndicesInputText.text = anim.indices.join(",");
			else animationIndicesInputText.text = '';

			curAnim = selectedAnimation;
			char.playAnim(anim.anim, true);
				
			if (ghostChar.visible) ghostChar.playAnim(anim.anim, true);
				
			genBoyOffsets();
		});

		var addUpdateButton:PsychUIButton = new PsychUIButton(70, animationIndicesInputText.y + 30, "Add/Update", () -> {
			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
			if(indicesStr.length > 1) {
				for (i in 0...indicesStr.length) {
					var index:Int = Std.parseInt(indicesStr[i]);
					if(indicesStr[i] != null && indicesStr[i] != '' && !Math.isNaN(index) && index > -1) {
						indices.push(index);
					}
				}
			}

			var lastAnim:String = '';
			if(char.animationsArray[curAnim] != null) {
				lastAnim = char.animationsArray[curAnim].anim;
			}

			var lastOffsets:Array<Int> = [0, 0];
			for (anim in char.animationsArray) {
				if(animationInputText.text == anim.anim) {
					lastOffsets = anim.offsets;
					if(char.hasAnimation(animationInputText.text))
					{
						#if flixel_animate
						if(char.isAnimateAtlas) char.anim.remove(animationInputText.text);
						else
						#end
							char.animation.remove(animationInputText.text);
					}
					char.animationsArray.remove(anim);
				}
			}

			var newAnim:AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationNameFramerate.value),
				loop: animationLoopCheckBox.checked,
				indices: indices,
				offsets: lastOffsets
			};
			
			#if flixel_animate
			if(char.isAnimateAtlas) {
				if(indices?.length > 0) {
					char.anim.addBySymbolIndices(newAnim.anim, newAnim.name, newAnim.indices, newAnim.fps, newAnim.loop);
				} else {
					char.anim.addBySymbol(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				}
			} else 
			#end
			{
				if(indices?.length > 0) {
					char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, "", newAnim.fps, newAnim.loop);
				} else {
					char.animation.addByPrefix(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				}
			}

			if(!char.hasAnimation(newAnim.anim)) char.addOffset(newAnim.anim, 0, 0);
			char.animationsArray.push(newAnim);

			if(lastAnim == animationInputText.text) {
				var leAnim:Dynamic = null;
				#if flixel_animate
				if(char.isAnimateAtlas) leAnim = char.anim.getByName(lastAnim);
				else
				#end
					leAnim = char.animation.getByName(lastAnim);
					
				if(leAnim?.frames.length > 0) {
					char.playAnim(lastAnim, true);
				} else {
					for(i in 0...char.animationsArray.length) {
						if(char.animationsArray[i] != null) {
							#if flixel_animate
							if(char.isAnimateAtlas) leAnim = char.anim.getByName(char.animationsArray[i].anim);
							else
							#end
								leAnim = char.animation.getByName(char.animationsArray[i].anim);
								
							if(leAnim?.frames.length > 0) {
								char.playAnim(char.animationsArray[i].anim, true);
								curAnim = i;
								break;
							}
						}
					}
				}
			}

			curAnim = char.animationsArray.length - 1;
			reloadAnimationDropDown();
			char.playAnim(animationInputText.text, true);
			if (ghostChar.visible) ghostChar.playAnim(animationInputText.text, true);

			genBoyOffsets();
			saveHistoryStuff();
		});

		var removeButton:PsychUIButton = new PsychUIButton(180, animationIndicesInputText.y + 30, "Remove", function() {
			for (anim in char.animationsArray) {
				if(animationInputText.text == anim.anim) {
					var resetAnim:Bool = false;
					if(anim.anim == char.getAnimationName()) resetAnim = true;

					if(char.hasAnimation(anim.anim))
					{
						#if flixel_animate
						if(char.isAnimateAtlas) char.anim.remove(anim.anim);
						else
						#end
							char.animation.remove(anim.anim);
						char.animOffsets.remove(anim.anim);
						char.animationsArray.remove(anim);
					}

					if(resetAnim && char.animationsArray.length > 0) {
                		char.playAnim(char.animationsArray[0].anim, true);
                		curAnim = 0;
						if (ghostChar.visible) {
							ghostChar.playAnim(char.animationsArray[0].anim, true);
						}
            		}

					if(resetAnim && char.animationsArray.length > 0)
						char.playAnim(char.animationsArray[0].anim, true);

					reloadAnimationDropDown();
					genBoyOffsets();
					saveHistoryStuff();
					break;
				}
			}
			saveHistoryStuff();
		});
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationNameFramerate.x, animationNameFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationNameFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
	}

	public function UIEvent(id:String, sender:Dynamic) {
		if (id == PsychUINumericStepper.CHANGE_EVENT) {
        	saveHistoryStuff();
    	}
	}

	function reloadCharacterImage() 
	{
		var lastAnim:String = char.getAnimationName() ?? '';
		
		#if flixel_animate
		if(char.isAnimateAtlas) {
			char.anim?.destroyAnimations();
			ghostChar.anim?.destroyAnimations();
		}
		#end
		
		char.animation.destroyAnimations();
		ghostChar.animation.destroyAnimations();

		if (char.graphic != null) {
			var oldGraphic = char.graphic;
			char.frames = null;
			ghostChar.frames = null;
			FlxG.bitmap.remove(oldGraphic);
		}

		if(Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			#if flixel_animate
			try {
				char.frames = Paths.getAnimateAtlas(char.imageFile);
				ghostChar.frames = Paths.getAnimateAtlas(char.imageFile);
			} catch(e:Dynamic) {}
			#end
		} else {
			if(Paths.fileExists('images/' + char.imageFile + '.txt', TEXT)) {
				char.frames = Paths.getPackerAtlas(char.imageFile);
				ghostChar.frames = Paths.getPackerAtlas(char.imageFile);
			}
			else if(Paths.fileExists('images/' + char.imageFile + '.json', TEXT)) {
				char.frames = Paths.getAsepriteAtlas(char.imageFile);
				ghostChar.frames = Paths.getAsepriteAtlas(char.imageFile);
			}
			else {
				char.frames = Paths.getSparrowAtlas(char.imageFile);
				ghostChar.frames = Paths.getSparrowAtlas(char.imageFile);
			}
		}

		if(char.animationsArray?.length > 0) {
			for (anim in char.animationsArray) {
				final animAnim:String = '' + anim.anim;
				final animName:String = '' + anim.name;
				final animFps:Int = anim.fps;
				final animLoop = anim.loop;
				final animIndices = anim.indices;
				
				#if flixel_animate
				if(char.isAnimateAtlas) 
				{
					if(animIndices?.length > 0)
						char.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else
						char.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					
					if(animIndices?.length > 0)
						ghostChar.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else
						ghostChar.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				} else 
				#end
				{
					if(animIndices?.length > 0) {
						char.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						ghostChar.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					} else {
						char.animation.addByPrefix(animAnim, animName, animFps, animLoop);
						ghostChar.animation.addByPrefix(animAnim, animName, animFps, animLoop);
					}
				}

				if(!char.hasAnimation(animAnim))
					char.addOffset(animAnim, 0, 0);

				if(!ghostChar.hasAnimation(animAnim))
					ghostChar.addOffset(animAnim, 0, 0);
			}
		}

		char.setPosition(char.positionArray[0] + 400, char.positionArray[1]);
		ghostChar.setPosition(char.x, char.y);
		
		if(char.animationsArray.length > 1) {
			if(lastAnim != '' && char.hasAnimation(lastAnim)) {
				char.playAnim(lastAnim, true);
				if(ghostChar.visible) ghostChar.playAnim(lastAnim, true);
			} else if(char.animationsArray.length > 0) {
				char.playAnim(char.animationsArray[0].anim, true);
				if(ghostChar.visible) ghostChar.playAnim(char.animationsArray[0].anim, true);
			}
		}
		
		reloadGhost();
		updatePointerPos(false);
		
		if(!char.isAnimationNull()) {
			char.playAnim(char.getAnimationName(), true);
		}
		saveHistoryStuff();
	}

	function genBoyOffsets():Void
	{
		var tab_group = UI_animList.getTab('Offsets').menu;
		
		var i:Int = tab_group.members.length - 1;
		while(i >= 0) {
			var memb = tab_group.members[i];
			if(memb != null) {
				memb.kill();
				tab_group.remove(memb, true);
				memb.destroy();
			}
			--i;
		}
		
		var daLoop:Int = 0;
		for (anim in char.animationsArray)
		{
			var offsets = char.animOffsets.get(anim.anim);

			var text:FlxText = new FlxText(10, 10 + (daLoop * 18), 0, anim.anim + ": " + offsets, 15);
			text.setFormat(null, 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.borderSize = 1;
			text.cameras = [camUI];
			
			tab_group.add(text);
			daLoop++;
		}

		if(tab_group.members.length < 1) {
			var text:FlxText = new FlxText(10, 10, 0, "ERROR! No animations found.", 15);
			text.borderSize = 1;
			tab_group.add(text);
			errorAnimText.visible = false;
		}

		for (i in 0...tab_group.members.length) {
			if (Std.isOfType(tab_group.members[i], FlxText)) {
				var text:FlxText = cast tab_group.members[i];
				if (i == curAnim) {
					text.color = FlxColor.BLUE;
					text.borderColor = FlxColor.BLACK;
					text.size = 18;
				} else {
					text.color = FlxColor.WHITE;
					text.size = 16;
				}
			}
		}
	}

	function loadChar(isDad:Bool, blahBlahBlah:Bool = true) {
		var i:Int = charLayer.members.length-1;
		while(i >= 0) {
			var memb:Character = charLayer.members[i];
			if(memb != null) {
				memb.kill();
				charLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		charLayer.clear();

		ghostChar = new Character(0, 0, daAnim, !isDad);
		ghostChar.debugMode = true;
		ghostChar.alpha = 0.6;
		ghostChar.visible = false;

		char = new Character(0, 0, daAnim, !isDad);
		if(char.animationsArray[0] != null) {
			char.playAnim(char.animationsArray[0].anim, true);
		}
		char.debugMode = true;

		charLayer.add(ghostChar);
		charLayer.add(char);

		char.setPosition(char.positionArray[0] + 400, char.positionArray[1]);

		undos = [];
    	redos = [];
    	curAnim = 0;

		if(blahBlahBlah) {
			genBoyOffsets();
			saveHistoryStuff();
		}
		reloadCharacterOptions();
		reloadBGs();
		updatePointerPos();
	}

	function updatePointerPos(?snap:Bool = true)
	{
		if(char == null || cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;
		
		if(!char.isPlayer)
		{
			offX = char.getMidpoint().x + 100 + char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		}
		else
		{
			offX = char.getMidpoint().x - 150 - char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		}
		cameraFollowPointer.setPosition(offX, offY);

		if(snap)
		{
			FlxG.camera.scroll.x = cameraFollowPointer.getMidpoint().x - FlxG.width/2;
			FlxG.camera.scroll.y = cameraFollowPointer.getMidpoint().y - FlxG.height/2;
		}
	}

	function findAnimationByName(name:String):AnimArray {
		for (anim in char.animationsArray) {
			if(anim.anim == name) {
				return anim;
			}
		}

		return char.animationsArray[0];
	}

	inline function reloadCharacterOptions() {
		if(UI_characterbox != null) {
			imageInputText.text = char.imageFile;
			healthIconInputText.text = char.healthIcon;
			vocalsInputText.text = char.vocalsFile ?? '';
			singDurationStepper.setValueSilent(char.singDuration);
			positionXStepper.setValueSilent(char.positionArray[0]);
			positionYStepper.setValueSilent(char.positionArray[1]);
			positionCameraXStepper.setValueSilent(char.cameraPosition[0]);
			positionCameraYStepper.setValueSilent(char.cameraPosition[1]);
			scaleStepper.setValueSilent(char.jsonScale);
			flipXCheckBox.checked = char.originalFlipX;
			noAntialiasingCheckBox.checked = char.noAntialiasing;
			leHealthIcon.changeIcon(healthIconInputText.text, false);

			healthBarBG.color = FlxColor.fromRGB(
				char.healthColorArray[0],
				char.healthColorArray[1],
				char.healthColorArray[2]
			);

			reloadAnimationDropDown();
			updatePresence();
		}
	}

	inline function reloadAnimationDropDown() {
		var animList:Array<String> = [];
		for (i in 0...char.animationsArray.length)
			animList.push(char.animationsArray[i].anim);

		if(animList.length < 1) animList.push('NO ANIMATIONS');

		animationDropDown.list = animList;
		genBoyOffsets();
	}

	function reloadGhost() 
	{
		var wasVisible = ghostChar.visible;
		var alpha = ghostChar.alpha;
		
		ghostChar.animOffsets.clear();

		#if flixel_animate
		if(ghostChar.isAnimateAtlas) {
			ghostChar.anim.destroyAnimations();
		} else 
		#end
		{
			ghostChar.animation.destroyAnimations();
		}
		
		for (anim in char.animationsArray) {
			var animAnim:String = anim.anim;
			var animName:String = anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = anim.loop;
			var animIndices:Array<Int> = anim.indices;
			
			#if flixel_animate
			if(ghostChar.isAnimateAtlas) {
				if(animIndices?.length > 0) {
					ghostChar.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
				} else {
					ghostChar.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				}
			} else 
			#end
			{
				if(animIndices?.length > 0) {
					ghostChar.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
				} else {
					ghostChar.animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
			}
			
			ghostChar.addOffset(animAnim, anim.offsets[0], anim.offsets[1]);
		}
		
		ghostChar.alpha = alpha;
		ghostChar.visible = wasVisible;
		ghostChar.antialiasing = char.antialiasing;
		ghostChar.flipX = char.flipX;
		
		if(ghostChar.visible && !char.isAnimationNull()) {
			var currentAnim = char.getAnimationName();
			if(ghostChar.hasAnimation(currentAnim)) {
				ghostChar.playAnim(currentAnim, true);
			}
		}
	}

	function reloadCharacterDropDown() {
		var charsLoaded:Map<String, Bool> = new Map();

		#if sys
		characterList = [];
		var directories:Array<String> = [#if MODS_ALLOWED Mods.getModPath('data/characters/'), Mods.getModPath(Mods.currentModDirectory + '/data/characters/'), #end Paths.getPreloadPath('data/characters/')];
		#if MODS_ALLOWED
		for(mod in Mods.getGlobalMods())
			directories.push(Mods.getModPath(mod + '/data/characters/'));
		#end
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						try {
							final charToCheck:String = file.substr(0, file.length - 5);
							final rawJson:String = sys.io.File.getContent(path);

							if(rawJson?.length > 0 && !charsLoaded.exists(charToCheck)) {
								final json = haxe.Json.parse(rawJson);

								if(json != null && Reflect.hasField(json, "animations") && Reflect.hasField(json, "image")) {
									characterList.push(charToCheck);
									charsLoaded.set(charToCheck, true);
								}
							}
						} catch(e) {
							trace('Error parsing character file: $path');
						}
					}
				}
			}
		}
		#else
		characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));
		#end

		if(characterList.length < 1) characterList.push('');
		charDropDown.list = characterList;
		charDropDown.selectedLabel = daAnim;
	}

	function updatePresence() {
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Character Editor", "Character: " + daAnim, leHealthIcon.getCharacter());
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.state.subState != null) return;

		final blockInput = PsychUIInputText.focusOn != null;

		handleAutoSave(elapsed);
		handleAnimationValidityCheck();

		if(!blockInput)
		{
			ClientPrefs.toggleVolumeKeys();
			handleHotkeys();
			handleCopyPasteUndoRedo();
			handleExit();
			handleCameraZoom(elapsed);
			handleCameraDrag();
			handleAnimationNavigation();
			handleOffsetReset();
			handleArrowKeyMovement(elapsed);
		} else {
			ClientPrefs.toggleVolumeKeys(false);
		}

		updateVisuals();
	}

	function handleAutoSave(elapsed:Float):Void
	{
		lastAutoSaveTime += elapsed;
		if(lastAutoSaveTime >= AUTO_SAVE_INTERVAL) {
			lastAutoSaveTime = 0;
			saveBackup();
		}
	}

	function handleAnimationValidityCheck():Void
	{
		if(char.animationsArray[curAnim] != null) {
			var animName = char.animationsArray[curAnim].anim;
			var validAnim = false;
			
			if(char.isAnimateAtlas) {
				#if flixel_animate
				validAnim = char.anim.getByName(animName) != null;
				#end
			} else {
				final anim = char.animation.getByName(animName);
				validAnim = anim?.frames?.length > 0;
			}
			
			errorAnimText.visible = !validAnim;
		} else {
			errorAnimText.visible = false;
		}
	}

	function handleHotkeys():Void
	{
		if (FlxG.keys.justPressed.F1)
			openSubState(new CharacterEditorTipsSubstate());

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
			saveCharacter(FlxG.keys.pressed.SHIFT);
	}

	function handleGridToggle(?forced:Bool = false):Void
	{
		if (forced || FlxG.keys.justPressed.G) {
    		gridVisible = !gridVisible;
    		grid.visible = gridVisible;
		}
	}

	function handleCopyPasteUndoRedo():Void
	{
		var changedOffset = false;
		
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.C) {
				copiedOffsets = char.animationsArray[curAnim].offsets.copy();
				changedOffset = true;
			}

			if (FlxG.keys.justPressed.V) {
				char.animationsArray[curAnim].offsets = copiedOffsets.copy();
				char.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
				ghostChar.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
				char.playAnim(char.animationsArray[curAnim].anim, false);
				genBoyOffsets();
				saveHistoryStuff();
				changedOffset = true;
			}

			if (FlxG.keys.justPressed.Z)
				undo();

			if (FlxG.keys.justPressed.Y)
				redo();
		}
		
		if (changedOffset) {
			saveOffsetChanges();
		}
	}

	function handleExit(?forced:Bool = false):Void
	{
		if (forced || FlxG.keys.justPressed.ESCAPE) {
			if(goToPlayState) {
				FlxG.switchState(() -> new PlayState());
			} else {
				FlxG.switchState(() -> new game.states.editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}
			FlxG.mouse.visible = false;
			return;
		}
	}

	function handleCameraZoom(elapsed:Float):Void
	{
		var shiftMult:Float = FlxG.keys.pressed.SHIFT ? 4 : 1;
		var ctrlMult:Float = FlxG.keys.pressed.CONTROL ? 0.25 : 1;

		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) {
			FlxG.camera.zoom = 1;
		}
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += Math.min(elapsed, 0.05) * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom >= 3) FlxG.camera.zoom = 3;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= Math.min(elapsed, 0.05) * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom <= 0.1) FlxG.camera.zoom = 0.1;
		}
	}

	function handleCameraDrag():Void
	{
		var overlapsMenu = topMenu != null && FlxG.mouse.overlaps(topMenu.bg, camUI);
		if (topMenu?.menuItems != null) 
		{
			for (item in topMenu.menuItems) 
			{
				if (item.isExpanded) 
				{
					for (drop in item.dropDownItems)
						if (FlxG.mouse.overlaps(drop.bg, camUI)) overlapsMenu = true;
				}
			}
		}

		if (!(FlxG.mouse.overlaps(UI_box.bg, camUI) || FlxG.mouse.overlaps(UI_characterbox.bg, camUI) || FlxG.mouse.overlaps(UI_animList.bg, camUI) || overlapsMenu))
		{
			if (FlxG.mouse.pressed && FlxG.mouse.justPressed && PsychUIInputText.focusOn == null)
			{
				draggingCamera = true;
				cameraScrollTarget.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
			}
			
			if (FlxG.mouse.justReleased)
			{
				draggingCamera = false;
			}
			
			if (draggingCamera && FlxG.mouse.pressed)
			{
				final deltaX = FlxG.mouse.deltaViewX * cameraDragSensitivity;
				final deltaY = FlxG.mouse.deltaViewY * cameraDragSensitivity;
				
				cameraScrollTarget.x -= deltaX;
				cameraScrollTarget.y -= deltaY;

				FlxG.camera.scroll.x += (cameraScrollTarget.x - FlxG.camera.scroll.x) * cameraSmoothness;
				FlxG.camera.scroll.y += (cameraScrollTarget.y - FlxG.camera.scroll.y) * cameraSmoothness;
			}
		}
	}

	function handleAnimationNavigation():Void
	{
		if(char.animationsArray?.length > 0 && !FlxG.keys.pressed.CONTROL) 
		{
			if (FlxG.keys.justPressed.W)
				curAnim--;

			if (FlxG.keys.justPressed.S)
				curAnim++;

			if (curAnim < 0)
				curAnim = char.animationsArray.length - 1;

			if (curAnim >= char.animationsArray.length)
				curAnim = 0;

			if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
			{
				if (char.animationsArray[curAnim] != null) 
				{
					char.playAnim(char.animationsArray[curAnim].anim, true);
					if (!ghostSingleAnimMode && ghostChar.visible)
						ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
					genBoyOffsets();
				}
			}
		}
	}

	function handleOffsetReset():Void
	{
		if (FlxG.keys.justPressed.T && char.animationsArray?.length > 0) 
		{
			final originalOffsets = char.animationsArray[curAnim].offsets.copy();
				
			char.animationsArray[curAnim].offsets = [0, 0];
			char.addOffset(char.animationsArray[curAnim].anim, 0, 0);
			ghostChar.addOffset(char.animationsArray[curAnim].anim, 0, 0);
				
			char.playAnim(char.animationsArray[curAnim].anim, false);
			ghostChar.playAnim(char.animationsArray[curAnim].anim, false);
				
			genBoyOffsets();
			saveHistoryStuff();
				
			char.animationsArray[curAnim].offsets = originalOffsets;
		}
	}

	function handleArrowKeyMovement(elapsed:Float)
	{
		if (char.animationsArray.length == 0) return;

		final leftP = FlxG.keys.pressed.LEFT;
		final rightP = FlxG.keys.pressed.RIGHT;
		final upP = FlxG.keys.pressed.UP;
		final downP = FlxG.keys.pressed.DOWN;
		
		final leftJ = FlxG.keys.justPressed.LEFT;
		final rightJ = FlxG.keys.justPressed.RIGHT;
		final upJ = FlxG.keys.justPressed.UP;
		final downJ = FlxG.keys.justPressed.DOWN;

		var shiftMultBig = FlxG.keys.pressed.SHIFT ? 10 : 1;
		var offsetChanged = false;

		if (leftJ || rightJ || upJ || downJ) 
		{
			final dx = ((leftJ ? 1 : 0) - (rightJ ? 1 : 0)) * shiftMultBig;
			final dy = ((upJ ? 1 : 0) - (downJ ? 1 : 0)) * shiftMultBig;

			char.offset.x += dx;
			char.offset.y += dy;
			offsetChanged = true;
		}

		if (leftP || rightP || upP || downP) 
		{
			holdingArrowsTime += elapsed;
			if (holdingArrowsTime > 0.6) 
			{
				holdingArrowsElapsed += elapsed;
				while (holdingArrowsElapsed > (1 / 60)) 
				{
					final dx = ((leftP ? 1 : 0) - (rightP ? 1 : 0)) * shiftMultBig;
					final dy = ((upP ? 1 : 0) - (downP ? 1 : 0)) * shiftMultBig;

					char.offset.x += dx;
					char.offset.y += dy;

					holdingArrowsElapsed -= (1 / 60);
					offsetChanged = true;
				}
			}
		} else {
			holdingArrowsTime = 0;
		}

		if (offsetChanged) saveOffsetChanges();
	}

	function saveOffsetChanges()
	{
		if (char.animationsArray[curAnim] != null) {
			final curX = char.offset.x;
			final curY = char.offset.y;

			final animName = char.animationsArray[curAnim].anim;
			char.animOffsets.set(animName, [curX, curY]);

			for (anim in char.animationsArray) {
				if (anim.anim == animName) {
					anim.offsets = [Std.int(curX), Std.int(curY)];
					break;
				}
			}

			if (ghostChar.visible && !ghostChar.isAnimationNull() && ghostChar.getAnimationName() == animName) {
				ghostChar.animOffsets.set(animName, [curX, curY]);
				ghostChar.offset.set(curX, curY);
			}

			genBoyOffsets();
			saveHistoryStuff();
		}
	}

	function updateVisuals():Void
	{
		ghostChar.setPosition(char.x, char.y);
	}

	var _file:FileReference;
	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved CHARACTER DATA.");
	}

	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Character data");
	}

	function saveBackup() {
		try {
			#if sys
			var backupDir = 'backups/characters/';
			if (!sys.FileSystem.exists(backupDir))
				sys.FileSystem.createDirectory(backupDir);
			#end

			var json:CharacterFile = {
				"animations": char.animationsArray,
				"image": char.imageFile,
				"scale": char.jsonScale,
				"sing_duration": char.singDuration,
				"healthicon": char.healthIcon,
				"position": char.positionArray,
				"camera_position": char.cameraPosition,
				"flip_x": char.originalFlipX,
				"no_antialiasing": char.noAntialiasing,
				"vocals_file": char.vocalsFile,
				"healthbar_colors": char.healthColorArray
			};

			var data:String = Json.stringify(json, "\t");
			#if sys
			sys.io.File.saveContent(backupDir + daAnim + '_backup.json', data);
			#end
		} catch(e) {
			trace('Failed to create backup: ' + e.message);
		}
	}

	function saveCharacter(forceDialog:Bool = false) {
		try {
			final json:CharacterFile = {
				"animations": char.animationsArray,
				"image": char.imageFile,
				"scale": char.jsonScale,
				"sing_duration": char.singDuration,
				"healthicon": char.healthIcon,
				"position": char.positionArray,
				"camera_position": char.cameraPosition,
				"flip_x": char.originalFlipX,
				"no_antialiasing": char.noAntialiasing,
				"vocals_file": char.vocalsFile,
				"healthbar_colors": char.healthColorArray
			};

			final data:String = Json.stringify(json, "\t");
			if (data.length > 0)
			{
				#if sys
				if (!forceDialog) 
				{
					final relativePath = Paths.json('characters/' + daAnim);
					final absolutePath = FileUtil.getAbsolutePath(relativePath);

					final dir = haxe.io.Path.directory(absolutePath);
					if (!sys.FileSystem.exists(dir))
						sys.FileSystem.createDirectory(dir);

					sys.io.File.saveContent(absolutePath, data);
					
					FlxG.sound.play(Paths.sound('confirmMenu'), 0.3);
					return;
				}
				#end

				if (_file == null) 
				{
					_file = new FileReference();
					_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
					_file.addEventListener(Event.CANCEL, onSaveCancel);
					_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
					_file.save(data, daAnim + ".json");
				}
			}
		} catch(e) {
			trace('Failed to save character: ' + e.message);
		}
	}

	function saveHistoryStuff() {
		var state:HistoryStuff = {
			animations: [for (anim in char.animationsArray) {
				anim: anim.anim,
				name: anim.name,
				fps: anim.fps,
				loop: anim.loop,
				indices: anim.indices.copy(),
				offsets: anim.offsets.copy()
			}],
			position: char.positionArray.copy(),
			scale: char.jsonScale,
			cameraPosition: char.cameraPosition.copy(),
			healthColor: char.healthColorArray.copy(),
			curAnim: curAnim
		};
		
		undos.push(state);
		if (undos.length > maxHistorySteps) undos.shift();
		
		redos = [];
	}

	function undo() {
		if (undos.length == 0) return;
		
		redos.push(getCurrentState());
		restoreState(undos.pop());
		
		reloadCharacterOptions();
		genBoyOffsets();
	}

	function redo() {
		if (redos.length == 0) return;
		
		undos.push(getCurrentState());
		restoreState(redos.pop());
		
		reloadCharacterOptions();
		genBoyOffsets();
	}

	function getCurrentState():HistoryStuff {
		return {
			animations: [for (anim in char.animationsArray) {
				anim: anim.anim,
				name: anim.name,
				fps: anim.fps,
				loop: anim.loop,
				indices: anim.indices.copy(),
				offsets: anim.offsets.copy()
			}],
			position: char.positionArray.copy(),
			scale: char.jsonScale,
			cameraPosition: char.cameraPosition.copy(),
			healthColor: char.healthColorArray.copy(),
			curAnim: curAnim
		};
	}

	function restoreState(state:HistoryStuff) {
		char.animationsArray = [for (anim in state.animations) anim];
		ghostChar.animationsArray = [for (anim in state.animations) anim];

		for (anim in char.animationsArray) 
		{
			char.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			ghostChar.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
		}
		
		char.positionArray = state.position.copy();
		char.cameraPosition = state.cameraPosition.copy();
		char.jsonScale = state.scale;
		char.healthColorArray = state.healthColor.copy();

		if (char.animationsArray.length > 0) 
		{
			char.playAnim(char.animationsArray[curAnim].anim, true);
			if (ghostChar.visible) ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
		}

		curAnim = state.curAnim;
		if (curAnim <= 0) curAnim = 0;
		if (curAnim >= char.animationsArray.length) curAnim = char.animationsArray.length - 1;
		
		reloadAnimationDropDown();
		reloadGhost();
		reloadCharacterOptions();
		reloadCharacterImage();
		updatePointerPos();
		genBoyOffsets();

		char.setPosition(char.positionArray[0] + 400, char.positionArray[1]);
    	ghostChar.setPosition(char.x, char.y);
	}

	override function destroy() {
		cameraScrollTarget.put();
		super.destroy();
	}
}

class ColorPickerSubstate extends MusicBeatSubstate
{
	var colorPicker:PsychUIColorPicker;
	var onColorSelected:FlxColor->Void;
	var getIconColorCallback:Void->FlxColor;
	
	var bg:FlxSprite;
	var panel:FlxSprite;
	var okButton:PsychUIButton;
	var cancelButton:PsychUIButton;
	var getIconColorButton:PsychUIButton;
	
	public function new(defaultColor:FlxColor, onColorSelected:FlxColor->Void, ?getIconColorCallback:Void->FlxColor, showAlpha:Bool = false, title:String = "Select Color")
	{
		super();

		this.onColorSelected = onColorSelected;
		this.getIconColorCallback = getIconColorCallback;

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.cameras = cameras;
		add(bg);

		var panelWidth = 400;
		var panelHeight = showAlpha ? 380 : 350;
		panel = new FlxSprite();
		panel.makeGraphic(panelWidth, panelHeight, FlxColor.BLACK);
		panel.scrollFactor.set();
		panel.screenCenter();
		panel.alpha = 0.85;
		panel.cameras = cameras;
		add(panel);

		var titleText = new FlxText(panel.x, panel.y + 10, panelWidth, title, 16);
		titleText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		titleText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
		titleText.scrollFactor.set();
		titleText.cameras = cameras;
		add(titleText);

		colorPicker = new PsychUIColorPicker(
			panel.x + (panelWidth - 250) / 2,
			panel.y + 40,
			defaultColor,
			null,
			showAlpha,
			""
		);
		colorPicker.broadcastPickerEvent = false;
		colorPicker.scrollFactor.set();
		colorPicker.cameras = cameras;
		add(colorPicker);

		var buttonY = panel.y + panelHeight - 40;
		var buttonSpacing = 10;

		okButton = new PsychUIButton(0, buttonY, "OK", () -> {
			if (onColorSelected != null) {
				onColorSelected(colorPicker.selectedColor);
			}
			close();
		}, 80);
		okButton.scrollFactor.set();
		okButton.normalStyle.bgColor = FlxColor.fromRGB(0, 180, 0);
		okButton.normalStyle.textColor = FlxColor.WHITE;
		okButton.cameras = cameras;

		cancelButton = new PsychUIButton(0, buttonY, "Cancel", () -> close(), 80);
		cancelButton.scrollFactor.set();
		cancelButton.normalStyle.bgColor = FlxColor.fromRGB(180, 0, 0);
		cancelButton.normalStyle.textColor = FlxColor.WHITE;
		cancelButton.cameras = cameras;

		if (getIconColorCallback != null) {
			getIconColorButton = new PsychUIButton(0, buttonY, "Get Icon Color", () -> {
				var iconColor = getIconColorCallback();
				colorPicker.setColor(iconColor);
			}, 120);
			getIconColorButton.scrollFactor.set();
			getIconColorButton.normalStyle.bgColor = FlxColor.fromRGB(0, 120, 180);
			getIconColorButton.normalStyle.textColor = FlxColor.WHITE;
			getIconColorButton.cameras = cameras;

			var totalWidth = okButton.width + cancelButton.width + getIconColorButton.width + buttonSpacing * 2;
			var startX = panel.x + (panelWidth - totalWidth) / 2;

			okButton.x = startX;
			getIconColorButton.x = okButton.x + okButton.width + buttonSpacing;
			cancelButton.x = getIconColorButton.x + getIconColorButton.width + buttonSpacing;

			add(getIconColorButton);
		} else {
			var totalWidth = okButton.width + cancelButton.width + buttonSpacing;
			var startX = panel.x + (panelWidth - totalWidth) / 2;

			okButton.x = startX;
			cancelButton.x = okButton.x + okButton.width + buttonSpacing;
		}

		add(okButton);
		add(cancelButton);
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(PsychUIInputText.focusOn != null)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);
		
		if (FlxG.keys.justPressed.ESCAPE || controls.BACK)
			close();
	}
}

class CharacterEditorTipsSubstate extends MusicBeatSubstate
{
	public function new()
	{
		super();

		final bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scrollFactor.set();
		add(bg);

		final panel = new FlxSprite(0, 0);
		panel.makeGraphic(900, 600, FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawRoundRect(panel, 0, 0, 900, 600, 20, 20, 0xDD111111);
		flixel.util.FlxSpriteUtil.drawRoundRect(panel, 2, 2, 896, 596, 20, 20, FlxColor.TRANSPARENT, {thickness: 2, color: 0xFF555555});
		panel.screenCenter();
		panel.scrollFactor.set();
		add(panel);

		final title = new FlxText(0, panel.y + 20, FlxG.width, "CHARACTER EDITOR SHORTCUTS", 28);
		title.setFormat(null, 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.scrollFactor.set();
		add(title);

		final shortcutsLeft = [
			"E/Q - Zoom In / Zoom Out",
			"R - Reset Zoom",
			"Drag Mouse - Move Camera",
			"",
			"W/S - Previous / Next Animation",
			"SPACE - Play Current Animation",
			"G - Toggle Grid Visibility",
			"ESC - Exit to Menu"
		];
		
		final shortcutsRight = [
			"Arrow Keys - Move Offset",
			"Shift + Arrows - Move Offset 10x Faster",
			"T - Reset Current Offset",
			"",
			"CTRL + C - Copy Offsets",
			"CTRL + V - Paste Offsets",
			"CTRL + Z / Y - Undo / Redo",
			"CTRL + S - Save Character"
		];

		final startY = panel.y + 120;
		for (i in 0...shortcutsLeft.length) {
			final text = new FlxText(panel.x + 30, startY + (i * 35), 400, shortcutsLeft[i], 16);
			text.setFormat(null, 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			add(text);
		}
		
		for (i in 0...shortcutsRight.length) {
			final text = new FlxText(panel.x + 450, startY + (i * 35), 400, shortcutsRight[i], 16);
			text.setFormat(null, 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			add(text);
		}

		final saveAsText = new FlxText(0, panel.y + 480, FlxG.width, "CTRL + SHIFT + S  -  Save Character As... (Open Dialog)", 18);
		saveAsText.setFormat(null, 18, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		saveAsText.scrollFactor.set();
		add(saveAsText);

		final closeText = new FlxText(0, panel.y + 550, FlxG.width, "Press F1 or ESC to close", 16);
		closeText.setFormat(null, 16, 0xFFAAAAAA, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		closeText.scrollFactor.set();
		add(closeText);

		camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.F1 || FlxG.keys.justPressed.ESCAPE) {
			close();
		}
	}
}