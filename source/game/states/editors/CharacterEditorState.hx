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
	var makeGhostButton:PsychUIButton;
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

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationNameFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var arrowKeysPressed:Array<Bool> = [false, false, false, false];
	var arrowKeysJustPressed:Array<Bool> = [false, false, false, false];

	public function new(daAnim:String = 'bf', goToPlayState:Bool = true)
	{
		super();
		this.daAnim = daAnim;
		this.goToPlayState = goToPlayState;
	}

	override function create()
	{
		camEditor = initFunkinCamera();
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

		var pointer:FlxGraphic = FlxGraphic.fromClass(GraphicCursorCross);
		cameraFollowPointer = new FlxSprite().loadGraphic(pointer);
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
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

		errorAnimText = new FlxText(300, 16, "ERROR ON LOADING ANIMATION");
		errorAnimText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorAnimText.scrollFactor.set();
		errorAnimText.borderSize = 1;
		errorAnimText.cameras = [camUI];
		errorAnimText.visible = false;
		add(errorAnimText);

		FlxG.camera.zoom = 1;
		FlxG.mouse.visible = true;

		createUIMenu();

		genBoyOffsets();

		addGhostUI();
		addSettingsUI();
		addCharacterUI();
		addAnimationsUI();

		UI_box.selectedName = 'Settings';
		UI_characterbox.selectedName = 'Character';

		var pressF1Text:FlxText = new FlxText(0, FlxG.height - 20, 0, "Press F1 to open tips", 8);
		pressF1Text.setFormat(Paths.font("pixel-latin.ttf"), 8, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		pressF1Text.scrollFactor.set();
		pressF1Text.cameras = [camUI];
		pressF1Text.borderSize = 1;
		add(pressF1Text);

		reloadCharacterOptions();

		super.create();
	}

	function createUIMenu()
	{
		UI_box = new PsychUIBox(FlxG.width - 275, 25, 250, 120, ['Ghost', 'Settings']);
		UI_box.cameras = [camUI];

		UI_characterbox = new PsychUIBox(UI_box.x - 100, UI_box.y + UI_box.height + 10, 350, 280, ['Animations', 'Character']);
		UI_characterbox.cameras = [camUI];

		UI_animList = new PsychUIBox(10, 25, 280, 450, ['Offsets']);
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

	function addGhostUI()
	{
		var tab_group = UI_box.getTab('Ghost').menu;

		makeGhostButton = new PsychUIButton(25, 15, "Make Ghost", () -> {
			ghostChar.visible = !ghostChar.visible;
			makeGhostButton.label = ghostChar.visible ? "Hide Ghost" : "Make Ghost";
			
			if (ghostChar.visible) {
				ghostAnim = (!char.isAnimateAtlas) ? char.animation.curAnim.name : char.atlas.anim.curAnim.name;
				ghostSingleAnimMode = true;
			}
			reloadGhost();
		});

		var highlightGhost:PsychUICheckBox = new PsychUICheckBox(20 + makeGhostButton.x + makeGhostButton.width, makeGhostButton.y, "Highlight Ghost", 100);
		highlightGhost.onClick = function()
		{
			final value = highlightGhost.checked ? 125 : 0;
			ghostChar.colorTransform.redOffset = value;
			ghostChar.colorTransform.greenOffset = value;
			ghostChar.colorTransform.blueOffset = value;
		};

		var ghostAlphaSlider:PsychUISlider = new PsychUISlider(15, makeGhostButton.y + 25, function(v:Float)
		{
			ghostAlpha = v;
			ghostChar.alpha = ghostAlpha;

		}, ghostAlpha, 0, 1);
		ghostAlphaSlider.label = 'Opacity:';

		tab_group.add(makeGhostButton);
		tab_group.add(highlightGhost);
		tab_group.add(ghostAlphaSlider);
	}

	function addSettingsUI() {
		var tab_group = UI_box.getTab('Settings').menu;

		var check_player = new PsychUICheckBox(10, 60, "Playable Character", 100);
		check_player.checked = daAnim.startsWith('bf');
		check_player.onClick = function()
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;
			updatePointerPos(false);
			reloadBGs();
			ghostChar.flipX = char.flipX;
		};

		charDropDown = new PsychUIDropDownMenu(10, 30, [''], function(index:Int, intended:String)
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

		var reloadCharacter:PsychUIButton = new PsychUIButton(140, 20, "Reload Char", function()
		{
			loadChar(!check_player.checked);
			reloadCharacterDropDown();
		});

		var templateCharacter:PsychUIButton = new PsychUIButton(140, 50, "Load Template", function()
		{
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
		});
		templateCharacter.normalStyle.bgColor = FlxColor.RED;
		templateCharacter.normalStyle.textColor = FlxColor.WHITE;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tab_group.add(check_player);
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);
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

		var saveCharacterButton:PsychUIButton = new PsychUIButton(reloadImage.x, noAntialiasingCheckBox.y + 40, "Save Character", () -> saveCharacter());

		var healthColorButton:PsychUIButton = new PsychUIButton(singDurationStepper.x, saveCharacterButton.y, "Health Bar Color", function() {
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
		tab_group.add(saveCharacterButton);
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
						if(!char.isAnimateAtlas) char.animation.remove(animationInputText.text);
						else char.atlas.anim.remove(animationInputText.text);
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
			if(char.isAnimateAtlas) {
				if(indices?.length > 0) {
					char.atlas.anim.addBySymbolIndices(newAnim.anim, newAnim.name, newAnim.indices, newAnim.fps, newAnim.loop);
				} else {
					char.atlas.anim.addBySymbol(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				}
			} else {
				if(indices?.length > 0) {
					char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, "", newAnim.fps, newAnim.loop);
				} else {
					char.animation.addByPrefix(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				}
			}

			if(!char.hasAnimation(newAnim.anim)) char.addOffset(newAnim.anim, 0, 0);
			char.animationsArray.push(newAnim);

			if(lastAnim == animationInputText.text) {
				var leAnim = !char.isAnimateAtlas ? char.animation.getByName(lastAnim) : char.atlas.anim.getByName(lastAnim);
				if(leAnim?.frames.length > 0) {
					char.playAnim(lastAnim, true);
				} else {
					for(i in 0...char.animationsArray.length) {
						if(char.animationsArray[i] != null) {
							leAnim = !char.isAnimateAtlas ? char.animation.getByName(char.animationsArray[i].anim) : char.atlas.anim.getByName(char.animationsArray[i].anim);
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
						if(!char.isAnimateAtlas) char.animation.remove(anim.anim);
						else char.atlas.anim.remove(anim.anim);
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

					if(resetAnim && char.animationsArray.length > 0) {
						char.playAnim(char.animationsArray[0].anim, true);
					}
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
		
		char.atlas = FlxDestroyUtil.destroy(char.atlas);
		char.isAnimateAtlas = false;

		ghostChar.atlas = FlxDestroyUtil.destroy(ghostChar.atlas);
		ghostChar.isAnimateAtlas = false;

		if(Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			#if flixel_animate
			char.isAnimateAtlas = true;
			ghostChar.isAnimateAtlas = true;

			char.atlas = new FlxAnimate();
			char.atlas.frames = Paths.getAnimateAtlas(char.imageFile);
			
			ghostChar.atlas = new FlxAnimate();
			ghostChar.atlas.frames = Paths.getAnimateAtlas(char.imageFile);
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

		if(char.animationsArray != null && char.animationsArray.length > 0) {
			for (anim in char.animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop = anim.loop;
				var animIndices = anim.indices;
				
				if(char.isAnimateAtlas) {
					#if flixel_animate
					if(animIndices?.length > 0) {
						char.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					} else {
						char.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					}
					
					if(animIndices?.length > 0) {
						ghostChar.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					} else {
						ghostChar.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					}
					#end
				} else {
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
		
		ghostChar.isAnimateAtlas = char.isAnimateAtlas;
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

		ghostChar.isAnimateAtlas = char.isAnimateAtlas;

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
			singDurationStepper.value = char.singDuration;
			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];
			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];
			scaleStepper.value = char.jsonScale;
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
		for (i in 0...char.animationsArray.length) {
			animList.push(char.animationsArray[i].anim);
		}
		if(animList.length < 1) animList.push('NO ANIMATIONS');

		animationDropDown.list = animList;
		genBoyOffsets();
	}

	function reloadGhost() 
	{
		var wasVisible = ghostChar.visible;
		var alpha = ghostChar.alpha;
		
		ghostChar.animOffsets.clear();

		if(ghostChar.isAnimateAtlas) {
			#if flixel_animate
			ghostChar.atlas?.anim.destroyAnimations();
			#end
		} else {
			ghostChar.animation.destroyAnimations();
		}
		
		for (anim in char.animationsArray) {
			var animAnim:String = anim.anim;
			var animName:String = anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = anim.loop;
			var animIndices:Array<Int> = anim.indices;
			
			if(ghostChar.isAnimateAtlas) {
				#if flixel_animate
				if(animIndices?.length > 0) {
					ghostChar.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
				} else {
					ghostChar.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				}
				#end
			} else {
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
			handleGridToggle();
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
				validAnim = char.atlas.anim.getByName(animName) != null;
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
		if (FlxG.keys.justPressed.F1) {
			openSubState(new CharacterEditorTipsSubstate());
		}
	}

	function handleGridToggle():Void
	{
		if (FlxG.keys.justPressed.G) {
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

			if (FlxG.keys.justPressed.Z) {
				undo();
			}

			if (FlxG.keys.justPressed.Y) {
				redo();
			}
		}
		
		if (changedOffset) {
			saveOffsetChanges();
		}
	}

	function handleExit():Void
	{
		if (FlxG.keys.justPressed.ESCAPE) {
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

		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom >= 3) FlxG.camera.zoom = 3;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom <= 0.1) FlxG.camera.zoom = 0.1;
		}
	}

	function handleCameraDrag():Void
	{
		if (!(FlxG.mouse.overlaps(UI_box.bg, camUI) || FlxG.mouse.overlaps(UI_characterbox.bg, camUI) || FlxG.mouse.overlaps(UI_animList.bg, camUI)))
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
		if(char.animationsArray.length > 0) {
			if (FlxG.keys.justPressed.W)
			{
				curAnim--;
			}

			if (FlxG.keys.justPressed.S)
			{
				curAnim++;
			}

			if (curAnim < 0)
				curAnim = char.animationsArray.length - 1;

			if (curAnim >= char.animationsArray.length)
				curAnim = 0;

			if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
			{
				char.playAnim(char.animationsArray[curAnim].anim, true);
				if (!ghostSingleAnimMode && ghostChar.visible)
					ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
				genBoyOffsets();
			}
		}
	}

	function handleOffsetReset():Void
	{
		if (FlxG.keys.justPressed.T && char.animationsArray.length > 0) {
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

		updateArrowKeyStates();

		var shiftMultBig = FlxG.keys.pressed.SHIFT ? 10 : 1;
		var offsetChanged = false;

		if (arrowKeysJustPressed.contains(true)) {
			final dx = ((arrowKeysJustPressed[0] ? 1 : 0) - (arrowKeysJustPressed[1] ? 1 : 0)) * shiftMultBig;
			final dy = ((arrowKeysJustPressed[2] ? 1 : 0) - (arrowKeysJustPressed[3] ? 1 : 0)) * shiftMultBig;

			if (char.isAnimateAtlas) {
				char.atlas.offset.x += dx;
				char.atlas.offset.y += dy;
			} else {
				char.offset.x += dx;
				char.offset.y += dy;
			}
			offsetChanged = true;
		}

		if (arrowKeysPressed.contains(true)) {
			holdingArrowsTime += elapsed;
			if (holdingArrowsTime > 0.6) {
				holdingArrowsElapsed += elapsed;
				while (holdingArrowsElapsed > (1 / 60)) {
					final dx = ((arrowKeysPressed[0] ? 1 : 0) - (arrowKeysPressed[1] ? 1 : 0)) * shiftMultBig;
					final dy = ((arrowKeysPressed[2] ? 1 : 0) - (arrowKeysPressed[3] ? 1 : 0)) * shiftMultBig;

					if (char.isAnimateAtlas) {
						char.atlas.offset.x += dx;
						char.atlas.offset.y += dy;
					} else {
						char.offset.x += dx;
						char.offset.y += dy;
					}

					holdingArrowsElapsed -= (1 / 60);
					offsetChanged = true;
				}
			}
		} else {
			holdingArrowsTime = 0;
		}

		if (offsetChanged) saveOffsetChanges();
	}

	function updateArrowKeyStates():Void
	{
		arrowKeysPressed[0] = FlxG.keys.pressed.LEFT;
		arrowKeysPressed[1] = FlxG.keys.pressed.RIGHT;
		arrowKeysPressed[2] = FlxG.keys.pressed.UP;
		arrowKeysPressed[3] = FlxG.keys.pressed.DOWN;
		
		arrowKeysJustPressed[0] = FlxG.keys.justPressed.LEFT;
		arrowKeysJustPressed[1] = FlxG.keys.justPressed.RIGHT;
		arrowKeysJustPressed[2] = FlxG.keys.justPressed.UP;
		arrowKeysJustPressed[3] = FlxG.keys.justPressed.DOWN;
	}

	function saveOffsetChanges()
	{
		if (char.animationsArray[curAnim] != null) {
			final curX = char.isAnimateAtlas ? char.atlas.offset.x : char.offset.x;
			final curY = char.isAnimateAtlas ? char.atlas.offset.y : char.offset.y;

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

	function saveCharacter() {
		if(_file != null) return;

		try {
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

			if (data.length > 0)
			{
				_file = new FileReference();
				_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
				_file.addEventListener(Event.CANCEL, onSaveCancel);
				_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
				_file.save(data, daAnim + ".json");
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

		for (anim in char.animationsArray) {
			char.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			ghostChar.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
		}
		
		char.positionArray = state.position.copy();
		char.cameraPosition = state.cameraPosition.copy();
		char.jsonScale = state.scale;
		char.healthColorArray = state.healthColor.copy();

		if (char.animationsArray.length > 0) {
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

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.8;
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		final text:String = 
			"E/Q - Zoom In/Out\n" +
			"R - Reset Zoom\n" +
			"Drag Mouse - Move Camera\n" +
			"W/S - Previous/Next Animation\n" +
			"Space - Play Animation\n" +
			"Arrow Keys - Move Offset\n" +
			"T - Reset Current Offset\n" +
			"Shift + Arrows - Move 10x Faster\n" +
			"G - Toggle Grid\n" +
			"CTRL + C - Copy Offsets\n" +
			"CTRL + V - Paste Offsets\n" +
			"CTRL + Z - Undo\n" +
			"CTRL + Y - Redo";

		var tipTextArray:Array<String> = text.split('\n');
		var grpTexts:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();
		add(grpTexts);

		final lineHeight:Int = 25;
		final totalHeight:Int = tipTextArray.length * lineHeight;
		final startY:Float = (FlxG.height - totalHeight) / 2;

		for (i in 0...tipTextArray.length) {
			var text:FlxText = new FlxText(0, startY + (i * lineHeight), FlxG.width, tipTextArray[i], 18);
			text.setFormat(null, 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.screenCenter(X);
			text.scrollFactor.set();
			grpTexts.add(text);
		}
		
		var closeText:FlxText = new FlxText(0, FlxG.height - (lineHeight - 5), FlxG.width, "Press ESC to close tips", 16);
		closeText.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		closeText.screenCenter(X);
		closeText.scrollFactor.set();
		add(closeText);

		camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.ESCAPE) {
            close();
        }
	}
}