package game.states.editors;

//modified by Justin/GreenColdTea

#if desktop
import api.Discord.DiscordClient;
#end
import openfl.geom.Rectangle;
import haxe.Json;
import haxe.format.JsonParser;
import haxe.io.Bytes;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
#if mobile
import mobile.flixel.FlxButton;
#else
import flixel.ui.FlxButton;
#end
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.ByteArray;

import game.backend.Conductor.BPMChangeEvent;
import game.backend.Section.SwagSection;
import game.backend.Song.SwagSong;

import game.objects.AttachedSprite;
import game.objects.Character;
import game.objects.Character.CharacterFile;
import game.objects.FlxUIDropDownMenuCustom;
import game.objects.HealthIcon;
import game.objects.Note;
import game.objects.StrumNote;
import game.objects.Prompt;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if (flixel < "5.3.0")
@:access(flixel.system.FlxSound._sound)
#else
@:access(flixel.sound.FlxSound._sound)
#end
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatState

{
	public static var noteTypeList:Array<String> = //Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	[
		'',
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation'
	];
	private var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
	private var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();
	public var ignoreWarnings = false;
	var undos = [];
	var redos = [];
	var maxUndoSteps:Int = 50;
	/*var eventStuff:Array<Dynamic> =
	[
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		["Lyrics", "Lyrics!!!\nValue 1: Text and optionally, colour\n(To specify colour, seperate it by a --)\nValue 2: Duration, in seconds.\nDuration defaults to text length multiplied by 0.5"],
		['Set Property', "Value 1: Variable name\nValue 2: New value"]
	]; for mods*/

	var eventStuff:Array<Dynamic> =
	[
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Philly Glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."],
		['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		["Lyrics", "Lyrics!!!\nValue 1: Text and optionally, colour\n(To specify colour, seperate it by a --)\nValue 2: Duration, in seconds.\nDuration defaults to text length multiplied by 0.5"],
		['Set Property', "Value 1: Variable name\nValue 2: New value"]
	];

	var _file:FileReference;
    var postfix:String = '';
    
	var UI_box:FlxUITabMenu;

	public static var goToPlayState:Bool = false;
	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec:Int = 0;
	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

	public static var GRID_SIZE:Int = 40;
	var CAM_OFFSET:Int = 360;

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var prevRenderedSustains:FlxTypedGroup<FlxSprite>;
	var prevRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var prevGridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	public var _song:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var tempBpm:Float = 0;

	var playbackSpeed:Float = 1;

	var vocals:FlxSound = null;
	var opponentVocals:FlxSound = null;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;
	var currentSongName:String;
	var zoomTxt:FlxText;

	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Int = 2;

	// unique sustain colors
	public static var sustainColors:Array<FlxColor> = [
    	0xFFC24B99, // pink (left note)
    	0xFF00FFFF, // blue (down)
    	0xFF12FA05, // green (up note)
    	0xFFF9393F  // red (right note)
	];

	// for opponent there are other colors to not miss with them
	public static var sustainColorsOppo:Array<FlxColor> = [
		0xFFFF0000,
		0xFFFF0000,
		0xFFFF0000,
		0xFFFF0000 
	];

	//select box things
	var selecting = false;
	var selectStart:FlxPoint = new FlxPoint();
	var selectBox:FlxSprite;
	var selectedNotes:Array<Note> = [];

	var clipboardNotes:Array<Dynamic> = [];

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenuCustom> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;

	public static var quantization:Int = 16;
	public static var curQuant = 3;

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];
	
	var text:String = "";
	public static var vortex:Bool = false;
	public var mouseQuant:Bool = false;

	var player:Character;
	var opponent:Character;
	var showCharacters:Bool = false;

	var tipsSubstate:ChartingTipsSubstate = null;
	
	override function create()
	{
		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();

			_song = {
				song: 'Test',
				notes: [],
				events: [],
				bpm: 146.0,
				needsVoices: true,
				arrowSkin: '',
				splashSkin: 'noteSplashes',//idk it would crash if i didn't
				player1: 'bf',
				player2: 'scrimbo',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage',
				validScore: false
			};
			addSection();
			PlayState.SONG = _song;
		}

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90).loadGraphic(Paths.image('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		rightIcon.flipX = true;

		eventIcon.scrollFactor.set(1, 1);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(GRID_SIZE + 10, -100);
		rightIcon.setPosition(GRID_SIZE * 5.2, -100);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		prevRenderedSustains = new FlxTypedGroup<FlxSprite>();
		prevRenderedNotes = new FlxTypedGroup<Note>();

		if(curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		FlxG.mouse.visible = true;
		//FlxG.save.bind('funkin', CoolUtil.getSavePath());

		tempBpm = _song.bpm;

		addSection();

		// sections = _song.notes;

		updateJsonData();
		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		bpmTxt = new FlxText(1027.5, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		quant = new AttachedSprite('chart_quant','chart_quant');
		quant.animation.addByPrefix('q','chart_quant',0,false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0...8){
			var note:StrumNote = new StrumNote(GRID_SIZE * (i+1), strumLine.y, i % 4, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		opponent = new Character(675, 450, "dad", false, true);
		opponent.scrollFactor.set();
		add(opponent);

		player = new Character(950, 575, "bf", true, true);
		player.scrollFactor.set();
		add(player);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(365, 400);
		UI_box.x = 640 + GRID_SIZE / 2;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		updateWaveform();

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);
		add(prevRenderedSustains);
		add(prevRenderedNotes);

		if(lastSong != currentSongName) {
			changeSection();
		}
		lastSong = currentSongName;

		zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.y -= 500;
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

		updateGrid();

		opponent.visible = false;
		player.visible = false;

		selectBox = new FlxSprite();
		selectBox.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		selectBox.alpha = 0.6;
		selectBox.visible = false;
		add(selectBox);

		var outline = new FlxSprite();
		outline.makeGraphic(1, 1, FlxColor.BLUE);
		add(outline);

		var fill = new FlxSprite(1, 1);
		fill.makeGraphic(1, 1, FlxColor.fromRGB(173, 216, 230, 50));
		add(fill);

		selectBox.stamp(outline, 0, 0);
		selectBox.stamp(outline, Std.int(selectBox.width) - 1, 0);
		selectBox.stamp(outline, 0, Std.int(selectBox.height) - 1);
		selectBox.stamp(outline, Std.int(selectBox.width) - 1, Std.int(selectBox.height) - 1);
		selectBox.stamp(fill, 1, 1);

		#if mobile
	  	addVirtualPad(LEFT_FULL, A_B_C_X_Y_Z);
		#end

		super.create();
	}

	var check_mute_inst:FlxUICheckBox = null;
	var check_mute_vocals:FlxUICheckBox = null;
	var check_mute_vocals_opponent:FlxUICheckBox = null;
	var check_vortex:FlxUICheckBox = null;
	var check_warnings:FlxUICheckBox = null;
	var playSoundBf:FlxUICheckBox = null;
	var playSoundDad:FlxUICheckBox = null;
	var UI_songTitle:FlxUIInputText;
	var noteSkinInputText:FlxUIInputText;
	var noteSplashesInputText:FlxUIInputText;
	var stageDropDown:FlxUIDropDownMenuCustom;
	var sliderRate:FlxUISlider;
	function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		UI_songTitle.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		blockPressWhileTypingOn.push(UI_songTitle);

		var check_voices = new FlxUICheckBox(10, 27, null, null, "Has Voice Track", 100);
		check_voices.textY += 3;
		check_voices.checked = _song.needsVoices;
		// _song.needsVoices = check_voices.checked;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			//trace('CHECKED!');
		};

		var saveButton:FlxButton = new FlxButton(185, 8, "Save", function()
		{
			saveLevel();
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			updateJsonData();
			loadSong();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.sound.music.pause();
				if(vocals != null) vocals.pause();
				if(opponentVocals != null) opponentVocals.pause();
			}
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function() {
				var songName = _song.song.toLowerCase();
				var songFolder = Paths.formatToSongPath(UI_songTitle.text);
				var formattedSongPath = checkForJSON(songName, songFolder);
				#if sys
				trace("Checking system file: " + formattedSongPath + " -> " + sys.FileSystem.exists(formattedSongPath));
				#end
				if (sys.FileSystem.exists(formattedSongPath)) {
					loadJson(songName);
				} else {
					openSubState(new Prompt('Song not found!\nPlease check the song name.', 1, function() {
						closeSubState();
					}, null, false, "OK", null));
				}
			}, null, ignoreWarnings, "OK", "CANCEL"));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
			MusicBeatState.resetState();
		});

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function()
		{

			var songName:String = Paths.formatToSongPath(_song.song);
			var file:String = Paths.json(songName + '/events');
			#if sys
			if (#if MODS_ALLOWED FileSystem.exists(Paths.modsJson(songName + '/events')) || #end FileSystem.exists(SUtil.getPath() + file))
			#else
			if (OpenFlAssets.exists(file))
			#end
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson('events', songName);
				_song.events = events.events;
				changeSection(curSec);
			}
		});

		var saveEvents:FlxButton = new FlxButton(saveButton.x, reloadSongJson.y, 'Save Events', function ()
		{
			saveEvents();
		});

		var clear_notes:FlxButton = new FlxButton(260, 340, 'Clear Notes', function()
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if(vocals != null) vocals.pause();
					if(opponentVocals != null) opponentVocals.pause();
				}
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function(){for (sec in 0..._song.notes.length) {
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null, ignoreWarnings, "OK", "CANCEL"));

			});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var clear_events:FlxButton = new FlxButton(clear_notes.x, clear_notes.y - 30, 'Clear Events', function()
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if(vocals != null) vocals.pause();
					if(opponentVocals != null) opponentVocals.pause();
				}
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, ignoreWarnings, "OK", "CANCEL"));
			});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods(Paths.currentModDirectory + '/characters/'), SUtil.getPath() + Paths.getPreloadPath('characters/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('characters/')];
		#end

		var tempMap:Map<String, Bool> = new Map<String, Bool>();
		var characters:Array<String> = CoolUtil.coolTextFile(SUtil.getPath() + Paths.txt('characterList'));
		for (i in 0...characters.length) {
			tempMap.set(characters[i], true);
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(!charToCheck.endsWith('-dead') && !tempMap.exists(charToCheck)) {
							tempMap.set(charToCheck, true);
							characters.push(charToCheck);
						}
					}
				}
			}
		}
		#end

		var player1DropDown = new FlxUIDropDownMenuCustom(10, stepperSpeed.y + 45, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateJsonData();
			updateHeads();
			//reloadCharacter('player'); temporarly disabled
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new FlxUIDropDownMenuCustom(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.gfVersion = characters[Std.parseInt(character)];
			updateJsonData();
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new FlxUIDropDownMenuCustom(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
			updateJsonData();
			updateHeads();
			//reloadCharacter('opponent'); this too
		});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('stages/'), Paths.mods(Paths.currentModDirectory + '/stages/'), SUtil.getPath() + Paths.getPreloadPath('stages/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end

		tempMap.clear();
		var stageFile:Array<String> = CoolUtil.coolTextFile(SUtil.getPath() + Paths.txt('stageList'));
		var stages:Array<String> = [];
		for (i in 0...stageFile.length) { //Prevent duplicates
			var stageToCheck:String = stageFile[i];
			if(!tempMap.exists(stageToCheck)) {
				stages.push(stageToCheck);
			}
			tempMap.set(stageToCheck, true);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var stageToCheck:String = file.substr(0, file.length - 5);
						if(!tempMap.exists(stageToCheck)) {
							tempMap.set(stageToCheck, true);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if(stages.length < 1) stages.push('stage');

		stageDropDown = new FlxUIDropDownMenuCustom(player1DropDown.x + 175, player1DropDown.y, FlxUIDropDownMenuCustom.makeStrIdLabelArray(stages, true), function(character:String)
		{
			_song.stage = stages[Std.parseInt(character)];
		});
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);
		
		
		var skin = PlayState.SONG.arrowSkin;
		if(skin == null) skin = '';
		noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, skin, 8);
		noteSkinInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin, 8);
		noteSplashesInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function() {
			try {
				_song.arrowSkin = noteSkinInputText.text;
				updateGrid();
			} catch (_:Dynamic) {
				if (FlxG.sound.music.playing)
					{
						FlxG.sound.music.pause();
						if(vocals != null) vocals.pause();
						if(opponentVocals != null) opponentVocals.pause();
					}
                openSubState(new Prompt('Notes skin not found!\nPlease check the notes skin name.', 1, function() { 
                    closeSubState(); 
                }, null, false, "OK", null));
			}
		});

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEvents);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Player:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfVersionDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(stageDropDown);

		UI_box.addGroup(tab_group_song);

		initFNFCamera().follow(camPos, LOCKON, 999);
	}

	var stepperBeats:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must Hit Section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 22, null, null, "GF Section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;
		// _song.needsVoices = check_mustHit.checked;

		check_altAnim = new FlxUICheckBox(check_gfSection.x + 120, check_gfSection.y, null, null, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;

		stepperBeats = new FlxUINumericStepper(10, 100, 1, 4, 1, 6, 2);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		if(check_changeBPM.checked) {
			stepperSectionBPM.value = _song.notes[curSec].bpm;
		} else {
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;
		var copyButton:FlxButton = new FlxButton(10, 190, "Copy Section", function()
		{
			notesCopied = [];
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				notesCopied.push(note);
			}

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if(endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 130, copyButton.y, "Paste Section", function()
		{
			if(notesCopied == null || notesCopied.length < 1)
			{
				return;
			}

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));
			//trace('Time to add: ' + addToTime);

			for (note in notesCopied)
			{
				var copiedNote:Array<Dynamic> = [];
				var newStrumTime:Float = note[0] + addToTime;
				if(note[1] < 0)
				{
					if(check_eventsSec.checked)
					{
						var copiedEventArray:Array<Dynamic> = [];
						for (i in 0...note[2].length)
						{
							var eventToPush:Array<Dynamic> = note[2][i];
							copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
						}
						_song.events.push([newStrumTime, copiedEventArray]);
					}
				}
				else
				{
					if(check_notesSec.checked)
					{
						if(note[4] != null) {
							copiedNote = [newStrumTime, note[1], note[2], note[3], note[4]];
						} else {
							copiedNote = [newStrumTime, note[1], note[2], note[3]];
						}
						_song.notes[curSec].sectionNotes.push(copiedNote);
					}
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 130, pasteButton.y, "Clear", function()
		{
			if(check_notesSec.checked)
			{
				_song.notes[curSec].sectionNotes = [];
			}

			if(check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while(i > -1) {
					var event:Array<Dynamic> = _song.events[i];
					if(event != null && endThing > event[0] && event[0] >= startThing)
					{
						_song.events.remove(event);
					}
					--i;
				}
			}
			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;
		
		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 100);
		check_notesSec.checked = true;
		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 100, check_notesSec.y, null, null, "Events", 100);
		check_eventsSec.checked = true;

		var swapSection:FlxButton = new FlxButton(10, check_notesSec.y + 40, "Swap Section", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
		});

		var stepperCopy:FlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, swapSection.y + 30, "Copy Last Section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if(value == 0) return;

			var daSec = FlxMath.maxInt(curSec, value);

			for (note in _song.notes[daSec - value].sectionNotes)
			{
				var strum = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);


				var copiedNote:Array<Dynamic> = [strum, note[1], note[2], note[3]];
				_song.notes[daSec].sectionNotes.push(copiedNote);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event[0];
				if(endThing > event[0] && event[0] >= startThing)
				{
					strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event[1].length)
					{
						var eventToPush:Array<Dynamic> = event[1][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();
		
		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var duetButton:FlxButton = new FlxButton(10, copyLastButton.y + 45, "Duet Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1];
				if (boob>3){
					boob -= 4;
				}else{
					boob += 4;
				}

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			_song.notes[curSec].sectionNotes.push(i);

			}

			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1]%4;
				boob = 3 - boob;
				if (note[1] > 3) boob += 4;

				note[1] = boob;
				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				//duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			//_song.notes[curSec].sectionNotes.push(i);

			}

			updateGrid();
		});

		tab_group_section.add(new FlxText(stepperBeats.x, stepperBeats.y - 15, 0, 'Beats per Section:'));
		tab_group_section.add(stepperBeats);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(check_notesSec);
		tab_group_section.add(check_eventsSec);
		tab_group_section.add(swapSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:FlxUIInputText; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:FlxUIDropDownMenuCustom;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		stepperSusLength.broadcastToFlxUI = true;
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, "0");
		strumTimeInputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if LUA_ALLOWED
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_notetypes/'));
		#if MODS_ALLOWED
		directories.push(Paths.modFolders('custom_notetypes/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && (file.endsWith('.lua') || file.endsWith('.hx'))) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!noteTypeMap.exists(fileToCheck)) {
							displayNameList.push(fileToCheck);
							noteTypeMap.set(fileToCheck, key);
							noteTypeIntMap.set(key, fileToCheck);
							key++;
						}
					}
				}
			}
		}
		#end

		for (i in 1...displayNameList.length) {
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new FlxUIDropDownMenuCustom(10, 105, FlxUIDropDownMenuCustom.makeStrIdLabelArray(displayNameList, true), function(type:String)
		{
			currentType = Std.parseInt(type);
			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = noteTypeIntMap.get(currentType);
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		strumTimeInputText.callback = function(text, _) {
			var newTime = Std.parseFloat(text);
			if (Math.isNaN(newTime)) newTime = 0;
			
			if (selectedNotes.length > 0) {
				var timeDiff = newTime - selectedNotes[0].strumTime;
				for (note in selectedNotes) {
					note.strumTime += timeDiff;
					note.rawData[0] = note.strumTime;
				}
				updateGrid();
			} else if (curSelectedNote != null) {
				curSelectedNote[0] = newTime;
				updateGrid();
			}
		};

		tab_group_note.add(new FlxText(10, 10, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(10, 50, 0, 'Strum time (in miliseconds):'));
		tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:FlxUIDropDownMenuCustom;
	var descText:FlxText;
	var selectedEventText:FlxText;
	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		#if LUA_ALLOWED
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_events/'));
		#if MODS_ALLOWED
		directories.push(Paths.modFolders('custom_events/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!eventPushedMap.exists(fileToCheck)) {
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length) {
			leEvents.push(eventStuff[i][0]);
		}

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);
		eventDropDown = new FlxUIDropDownMenuCustom(20, 50, FlxUIDropDownMenuCustom.makeStrIdLabelArray(leEvents, true), function(type:String) {
			var eventName = eventStuff[Std.parseInt(type)][0];
			descText.text = eventStuff[Std.parseInt(type)][1] ?? "No description available lol.";

			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.noteData < 0) {
						note.eventName = eventName;
						if (note.rawData[1][0] != null) {
							note.rawData[1][0][0] = eventName;
						}
					}
				}
				updateGrid();
			} else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
				curSelectedNote[1][curEventSelected][0] = eventName;
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new FlxUIInputText(20, 110, 100, "");
		value1InputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new FlxUIInputText(20, 150, 100, "");
		value2InputText.focusGained = () -> FlxG.stage.window.textInputEnabled = true;
		blockPressWhileTypingOn.push(value2InputText);

		value1InputText.callback = function(text, _) {
			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.noteData < 0) {
						note.eventVal1 = text;
						if (note.rawData[1][0] != null) {
							note.rawData[1][0][1] = text;
						}
					}
				}
				updateGrid();
			} else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
				curSelectedNote[1][curEventSelected][1] = text;
				updateGrid();
			}
		};

		value2InputText.callback = function(text, _) {
			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.noteData < 0) {
						note.eventVal2 = text;
						if (note.rawData[1][0] != null) {
							note.rawData[1][0][2] = text;
						}
					}
				}
				updateGrid();
			} else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
				curSelectedNote[1][curEventSelected][2] = text;
				updateGrid();
			}
		};

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				if(curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if(curEventSelected < 0) curEventSelected = 0;
				else if(curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function()
		{
			changeEventSelected(-1);
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function()
		{
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0)
	{
		if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if(curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	var metronome:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	var waveformUseInstrumental:FlxUICheckBox;
	var waveformUseVoices:FlxUICheckBox;
	var waveformUseOppVoices:FlxUICheckBox;
	var instVolume:FlxUINumericStepper;
	var voicesVolume:FlxUINumericStepper;
	var voicesOppVolume:FlxUINumericStepper;
	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';

		if (FlxG.save.data.chart_waveformInst == null) FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null) FlxG.save.data.chart_waveformVoices = false;
		if (FlxG.save.data.chart_waveformOppVoices == null) FlxG.save.data.chart_waveformOppVoices = false;

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, "Waveform (Instrumental)", 100);
		waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = function()
		{
			waveformUseVoices.checked = false;
			waveformUseOppVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformOppVoices = false;
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			updateWaveform();
		};

		waveformUseVoices = new FlxUICheckBox(waveformUseInstrumental.x + 125, waveformUseInstrumental.y, null, null, "Waveform\n(Main Voices)", 100);
		waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices && !waveformUseInstrumental.checked;
		waveformUseVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			waveformUseOppVoices.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformOppVoices = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
			updateWaveform();
		};

		waveformUseOppVoices = new FlxUICheckBox(waveformUseInstrumental.x + 260, waveformUseInstrumental.y, null, null, "Waveform\n(Opp. Voices)", 85);
		waveformUseOppVoices.checked = FlxG.save.data.chart_waveformOppVoices && !waveformUseVoices.checked;
		waveformUseOppVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformOppVoices = waveformUseOppVoices.checked;
			updateWaveform();
		};

		check_mute_inst = new FlxUICheckBox(10, 310, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};
		mouseScrollingQuant = new FlxUICheckBox(10, 200, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		mouseScrollingQuant.callback = function()
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};

		check_vortex = new FlxUICheckBox(10, 160, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
		check_vortex.checked = FlxG.save.data.chart_vortex;

		check_vortex.callback = function()
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
		check_warnings.checked = FlxG.save.data.ignoreWarnings;

		check_warnings.callback = function()
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};

		var check_mute_vocals = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, "Mute Main Voices (in editor)", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = function()
		{
			if(vocals != null) {
				var vol:Float = 1;

				if (check_mute_vocals.checked)
					vol = 0;

				vocals.volume = vol;
			}
		};

		check_mute_vocals_opponent = new FlxUICheckBox(check_mute_vocals.x + 120, check_mute_vocals.y, null, null, "Mute Opp. Voices (in editor)", 100);
		check_mute_vocals_opponent.checked = false;
		check_mute_vocals_opponent.callback = function()
		{
			var vol:Float = voicesOppVolume.value;
			if (check_mute_vocals_opponent.checked)
				vol = 0;

			if(opponentVocals != null) opponentVocals.volume = vol;
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, null, null, 'Play Sound (Player notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundBf = playSoundBf.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundBf == null) FlxG.save.data.chart_playSoundBf = false;
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundDad = playSoundDad.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundDad == null) FlxG.save.data.chart_playSoundDad = false;
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100,
			function() {
				FlxG.save.data.chart_metronome = metronome.checked;
			}
		);
		if (FlxG.save.data.chart_metronome == null) FlxG.save.data.chart_metronome = false;
		metronome.checked = FlxG.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(100, 55, 5, _song.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 215, metronome.y, null, null, "Disable Autoscroll (Not Recommended)", 120,
			function() {
				FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
			}
		);
		if (FlxG.save.data.chart_noAutoScroll == null) FlxG.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(50, 270, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		blockPressWhileTypingOnStepper.push(voicesVolume);

		voicesOppVolume = new FlxUINumericStepper(instVolume.x + 200, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesOppVolume.value = vocals.volume;
		voicesOppVolume.name = 'voices_opp_volume';
		blockPressWhileTypingOnStepper.push(voicesOppVolume);
		
		#if !html5
		sliderRate = new FlxUISlider(this, 'playbackSpeed', 165, 120, 0.5, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = 'Playback Rate';
		tab_group_chart.add(sliderRate);
		#end

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:'));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		tab_group_chart.add(new FlxText(instVolume.x - 2, instVolume.y - 15, 0, 'Inst Volume'));
		tab_group_chart.add(new FlxText(voicesVolume.x - 13, voicesVolume.y - 15, 0, 'Main Voices Vol.'));
		tab_group_chart.add(new FlxText(voicesOppVolume.x - 13, voicesOppVolume.y - 15, 0, 'Opp. Vocals Vol.'));
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);
		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		tab_group_chart.add(waveformUseInstrumental);
		tab_group_chart.add(waveformUseVoices);
		tab_group_chart.add(waveformUseOppVoices);
		tab_group_chart.add(instVolume);
		tab_group_chart.add(voicesVolume);
		tab_group_chart.add(voicesOppVolume);
		tab_group_chart.add(check_mute_inst);
		tab_group_chart.add(check_mute_vocals);
		tab_group_chart.add(check_mute_vocals_opponent);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_warnings);
		tab_group_chart.add(playSoundBf);
		tab_group_chart.add(playSoundDad);
		UI_box.addGroup(tab_group_chart);
	}

	function loadSong():Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		if(vocals != null)
		{
			vocals.stop();
			vocals.destroy();
		}

		if(opponentVocals != null)
		{
			opponentVocals.stop();
			opponentVocals.destroy();
		}

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			var playerVocals = Paths.voices(currentSongName, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1);
			vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(currentSongName));
		}
		vocals.autoDestroy = false;
		FlxG.sound.list.add(vocals);

		opponentVocals = new FlxSound();
		try
		{
			var oppVocals = Paths.voices(currentSongName, (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2);
			if(oppVocals != null) opponentVocals.loadEmbedded(oppVocals);
		}
		opponentVocals.autoDestroy = false;
		FlxG.sound.list.add(opponentVocals);

		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;
	}
	
	var characterData:Dynamic = {
		iconP1: null,
		iconP2: null,
		vocalsP1: null,
		vocalsP2: null
	};

	function updateJsonData():Void
	{
		for (i in 1...3)
		{
			var data:CharacterFile = loadHealthIconFromCharacter(Reflect.field(_song, 'player$i'));
			Reflect.setField(characterData, 'iconP$i', !characterFailed ? data.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP$i', data.vocals_file != null ? data.vocals_file : '');
		}
	}

	function generateSong() {
		FlxG.sound.playMusic(Paths.inst(currentSongName), 0.6/*, false*/);
		if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked) FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if(vocals != null) {
				vocals.pause();
				vocals.time = 0;
			}
			if(opponentVocals != null) {
				opponentVocals.pause();
				opponentVocals.time = 0;
			}
			changeSection();
			curSec = 0;
			updateGrid();
			updateSectionUI();
			if(vocals != null) vocals.play();
			if(opponentVocals != null) opponentVocals.play();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general freak
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must Hit Section':
					_song.notes[curSec].mustHitSection = check.checked;

					updateGrid();
					updateHeads();

				case 'GF Section':
					_song.notes[curSec].gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'Change BPM':
					_song.notes[curSec].changeBPM = check.checked;
					FlxG.log.add('changed bpm freak');

				case "Alt Animation":
					_song.notes[curSec].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			if (nums == stepperSusLength)
			{
				if (selectedNotes.length > 0) {
					for (note in selectedNotes) {
						if (note.noteData > -1) {
							note.rawData[2] = nums.value;
						}
					}
					updateGrid();
				} else if (curSelectedNote != null && curSelectedNote[2] != null) {
					curSelectedNote[2] = nums.value;
					updateGrid();
				}
			}

			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_beats')
			{
				_song.notes[curSec].sectionBeats = nums.value;
				reloadGridLayer();
			}
			else if (wname == 'song_speed')
			{
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = nums.value;
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(nums.value);
			}
			else if (wname == 'note_susLength')
			{
				if(curSelectedNote != null && curSelectedNote[2] != null) {
					curSelectedNote[2] = nums.value;
					updateGrid();
				}
			}
			else if (wname == 'section_bpm')
			{
				_song.notes[curSec].bpm = nums.value;
				updateGrid();
			}
			else if (wname == 'inst_volume')
			{
				FlxG.sound.music.volume = nums.value;
			}
			else if (wname == 'voices_volume')
			{
				vocals.volume = nums.value;
			}
			else if(wname == 'voices_opp_volume')
			{
				opponentVocals.volume = nums.value;
				if(check_mute_vocals_opponent.checked) opponentVocals.volume = 0;
			}
		}
		else if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(sender == noteSplashesInputText) {
				_song.splashSkin = noteSplashesInputText.text;
			}
			else if(curSelectedNote != null)
			{
				if(sender == value1InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][1] = value1InputText.text;
						updateGrid();
					}
				}
				else if(sender == value2InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][2] = value2InputText.text;
						updateGrid();
					}
				}
				else if(sender == strumTimeInputText) {
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if(Math.isNaN(value)) value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
			}
		}
		else if (id == FlxUISlider.CHANGE_EVENT && (sender is FlxUISlider))
		{
			switch (sender)
			{
				case 'playbackSpeed':
					playbackSpeed = Std.int(sliderRate.value);
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if(_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		return daPos;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;
	override function update(elapsed:Float)
	{
		curStep = recalculateSteps();

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = UI_songTitle.text;

		strumLineUpdateY();
		for (i in 0...8){
			strumLineNotes.members[i].y = strumLine.y;
		}

		FlxG.mouse.visible = true;//cause reasons. trust me
		camPos.y = strumLine.y;
		if(!disableAutoScrolling.checked) {
			if (Math.ceil(strumLine.y) >= gridBG.height)
			{
				if (_song.notes[curSec + 1] == null)
				{
					addSection();
				}

				changeSection(curSec + 1, false);
			} else if(strumLine.y < -10) {
				changeSection(curSec - 1, false);
			}
		}
		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.x > gridBG.x
				&& touch.x < gridBG.x + gridBG.width
				&& touch.y > gridBG.y
				&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
			{
				dummyArrow.visible = true;
				dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
				if (_virtualpad.buttonY.pressed)
					dummyArrow.y = touch.y;
				else
				{
					var gridmult = GRID_SIZE / (quantization / 16);
					dummyArrow.y = Math.floor(touch.y / gridmult) * gridmult;
				}
			} else {
				dummyArrow.visible = false;
			}

			if (touch.justReleased)
			{
				if (touch.overlaps(curRenderedNotes))
				{
					curRenderedNotes.forEachAlive(function(note:Note)
					{
						if (touch.overlaps(note))
						{
							//trace('tryin to delete note...');
							deleteNote(note);
						}
					});
				}
				else
				{
					if (touch.x > gridBG.x
						&& touch.x < gridBG.x + gridBG.width
						&& touch.y > gridBG.y
						&& touch.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
					{
						FlxG.log.add('added note');
						addNote();
					}
				}
			}
		}
		#else

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
			{
				var gridmult = GRID_SIZE / (quantization / 16);
				dummyArrow.y = Math.floor(FlxG.mouse.y / gridmult) * gridmult;
			}
		} else {
			dummyArrow.visible = false;
		}

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							curSelectedNote[3] = noteTypeIntMap.get(currentType);
							updateGrid();
						}
						else
						{
							//trace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * getSectionBeats() * 4) * zoomList[curZoom])
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}
		#end

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;
				break;
			}
		}

		if(!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				var leText:Dynamic = stepper.text_field;
				var leText:FlxUIInputText = leText;
				if(leText.hasFocus) {
					FlxG.sound.muteKeys = [];
					FlxG.sound.volumeDownKeys = [];
					FlxG.sound.volumeUpKeys = [];
					blockInput = true;
					break;
				}
			}
		}

		if(!blockInput) {
			FlxG.sound.muteKeys = Init.muteKeys;
			FlxG.sound.volumeDownKeys = Init.volumeDownKeys;
			FlxG.sound.volumeUpKeys = Init.volumeUpKeys;
			for (dropDownMenu in blockPressWhileScrolling) {
				if(dropDownMenu.dropPanel.visible) {
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ESCAPE #if mobile || _virtualpad.buttonB.justPressed #end)
			{
				autosaveSong();
				FlxG.sound.music.pause();
				vocals.pause();
				MusicBeatState.switchState(new game.states.editors.EditorPlayState(sectionStartTime()));
			}
			if (FlxG.keys.justPressed.ENTER #if mobile || _virtualpad.buttonA.justPressed #end)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				PlayState.SONG = _song;
				FlxG.sound.music.stop();
				if(vocals != null) vocals.stop();
				if(opponentVocals != null) opponentVocals.pause();

				//if(_song.stage == null) _song.stage = stageDropDown.selectedLabel;
				StageData.loadDirectory(_song);
				LoadingState.loadAndSwitchState(new PlayState());
			}

			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}

			updateSelectionBox();

			if (FlxG.mouse.justPressed)
			{
				var clickedOnNote = false;
				
				curRenderedNotes.forEachAlive(function(note:Note) {
					if (FlxG.mouse.overlaps(note)) {
						clickedOnNote = true;
					}
				});
				
				if (!clickedOnNote)
				{
					selecting = true;
					var mousePos = FlxG.mouse.getWorldPosition();
					selectStart.set(mousePos.x, mousePos.y);
					
					selectBox.visible = true;
					selectBox.x = mousePos.x;
					selectBox.y = mousePos.y;
					selectBox.scale.set(0, 0);
				}
			}

			if (FlxG.mouse.justReleased)
			{
				if (selecting)
				{
					selecting = false;
					selectBox.visible = false;
					
					var selectionBox = new FlxRect(
						selectBox.x, 
						selectBox.y, 
						selectBox.scale.x, 
						selectBox.scale.y
					);
					
					for (note in selectedNotes) {
						note.color = FlxColor.WHITE;
					}
					selectedNotes = [];
					
					curRenderedNotes.forEachAlive(function(note:Note) {
						var noteRect = new FlxRect(note.x, note.y, note.width, note.height);
						if (selectionBox.overlaps(noteRect)) {
							selectedNotes.push(note);
							note.color = FlxColor.BLUE;
						}
					});
					
					if (selectedNotes.length == 1) {
						selectNote(selectedNotes[0]);
					}
				}
				else
				{
					for (note in selectedNotes) {
						note.color = FlxColor.WHITE;
					}
					selectedNotes = [];
				}
			}

			#if mobile
			for (touch in FlxG.touches.list)
			{
				if (touch.justReleased)
				{
					selecting = false;
					selectBox.visible = false;
				}
			}
			#end

			if (FlxG.mouse.justPressedRight)
			{
				var clickedNote:Note = null;
				curRenderedNotes.forEachAlive(function(note:Note) {
					if (FlxG.mouse.overlaps(note)) clickedNote = note;
				});
				
				if (clickedNote != null)
				{
					openSubState(new ContextMenu(
						FlxG.mouse.screenX,
						FlxG.mouse.screenY,
						clickedNote,
						deleteNote,
						copyNote,
						pasteNote
					));
				}
			}

			if (FlxG.keys.justPressed.F1) {
				tipsSubstate = new ChartingTipsSubstate();
				openSubState(tipsSubstate);
			}

			if (FlxG.keys.justPressed.F2) {
				showCharacters = !showCharacters;
				opponent.visible = showCharacters;
				player.visible = showCharacters;
			}

			if (FlxG.keys.justPressed.BACKSPACE #if android || FlxG.android.justReleased.BACK #end) {
				PlayState.chartingMode = false;
				MusicBeatState.switchState(new game.states.editors.MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				FlxG.mouse.visible = false;
				return;
			}
			
			if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C && curSelectedNote != null)
			{
				var noteData = curSelectedNote[1];
				var isEvent = noteData == -1 || Std.isOfType(noteData, Array);
				
				var note:Note;
				if (isEvent) {
					note = new Note(curSelectedNote[0], -1);
					if (curSelectedNote[1].length > 0) {
						note.eventName = curSelectedNote[1][0][0];
						note.eventVal1 = curSelectedNote[1][0][1];
						note.eventVal2 = curSelectedNote[1][0][2];
					}
				} else {
					note = new Note(curSelectedNote[0], noteData % 4);
					note.sustainLength = curSelectedNote[2];
					note.noteType = curSelectedNote[3];
				}
				
				copyNote(note);
			}

			if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V)
			{
				pasteNote();
			}
 
			if(FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) {
				undo();
			}

			if(FlxG.keys.justPressed.Y && FlxG.keys.pressed.CONTROL) {
				redo();
			}

			if((FlxG.keys.justPressed.Z #if mobile || _virtualpad.buttonZ.justPressed #end) && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
				--curZoom;
				updateZoom();
			}
			if(FlxG.keys.justPressed.X #if mobile || _virtualpad.buttonC.justPressed #end && curZoom < zoomList.length-1) {
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selected_tab -= 1;
					if (UI_box.selected_tab < 0)
						UI_box.selected_tab = 2;
				}
				else
				{
					UI_box.selected_tab += 1;
					if (UI_box.selected_tab >= 3)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE #if mobile || _virtualpad.buttonX.justPressed #end)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if(vocals != null) vocals.pause();
					if(opponentVocals != null) opponentVocals.pause();
				}
				else
				{
					if(vocals != null) {
						vocals.play();
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
						vocals.play();
					}
					if(opponentVocals != null) {
						opponentVocals.play();
						opponentVocals.pause();
						opponentVocals.time = FlxG.sound.music.time;
						opponentVocals.play();
					}
					FlxG.sound.music.play();
				}
			}

			if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end)
					resetSection(true);
				else
					resetSection();
			}

			#if !mobile
			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				if (!mouseQuant)
					FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet*0.8);
				else
					{
						var time:Float = FlxG.sound.music.time;
						var beat:Float = curDecBeat;
						var snap:Float = quantization / 4;
						var increase:Float = 1 / snap;
						if (FlxG.mouse.wheel > 0)
						{
							var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}else{
							var fuck:Float = CoolUtil.quantize(beat, snap) + increase;
							FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
						}
					}
				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				if(opponentVocals != null) {
					opponentVocals.pause();
					opponentVocals.time = FlxG.sound.music.time;
				}
			}
			#end

			//ARROW VORTEX freak NO DEADASS



			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S #if mobile || _virtualpad.buttonUp.pressed || _virtualpad.buttonDown.pressed #end)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end) holdingShift = 4;

				var daTime:Float = 700 * FlxG.elapsed * holdingShift;

				if (FlxG.keys.pressed.W #if mobile || _virtualpad.buttonUp.pressed #end)
				{
					FlxG.sound.music.time -= daTime;
				}
				else
					FlxG.sound.music.time += daTime;

				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				if(opponentVocals != null) {
					opponentVocals.pause();
					opponentVocals.time = FlxG.sound.music.time;
				}
			}

			if(!vortex){
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();
					updateCurStep();
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP )
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase; //(Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}else{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; //(Math.floor((beat+snap) / snap) * snap);
						FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
					}
				}
			}

			var style = currentType;

			if (FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end) {
				style = 3;
			}

			var conductorTime = Conductor.songPosition; //+ sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			//AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if(!blockInput){
				if(FlxG.keys.justPressed.RIGHT #if mobile || _virtualpad.buttonRight.justPressed #end){
					curQuant++;
					if(curQuant>quantizations.length-1)
						curQuant = 0;

					quantization = quantizations[curQuant];
				}

				if(FlxG.keys.justPressed.LEFT  #if mobile || _virtualpad.buttonLeft.justPressed #end){
					curQuant--;
					if(curQuant<0)
						curQuant = quantizations.length-1;

					quantization = quantizations[curQuant];
				}
				quant.animation.play('q', true, false, curQuant);
			}
			if(vortex && !blockInput){
				var controlArray:Array<Bool> = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
											   FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];

				if(controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if(controlArray[i])
							doANoteThing(conductorTime, i, style);
					}
				}

				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN #if mobile || _virtualpad.buttonUp.justPressed || _virtualpad.buttonDown.justPressed #end)
				{
					FlxG.sound.music.pause();


					updateCurStep();
					//FlxG.sound.music.time = (Math.round(curStep/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;

						//(Math.floor((curStep+quants[curQuant]*1.5/(quants[curQuant]/2))/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;//snap into quantization
					var time:Float = FlxG.sound.music.time;
					var beat:Float = curDecBeat;
					var snap:Float = quantization / 4;
					var increase:Float = 1 / snap;
					if (FlxG.keys.pressed.UP #if mobile || _virtualpad.buttonUp.pressed #end)
					{
						var fuck:Float = CoolUtil.quantize(beat, snap) - increase;
						feces = Conductor.beatToSeconds(fuck);
					}else{
						var fuck:Float = CoolUtil.quantize(beat, snap) + increase; //(Math.floor((beat+snap) / snap) * snap);
						feces = Conductor.beatToSeconds(fuck);
					}
					FlxTween.tween(FlxG.sound.music, {time:feces}, 0.1, {ease:FlxEase.circOut});
					if(vocals != null) {
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
					}
					if(opponentVocals != null) {
						opponentVocals.pause();
						opponentVocals.time = FlxG.sound.music.time;
					}

					var dastrum = 0;

					if (curSelectedNote != null){
						dastrum = curSelectedNote[0];
					}

					var secStart:Float = sectionStartTime();
					var datime = (feces - secStart) - (dastrum - secStart); //idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
													   FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT];

						if(controlArray.contains(true))
						{

							for (i in 0...controlArray.length)
							{
								if(controlArray[i])
									if(curSelectedNote[1] == i) curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;
							}
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end)
				shiftThing = 4;

			if (FlxG.keys.justPressed.D #if mobile || _virtualpad.buttonRight.justPressed #end)
				changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A #if mobile || _virtualpad.buttonLeft.justPressed #end) {
				if(curSec <= 0) {
					changeSection(_song.notes.length-1);
				} else {
					changeSection(curSec - shiftThing);
				}
			}
		} else if (FlxG.keys.justPressed.ENTER) {
			for (i in 0...blockPressWhileTypingOn.length) {
				if(blockPressWhileTypingOn[i].hasFocus) {
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		_song.bpm = tempBpm;

		strumLineNotes.visible = quant.visible = vortex;

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLineUpdateY();
		camPos.y = strumLine.y;
		for (i in 0...8){
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		// PLAYBACK SPEED CONTROLS //
		var holdingShift = FlxG.keys.pressed.SHIFT;
		var holdingLB = FlxG.keys.pressed.LBRACKET;
		var holdingRB = FlxG.keys.pressed.RBRACKET;
		var pressedLB = FlxG.keys.justPressed.LBRACKET;
		var pressedRB = FlxG.keys.justPressed.RBRACKET;

		if (!holdingShift && pressedLB || holdingShift && holdingLB)
			playbackSpeed -= 0.01;
		if (!holdingShift && pressedRB || holdingShift && holdingRB)
			playbackSpeed += 0.01;
		if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB))
			playbackSpeed = 1;
		//

		if (playbackSpeed <= 0.5)
			playbackSpeed = 0.5;
		if (playbackSpeed >= 3)
			playbackSpeed = 3;

		FlxG.sound.music.pitch = playbackSpeed;
		vocals.pitch = playbackSpeed;
		opponentVocals.pitch = playbackSpeed;

		var currentTime:String = formatTime(Conductor.songPosition);
        var songLength:String = (FlxG.sound.music != null) ? formatTime(FlxG.sound.music.length) : "00:00:00";

        bpmTxt.text =
            "Time: " + currentTime + " / " + songLength +
            "\n\nSection: " + curSec +
            "\n\nBeat: " + Std.string(curDecBeat).substring(0,4) +
            "\n\nStep: " + curStep +
            "\n\nBeat Snap: " + quantization + "th";

		var activeNotes:Map<String, Bool> = ["player" => false, "opponent" => false];

		var playedSound:Array<Bool> = [false, false, false, false]; //Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive(function(note:Note) {
			note.alpha = 1;
			if (curSelectedNote != null) {
				var noteDataToCheck:Int = note.noteData;
				if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
		
				if (selectedNotes.contains(note)) {
					note.color = FlxColor.BLUE;
				}
				else if (curSelectedNote != null && note.rawData == curSelectedNote) {
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999);
				}
				else {
					note.color = FlxColor.WHITE;
				}
			}

			if (note.strumTime <= Conductor.songPosition && note.strumTime + note.sustainLength > Conductor.songPosition) {
				if (note.mustPress) activeNotes.set("player", true);
				else activeNotes.set("opponent", true);
			}
		
			if (note.strumTime <= Conductor.songPosition) {
				note.alpha = 0.4;
				if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1) {
					var data:Int = note.noteData % 4;
					var noteDataToCheck:Int = note.noteData;
					if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
					strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
					strumLineNotes.members[noteDataToCheck].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
					if (!playedSound[data]) {
						if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)) {
							var soundToPlay = 'hitsound';
							if (_song.player1 == 'gf') { // Easter egg
								soundToPlay = 'GF_' + Std.string(data + 1);
							}
							FlxG.sound.play(Paths.sound(soundToPlay)).pan = note.noteData < 4 ? -0.3 : 0.3;
							playedSound[data] = true;
						}

						var isPlayerNote = note.mustPress;
						var anims = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
						var animToPlay = anims[data];
						var shouldPlayAnim = !(note.ignoreNote || note.noAnimation);
						
						if (shouldPlayAnim) {
							if (isPlayerNote) {
								if (player.animation.getByName(animToPlay) != null) {
									player.playAnim(animToPlay, true);
									player.holdTimer = 0;
								}
							} else {
								if (opponent.animation.getByName(animToPlay) != null) {
									opponent.playAnim(animToPlay, true);
									opponent.holdTimer = 0;
								}
							}
						}
					}
				}
			}
		});	
		
		if (activeNotes.get("opponent") && opponent.animation.curAnim != null && opponent.animation.curAnim.name.startsWith('sing')) {
			opponent.holdTimer = 0;
		} else if (!activeNotes.get("opponent") && opponent.holdTimer >= Conductor.stepCrochet * 0.001 * opponent.singDuration) {
			if (opponent.animation.curAnim != null && opponent.animation.curAnim.name.startsWith('sing')) {
				opponent.dance();
			}
		}

		if (activeNotes.get("player") && player.animation.curAnim != null && player.animation.curAnim.name.startsWith('sing')) {
			player.holdTimer = 0;
		} else if (!activeNotes.get("player") && player.holdTimer >= Conductor.stepCrochet * 0.001 * player.singDuration) {
			if (player.animation.curAnim != null && player.animation.curAnim.name.startsWith('sing')) {
				player.dance();
			}
		}

		if(metronome.checked && lastConductorPos != Conductor.songPosition) {
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if(metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				//trace('Ticked');
			}
		}

		lastConductorPos = Conductor.songPosition;
		super.update(elapsed);
	}

	function updateZoom() {
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if(daZoom < 1) zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	}

	function reloadCharacter(char:String) {
		switch(char) {
			case 'player':
				remove(player);
				player = new Character(750, 435, _song.player1, true);
				player.scrollFactor.set();
				add(player);
				player.visible = showCharacters;

			case 'opponent':
				remove(opponent);
				opponent = new Character(450, 455, _song.player2, false, true);
				opponent.scrollFactor.set();
				add(opponent);
				opponent.visible = showCharacters;
		}
	}

	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;
	function reloadGridLayer() {
		gridLayer.clear();
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * getSectionBeats() * 4 * zoomList[curZoom]));

		if(FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOppVoices) {
			updateWaveform();
		}

		updateGrid();

		var foundPrevSec:Bool = false;
		var foundNextSec:Bool = false;

		var leHeight:Int = Std.int(gridBG.height) * -1;
		if(curSec > 0 && sectionStartTime(-1) >= 0)
		{
			prevGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * getSectionBeats(curSec - 1) * 4 * zoomList[curZoom]));
			leHeight = Std.int(gridBG.y - prevGridBG.height);
			foundPrevSec = true;
		}
		else prevGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		prevGridBG.y = gridBG.y - prevGridBG.height;

		var leHeight2:Int = Std.int(gridBG.height);
		if(sectionStartTime(1) <= FlxG.sound.music.length)
		{
			nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
			leHeight2 = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
		}
		else nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;

		gridLayer.add(prevGridBG);
		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if(foundPrevSec)
		{
			var gridBlackPrev:FlxSprite = new FlxSprite(0, prevGridBG.y).makeGraphic(Std.int(GRID_SIZE * 9), Std.int(prevGridBG.height), FlxColor.BLACK);
			gridBlackPrev.alpha = 0.4;
			gridLayer.add(gridBlackPrev);
		}

		if(foundNextSec)
		{
			var gridBlackNext:FlxSprite = new FlxSprite(0, gridBG.height).makeGraphic(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height), FlxColor.BLACK);
			gridBlackNext.alpha = 0.4;
			gridLayer.add(gridBlackNext);
		}

		var topY = prevGridBG.y;
        var totalHeight = nextGridBG.y + nextGridBG.height - topY;

		var gridBlackLineLeft = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, Std.int(totalHeight), FlxColor.BLACK);
        gridBlackLineLeft.y = topY;
        gridLayer.add(gridBlackLineLeft);

        var gridBlackLineRight = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(2, Std.int(totalHeight), FlxColor.BLACK);
        gridBlackLineRight.y = topY;
        gridLayer.add(gridBlackLineRight);

		for (i in 1...Std.int(getSectionBeats())) {
			var beatsep:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * zoomList[curZoom])) * i).makeGraphic(1, 1, 0x44FF0000);
			beatsep.scale.x = gridBG.width;
			beatsep.updateHitbox();
			if(vortex) gridLayer.add(beatsep);
		}

		lastSecBeats = getSectionBeats();
		if(sectionStartTime(1) > FlxG.sound.music.length) lastSecBeatsNext = 0;
		else getSectionBeats(curSec + 1);
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function updateWaveform() {
		if(waveformPrinted) {
			waveformSprite.makeGraphic(Std.int(GRID_SIZE * 8), Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices && !FlxG.save.data.chart_waveformOppVoices) {
			//trace('Epic fail on the waveform lol');
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = Math.round(getSectionBeats() * 4);
		var st:Float = sectionStartTime();
		var et:Float = st + (Conductor.stepCrochet * steps);

		if (FlxG.save.data.chart_waveformInst) {
			var sound:FlxSound = FlxG.sound.music;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		} 
		
		if (FlxG.save.data.chart_waveformVoices) {
			var sound:FlxSound = vocals;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		} 
		
		if (FlxG.save.data.chart_waveformOppVoices) {
			var sound:FlxSound = opponentVocals;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var size:Float = 1;

		var leftLength:Int = (
			wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length
		);

		var rightLength:Int = (
			wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length
		);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		var index:Int;
		for (i in 0...length) {
			index = i;

			lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2) {
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else {
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeNoteSustain(value:Float):Void
	{
		if (selectedNotes.length > 0)
		{
			for (note in selectedNotes)
			{
				if (note.noteData > -1 && note.rawData[2] != null)
				{
					note.rawData[2] += value;
					note.rawData[2] = Math.max(note.rawData[2], 0);
				}
			}
		}
		else if (curSelectedNote != null && curSelectedNote[2] != null)
		{
			curSelectedNote[2] += value;
			curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
		}

		updateGrid();
		updateNoteUI();
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old freak from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		if(vocals != null) {
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}
		if(opponentVocals != null) {
			opponentVocals.pause();
			opponentVocals.time = FlxG.sound.music.time;
		}
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		if (_song.notes[sec] != null)
		{
			curSec = sec;
			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = sectionStartTime();
				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				if(opponentVocals != null) {
					opponentVocals.pause();
					opponentVocals.time = FlxG.sound.music.time;
				}
				updateCurStep();
			}

			var blah1:Float = getSectionBeats();
			var blah2:Float = getSectionBeats(curSec + 1);
			if(sectionStartTime(1) > FlxG.sound.music.length) blah2 = 0;
	
			if(blah1 != lastSecBeats || blah2 != lastSecBeatsNext)
			{
				reloadGridLayer();
			}
			else
			{
				updateGrid();
			}
			updateSectionUI();
		}
		else
		{
			changeSection();
		}

		/*if (player.holdTimer >= Conductor.stepCrochet * 0.001 * player.singDuration)
			player.dance();

		if (opponent.holdTimer >= Conductor.stepCrochet * 0.001 * opponent.singDuration)
			opponent.dance();*/

		Conductor.songPosition = FlxG.sound.music.time;
		updateWaveform();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSec];

		stepperBeats.value = getSectionBeats();
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	function updateHeads():Void
	{
		var char1:CharacterFile = loadHealthIconFromCharacter(_song.player1);
		var char2:CharacterFile = loadHealthIconFromCharacter(_song.player2);
		var char3:CharacterFile = loadHealthIconFromCharacter(_song.gfVersion);
		
		var healthIconP1:String = !characterFailed ? char1.healthicon : 'face';
		var healthIconP2:String = !characterFailed ? char2.healthicon : 'face';
		var healthIconGF:String = !characterFailed ? char3.healthicon : 'face';
	
		if (_song.notes[curSec].mustHitSection)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (_song.notes[curSec].gfSection) leftIcon.changeIcon(healthIconGF);
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (_song.notes[curSec].gfSection) rightIcon.changeIcon(healthIconGF);
		}

		//trace ('Health icons updated');
	}

	var characterFailed:Bool = false;
	function loadHealthIconFromCharacter(char:String):CharacterFile {
		characterFailed = false;
		var characterPath:String = 'characters/' + char + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!OpenFlAssets.exists(path))
		#end
		{
			path = Paths.getPreloadPath('characters/' + Character.DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			characterFailed = true;
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = OpenFlAssets.getText(path);
		#end
		return cast Json.parse(rawJson);
	}

	function updateNoteUI():Void
	{
		if (selectedNotes.length > 0)
		{
			var firstNote = selectedNotes[0];
			var allSameSustain = true;
			var allSameType = true;
			var allSameEvent = true;
			var firstEventName = null;
			var firstEventVal1 = null;
			var firstEventVal2 = null;

			for (note in selectedNotes)
			{
				if (note.rawData[2] != firstNote.rawData[2]) allSameSustain = false;
				if (note.rawData[3] != firstNote.rawData[3]) allSameType = false;
				
				if (note.noteData < 0) // hevent
				{
					if (firstEventName == null)
					{
						firstEventName = note.eventName;
						firstEventVal1 = note.eventVal1;
						firstEventVal2 = note.eventVal2;
					}
					else
					{
						if (note.eventName != firstEventName) allSameEvent = false;
						if (note.eventVal1 != firstEventVal1) allSameEvent = false;
						if (note.eventVal2 != firstEventVal2) allSameEvent = false;
					}
				}
			}

			if (firstNote.noteData > -1) // nomal nutes
			{
				stepperSusLength.value = allSameSustain ? firstNote.rawData[2] : 0;
				currentType = allSameType ? noteTypeMap.get(firstNote.rawData[3]) : 0;
				noteTypeDropDown.selectedLabel = allSameType ? currentType + '. ' + firstNote.rawData[3] : '[Multiple]';
				strumTimeInputText.text = '';
			}
			else // eventus
			{
				eventDropDown.selectedLabel = allSameEvent ? firstNote.eventName : '[Multiple]';
				value1InputText.text = allSameEvent ? firstNote.eventVal1 : '';
				value2InputText.text = allSameEvent ? firstNote.eventVal2 : '';
				strumTimeInputText.text = '';
			}
		}
		else if (curSelectedNote != null)
		{
			if(curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if(curSelectedNote[3] != null) {
					currentType = noteTypeMap.get(curSelectedNote[3]);
					if(currentType <= 0) {
						noteTypeDropDown.selectedLabel = '';
					} else {
						noteTypeDropDown.selectedLabel = currentType + '. ' + curSelectedNote[3];
					}
				}
			} else {
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if(selected > 0 && selected < eventStuff.length) {
					descText.text = eventStuff[selected][1];
				}
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
		else
		{
			stepperSusLength.value = 0;
			noteTypeDropDown.selectedLabel = '';
			eventDropDown.selectedLabel = '';
			value1InputText.text = '';
			value2InputText.text = '';
			strumTimeInputText.text = '';
		}
	}

	function updateGrid():Void
	{
		curRenderedNotes.clear();
		curRenderedSustains.clear();
		curRenderedNoteType.clear();
		nextRenderedNotes.clear();
		nextRenderedSustains.clear();
		prevRenderedNotes.clear();
		prevRenderedSustains.clear();
	
		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0) {
			Conductor.changeBPM(_song.notes[curSec].bpm);
		} else {
			var daBPM:Float = _song.bpm;
			for (i in 0...curSec) {
				if (_song.notes[i].changeBPM) {
					daBPM = _song.notes[i].bpm;
				}
			}
			Conductor.changeBPM(daBPM);
		}

		curRenderedNotes.forEachAlive(function(note:Note) {
			if (selectedNotes.contains(note)) {
				note.color = FlxColor.BLUE;
			} else {
				note.color = FlxColor.WHITE;
			}
		});
	
		// CURRENT SECTION
		var beats:Float = getSectionBeats();
		for (i in _song.notes[curSec].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note, beats));
			}
	
			if(i[3] != null && note.noteType != null && note.noteType.length > 0) {
				var typeInt:Null<Int> = noteTypeMap.get(i[3]);
				var theType:String = '' + typeInt;
				if(typeInt == null) theType = '?';
	
				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 18);
				daText.setFormat(Paths.font("pixel-latin.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				daText.borderStyle = NONE;
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			note.mustPress = _song.notes[curSec].mustHitSection;
			if(i[1] > 3) note.mustPress = !note.mustPress;
		}
	
		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events)
		{
			if(endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);
	
				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: ' + note.eventVal2;
				if(note.eventLength > 1) text = note.eventLength + ' Events:\n' + note.eventName;
	
				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 8);
				daText.setFormat(Paths.font("pixel-latin.ttf"), 8, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.borderStyle = NONE;
				daText.xAdd = -410;
				daText.borderSize = 1;
				if(note.eventLength > 1) daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
				//trace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
			}
		}
	
		// NEXT SECTION
		var beats:Float = getSectionBeats(1);
		if(curSec < _song.notes.length-1) {
			for (i in _song.notes[curSec+1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true, false);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note, beats));
				}
			}
		}

		// PREV SECTION 
		var beats:Float = getSectionBeats(-1); 
		if(curSec > 0) {
			for (i in _song.notes[curSec-1].sectionNotes)
			{
				var note:Note = setupNoteData(i, false, true);
				note.alpha = 0.6;
				prevRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					prevRenderedSustains.add(setupSusNote(note, beats));
				}
			}
		}
	
		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in _song.events)
		{
			if(endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}

		// PREV EVENTS
		var beats:Float = getSectionBeats(-1); 
		if(curSec > 0) {
			for (i in _song.events)
			{
				var note:Note = setupNoteData(i, false, true);
				note.alpha = 0.6;
				prevRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					prevRenderedSustains.add(setupSusNote(note, beats));
				}
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool, isPrevSection:Bool = false):Note
	{
		var daNoteInfo = i[1];
		var daStrumTime = i[0];
		var daSus:Dynamic = i[2];

		var note:Note = new Note(daStrumTime, daNoteInfo % 4, null, null, true);
		if(daSus != null) { //Common note
			if(!Std.isOfType(i[3], String)) //Convert old note type to new note type format
			{
				i[3] = noteTypeIntMap.get(i[3]);
			}
			if(i.length > 3 && (i[3] == null || i[3].length < 1))
			{
				i.remove(i[3]);
			}
			note.sustainLength = daSus;
			note.noteType = i[3] != null ? i[3] : "";
		} else { //Event note
			note.loadGraphic(Paths.image('eventArrow'));
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if(i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.eventName = getEventName(i[1]);
			note.noteData = -1;
			daNoteInfo = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if(isNextSection && _song.notes[curSec].mustHitSection != _song.notes[curSec+1].mustHitSection) {
			if(daNoteInfo > 3) {
				note.x -= GRID_SIZE * 4;
			} else if(daSus != null) {
				note.x += GRID_SIZE * 4;
			}
		}
		if(isPrevSection && _song.notes[curSec].mustHitSection != _song.notes[curSec-1].mustHitSection) {
			if(daNoteInfo > 3) {
				note.x -= GRID_SIZE * 4;
			} else if(daSus != null) {
				note.x += GRID_SIZE * 4;
			}
		}

		var num:Int = 0;
		if(isNextSection) num = 1;
		if(isPrevSection) num = -1;
		var beats:Float = getSectionBeats(curSec + num);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		note.rawData = i;
		//if(isNextSection) note.y += gridBG.height;
		//if(note.y < -150) note.y = -150;
		return note;
	}

	private function updateNoteData(oldNote:Note, newNote:Note):Void
	{
		if (oldNote.rawData != null)
		{
			oldNote.rawData[0] = newNote.strumTime;
			oldNote.rawData[1] = newNote.noteData;
			oldNote.rawData[2] = newNote.sustainLength;
			
			if (oldNote.noteData > -1) // for namal nutes
			{
				if (oldNote.rawData.length > 3) {
					oldNote.rawData[3] = newNote.noteType;
				} else if (newNote.noteType != null && newNote.noteType.length > 0) {
					oldNote.rawData.push(newNote.noteType);
				}
			}
			else // for events
			{
				if (oldNote.rawData.length > 1 && oldNote.rawData[1].length > 0) {
					oldNote.rawData[1][0][0] = newNote.eventName;
					oldNote.rawData[1][0][1] = newNote.eventVal1;
					oldNote.rawData[1][0][2] = newNote.eventVal2;
				}
			}
		}
		else
		{
			if (oldNote.noteData > -1) {
				for (section in _song.notes) {
					for (noteData in section.sectionNotes) {
						if (noteData[0] == oldNote.strumTime && noteData[1] == oldNote.noteData) {
							noteData[0] = newNote.strumTime;
							noteData[1] = newNote.noteData;
							noteData[2] = newNote.sustainLength;
							if (noteData.length > 3) {
								noteData[3] = newNote.noteType;
							} else if (newNote.noteType != null) {
								noteData.push(newNote.noteType);
							}
							return;
						}
					}
				}
			} else {
				for (event in _song.events) {
					if (event[0] == oldNote.strumTime) {
						if (event[1].length > 0) {
							event[1][0][0] = newNote.eventName;
							event[1][0][1] = newNote.eventVal1;
							event[1][0][2] = newNote.eventVal2;
						}
						return;
					}
				}
			}
		}
	}


	function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if(addedOne) retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	function setupSusNote(note:Note, beats:Float):FlxSprite
	{
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom]) + (GRID_SIZE * zoomList[curZoom]) - GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if(height < minHeight) height = minHeight;
		if(height < 1) height = 1;

		// Player/Opponent note sustains
		var color:FlxColor;
		if(note.noteData > 3) { // opponent notes (4-7)
			color = sustainColorsOppo[note.noteData - 4];
		} else { // player notes (0-3)
			color = sustainColors[note.noteData];
		}

		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE / 2).makeGraphic(8, height, color);
		return spr;
	}

	private function addSection(sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;
		curSelectedNote = null;

		if (FlxG.keys.pressed.CONTROL)
		{
			if (selectedNotes.contains(note))
			{
				note.color = FlxColor.WHITE;
				selectedNotes.remove(note);
			}
			else
			{
				note.color = FlxColor.BLUE;
				selectedNotes.push(note);
			}
			return;
		}

		if(noteDataToCheck > -1) // Normal note
		{
			if(note.mustPress != _song.notes[curSec].mustHitSection) {
            	noteDataToCheck += 4;
        	}
			
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else // Event
		{
			for (i in _song.events)
			{
				if (i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = 0;
					break;
				}
			}
		}
		
		if (curSelectedNote != null) {
			changeEventSelected();
			updateGrid();
			updateNoteUI();
		}
	}

	function deleteNote(note:Note):Void
	{
		if (selectedNotes.length > 0)
		{
			for (n in selectedNotes) {
				_deleteSingleNote(n);
				n.color = n.noteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
			}
			selectedNotes = [];
		}
		else
		{
			_deleteSingleNote(note);
			note.color = note.noteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
		}

		updateGrid();
	}

	private function _deleteSingleNote(note:Note):Void
	{
		saveToUndo();
		
		if (note.rawData != null)
		{
			if (note.noteData > -1) {
				for (section in _song.notes) {
					if (section.sectionNotes.contains(note.rawData)) {
						section.sectionNotes.remove(note.rawData);
						break;
					}
				}
			} else {
				_song.events.remove(note.rawData);
			}
		}
		else
		{
			var noteDataToCheck = note.noteData;
			if (note.noteData > -1) {
				for (section in _song.notes) {
					for (i in 0...section.sectionNotes.length) {
						var noteData = section.sectionNotes[i];
						if (noteData[0] == note.strumTime && noteData[1] == noteDataToCheck) {
							section.sectionNotes.remove(noteData);
							return;
						}
					}
				}
			} else {
				for (i in 0..._song.events.length) {
					if (_song.events[i][0] == note.strumTime) {
						_song.events.remove(_song.events[i]);
						return;
					}
				}
			}
		}
	}

	public function doANoteThing(cs, d, style){
		var delnote = false;
		if(strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y+1)) && note.noteData == d%4)
				{
						//trace('tryin to delete note...');
						if(!delnote) deleteNote(note);
						delnote = true;
				}
			});
		}

		if (!delnote){
			addNote(cs, d, style);
		}
	}
	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		saveToUndo();
		var noteStrum = getStrumTime(dummyArrow.y, false) + sectionStartTime();
		var noteData = 0;
		#if mobile
		for (touch in FlxG.touches.list)
		{
			noteData = Math.floor((touch.x - GRID_SIZE) / GRID_SIZE);
		}
		#else
		noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		#end
		var noteSus = 0;
		var daAlt = false;
		var daType = currentType;

		if (strum != null) noteStrum = strum;
		if (data != null) noteData = data;
		if (type != null) daType = type;

		if(noteData > -1)
		{
			var noteTypeValue = noteTypeIntMap.exists(daType) ? noteTypeIntMap.get(daType) : "";
			_song.notes[curSec].sectionNotes.push([
				noteStrum, 
				noteData, 
				noteSus, 
				noteTypeValue
			]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		}
		else
		{
			var event = eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			var text1 = value1InputText.text;
			var text2 = value2InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
		}
		changeEventSelected();

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, noteTypeIntMap.get(daType)]);
		}

		//trace(noteData + ', ' + noteStrum + ', ' + curSec);
		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
	}

	public static function checkForJSON(jsonInput:String, ?folder:String):String
	{
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(FileSystem.exists(moddyFile)) {
			return moddyFile;
		}
		#end

		return Paths.json(formattedFolder + '/' + formattedSong);
	}

	function saveToUndo() {
        if (undos.length >= maxUndoSteps) undos.shift();
        undos.push(Json.parse(Json.stringify(_song)));
        redos = [];
    }

	function undo() {
        if (undos.length > 0) {
            var lastState = undos.pop();
            redos.push(Json.parse(Json.stringify(_song)));
            _song = lastState;
            updateGrid();
            updateSectionUI();
        }
    }

    function redo() {
        if (redos.length > 0) {
            var lastState = redos.pop();
            undos.push(Json.parse(Json.stringify(_song)));
            _song = lastState;
            updateGrid();
            updateSectionUI();
        }
    }

	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}
	
	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
	{
		var value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
	}

	function copyNote(note:Note):Void
	{
		if (note == null) return;
		
		saveToUndo();
		
		if (clipboardNotes == null) clipboardNotes = [];
		clipboardNotes = [];
		
		if (selectedNotes.length > 0)
		{
			for (n in selectedNotes) copySingleNote(n);
			trace("Copied " + selectedNotes.length + " notes");
		}
		else
		{
			copySingleNote(note);
			FlxG.log.add("Copied 1 note");
		}

		selectedNotes = [];
		
		updateGrid();
	}

	function pasteNote():Void
	{
		if (clipboardNotes == null || clipboardNotes.length == 0) {
			FlxG.log.add("Clipboard is empty");
			return;
		}
		
		saveToUndo();
		
		var timeShift:Float = Conductor.songPosition - clipboardNotes[0][0];
		
		for (noteData in clipboardNotes)
		{
			var newData = noteData.copy();
			newData[0] += timeShift;
			
			if (Std.isOfType(newData[1], Array)) // Event
			{
				_song.events.push(newData);
			}
			else // Normal Note
			{
				_song.notes[curSec].sectionNotes.push(newData);
			}
		}
		
		updateGrid();
		trace("Pasted " + clipboardNotes.length + " notes");
	}

	function updateSelectionBox():Void {
		if (selecting) {
			selectBox.visible = true;
			
			var mousePos = FlxG.mouse.getWorldPosition();
			var width = mousePos.x - selectStart.x;
			var height = mousePos.y - selectStart.y;
			
			selectBox.scale.set(Math.abs(width), Math.abs(height));
			selectBox.updateHitbox();
			
			selectBox.x = width < 0 ? mousePos.x : selectStart.x;
			selectBox.y = height < 0 ? mousePos.y : selectStart.y;

			for (note in selectedNotes) {
                if (note.rawData == null) {
                    if (note.noteData > -1) {
                        for (section in _song.notes) {
                            for (noteData in section.sectionNotes) {
                                if (noteData[0] == note.strumTime && noteData[1] == note.noteData) {
                                    note.rawData = noteData;
                                    break;
                                }
                            }
                        }
                    } else {
                        for (event in _song.events) {
                            if (event[0] == note.strumTime) {
                                note.rawData = event;
                                break;
                            }
                        }
                    }
                }
            }
		}
	}

	private function copySingleNote(note:Note):Void
	{
		var noteData = getNoteData(note);
		if (noteData != null) clipboardNotes.push(noteData);
	}

	private function getNoteData(note:Note):Array<Dynamic>
	{
		if (note.rawData != null) {
			return note.rawData.copy();
		}
		
		if (note.noteData > -1) {
			return [
				note.strumTime,
				note.noteData,
				note.sustainLength,
				note.noteType != null ? note.noteType : ""
			];
		} else {
			return [
				note.strumTime,
				[[
					note.eventName,
					note.eventVal1 != null ? note.eventVal1 : "",
					note.eventVal2 != null ? note.eventVal2 : ""
				]]
			];
		}
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
		var songLower:String = song.toLowerCase();	
		var lastDashIndex = songLower.lastIndexOf("-");
			
		PlayState.SONG = Song.loadFromJson(songLower, songLower);
		MusicBeatState.resetState();
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	private function saveLevel()
	{
		if(_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		
		// remove format & offset fields if they exist
		Reflect.deleteField(_song, "format");
		Reflect.deleteField(_song, "offset");
		
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			#if mobile
			SUtil.saveContent(Paths.formatToSongPath(_song.song) + ".json", data.trim());
			#else
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
			#end
		}
	}

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}


    function formatTime(ms:Float):String {
		var mm:Int = Std.int(ms / 60000);
		var ss:Int = Std.int((ms % 60000) / 1000);
		var msDisplay:Int = Std.int((ms % 1000) / 10);
	
		return StringTools.lpad(Std.string(mm), "0", 2) + ":" +
			   StringTools.lpad(Std.string(ss), "0", 2) + ":" +
			   StringTools.lpad(Std.string(msDisplay), "0", 2);
	}

	private function saveEvents()
	{
		if(_song.events != null && _song.events.length > 1) _song.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			#if mobile
			SUtil.saveContent("events.json", data.trim());
			#else
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
			#end
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
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
		FlxG.log.error("Problem saving Level data");
	}

	function getSectionBeats(?section:Null<Int> = null)
	{
		if (section == null) section = curSec;
		var val:Null<Float> = null;
		
		if(_song.notes[section] != null) val = _song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true) {
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null) {
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}

