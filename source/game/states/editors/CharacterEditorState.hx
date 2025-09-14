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
	var char:Character;
	var ghostChar:Character;
	var textAnim:FlxText;
	var bgLayer:FlxTypedGroup<FlxSprite>;
	var charLayer:FlxTypedGroup<Character>;
	var dumbTexts:FlxTypedGroup<FlxText>;
	//var animList:Array<String> = [];
	var curAnim:Int = 0;
	var daAnim:String = 'spooky';
	var goToPlayState:Bool = true;

	public function new(daAnim:String = 'spooky', goToPlayState:Bool = true)
	{
		super();
		this.daAnim = daAnim;
		this.goToPlayState = goToPlayState;
	}

	var UI_box:PsychUIBox;
	var UI_characterbox:PsychUIBox;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;

	var grid:FlxSprite;
	var gridVisible:Bool = false;

	var copiedOffsets:Array<Int> = [0, 0];

	var undos:Array<Dynamic> = [];
	var redos:Array<Dynamic> = [];
	var maxHistorySteps:Int = 75;

	var changeBGbutton:PsychUIButton;
	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];

	var cameraFollowPointer:FlxSprite;
	var healthBarBG:FlxSprite;

	var lastAutoSaveTime:Float = 0;
	static inline final AUTO_SAVE_INTERVAL:Float = 60; // Auto save every 60 seconds

	override function create()
	{
		//FlxG.sound.playMusic(Paths.music('breakfast'), 0.5);
		camEditor = initFNFCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);

		grid = FlxGridOverlay.create(10, 10, FlxG.width * 4, FlxG.height * 4, true, 0x22FFFFFF, 0x55FFFFFF);
		grid.screenCenter();
		grid.visible = gridVisible;
		grid.cameras = [camEditor];

		bgLayer = new FlxTypedGroup<FlxSprite>();
		add(bgLayer);

		add(grid);

		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);

		changeBGbutton = new PsychUIButton(FlxG.width - 360, 25, "", function()
		{
			onPixelBG = !onPixelBG;
			reloadBGs();
		});
		changeBGbutton.cameras = [camHUD];

		var pointer:FlxGraphic = FlxGraphic.fromClass(GraphicCursorCross);
		cameraFollowPointer = new FlxSprite().loadGraphic(pointer);
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		add(cameraFollowPointer);

		loadChar(!daAnim.startsWith('bf'), false);

		healthBarBG = new FlxSprite(30, FlxG.height - 75).loadGraphic(Paths.image('healthBar'));
		healthBarBG.scrollFactor.set();
		add(healthBarBG);
		healthBarBG.cameras = [camHUD];

		leHealthIcon = new HealthIcon(char.healthIcon, false);
		leHealthIcon.y = FlxG.height - 150;
		add(leHealthIcon);
		leHealthIcon.cameras = [camHUD];

		dumbTexts = new FlxTypedGroup<FlxText>();
		add(dumbTexts);
		dumbTexts.cameras = [camHUD];

		textAnim = new FlxText(300, 16);
		textAnim.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		textAnim.borderSize = 1;
		textAnim.size = 32;
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

		genBoyOffsets();

		var tipTextArray:Array<String> = [
			"E/Q - Zoom In/Out",
			"R - Reset Zoom",
			"JKLI - Move Camera",
			"W/S - Prev/Next Animation",
			"Space - Play Animation",
			"Arrows - Move Offset",
			"T - Reset Current Offset",
			"With Shift - Move 10x Faster",
			"G - Toggle Grid",
			"CTRL + C - Copy Offsets",
			"CTRL + V - Paste Offsets",
			"CTRL + Z - Undo",
			"CTRL + Y - Redo",
			"ESC - Exit"
		];

		for (i in 0...tipTextArray.length)
		{
			var tipText:FlxText = new FlxText(FlxG.width - 320, FlxG.height - 15 - 16 * (tipTextArray.length - i), 300, tipTextArray[i], 12);
			tipText.cameras = [camHUD];
			tipText.setFormat(null, 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			tipText.scrollFactor.set();
			tipText.borderSize = 1;
			add(tipText);
		}

		FlxG.camera.zoom = 1;
		FlxG.mouse.visible = true;

		createUIMenu();

		add(changeBGbutton);

		addGhostUI();
		addSettingsUI();
		addCharacterUI();
		addAnimationsUI();

		UI_box.selectedName = 'Settings';
		UI_characterbox.selectedName = 'Character';

		reloadCharacterOptions();

		super.create();
	}

	function createUIMenu()
	{
		UI_box = new PsychUIBox(FlxG.width - 275, 25, 250, 120, ['Ghost', 'Settings']);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		UI_characterbox = new PsychUIBox(UI_box.x - 100, UI_box.y + UI_box.height + 10, 350, 280, ['Animations', 'Character']);
		UI_characterbox.scrollFactor.set();
		UI_characterbox.cameras = [camHUD];
		add(UI_characterbox);
		add(UI_box);

		UI_characterbox.resize(350, 280);
		UI_characterbox.x = UI_box.x - 100;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);
	}

	var onPixelBG:Bool = false;
	var OFFSET_X:Float = 300;
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
		var playerXDifference = 0;
		if(char.isPlayer) playerXDifference = 670;

		if(onPixelBG) {
			var playerYDifference:Float = 0;
			if(char.isPlayer) {
				playerXDifference += 200;
				playerYDifference = 220;
			}

			var bgSky:BGSprite = new BGSprite('bgs/weeb/weebSky', OFFSET_X - (playerXDifference / 2) - 300, 0 - playerYDifference, 0.1, 0.1);
			bgLayer.add(bgSky);
			bgSky.antialiasing = false;

			var repositionShit = -200 + OFFSET_X - playerXDifference;

			var bgSchool:BGSprite = new BGSprite('bgs/weeb/weebSchool', repositionShit, -playerYDifference + 6, 0.6, 0.90);
			bgLayer.add(bgSchool);
			bgSchool.antialiasing = false;

			var bgStreet:BGSprite = new BGSprite('bgs/weeb/weebStreet', repositionShit, -playerYDifference, 0.95, 0.95);
			bgLayer.add(bgStreet);
			bgStreet.antialiasing = false;

			var widShit = Std.int(bgSky.width * 6);
			var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800 - playerYDifference);
			bgTrees.frames = Paths.getPackerAtlas('bgs/weeb/weebTrees');
			bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
			bgTrees.animation.play('treeLoop');
			bgTrees.scrollFactor.set(0.85, 0.85);
			bgLayer.add(bgTrees);
			bgTrees.antialiasing = false;

			bgSky.setGraphicSize(widShit);
			bgSchool.setGraphicSize(widShit);
			bgStreet.setGraphicSize(widShit);
			bgTrees.setGraphicSize(Std.int(widShit * 1.4));

			bgSky.updateHitbox();
			bgSchool.updateHitbox();
			bgStreet.updateHitbox();
			bgTrees.updateHitbox();
			changeBGbutton.label = "Regular BG";
		} else {
			var bg:BGSprite = new BGSprite('stageback', -600 + OFFSET_X - playerXDifference, -300, 0.9, 0.9);
			bgLayer.add(bg);

			var stageFront:BGSprite = new BGSprite('stagefront', -650 + OFFSET_X - playerXDifference, 500, 0.9, 0.9);
			stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
			stageFront.updateHitbox();
			bgLayer.add(stageFront);
			changeBGbutton.label = "Pixel BG";
		}
	}

	var TemplateCharacter:String = '{
			"animations": [
				{
					"loop": false,
					"offsets": [
						0,
						0
					],
					"fps": 24,
					"anim": "idle",
					"indices": [],
					"name": "Dad idle dance"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singLEFT",
					"loop": false,
					"name": "Dad Sing Note LEFT"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singDOWN",
					"loop": false,
					"name": "Dad Sing Note DOWN"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singUP",
					"loop": false,
					"name": "Dad Sing Note UP"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singRIGHT",
					"loop": false,
					"name": "Dad Sing Note RIGHT"
				}
			],
			"no_antialiasing": false,
			"image": "characters/DADDY_DEAREST",
			"position": [
				0,
				0
			],
			"healthicon": "face",
			"flip_x": false,
			"healthbar_colors": [
				161,
				161,
				161
			],
			"camera_position": [
				0,
				0
			],
			"sing_duration": 6.1,
			"vocals_file": null,
			"scale": 1
		}';

	var ghostAnim:String = '';
	var ghostAlpha:Float = 0.6;
	var makeGhostButton:PsychUIButton;
	var ghostSingleAnimMode:Bool = false;
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
			var value = highlightGhost.checked ? 125 : 0;
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

	var charDropDown:PsychUIDropDownMenu;
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

			var characterPath:String = 'characters/$intended.json';
			var path:String = Paths.getPath(characterPath, TEXT, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (OpenFLAssets.exists(path))
			#end
			{
				daAnim = intended;
				//check_player.checked = character.isPlayer;
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
			var parsedJson:CharacterFile = cast Json.parse(TemplateCharacter);
			var characters:Array<Character> = [char, ghostChar];
			for (character in characters)
			{
				character.animOffsets.clear();
				character.animationsArray = parsedJson.animations;
				for (anim in character.animationsArray)
				{
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
				character.setPosition(character.positionArray[0] + OFFSET_X + 100, character.positionArray[1]);
			}

			reloadCharacterImage();
			reloadCharacterDropDown();
			reloadCharacterOptions();
			resetHealthBarColor();
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

	var healthColorStepperR:PsychUINumericStepper;
	var healthColorStepperG:PsychUINumericStepper;
	var healthColorStepperB:PsychUINumericStepper;

	function addCharacterUI() {
		var tab_group = UI_characterbox.getTab('Character').menu;

		imageInputText = new PsychUIInputText(15, 30, 200, 'characters/BOYFRIEND', 8);
		var reloadImage:PsychUIButton = new PsychUIButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function()
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();
			if(!char.isAnimationNull()) {
				char.playAnim(char.getAnimationName(), true);
			}
		});

		var decideIconColor:PsychUIButton = new PsychUIButton(reloadImage.x, reloadImage.y + 30, "Get Icon Color", function()
			{
				var coolColor = FlxColor.fromInt(CoolUtil.dominantColor(leHealthIcon));
				healthColorStepperR.value = coolColor.red;
				healthColorStepperG.value = coolColor.green;
				healthColorStepperB.value = coolColor.blue;
				UIEvent(PsychUINumericStepper.CHANGE_EVENT, healthColorStepperR);
				UIEvent(PsychUINumericStepper.CHANGE_EVENT, healthColorStepperG);
				UIEvent(PsychUINumericStepper.CHANGE_EVENT, healthColorStepperB);
			});

		healthIconInputText = new PsychUIInputText(15, imageInputText.y + 35, 75, leHealthIcon.getCharacter(), 8);

		vocalsInputText = new PsychUIInputText(15, healthIconInputText.y + 35, 75, char.vocalsFile != null ? char.vocalsFile : '', 8);

		singDurationStepper = new PsychUINumericStepper(15, healthIconInputText.y + 75, 0.1, 4, 0, 999, 1);

		scaleStepper = new PsychUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);

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

		positionXStepper = new PsychUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, char.positionArray[0], -9000, 9000, 0);
		positionYStepper = new PsychUINumericStepper(positionXStepper.x + 70, positionXStepper.y, 10, char.positionArray[1], -9000, 9000, 0);

		positionCameraXStepper = new PsychUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0], -9000, 9000, 0);
		positionCameraYStepper = new PsychUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1], -9000, 9000, 0);

		var saveCharacterButton:PsychUIButton = new PsychUIButton(reloadImage.x, noAntialiasingCheckBox.y + 40, "Save Character", () -> saveCharacter());

		healthColorStepperR = new PsychUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, char.healthColorArray[0], 0, 255, 0);
		healthColorStepperG = new PsychUINumericStepper(singDurationStepper.x + 65, saveCharacterButton.y, 20, char.healthColorArray[1], 0, 255, 0);
		healthColorStepperB = new PsychUINumericStepper(singDurationStepper.x + 130, saveCharacterButton.y, 20, char.healthColorArray[2], 0, 255, 0);

		tab_group.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tab_group.add(new FlxText(15, vocalsInputText.y - 18, 0, 'Vocals File Postfix:'));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tab_group.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tab_group.add(new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 0, 'Health bar R/G/B:'));
		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(decideIconColor);
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
		tab_group.add(healthColorStepperR);
		tab_group.add(healthColorStepperG);
		tab_group.add(healthColorStepperB);
		tab_group.add(saveCharacterButton);
	}

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationNameFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;
	function addAnimationsUI() {
		var tab_group = UI_characterbox.getTab('Animations').menu;

		animationInputText = new PsychUIInputText(15, 85, 80, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationNameFramerate = new PsychUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, "Should it Loop?", 100);

		animationDropDown = new PsychUIDropDownMenu(15, animationInputText.y - 55, null, (selectedAnimation:Int, pressed:String) -> {
			var anim:AnimArray = char.animationsArray[selectedAnimation];
			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationNameFramerate.value = anim.fps;
				
			if (anim.indices != null && anim.indices.length > 0) 
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
				if(indices != null && indices.length > 0) {
					char.atlas.anim.addBySymbolIndices(newAnim.anim, newAnim.name, newAnim.indices, newAnim.fps, newAnim.loop);
				} else {
					char.atlas.anim.addBySymbol(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				}
			} else {
				if(indices != null && indices.length > 0) {
					char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, "", newAnim.fps, newAnim.loop);
				} else {
					char.animation.addByPrefix(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				}
			}

			if(!char.hasAnimation(newAnim.anim)) char.addOffset(newAnim.anim, 0, 0);
			char.animationsArray.push(newAnim);

			if(lastAnim == animationInputText.text) {
				var leAnim = !char.isAnimateAtlas ? char.animation.getByName(lastAnim) : char.atlas.anim.getByName(lastAnim);
				if(leAnim != null && leAnim.frames.length > 0) {
					char.playAnim(lastAnim, true);
				} else {
					for(i in 0...char.animationsArray.length) {
						if(char.animationsArray[i] != null) {
							leAnim = !char.isAnimateAtlas ? char.animation.getByName(char.animationsArray[i].anim) : char.atlas.anim.getByName(char.animationsArray[i].anim);
							if(leAnim != null && leAnim.frames.length > 0) {
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
			trace('Added/Updated animation: ' + animationInputText.text);
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
					trace('Removed animation: ' + animationInputText.text);
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
		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText)) {
			if(sender == healthIconInputText) {
				leHealthIcon.changeIcon(healthIconInputText.text, false);
				char.healthIcon = healthIconInputText.text;
				updatePresence();
				saveHistoryStuff();
			}
			else if(sender == imageInputText) {
				char.imageFile = imageInputText.text;
				saveHistoryStuff();
			}
		} else if(id == PsychUINumericStepper.CHANGE_EVENT && (sender is PsychUINumericStepper)) {
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				char.jsonScale = sender.value;
				char.setGraphicSize(Std.int(char.width * char.jsonScale));
				char.updateHitbox();
				ghostChar.setGraphicSize(Std.int(ghostChar.width * char.jsonScale));
				ghostChar.updateHitbox();
				reloadGhost();
				updatePointerPos(false);

				if(!char.isAnimationNull()) {
					char.playAnim(char.getAnimationName(), true);
				}
				saveHistoryStuff();
			}
			else if(sender == positionXStepper)
			{
				char.positionArray[0] = positionXStepper.value;
				char.x = char.positionArray[0] + OFFSET_X + 100;
				updatePointerPos();
				saveHistoryStuff();
			}
			else if(sender == singDurationStepper)
			{
				char.singDuration = singDurationStepper.value;//ermm you forgot this??
				saveHistoryStuff();
			}
			else if(sender == positionYStepper)
			{
				char.positionArray[1] = positionYStepper.value;
				char.y = char.positionArray[1];
				updatePointerPos();
				saveHistoryStuff();
			}
			else if(sender == positionCameraXStepper)
			{
				char.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
				saveHistoryStuff();
			}
			else if(sender == positionCameraYStepper)
			{
				char.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
				saveHistoryStuff();
			}
			else if(sender == vocalsInputText)
			{
				char.vocalsFile = vocalsInputText.text;
			}
			else if(sender == healthColorStepperR)
			{
				char.healthColorArray[0] = Math.round(healthColorStepperR.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
				saveHistoryStuff();
			}
			else if(sender == healthColorStepperG)
			{
				char.healthColorArray[1] = Math.round(healthColorStepperG.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
				saveHistoryStuff();
			}
			else if(sender == healthColorStepperB)
			{
				char.healthColorArray[2] = Math.round(healthColorStepperB.value);
				healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
				saveHistoryStuff();
			}
		}
	}

	function reloadCharacterImage() {
		var lastAnim:String = char.getAnimationName() ?? '';
		
		char.atlas = FlxDestroyUtil.destroy(char.atlas);
		char.isAnimateAtlas = false;

		if(Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			char.atlas = new FlxAnimate();
			char.atlas.frames = Paths.getAnimateAtlas(char.imageFile);
			char.isAnimateAtlas = true;
		} else {
			if(Paths.fileExists('images/' + char.imageFile + '.txt', TEXT))
				char.frames = Paths.getPackerAtlas(char.imageFile);
			else if(Paths.fileExists('images/' + char.imageFile + '.json', TEXT))
				char.frames = Paths.getAsepriteAtlas(char.imageFile);
			else
				char.frames = Paths.getSparrowAtlas(char.imageFile);
			ghostChar.frames = char.frames;
		}

		if(char.animationsArray != null) {
			for (anim in char.animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop = anim.loop;
				var animIndices = anim.indices;
				
				if(char.isAnimateAtlas) {
					if(animIndices != null && animIndices.length > 0) {
						char.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					} else {
						char.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					}
				} else {
					if(animIndices != null && animIndices.length > 0) {
						char.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					} else {
						char.animation.addByPrefix(animAnim, animName, animFps, animLoop);
					}
				}

				if(!char.hasAnimation(animAnim))
					char.addOffset(animAnim, 0, 0);
			}
		}
		
		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);
		ghostChar.setPosition(char.x, char.y);
		
		if(char.animationsArray.length > 1) {
			if(lastAnim != '') char.playAnim(lastAnim, true);
			else char.dance();
		}
		
		reloadGhost();
	}

	function genBoyOffsets():Void
	{
		var daLoop:Int = 0;

		var i:Int = dumbTexts.members.length-1;
		while(i >= 0) {
			var memb:FlxText = dumbTexts.members[i];
			if(memb != null) {
				memb.kill();
				dumbTexts.remove(memb);
				memb.destroy();
			}
			--i;
		}
		dumbTexts.clear();

		for (anim => offsets in char.animOffsets)
		{
			var text:FlxText = new FlxText(10, 20 + (18 * daLoop), 0, anim + ": " + offsets, 15);
			text.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 1;
			dumbTexts.add(text);
			text.cameras = [camHUD];

			daLoop++;
		}

		textAnim.visible = true;
		if(dumbTexts.length < 1) {
			var text:FlxText = new FlxText(10, 38, 0, "ERROR! No animations found.", 15);
			text.scrollFactor.set();
			text.borderSize = 1;
			dumbTexts.add(text);
			textAnim.visible = false;
		}

		 for (i in 0...dumbTexts.length) {
			var text = dumbTexts.members[i];
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

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);

		undos = [];
    	redos = [];
    	curAnim = 0;

		/* THIS FUNCTION WAS USED TO PUT THE .TXT OFFSETS INTO THE .JSON

		for (anim => offset in char.animOffsets) {
			var leAnim:AnimArray = findAnimationByName(anim);
			if(leAnim != null) {
				leAnim.offsets = [offset[0], offset[1]];
			}
		}*/

		if(blahBlahBlah) {
			genBoyOffsets();
			saveHistoryStuff();
		}
		reloadCharacterOptions();
		reloadBGs();
		updatePointerPos();
	}

	inline function updatePointerPos(?snap:Bool = true)
	{
		if(char == null || cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;
		if(!char.isPlayer)
		{
			offX = char.getMidpoint().x + 150 + char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		}
		else
		{
			offX = char.getMidpoint().x - 100 - char.cameraPosition[0];
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
			vocalsInputText.text = char.vocalsFile != null ? char.vocalsFile : '';
			singDurationStepper.value = char.singDuration;
			scaleStepper.value = char.jsonScale;
			flipXCheckBox.checked = char.originalFlipX;
			noAntialiasingCheckBox.checked = char.noAntialiasing;
			resetHealthBarColor();
			leHealthIcon.changeIcon(healthIconInputText.text, false);
			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];
			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];
			reloadAnimationDropDown();
			updatePresence();
		}
	}

	inline function reloadAnimationDropDown() {
		var animList:Array<String> = [];
		for (i in 0...char.animationsArray.length) {
			animList.push(char.animationsArray[i].anim);
		}
		if(animList.length < 1) animList.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.list = animList;
		//reloadGhost();
	}

	inline function reloadGhost() {
		var wasVisible = ghostChar.visible;
		var alpha = ghostChar.alpha;
		
		ghostChar.animOffsets.clear();

		ghostChar.atlas = FlxDestroyUtil.destroy(ghostChar.atlas);
		ghostChar.isAnimateAtlas = false;
		ghostChar.color = FlxColor.WHITE;
		ghostChar.alpha = 1;
		
		if (ghostSingleAnimMode && ghostChar.visible) {
			var animToPlay = ghostAnim;
			if (animToPlay == null || animToPlay == "") animToPlay = char.animationsArray[0].anim;
			
			var animData = findAnimationByName(animToPlay);
			if (animData != null) {
				if(ghostChar.isAnimateAtlas) {
					if(animData.indices != null && animData.indices.length > 0) {
						ghostChar.atlas.anim.addBySymbolIndices(animData.anim, animData.name, animData.indices, animData.fps, animData.loop);
					} else {
						ghostChar.atlas.anim.addBySymbol(animData.anim, animData.name, animData.fps, animData.loop);
					}
				} else {
					if(animData.indices != null && animData.indices.length > 0) {
						ghostChar.animation.addByIndices(animData.anim, animData.name, animData.indices, "", animData.fps, animData.loop);
					} else {
						ghostChar.animation.addByPrefix(animData.anim, animData.name, animData.fps, animData.loop);
					}
				}
				
				ghostChar.addOffset(animData.anim, animData.offsets[0], animData.offsets[1]);
				ghostChar.playAnim(animData.anim, true);
			}
		} else {
			for (anim in char.animationsArray) {
				var animAnim = anim.anim;
				var animName = anim.name;
				var animFps = anim.fps;
				var animLoop = anim.loop;
				var animIndices = anim.indices;
				
				if(ghostChar.isAnimateAtlas) {
					if(animIndices != null && animIndices.length > 0) {
						ghostChar.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					} else {
						ghostChar.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					}
				} else {
					if(animIndices != null && animIndices.length > 0) {
						ghostChar.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					} else {
						ghostChar.animation.addByPrefix(animAnim, animName, animFps, animLoop);
					}
				}
				
				ghostChar.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			}
		}
		
		ghostChar.visible = wasVisible;
		ghostChar.alpha = alpha;
		ghostChar.antialiasing = char.antialiasing;
	}

	inline function reloadCharacterDropDown() {
		var charsLoaded:Map<String, Bool> = new Map();

		#if sys
		characterList = [];
		var directories:Array<String> = [#if MODS_ALLOWED Paths.mods('characters/'), Paths.mods(Paths.currentModDirectory + '/characters/'), #end Paths.getPreloadPath('characters/')];
		#if MODS_ALLOWED
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		#end
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json')) {
						try {
							var charToCheck:String = file.substr(0, file.length - 5);
							var rawJson:String = sys.io.File.getContent(path);
							if(rawJson != null && rawJson.length > 0 && !charsLoaded.exists(charToCheck)) {
								var json = haxe.Json.parse(rawJson);
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

	inline function resetHealthBarColor() {
		healthColorStepperR.value = char.healthColorArray[0];
		healthColorStepperG.value = char.healthColorArray[1];
		healthColorStepperB.value = char.healthColorArray[2];
		healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
	}

	function updatePresence() {
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + daAnim, leHealthIcon.getCharacter());
		#end
	}

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.F1) {
			trace('Char position: ${char.x}, ${char.y}');
			trace('Camera follow pointer: ${cameraFollowPointer.x}, ${cameraFollowPointer.y}');
			trace('Camera scroll: ${FlxG.camera.scroll.x}, ${FlxG.camera.scroll.y}');
			trace('Char visibility: ${char.visible}, Alpha: ${char.alpha}');
		}

		lastAutoSaveTime += elapsed;
		if(lastAutoSaveTime >= AUTO_SAVE_INTERVAL) {
			lastAutoSaveTime = 0;
			saveBackup();
		}

		if(char.animationsArray[curAnim] != null) {
			textAnim.text = char.animationsArray[curAnim].anim;

			var animName = char.animationsArray[curAnim].anim;
			var validAnim = false;
			
			if(char.isAnimateAtlas) {
				validAnim = char.atlas.anim.getByName(animName) != null;
			} else {
				var anim = char.animation.getByName(animName);
				validAnim = anim != null && anim.frames.length > 0;
			}
			
			if(!validAnim) {
				textAnim.text += ' (ERROR!)';
			}
		} else {
			textAnim.text = '';
		}

		if(PsychUIInputText.focusOn != null)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);

		if (FlxG.keys.justPressed.G) {
    		gridVisible = !gridVisible;
    		grid.visible = gridVisible;
		}

		var changedOffset = false;
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.C) {
				copiedOffsets = char.animationsArray[curAnim].offsets.copy();
				changedOffset = true;
				FlxG.log.add("Offsets copied!");
			}

			if (FlxG.keys.justPressed.V) {
				char.animationsArray[curAnim].offsets = copiedOffsets.copy();
				char.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
				ghostChar.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
				char.playAnim(char.animationsArray[curAnim].anim, false);
				genBoyOffsets();
				saveHistoryStuff();
				changedOffset = true;
				FlxG.log.add("Offsets pasted!");
			}

			if (FlxG.keys.justPressed.Z) {
				undo();
			}

			if (FlxG.keys.justPressed.Y) {
				redo();
			}
		}

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

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		}

		if (FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		if(char.animationsArray.length > 0) {
			if (FlxG.keys.justPressed.W)
			{
				curAnim -= 1;
			}

			if (FlxG.keys.justPressed.S)
			{
				curAnim += 1;
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
			if (FlxG.keys.justPressed.T) {
				var originalOffsets = char.animationsArray[curAnim].offsets.copy();
					
				char.animationsArray[curAnim].offsets = [0, 0];
				char.addOffset(char.animationsArray[curAnim].anim, 0, 0);
				ghostChar.addOffset(char.animationsArray[curAnim].anim, 0, 0);
					
				char.playAnim(char.animationsArray[curAnim].anim, false);
				ghostChar.playAnim(char.animationsArray[curAnim].anim, false);
					
				genBoyOffsets();
				saveHistoryStuff();
					
				char.animationsArray[curAnim].offsets = originalOffsets;

				changedOffset = true;
			}

			var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
			var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
			if(moveKeysP.contains(true))
			{
				char.offset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
				char.offset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
				changedOffset = true;
			}

			if(moveKeys.contains(true))
			{
				holdingArrowsTime += elapsed;
				if(holdingArrowsTime > 0.6)
				{
					holdingArrowsElapsed += elapsed;
					while(holdingArrowsElapsed > (1/60))
					{
						char.offset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
						char.offset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
						holdingArrowsElapsed -= (1/60);
						changedOffset = true;
					}
				}
			}
			else holdingArrowsTime = 0;

			if (changedOffset) {
				if (char.animationsArray[curAnim] != null) {
					var animName = char.animationsArray[curAnim].anim;
					char.animOffsets.set(animName, [char.offset.x, char.offset.y]);
					
					for (anim in char.animationsArray) {
						if (anim.anim == animName) {
							anim.offsets = [Std.int(char.offset.x), Std.int(char.offset.y)];
							break;
						}
					}
					
					if (ghostChar.visible && !ghostChar.isAnimationNull() && 
						ghostChar.getAnimationName() == animName) 
					{
						ghostChar.animOffsets.set(animName, [char.offset.x, char.offset.y]);
						ghostChar.offset.set(char.offset.x, char.offset.y);
					}
					
					genBoyOffsets();
					saveHistoryStuff();
				}
				changedOffset = false;
			}
		}
		//camHUD.zoom = FlxG.camera.zoom;
		ghostChar.setPosition(char.x, char.y);
	}

	var _file:FileReference;

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
	}

	/**
	* Called when the save file dialog is cancelled.
	*/
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	* Called if there is an error while saving the gameplay recording.
	*/
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function saveBackup() {
		try {
			#if sys
			var backupDir = 'backups/characters/';
			if (!sys.FileSystem.exists(backupDir))
				sys.FileSystem.createDirectory(backupDir);
			#end

			var json = {
				"animations": char.animationsArray,
				"image": char.imageFile,
				"scale": char.jsonScale,
				"sing_duration": char.singDuration,
				"healthicon": char.healthIcon,
				"position":	char.positionArray,
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
			var json = {
				"animations": char.animationsArray,
				"image": char.imageFile,
				"scale": char.jsonScale,
				"sing_duration": char.singDuration,
				"healthicon": char.healthIcon,

				"position":	char.positionArray,
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

	function ClipboardAdd(prefix:String = ''):String {
		if(prefix.toLowerCase().endsWith('v')) //probably copy paste attempt
		{
			prefix = prefix.substring(0, prefix.length-1);
		}

		var text:String = prefix + Clipboard.text.replace('\n', '');
		return text;
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
		// Recovering the anims
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
		if (curAnim < 0) curAnim = 0;
		if (curAnim >= char.animationsArray.length) curAnim = char.animationsArray.length - 1;
		
		reloadAnimationDropDown();
		reloadGhost();
		reloadCharacterOptions();
		reloadCharacterImage();
		updatePointerPos();
		genBoyOffsets();

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);
    	ghostChar.setPosition(char.x, char.y);
		
		// update health bar color
		healthBarBG.color = FlxColor.fromRGB(
			char.healthColorArray[0],
			char.healthColorArray[1],
			char.healthColorArray[2]
		);
	}

	override function destroy() {
		super.destroy();
	}
}