class ChartingTipsSubstate extends MusicBeatSubstate
{
    public function new()
    {
        super();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.8;
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		var text:String = 
			"F2 - Show/hide characters\n" +
			"W/S or Mouse Wheel - Change playback position\n" +
			"A/D - Go to previous/next section\n" +
			"Left/Right - Change quantization\n" +
			"Up/Down - Change playback position with quantization\n" +
			"[ / ] - Change playback speed (SHIFT for faster change)\n" +
			"ALT + [ / ] - Reset playback speed\n" +
			"SHIFT - Move faster (4x)\n" +
			"CTRL + click - Select note/event\n" +
			"Ctrl + Z - Undo\n" +
			"Ctrl + Y - Redo\n" +
			"Z/X - Zoom in/out\n" +
			"ENTER - Play chart\n" +
			"Q/E - Decrease/increase note length\n" +
			"SPACE - Pause/resume playback";

		var tipTextArray:Array<String> = text.split('\n');
		var grpTexts:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();
		add(grpTexts);

		// calculate total height for vertical centering --math brouu
		var lineHeight:Int = 30;
		var totalHeight:Int = tipTextArray.length * lineHeight;
		var startY:Float = (FlxG.height - totalHeight) / 2;

		for (i in 0...tipTextArray.length) {
			var text:FlxText = new FlxText(0, startY + (i * lineHeight), FlxG.width, tipTextArray[i], 24);
			text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.screenCenter(X);
			text.scrollFactor.set();
			grpTexts.add(text);
		}
		
		var closeText:FlxText = new FlxText(0, FlxG.height - 40, FlxG.width, "Press F1/ESC to close tips", 16);
		closeText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		closeText.screenCenter(X);
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

class ContextMenu extends MusicBeatSubstate
{
    public function new(x:Float, y:Float, note:Note, deleteCallback:Note->Void, copyCallback:Note->Void, pasteCallback:Void->Void)
    {
        super();
        
        var bg:FlxSprite = new FlxSprite().makeGraphic(100, 130, FlxColor.BLACK);
		bg.scrollFactor.set();
        bg.alpha = 0.8;
        bg.x = x;
        bg.y = y;
        add(bg);
        
        var deleteBtn = new FlxButton(x + 10, y + 10, "Delete", () -> {
            deleteCallback(note);
            close();
        });
        
        var copyBtn = new FlxButton(x + 10, y + 40, "Copy", () -> {
            copyCallback(note);
            close();
        });
        
        var pasteBtn = new FlxButton(x + 10, y + 70, "Paste", () -> {
            pasteCallback();
            close();
        });
        
        var propertiesBtn = new FlxButton(x + 10, y + 100, "Properties", () -> {
            openNoteProperties(note);
            close();
        });
        
        add(deleteBtn);
        add(copyBtn);
        add(pasteBtn);
        add(propertiesBtn);
        
        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    }
    
    function openNoteProperties(note:Note):Void
	{
		@:privateAccess {
			var parent:ChartingState = cast FlxG.state.subState._parentState;
			parent.openSubState(new NotePropertiesSubstate(note, function(updatedNote:Note) {
				parent.saveToUndo();
				parent.updateNoteData(note, updatedNote);
				parent.updateGrid();
			}, parent.eventStuff));
		}
	}
}

class NotePropertiesSubstate extends MusicBeatSubstate
{
    var note:Note;
    var onSaveCallback:Note->Void;
    var onCloseCallback:Void->Void;
	var eventStuff:Array<Dynamic>;
    
	var descText:FlxText;
    var strumTimeStepper:FlxUINumericStepper;
    var noteDataStepper:FlxUINumericStepper;
    var sustainStepper:FlxUINumericStepper;
    var typeInput:FlxUIInputText;
    var value1Input:FlxUIInputText;
    var value2Input:FlxUIInputText;
    var eventDropdown:FlxUIDropDownMenuCustom;
    
    public function new(note:Note, onSaveCallback:Note->Void, eventStuff:Array<Dynamic>)
	{
        super();
        this.note = note;
        this.onSaveCallback = onSaveCallback;
		this.eventStuff = eventStuff; 
        
        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        bg.scrollFactor.set();
        add(bg);
        
        var panel = new FlxSprite(FlxG.width / 2 - 150, FlxG.height / 2 - 150).makeGraphic(300, 300, FlxColor.GRAY);
		panel.scrollFactor.set();
        add(panel);
        
        var title = new FlxText(panel.x, panel.y + 10, 300, "Note Properties", 16);
        title.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		title.scrollFactor.set();
        add(title);
        
        var yOffset:Int = 50;
        
        if (note.noteData > -1)
        {
            var timeLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Strum Time:");
			timeLabel.scrollFactor.set();
            add(timeLabel);
            
            strumTimeStepper = new FlxUINumericStepper(panel.x + 120, panel.y + yOffset, 10, note.strumTime, 0, 999999, 0);
			strumTimeStepper.scrollFactor.set();
            add(strumTimeStepper);
            yOffset += 30;
            
            var dataLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Note Data:");
			dataLabel.scrollFactor.set();
            add(dataLabel);
            
			noteDataStepper = new FlxUINumericStepper(panel.x + 120, panel.y + yOffset, 1, note.noteData, 0, 7, 0);
			noteDataStepper.scrollFactor.set();
            add(noteDataStepper);
            yOffset += 30;
            
            var sustainLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Sustain:");
			sustainLabel.scrollFactor.set();
            add(sustainLabel);
            
            sustainStepper = new FlxUINumericStepper(panel.x + 120, panel.y + yOffset, 10, note.sustainLength, 0, 9999, 0);
			sustainStepper.scrollFactor.set();
            add(sustainStepper);
            yOffset += 30;
            
            var typeLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Note Type:");
			typeLabel.scrollFactor.set();
            add(typeLabel);
            
            typeInput = new FlxUIInputText(panel.x + 120, panel.y + yOffset, 150, note.noteType != null ? note.noteType : "");
			typeInput.scrollFactor.set();
            add(typeInput);
        }
        else
        {
            var eventLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Event Type:");
			eventLabel.scrollFactor.set();
            add(eventLabel);
            
            var eventList = [];
            for (i in 0...eventStuff.length) {
                eventList.push({label: eventStuff[i][0], id: Std.string(i)});
            }
            
            var eventNames:Array<String> = [for (event in eventStuff) event[0]];
			eventDropdown = new FlxUIDropDownMenuCustom(panel.x + 120, panel.y + yOffset, 
				FlxUIDropDownMenuCustom.makeStrIdLabelArray(eventNames), 
				function(id:String) {
					var selectedEventIndex = Std.parseInt(id);
					if (selectedEventIndex >= 0 && selectedEventIndex < eventStuff.length) {
						var eventName = eventStuff[selectedEventIndex][0];
						var eventDesc = eventStuff[selectedEventIndex][1];
						descText.text = eventDesc;
						
						if (value1Input != null && value1Input.text == "") {
							var defaultValues = getDefaultEventValues(eventName);
							value1Input.text = defaultValues[0];
							value2Input.text = defaultValues[1];
						}
					}
				}
			);
            eventDropdown.selectedId = note.eventName;
			eventDropdown.scrollFactor.set();
			
            yOffset += 30;
            
            var val1Label = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Value 1:");
			val1Label.scrollFactor.set();
            add(val1Label);
            
            value1Input = new FlxUIInputText(panel.x + 120, panel.y + yOffset, 150, note.eventVal1 != null ? note.eventVal1 : "");
			value1Input.scrollFactor.set();
            add(value1Input);

            yOffset += 30;
            
            var val2Label = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Value 2:");
			val2Label.scrollFactor.set();
            add(val2Label);
            
            value2Input = new FlxUIInputText(panel.x + 120, panel.y + yOffset, 150, note.eventVal2 != null ? note.eventVal2 : "");
			value2Input.scrollFactor.set();
            add(value2Input);

			var currentEventIndex = -1;
			for (i in 0...eventStuff.length)
			{
				if (eventStuff[i][0] == note.eventName)
				{
					currentEventIndex = i;
					break;
				}
			}

			descText = new FlxText(panel.x + 20, panel.y + yOffset + 30, 260, "", 12);
			descText.wordWrap = true;
			descText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE);
			descText.scrollFactor.set();
			add(descText);

			if (currentEventIndex != -1)
			{
				eventDropdown.selectedId = Std.string(currentEventIndex);
				
				descText.text = eventStuff[currentEventIndex][1];
			}
			else
			{
				eventDropdown.selectedLabel = note.eventName;
				descText.text = "Custom Event";
			}
        }
        
        yOffset += 40;

		if (note.noteData == -1) yOffset += 80;
        
        var saveButton = new FlxButton(panel.x + 50, panel.y + yOffset, "Save", () -> {
            saveChanges();
            close();
        });
        add(saveButton);
        
        var cancelButton = new FlxButton(panel.x + 150, panel.y + yOffset, "Cancel", () -> {
            close();
        });
        add(cancelButton);

		add(eventDropdown);
        
        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    }
    
    function saveChanges()
    {
        var updatedNote = new Note(0, 0);
        updatedNote.noteData = note.noteData;
        
        if (note.noteData > -1) //Nomal note
        {
			var newData = Std.int(noteDataStepper.value);
        	if (note.noteData > 3) newData += 4;
        
            updatedNote.strumTime = strumTimeStepper.value;
            updatedNote.noteData = newData;
            updatedNote.sustainLength = sustainStepper.value;
            updatedNote.noteType = typeInput.text;
        }
        else //Event
        {
            updatedNote.strumTime = note.strumTime;
			updatedNote.eventName = eventDropdown.selectedLabel;
			updatedNote.eventVal1 = value1Input.text;
			updatedNote.eventVal2 = value2Input.text;
			
			if (value1Input != null) updatedNote.eventVal1 = value1Input.text;
			if (value2Input != null) updatedNote.eventVal2 = value2Input.text;
        }
        
        onSaveCallback(updatedNote);
    }

	function getDefaultEventValues(eventName:String):Array<String>
	{
		switch(eventName)
		{
			case 'Dadbattle Spotlight':
				return ['1', '0'];
			case 'Hey!':
				return ['BF', '0.6'];
			case 'Set GF Speed':
				return ['1', ''];
			case 'Add Camera Zoom':
				return ['0.015', '0.03'];
			case 'Play Animation':
				return ['idle', 'BF'];
			case 'Camera Follow Pos':
				return ['', ''];
			case 'Alt Idle Animation':
				return ['BF', '-alt'];
			case 'Screen Shake':
				return ['0, 0.05', '0, 0.05'];
			case 'Change Character':
				return ['BF', 'bf-car'];
			case 'Change Scroll Speed':
				return ['1', '1'];
			case 'Lyrics':
				return ['Hello! --FF0000', '2'];
			case 'Set Property':
				return ['health', '0.5'];
			default:
				return ['', ''];
		}
	}
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (FlxG.keys.justPressed.ESCAPE)
        {
            close();
        }
    }
}
