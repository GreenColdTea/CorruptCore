package game.states.editors;

//modified by Justin/GreenColdTea

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import haxe.Json;
import haxe.format.JsonParser;
import haxe.io.Bytes;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
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

import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxSort;

import lime.media.AudioBuffer;
import lime.utils.Assets;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
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
import game.objects.HealthIcon;
import game.objects.Note;
import game.objects.StrumNote;
import game.objects.Prompt;

import game.states.editors.meta.ChartBackupManager;

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

class ChartEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent

{
	public static final GRID_SIZE:Int = 40;
	public final CAM_OFFSET:Int = 180;

	var autoBackupTimer:FlxTimer;
	var backupInterval:Float = 30; // half minute per seconds

	var backupManager:ChartBackupManager;

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
		['Play Sound', "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"],
		['Play Video', "Value 1: Video file name"],
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
		['Play Sound', "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"],
		['Play Video', "Value 1: Video file name/URl"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		["Lyrics", "Lyrics!!!\nValue 1: Text and optionally, colour\n(To specify colour, seperate it by a --)\nValue 2: Duration, in seconds.\nDuration defaults to text length multiplied by 0.5"],
		['Set Property', "Value 1: Variable name\nValue 2: New value"]
	];

	private var _file:FileReference;
    var postfix:String = '';
    
	var mainBox:PsychUIBox;
	var mainBoxPosition:FlxPoint = FlxPoint.get(875, 50);
	var infoBox:PsychUIBox;
	var infoBoxPosition:FlxPoint = FlxPoint.get(50, 145);

	var infoText:FlxText;

	public static var goToPlayState:Bool = false;
	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec:Int = 0;
	public static var lastSection:Int = 0;
	private static var lastSong:String = '';

	var followPoint:FlxPoint;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

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

	var value1InputText:PsychUIInputText;
	var value2InputText:PsychUIInputText;
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

	//select box things
	var selectBox:FlxSprite;
	var selectBoxOutline:FlxSprite;
	var selecting = false;
	var selectStart:FlxPoint = new FlxPoint();
	var selectedNotes:Array<Note> = [];

	var clipboardNotes:Array<Dynamic> = [];

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

	var chartEditorSave:FlxSave;

	var camUI:FlxCamera;
	
	override function create()
	{
		//yep, this shit causes lags
		MemoryUtil.forceGC(false);

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
			_song = Song.getDefaultSong();

			addSection();
			PlayState.SONG = _song;
		}

		initFNFCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		chartEditorSave = new FlxSave();
		chartEditorSave.bind('chart_editor_data', CoolUtil.getSavePath());

		FlxG.mouse.visible = true;

		backupManager = new ChartBackupManager(this);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = chartEditorSave.data.chart_vortex;
		ignoreWarnings = chartEditorSave.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(GRID_SIZE + 375).loadGraphic(Paths.image('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		rightIcon.flipX = true;

		eventIcon.scrollFactor.set();
		leftIcon.scrollFactor.set();
		rightIcon.scrollFactor.set();

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		eventIcon.cameras = [camUI];
		leftIcon.cameras = [camUI];
		rightIcon.cameras = [camUI];

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(eventIcon.x + 90, eventIcon.y - 10);
		rightIcon.setPosition(leftIcon.x + 162, leftIcon.y);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		prevRenderedSustains = new FlxTypedGroup<FlxSprite>();
		prevRenderedNotes = new FlxTypedGroup<Note>();

		if(curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		tempBpm = _song.bpm;

		addSection();

		updateJsonData();
		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		strumLine.screenCenter(X);
		add(strumLine);

		quant = new AttachedSprite('chart_quant', 'chart_quant');
		quant.animation.addByPrefix('q','chart_quant',0,false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -GRID_SIZE;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0...8){
			var note:StrumNote = new StrumNote(gridBG.x + GRID_SIZE * (i+1), strumLine.y, i % 4, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		followPoint = new FlxPoint(strumLine.x + CAM_OFFSET, strumLine.y);
		FlxG.camera.follow(strumLine, LOCKON, 999);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		dummyArrow.screenCenter(X);
		add(dummyArrow);

		opponent = new Character(25, 390, "dad", false, true);
		opponent.scrollFactor.set();
		opponent.cameras = [camUI];
		add(opponent);

		player = new Character(opponent.x + 275, opponent.y + 125, "bf", true, true);
		player.scrollFactor.set();
		player.cameras = [camUI];
		add(player);

		mainBox = new PsychUIBox(mainBoxPosition.x, mainBoxPosition.y, 365, 400, ['Charting', 'Events', 'Note', 'Section', 'Song']);
		mainBox.selectedName = 'Charting';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		add(mainBox);

		infoBox = new PsychUIBox(infoBoxPosition.x, infoBoxPosition.y, 220, 190, ['Information']);
		infoBox.scrollFactor.set();
		infoBox.cameras = [camUI];

		infoText = new FlxText(15, 12, 230, '', 16);
		infoText.scrollFactor.set();
		infoBox.getTab('Information').menu.add(infoText);
		add(infoBox);

		// save data positions for the UI boxes
		if(chartEditorSave.data.mainBoxPosition != null && chartEditorSave.data.mainBoxPosition.length > 1)
			mainBox.setPosition(chartEditorSave.data.mainBoxPosition[0], chartEditorSave.data.mainBoxPosition[1]);
		if(chartEditorSave.data.infoBoxPosition != null && chartEditorSave.data.infoBoxPosition.length > 1)
			infoBox.setPosition(chartEditorSave.data.infoBoxPosition[0], chartEditorSave.data.infoBoxPosition[1]);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		updateWaveform();

		FlxG.camera.follow(strumLine, LOCKON, 999);

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);
		add(prevRenderedSustains);
		add(prevRenderedNotes);

		if(lastSong != currentSongName) changeSection();
		lastSong = currentSongName;

		zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.y -= 500;
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

		updateGrid();

		createSongSlider();

		opponent.visible = false;
		player.visible = false;

		selectBox = new FlxSprite();
		selectBox.makeGraphic(1, 1, FlxColor.BLUE);
		selectBox.alpha = 0.4;
		selectBox.visible = false;
		selectBox.blend = ADD;
		add(selectBox);

		selectBoxOutline = new FlxSprite();
		selectBoxOutline.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		selectBoxOutline.alpha = 0.8;
		selectBoxOutline.visible = false;
		add(selectBoxOutline);

		#if mobile
	  	addVirtualPad(LEFT_FULL, A_B_C_X_Y_Z);
		#end

		autoBackupTimer = new FlxTimer();
		autoBackupTimer.start(backupInterval, (tmr:FlxTimer) -> {
			backupManager.createAutoBackup(_song);
			tmr.reset(backupInterval);
		}, 0);

		super.create();
	}

	var sliderBg:FlxSprite;
	var pressF1Text:FlxText;
	var positionSlider:PsychUISlider;
	var timeText:FlxText;
	inline function createSongSlider() {
		sliderBg = new FlxSprite(0, FlxG.height - 60).makeGraphic(FlxG.width, 60, FlxColor.BLACK);
		sliderBg.alpha = 0.85;
		sliderBg.scrollFactor.set();
		sliderBg.cameras = [camUI];
		add(sliderBg);

		pressF1Text = new FlxText(sliderBg.x, sliderBg.y + 45, 0, "Press F1 to open tips", 8);
		pressF1Text.setFormat(Paths.font("pixel-latin.ttf"), 8, FlxColor.WHITE, LEFT);
		pressF1Text.scrollFactor.set();
		pressF1Text.cameras = [camUI];
		add(pressF1Text);

		timeText = new FlxText(10, FlxG.height - 30, FlxG.width - 20, "00:00:00 / 00:00:00", 16);
		timeText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		timeText.scrollFactor.set();
		timeText.cameras = [camUI];
		add(timeText);

		positionSlider = new PsychUISlider(10, FlxG.height - 50, (v:Float) -> {
			if (FlxG.sound.music != null && positionSlider.movingHandle) {
				var targetTime = v * FlxG.sound.music.length;
				FlxG.sound.music.pause();
				FlxG.sound.music.time = targetTime;
				
				if (vocals != null) {
					vocals.pause();
					vocals.time = targetTime;
				}
				if (opponentVocals != null) {
					opponentVocals.pause();
					opponentVocals.time = targetTime;
				}
				
				updateCurStep();
				updateGrid();
			}
		}, 0, 0, 1, FlxG.width - 20, FlxColor.fromRGB(194, 62, 201), FlxColor.WHITE);
		positionSlider.rightColor = FlxColor.fromRGB(57, 23, 59);
		
		positionSlider.minText.visible = false;
		positionSlider.maxText.visible = false;
		positionSlider.valueText.visible = false;
		positionSlider.labelText.visible = false;
		positionSlider.broadcastSliderEvent = false;
		
		positionSlider.cameras = [camUI];
		add(positionSlider);
	}

	inline function updateSongSlider() {
		if (FlxG.sound.music != null && FlxG.sound.music.length > 0) {
			var ratio = FlxG.sound.music.time / FlxG.sound.music.length;
			if (!positionSlider.movingHandle) positionSlider.value = ratio;
			
			var currentTime = formatTime(FlxG.sound.music.time);
			var totalTime = formatTime(FlxG.sound.music.length);
			timeText.text = currentTime + " / " + totalTime;
		} else {
			timeText.text = "00:00:00 / 00:00:00";
		}
	}

	var check_mute_inst:PsychUICheckBox = null;
	var check_mute_vocals:PsychUICheckBox = null;
	var check_mute_vocals_opponent:PsychUICheckBox = null;
	var check_vortex:PsychUICheckBox = null;
	var check_warnings:PsychUICheckBox = null;
	var playSoundBf:PsychUICheckBox = null;
	var playSoundDad:PsychUICheckBox = null;
	var UI_songTitle:PsychUIInputText;
	var noteSkinInputText:PsychUIInputText;
	var noteSplashesInputText:PsychUIInputText;
	var holdCoverInputText:PsychUIInputText;
	var stageDropDown:PsychUIDropDownMenu;
	var playbackSlider:PsychUISlider;
	inline function addSongUI():Void
	{
		var tab_group_song = mainBox.getTab('Song').menu;

		UI_songTitle = new PsychUIInputText(10, 10, 70, _song.song, 8);

		var check_voices = new PsychUICheckBox(10, 27, "Has Voice Track", 100);
		check_voices.checked = _song.needsVoices;
		check_voices.onClick = () -> _song.needsVoices = check_voices.checked;

		var saveButton:PsychUIButton = new PsychUIButton(185, 8, "Save", () -> saveChart());

		var reloadSong:PsychUIButton = new PsychUIButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			_song.song = UI_songTitle.text;
			updateJsonData();
			loadSong();
			updateWaveform();
		});

		var reloadSongJson:PsychUIButton = new PsychUIButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.sound.music.pause();
				vocals?.pause();
				opponentVocals?.pause();
			}
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function() {
				_song.song = UI_songTitle.text;
				var songName = _song.song.toLowerCase();
				loadJson(songName);
			}, null, ignoreWarnings, "OK", "CANCEL"));
		});

		var loadBackupButton:PsychUIButton = new PsychUIButton(reloadSongJson.x, reloadSongJson.y + 30, "Load Backup", () ->
			backupManager.loadBackup()
		);

		var createBackupButton:PsychUIButton = new PsychUIButton(loadBackupButton.x - 90, loadBackupButton.y, "Create Backup", () ->
			backupManager.createManualBackup(_song)
		);

		var loadEventJson:PsychUIButton = new PsychUIButton(loadBackupButton.x, loadBackupButton.y + 30, 'Load Events', function()
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

		var saveEvents:PsychUIButton = new PsychUIButton(saveButton.x, reloadSongJson.y, 'Save Events', function ()
		{
			saveEvents();
		});

		var clear_notes:PsychUIButton = new PsychUIButton(260, 340, 'Clear Notes', function()
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals?.pause();
					opponentVocals?.pause();
				}
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, () -> {
				for (sec in 0..._song.notes.length) {
					_song.notes[sec].sectionNotes = [];
				}
				updateGrid();
			}, null, ignoreWarnings, "OK", "CANCEL"));

			});
		clear_notes.normalStyle.bgColor = FlxColor.RED;
		clear_notes.normalStyle.textColor = FlxColor.WHITE;

		var clear_events:PsychUIButton = new PsychUIButton(clear_notes.x, clear_notes.y - 30, 'Clear Events', function()
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals?.pause();
					opponentVocals?.pause();
				}
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null, ignoreWarnings, "OK", "CANCEL"));
			});
		clear_events.normalStyle.bgColor = FlxColor.RED;
		clear_events.normalStyle.textColor = FlxColor.WHITE;

		var stepperBPM:PsychUINumericStepper = new PsychUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		stepperBPM.onValueChange = () -> {
			_song.bpm = stepperBPM.value;
			updateGrid();
		}

		var stepperSpeed:PsychUINumericStepper = new PsychUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		var directories:Array<String> = [#if MODS_ALLOWED Paths.mods('characters/'), Paths.mods(Paths.currentModDirectory + '/characters/'), #end SUtil.getPath() + Paths.getPreloadPath('characters/')];
		#if MODS_ALLOWED
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

		#if sys
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

		var player1DropDown = new PsychUIDropDownMenu(10, stepperSpeed.y + 45, characters, function(id:Int, character:String)
		{
			_song.player1 = characters[id];
			updateJsonData();
			updateHeads();
			//reloadCharacter('player'); temporarly disabled
		});
		player1DropDown.selectedLabel = _song.player1;

		var gfVersionDropDown = new PsychUIDropDownMenu(player1DropDown.x, player1DropDown.y + 40, characters, function(id:Int, character:String)
		{
			_song.gfVersion = characters[id];
			updateJsonData();
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = _song.gfVersion;

		var player2DropDown = new PsychUIDropDownMenu(player1DropDown.x, gfVersionDropDown.y + 40, characters, function(id:Int, character:String)
		{
			_song.player2 = characters[id];
			updateJsonData();
			updateHeads();
			//reloadCharacter('opponent'); this too
		});
		player2DropDown.selectedLabel = _song.player2;

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

		#if sys
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

		stageDropDown = new PsychUIDropDownMenu(player1DropDown.x + 175, player1DropDown.y, stages, (id:Int, character:String) -> _song.stage = stages[id]);
		stageDropDown.selectedLabel = _song.stage;
		
		noteSkinInputText = new PsychUIInputText(player2DropDown.x, player2DropDown.y + 50, 150, PlayState.SONG.arrowSkin ?? '', 8);

		noteSplashesInputText = new PsychUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 150, PlayState.SONG.splashSkin ?? '', 8);
		noteSplashesInputText.onChange = (old, curTxt) -> PlayState.SONG.splashSkin = curTxt;

		holdCoverInputText = new PsychUIInputText(noteSplashesInputText.x, noteSplashesInputText.y + 35, 150, PlayState.SONG.holdCoverSkin ?? '', 8);
		holdCoverInputText.onChange = (old, curTxt) -> PlayState.SONG.holdCoverSkin = curTxt;

		var reloadNotesButton:PsychUIButton = new PsychUIButton(noteSkinInputText.x + 160, noteSkinInputText.y - 2.5, 'Change Notes', function() {
			try {
				_song.arrowSkin = noteSkinInputText.text;
				updateGrid();
			} catch (_:Dynamic) {
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals?.pause();
					opponentVocals?.pause();
				}
                openSubState(new Prompt('Notes skin not found!\nPlease check the notes skin name.', 1, () -> closeSubState(), 
					null, false, "OK", null
				));
			}
		});

		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEvents);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(createBackupButton);
		tab_group_song.add(loadBackupButton);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);
		tab_group_song.add(holdCoverInputText);
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Player:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		tab_group_song.add(new FlxText(holdCoverInputText.x, holdCoverInputText.y - 15, 0, 'Note Hold Covers Texture:'));
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfVersionDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(stageDropDown);

		//FlxG.camera.follow(camPos, LOCKON, 999);
	}

	var stepperBeats:PsychUINumericStepper;
	var check_mustHitSection:PsychUICheckBox;
	var check_gfSection:PsychUICheckBox;
	var check_changeBPM:PsychUICheckBox;
	var stepperSectionBPM:PsychUINumericStepper;
	var check_altAnim:PsychUICheckBox;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	inline function addSectionUI():Void
	{
		var tab_group_section = mainBox.getTab('Section').menu;

		check_mustHitSection = new PsychUICheckBox(10, 15, "Must Hit Section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new PsychUICheckBox(10, check_mustHitSection.y + 22, "GF Section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;
		// _song.needsVoices = check_mustHit.checked;

		check_altAnim = new PsychUICheckBox(check_gfSection.x + 120, check_gfSection.y, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;

		stepperBeats = new PsychUINumericStepper(10, 100, 1, 4, 1, 6, 2);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new PsychUICheckBox(10, stepperBeats.y + 30, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';
		check_changeBPM.onClick = () -> {
			updateGrid();
			updateNoteUI();
		}

		stepperSectionBPM = new PsychUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		stepperSectionBPM.value = check_changeBPM.checked ? _song.notes[curSec].bpm : Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';
		stepperSectionBPM.onValueChange = () -> {
			updateGrid();
			updateNoteUI();
		}

		var check_eventsSec:PsychUICheckBox = null;
		var check_notesSec:PsychUICheckBox = null;
		var copyButton:PsychUIButton = new PsychUIButton(10, 190, "Copy Section", function()
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

		var pasteButton:PsychUIButton = new PsychUIButton(copyButton.x + 130, copyButton.y, "Paste Section", function()
		{
			if(notesCopied == null || notesCopied.length < 1) return;

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

		var clearSectionButton:PsychUIButton = new PsychUIButton(pasteButton.x + 130, pasteButton.y, "Clear", function()
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
		clearSectionButton.normalStyle.bgColor = FlxColor.RED;
		clearSectionButton.normalStyle.textColor = FlxColor.WHITE;
		
		check_notesSec = new PsychUICheckBox(10, clearSectionButton.y + 25, "Notes", 100);
		check_notesSec.checked = true;
		check_eventsSec = new PsychUICheckBox(check_notesSec.x + 100, check_notesSec.y, "Events", 100);
		check_eventsSec.checked = true;

		var swapSection:PsychUIButton = new PsychUIButton(10, check_notesSec.y + 40, "Swap Section", function()
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
		});

		var stepperCopy:PsychUINumericStepper = null;
		var copyLastSecButton:PsychUIButton = new PsychUIButton(swapSection.x, swapSection.y + 35, "Copy Last Section", function()
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
		copyLastSecButton.resize(80, 26);
		
		stepperCopy = new PsychUINumericStepper(copyLastSecButton.x + 100, copyLastSecButton.y + 5, 1, 1, -999, 999, 0);

		var duetButton:PsychUIButton = new PsychUIButton(10, copyLastSecButton.y + 45, "Duet Notes", function()
		{
			var duetNotes:Array<Array<Dynamic>> = [];
			for (note in _song.notes[curSec].sectionNotes)
			{
				var boob = note[1];
				boob -= (boob > 3) ? 4 : -4;

				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
				duetNotes.push(copiedNote);
			}

			for (i in duetNotes){
			_song.notes[curSec].sectionNotes.push(i);

			}

			updateGrid();
		});
		var mirrorButton:PsychUIButton = new PsychUIButton(duetButton.x + 100, duetButton.y, "Mirror Notes", function()
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
		tab_group_section.add(copyLastSecButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);
	}

	var stepperSusLength:PsychUINumericStepper;
	var strumTimeInputText:PsychUIInputText; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:PsychUIDropDownMenu;
	var currentType:Int = 0;

	inline function addNoteUI():Void
	{
		var tab_group_note = mainBox.getTab('Note').menu;

		stepperSusLength = new PsychUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';

		strumTimeInputText = new PsychUIInputText(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_notetypes/'));
		#if MODS_ALLOWED
		directories.push(Paths.modFolders('custom_notetypes/'));
		#end

		#if sys
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
		#end

		for (i in 1...displayNameList.length) {
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new PsychUIDropDownMenu(10, 105, displayNameList, function(id:Int, type:String)
		{
			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.noteData > -1) {
						note.rawData[3] = noteTypeIntMap.get(id);
					}
				}
				currentType = id;
				updateGrid();
			}
			else if (curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = noteTypeIntMap.get(id);
				currentType = id;
				updateGrid();
			}
		});

		strumTimeInputText.onChange = function(old, curTxt) {
			var newTime = Std.parseFloat(curTxt);
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
	}

	var eventDropDown:PsychUIDropDownMenu;
	var descText:FlxText;
	var selectedEventText:FlxText;
	inline function addEventsUI():Void
	{
		var tab_group_event = mainBox.getTab('Events').menu;

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_events/'));
		#if MODS_ALLOWED
		directories.push(Paths.modFolders('custom_events/'));
		#end

		#if sys
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
		#end
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
		eventDropDown = new PsychUIDropDownMenu(20, 50, leEvents, function(id:Int, type:String) {
			var eventName = eventStuff[id][0];
			descText.text = eventStuff[id][1] ?? "No description available lol.";

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

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new PsychUIInputText(20, 110, 100, "");

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new PsychUIInputText(20, 150, 100, "");

		value1InputText.onChange = function(old, curText) {
			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.noteData < 0) {
						note.eventVal1 = curText;
						if (note.rawData[1][0] != null) {
							note.rawData[1][0][1] = curText;
						}
					}
				}
				updateGrid();
			} else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
				curSelectedNote[1][curEventSelected][1] = curText;
				updateGrid();
			}
		};

		value2InputText.onChange = function(old, curText) {
			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.noteData < 0) {
						note.eventVal2 = curText;
						if (note.rawData[1][0] != null) {
							note.rawData[1][0][2] = curText;
						}
					}
				}
				updateGrid();
			} else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
				curSelectedNote[1][curEventSelected][2] = curText;
				updateGrid();
			}
		};

		// New event buttons
		var removeButton:PsychUIButton = new PsychUIButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
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
		}, 20);
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;
		tab_group_event.add(removeButton);

		var addButton:PsychUIButton = new PsychUIButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		}, 20);
		addButton.normalStyle.bgColor = FlxColor.GREEN;
		addButton.normalStyle.textColor = FlxColor.WHITE;
		tab_group_event.add(addButton);

		var moveLeftButton:PsychUIButton = new PsychUIButton(addButton.x + addButton.width + 20, addButton.y, '<', () -> changeEventSelected(-1), 20);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:PsychUIButton = new PsychUIButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', () -> changeEventSelected(1), 20);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);
	}

	inline function changeEventSelected(change:Int = 0)
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

	var metronome:PsychUICheckBox;
	var mouseScrollingQuant:PsychUICheckBox;
	var metronomeStepper:PsychUINumericStepper;
	var metronomeOffsetStepper:PsychUINumericStepper;
	var disableAutoScrolling:PsychUICheckBox;
	var waveformUseInstrumental:PsychUICheckBox;
	var waveformUseVoices:PsychUICheckBox;
	var waveformUseOppVoices:PsychUICheckBox;
	var instVolume:PsychUINumericStepper;
	var voicesVolume:PsychUINumericStepper;
	var voicesOppVolume:PsychUINumericStepper;
	inline function addChartingUI() {
		var tab_group_chart = mainBox.getTab('Charting').menu;

		chartEditorSave.data.chart_waveformInst ??= false;
		chartEditorSave.data.chart_waveformVoices ??= false;
		chartEditorSave.data.chart_waveformOppVoices ??= false;

		waveformUseInstrumental = new PsychUICheckBox(10, 90, "Waveform (Instrumental)", 100);
		waveformUseInstrumental.checked = chartEditorSave.data.chart_waveformInst;
		waveformUseInstrumental.onClick = function()
		{
			waveformUseVoices.checked = false;
			waveformUseOppVoices.checked = false;
			chartEditorSave.data.chart_waveformVoices = false;
			chartEditorSave.data.chart_waveformOppVoices = false;
			chartEditorSave.data.chart_waveformInst = waveformUseInstrumental.checked;
			updateWaveform();
		};

		waveformUseVoices = new PsychUICheckBox(waveformUseInstrumental.x + 125, waveformUseInstrumental.y, "Waveform\n(Main Voices)", 100);
		waveformUseVoices.checked = chartEditorSave.data.chart_waveformVoices && !waveformUseInstrumental.checked;
		waveformUseVoices.onClick = function()
		{
			waveformUseInstrumental.checked = false;
			waveformUseOppVoices.checked = false;
			chartEditorSave.data.chart_waveformInst = false;
			chartEditorSave.data.chart_waveformOppVoices = false;
			chartEditorSave.data.chart_waveformVoices = waveformUseVoices.checked;
			updateWaveform();
		};

		waveformUseOppVoices = new PsychUICheckBox(waveformUseInstrumental.x + 260, waveformUseInstrumental.y, "Waveform\n(Opp. Voices)", 85);
		waveformUseOppVoices.checked = chartEditorSave.data.chart_waveformOppVoices && !waveformUseVoices.checked;
		waveformUseOppVoices.onClick = function()
		{
			waveformUseInstrumental.checked = false;
			waveformUseVoices.checked = false;
			chartEditorSave.data.chart_waveformInst = false;
			chartEditorSave.data.chart_waveformVoices = false;
			chartEditorSave.data.chart_waveformOppVoices = waveformUseOppVoices.checked;
			updateWaveform();
		};

		check_mute_inst = new PsychUICheckBox(10, 310, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.onClick = function()
		{
			var vol:Float = check_mute_inst.checked ? 0 : instVolume.value;
			FlxG.sound.music.volume = vol;
		};
		mouseScrollingQuant = new PsychUICheckBox(10, 200, "Mouse Scrolling Quantization", 100);
		chartEditorSave.data.mouseScrollingQuant ??= false;
		mouseScrollingQuant.checked = chartEditorSave.data.mouseScrollingQuant;

		mouseScrollingQuant.onClick = function()
		{
			chartEditorSave.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = chartEditorSave.data.mouseScrollingQuant;
		};

		check_vortex = new PsychUICheckBox(10, 160, "Vortex Editor (BETA)", 100);
		chartEditorSave.data.chart_vortex ??= false;
		check_vortex.checked = chartEditorSave.data.chart_vortex;

		check_vortex.onClick = function()
		{
			chartEditorSave.data.chart_vortex = check_vortex.checked;
			vortex = chartEditorSave.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new PsychUICheckBox(10, 120, "Ignore Progress Warnings", 100);
		chartEditorSave.data.ignoreWarnings ??= false;
		check_warnings.checked = chartEditorSave.data.ignoreWarnings;

		check_warnings.onClick = function()
		{
			chartEditorSave.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = chartEditorSave.data.ignoreWarnings;
		};

		var check_mute_vocals = new PsychUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, "Mute Main Voices (in editor)", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.onClick = function()
		{
			var vol:Float = check_mute_vocals.checked ? 0 : voicesVolume.value;
			if(vocals != null) vocals.volume = vol;
		};

		check_mute_vocals_opponent = new PsychUICheckBox(check_mute_vocals.x + 120, check_mute_vocals.y, "Mute Opp. Voices (in editor)", 100);
		check_mute_vocals_opponent.checked = false;
		check_mute_vocals_opponent.onClick = function()
		{
			var vol:Float = check_mute_vocals_opponent.checked ? 0 : voicesOppVolume.value;
			if(opponentVocals != null) opponentVocals.volume = vol;
		};

		playSoundBf = new PsychUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, 'Play Sound (Player notes)', 100,
			() -> chartEditorSave.data.chart_playSoundBf = playSoundBf.checked);
		chartEditorSave.data.chart_playSoundBf ??= false;
		playSoundBf.checked = chartEditorSave.data.chart_playSoundBf;

		playSoundDad = new PsychUICheckBox(check_mute_inst.x + 120, playSoundBf.y, 'Play Sound (Opponent notes)', 100,
			() -> chartEditorSave.data.chart_playSoundDad = playSoundDad.checked);
		chartEditorSave.data.chart_playSoundDad ??= false;
		playSoundDad.checked = chartEditorSave.data.chart_playSoundDad;

		metronome = new PsychUICheckBox(10, 15, "Metronome Enabled", 100,
			() -> chartEditorSave.data.chart_metronome = metronome.checked);
		chartEditorSave.data.chart_metronome ??= false;
		metronome.checked = chartEditorSave.data.chart_metronome;

		metronomeStepper = new PsychUINumericStepper(100, 55, 5, _song.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new PsychUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);

		disableAutoScrolling = new PsychUICheckBox(metronome.x + 215, metronome.y, "Disable Autoscroll (Not Recommended)", 120,
			() -> chartEditorSave.data.chart_noAutoScroll = disableAutoScrolling.checked);
		chartEditorSave.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = chartEditorSave.data.chart_noAutoScroll;

		instVolume = new PsychUINumericStepper(50, 270, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';

		voicesVolume = new PsychUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';

		voicesOppVolume = new PsychUINumericStepper(instVolume.x + 200, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesOppVolume.value = vocals.volume;
		voicesOppVolume.name = 'voices_opp_volume';
		
		#if FLX_PITCH
		playbackSlider = new PsychUISlider(145, 120, (v:Float) -> playbackSpeed = v, 1, 0.1, 5.0, 200);
		playbackSlider.label = 'Playback Rate';
		tab_group_chart.add(playbackSlider);
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
	}

	inline function loadSong():Void
	{
	    FlxG.sound?.music?.stop();

		vocals?.stop();
		vocals?.destroy();

		opponentVocals?.stop();
		opponentVocals?.destroy();

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			var playerVocals = Paths.voices(currentSongName, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1);
			vocals.loadEmbedded(playerVocals ?? Paths.voices(currentSongName));
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
			var tmp:Dynamic = Reflect.field(_song, 'player' + Std.string(i));
			var data:CharacterFile = loadHealthIconFromCharacter(cast tmp);
			Reflect.setField(characterData, 'iconP' + Std.string(i), !characterFailed ? data.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP' + Std.string(i), data.vocals_file != null ? data.vocals_file : '');
		}
	}

	inline function generateSong() {
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
			
			vocals?.play();
			opponentVocals?.play();
		};
	}

	inline function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general freak
		var title:FlxText = new FlxText(mainBox.x + 20, mainBox.y + 20, 0);
		bullshitUI.add(title);
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		switch (id)
		{
			case PsychUIBox.DROP_EVENT:
				chartEditorSave.data.mainBoxPosition = [mainBox.x, mainBox.y];
				chartEditorSave.data.infoBoxPosition = [infoBox.x, infoBox.y];

			case PsychUICheckBox.CLICK_EVENT:
				handleCheckBoxEvent(cast sender);
				
			case PsychUINumericStepper.CHANGE_EVENT if (Std.isOfType(sender, PsychUINumericStepper)):
				handleNumericStepperEvent(cast sender);
				
			case PsychUIInputText.CHANGE_EVENT if (Std.isOfType(sender, PsychUIInputText)):
				handleInputTextEvent(cast sender);
		}
	}

	private function handleCheckBoxEvent(check:PsychUICheckBox):Void
	{
		var label = check.label;
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
				reloadGridLayer();
				updateGrid();
				FlxG.log.add('changed bpm');

			case "Alt Animation":
				_song.notes[curSec].altAnim = check.checked;
		}
	}

	private function handleNumericStepperEvent(nums:PsychUINumericStepper):Void
	{
		if (nums == stepperSusLength)
		{
			handleNoteLengthChange(nums);
			return;
		}

		var wname = nums.name;
		FlxG.log.add(wname);
		
		switch (wname)
		{
			case 'section_beats':
				_song.notes[curSec].sectionBeats = nums.value;
				reloadGridLayer();
				
			case 'song_speed':
				_song.speed = nums.value;
				
			case 'song_bpm':
				tempBpm = nums.value;
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(nums.value);
				
			case 'note_susLength':
				if (curSelectedNote != null && curSelectedNote[2] != null)
				{
					curSelectedNote[2] = nums.value;
					updateGrid();
				}
				
			case 'section_bpm':
				_song.notes[curSec].bpm = nums.value;
				updateGrid();
				
			case 'inst_volume':
				FlxG.sound.music.volume = nums.value;
				
			case 'voices_volume':
				vocals.volume = nums.value;
				
			case 'voices_opp_volume':
				opponentVocals.volume = nums.value;
				if (check_mute_vocals_opponent.checked) opponentVocals.volume = 0;
		}
	}

	private function handleNoteLengthChange(nums:PsychUINumericStepper):Void
	{
		if (selectedNotes.length > 0)
		{
			for (note in selectedNotes)
			{
				if (note.noteData > -1) // Only normal notes have sustain length
				{
					note.rawData[2] = nums.value;
					note.sustainLength = nums.value; // Update the visual note property too
				}
			}
			updateGrid();
		}
		else if (curSelectedNote != null && curSelectedNote[2] != null)
		{
			curSelectedNote[2] = nums.value;
			updateGrid();
		}
	}

	private function handleInputTextEvent(input:PsychUIInputText):Void
	{
		if (curSelectedNote == null) return;

		switch(input)
		{
			case value1InputText if(curSelectedNote[1][curEventSelected] != null):
				curSelectedNote[1][curEventSelected][1] = input.text;
				updateGrid();

			case value2InputText if(curSelectedNote[1][curEventSelected] != null):
				curSelectedNote[1][curEventSelected][2] = input.text;
				updateGrid();

			case strumTimeInputText:
				var value:Float = Std.parseFloat(input.text);
				if (Math.isNaN(value)) value = 0;
				curSelectedNote[0] = value;
				updateGrid();
		}
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

	function isMouseOverUI():Bool {
		return FlxG.mouse.overlaps(mainBox) || 
			FlxG.mouse.overlaps(infoBox) || 
			FlxG.mouse.overlaps(sliderBg) ||
			FlxG.mouse.overlaps(positionSlider) ||
			FlxG.mouse.overlaps(sliderBg);
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;
	/**
	 * huh, more organized update func
	 * mmmmmmmm
	 */
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		curStep = recalculateSteps();
		final conductorTime = Conductor.songPosition;
		final blockInput = PsychUIInputText.focusOn != null;
		final mouseOverUI = isMouseOverUI();
		
		updateMusicPlayback();

		updateSongSlider();
		
		if (!blockInput) {
			ClientPrefs.toggleVolumeKeys();
			handleKeyboardInput();
			handleMouseInput(mouseOverUI);
		} else {
			ClientPrefs.toggleVolumeKeys(false);
		}

		strumLineNotes.visible = quant.visible = vortex;
		
		updateNoteSelectionAndColors(elapsed);
		updateWaveformIfNeeded();
		updatePlaybackSpeed();
		updateMetronome(conductorTime);

		updateStrumLineNotes(elapsed);
		
		updateInfoText();
		updateCharacterAnimations(elapsed);
		
		lastConductorPos = conductorTime;
	}

	function updateMusicPlayback():Void
	{
		var curTime = FlxG.sound.music.time;

		if(curTime < 0) {
			FlxG.sound.music.pause();
			curTime = 0;
		}
		else if(curTime > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			curTime = 0;
			changeSection();
		}
		Conductor.songPosition = curTime;
			
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
	}

	function updateStrumLineNotes(elapsed:Float):Void
	{
		followPoint.set(strumLine.x + CAM_OFFSET, strumLine.y);
		FlxG.camera.scroll.x = followPoint.x - FlxG.width / 2;
		FlxG.camera.scroll.y = followPoint.y - FlxG.height / 2;

		strumLineUpdateY();
		
		for (i in 0...8) {
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		if (quant != null && quant.exists) quant?.update(elapsed);
		if (daNoteType != null && daNoteType.exists) daNoteType.update(elapsed);
		if (daEventText != null && daEventText.exists) daEventText.update(elapsed);
	}

	function handleKeyboardInput():Void
	{
		// playstate but in editor
		if (FlxG.keys.justPressed.ESCAPE #if mobile || _virtualpad.buttonB.justPressed #end) {
			FlxG.sound.music.pause();
			vocals?.pause();
			opponentVocals?.pause();
			FlxG.switchState(() -> new game.states.editors.EditorPlayState(sectionStartTime()));
		}
		
		// Song play button
		if (FlxG.keys.justPressed.ENTER #if mobile || _virtualpad.buttonA.justPressed #end) {
			FlxG.mouse.visible = false;
			PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals?.stop();
			opponentVocals?.pause();

			StageData.loadDirectory(_song);
			LoadingState.loadAndSwitchState(() -> new PlayState());
		}
		
		// Note sustains change
		if(curSelectedNote != null && curSelectedNote[1] > -1) {
			if (FlxG.keys.justPressed.E) changeNoteSustain(Conductor.stepCrochet);
			if (FlxG.keys.justPressed.Q) changeNoteSustain(-Conductor.stepCrochet);
		}
		
		// Hot keys
		if (FlxG.keys.justPressed.F1) showTips();
		if (FlxG.keys.justPressed.F2) toggleCharacters();
		if (FlxG.keys.justPressed.BACKSPACE #if android || FlxG.android.justReleased.BACK #end) exitToMenu();
		
		// Toggle zoom
		if(FlxG.keys.justPressed.Z #if mobile || _virtualpad.buttonZ.justPressed #end && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
			curZoom--;
			updateZoom();
		}
		if(FlxG.keys.justPressed.X #if mobile || _virtualpad.buttonC.justPressed #end && curZoom < zoomList.length-1) {
			curZoom++;
			updateZoom();
		}
		
		// Tabs switching
		if (FlxG.keys.justPressed.TAB) switchTabs();
		
		// Play/Pause
		if (FlxG.keys.justPressed.SPACE #if mobile || _virtualpad.buttonX.justPressed #end) togglePlayback();
		
		// Section reset
		if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			resetSection(FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end);
		
		// Section navigating
		var shiftThing:Int = (FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end) ? 4 : 1;
		if (FlxG.keys.justPressed.D #if mobile || _virtualpad.buttonRight.justPressed #end) changeSection(curSec + shiftThing);
		if (FlxG.keys.justPressed.A #if mobile || _virtualpad.buttonLeft.justPressed #end)
			changeSection((curSec <= 0) ? _song.notes.length-1 : curSec - shiftThing);
		
		// Cursor control thingie
		if (FlxG.keys.pressed.W || FlxG.keys.pressed.S #if mobile || _virtualpad.buttonUp.pressed || _virtualpad.buttonDown.pressed #end)
			handlePlaybackSeeking();

		if(FlxG.keys.justPressed.RIGHT #if mobile || _virtualpad.buttonRight.justPressed #end){
			curQuant++;
			if(curQuant > quantizations.length - 1)
				curQuant = 0;

			quantization = quantizations[curQuant];
		}

		if(FlxG.keys.justPressed.LEFT  #if mobile || _virtualpad.buttonLeft.justPressed #end){
			curQuant--;
			if(curQuant < 0)
				curQuant = quantizations.length-1;

			quantization = quantizations[curQuant];
		}
		quant.animation.play('q', true, false, curQuant);
		
		// Quntization
		if(!vortex){
			if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) {
				handleQuantizedSeeking();
			}
		}
		
		// vortex thing
		if(vortex) handleVortexInput();
		
		// Copy/paste
		if (FlxG.keys.pressed.CONTROL) {
			if (FlxG.keys.justPressed.C && curSelectedNote != null) 
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

			if (FlxG.keys.justPressed.V) pasteNote();
			if (FlxG.keys.justPressed.Z) undo();
			if (FlxG.keys.justPressed.Y) redo();
		}
	}

	function handleMouseInput(mouseOverUI:Bool):Void
	{
		// dimmy arrows visibility
		// lol
		updateDummyArrowVisibility();
		
		if (!mouseOverUI)
		{
			if (FlxG.mouse.justPressed)
				handleMouseClick();
			
			if (FlxG.mouse.justReleased)
				handleMouseRelease();

			if (FlxG.mouse.justPressedRight)
				handleRightClick();
		}
		
		updateSelectionBox();
		#if !mobile
		if (FlxG.mouse.wheel != 0)
			handleMouseWheel();
		#end
	}

	function updateDummyArrowVisibility():Void
	{
		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + gridBG.height)
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) * GRID_SIZE + gridBG.x;
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
	}

	function handleMouseClick():Void
	{
		var clickedOnNote = false;
		
		curRenderedNotes.forEachAlive((note:Note) -> {
			if (FlxG.mouse.overlaps(note))
				clickedOnNote = true;
		});
		
		if (!clickedOnNote)
		{
			if (!FlxG.keys.pressed.CONTROL && !FlxG.keys.pressed.ALT && dummyArrow.visible)
			{
				var noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;
				var noteStrum = getStrumTime(dummyArrow.y, false) + sectionStartTime();
				addNote(noteStrum, noteData, currentType);
			}
			else
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
		else
		{
			curRenderedNotes.forEachAlive((note:Note) ->
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
						deleteNote(note);
					}
				}
			});
		}
	}

	function handleMouseRelease():Void
	{
		if (selecting)
		{
			selecting = false;
			selectBox.visible = false;
			selectBoxOutline.visible = false;
			
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
			
			curRenderedNotes.forEachAlive((note:Note) -> {
				var noteRect = new FlxRect(note.x, note.y, note.width, note.height);
				if (selectionBox.overlaps(noteRect)) {
					selectedNotes.push(note);
					note.color = FlxColor.BLUE;
				}
			});
			
			if (selectedNotes.length == 1)
				selectNote(selectedNotes[0]);
		}
		else
		{
			for (note in selectedNotes)
				note.color = FlxColor.WHITE;

			selectedNotes = [];
		}
	}

	function handleRightClick():Void
	{
		var clickedNote:Note = null;
		curRenderedNotes.forEachAlive((note:Note) ->
			if (FlxG.mouse.overlaps(note)) clickedNote = note);
		
		if (clickedNote != null)
		{
			openSubState(new ContextMenu(
				FlxG.mouse.viewX,
				FlxG.mouse.viewY,
				clickedNote,
				deleteNote,
				copyNote,
				pasteNote
			));
		}
	}

	function handleMouseWheel():Void
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
				var fuck:Float = MathUtil.quantize(beat, snap) - increase;
				FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
			} else {
				var fuck:Float = MathUtil.quantize(beat, snap) + increase;
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

	function updateNoteSelectionAndColors(elapsed:Float):Void
	{
		final activeNotes = ["player" => false, "opponent" => false];
		final playedSound = [false, false, false, false];
		
		curRenderedNotes.forEachAlive((note:Note) -> {
			note.alpha = 1;
			
			if (curSelectedNote != null)
				updateNoteColor(note, elapsed);
			
			if (note.strumTime <= Conductor.songPosition && note.strumTime + note.sustainLength > Conductor.songPosition) {
				activeNotes.set(note.mustPress ? "player" : "opponent", true);
			}
			
			if (note.strumTime <= Conductor.songPosition)
				handleNotePlayback(note, playedSound);
		});
		
		updateCharacterDanceStates(activeNotes);
	}

	function updateNoteColor(note:Note, elapsed:Float):Void
	{
		var noteDataToCheck:Int = note.noteData;
		if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) {
			noteDataToCheck += 4;
		}
		
		if (selectedNotes.contains(note)) {
			note.color = FlxColor.BLUE;
		} else if (curSelectedNote != null && note.rawData == curSelectedNote) {
			colorSine += elapsed;
			final colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
			note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999);
		} else {
			note.color = FlxColor.WHITE;
		}
	}

	function handleNotePlayback(note:Note, playedSound:Array<Bool>):Void
	{
		note.alpha = 0.4;
		if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1) {
			var data:Int = note.noteData % 4;
			var noteDataToCheck:Int = note.noteData;
			if (noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) {
				noteDataToCheck += 4;
			}
			
			strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
			strumLineNotes.members[noteDataToCheck].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
			
			if (!playedSound[data]) {
				playNoteSound(note, data);
				playCharacterAnimation(note, data);
			}
			
			playedSound[data] = true;
		}
	}

	function playNoteSound(note:Note, data:Int):Void
	{
		if ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)) {
			var soundToPlay = 'hitsound';
			if (_song.player1 == 'gf') { // Easter egg
				soundToPlay = 'GF_' + Std.string(data + 1);
			}
			FlxG.sound.play(Paths.sound(soundToPlay)).pan = note.noteData < 4 ? -0.3 : 0.3;
		}
	}

	function playCharacterAnimation(note:Note, data:Int):Void
	{
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

	function updateCharacterDanceStates(activeNotes:Map<String, Bool>):Void
	{
		if (activeNotes["opponent"] && !opponent.isAnimationNull() && opponent.getAnimationName().startsWith('sing')) {
			opponent.holdTimer = 0;
		} else if (!activeNotes["opponent"] && opponent.holdTimer >= Conductor.stepCrochet * 0.001 * opponent.singDuration) {
			if (!opponent.isAnimationNull() && opponent.getAnimationName().startsWith('sing')) {
				opponent.dance();
			}
		}

		if (activeNotes["player"] && !player.isAnimationNull() && player.getAnimationName().startsWith('sing')) {
			player.holdTimer = 0;
		} else if (!activeNotes["player"] && player.holdTimer >= Conductor.stepCrochet * 0.001 * player.singDuration) {
			if (!player.isAnimationNull() && player.getAnimationName().startsWith('sing')) {
				player.dance();
			}
		}
	}

	function updateWaveformIfNeeded():Void
	{
		if(waveformPrinted && (chartEditorSave.data.chart_waveformInst || chartEditorSave.data.chart_waveformVoices || chartEditorSave.data.chart_waveformOppVoices)) {
			updateWaveform();
		}
	}

	/**
	 * Playback update function
	 */
	function updatePlaybackSpeed():Void
	{
		#if FLX_PITCH
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

		if (playbackSpeed <= playbackSlider.min)
			playbackSpeed = playbackSlider.min;
		if (playbackSpeed >= playbackSlider.max)
			playbackSpeed = playbackSlider.max;

		FlxG.sound.music.pitch = playbackSpeed;
		vocals.pitch = playbackSpeed;
		opponentVocals.pitch = playbackSpeed;
		playbackSlider.value = playbackSpeed;
		#end
	}

	function updateMetronome(time:Float):Void
	{
		if(metronome.checked && lastConductorPos != time) {
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((time + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if(metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
			}
		}
	}

	function updateInfoText():Void
	{
		infoText.text =
			"Section: " + curSec +
			"\n\nBeat: " + Std.string(curDecBeat).substring(0,4) +
			"\n\nStep: " + curStep +
			"\n\nBeat Snap: " + quantization + "th";
	}

	function updateCharacterAnimations(elapsed:Float):Void
	{
		/*TODO: Needs to make the tab like in pe 1.0 where you can change the ui colors first
		colorSine += elapsed;
		var bgColorValue = 0.7 + Math.sin(colorSine * 0.5) * 0.3;
		var bg = members[0]; //first elem.
		if (Std.isOfType(bg, FlxSprite))
			cast(bg, FlxSprite).color = FlxColor.fromRGBFloat(bgColorValue, bgColorValue, bgColorValue);
		
		if (metronome.checked && FlxG.sound.music.playing) {
			var beatProgress = (Conductor.songPosition % Conductor.crochet) / Conductor.crochet;
			quant.alpha = 0.5 + Math.sin(beatProgress * Math.PI) * 0.5;
		} else {
			quant.alpha = 1;
		}*/
	}

	function handlePlaybackSeeking():Void
	{
		FlxG.sound.music.pause();

		var holdingShift:Float = 1;
		if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
		else if (FlxG.keys.pressed.SHIFT #if mobile || _virtualpad.buttonY.pressed #end) holdingShift = 3;

		var daTime:Float = 700 * FlxG.elapsed * holdingShift;

		if (FlxG.keys.pressed.W #if mobile || _virtualpad.buttonUp.pressed #end)
			FlxG.sound.music.time = Math.max(0, FlxG.sound.music.time - daTime);
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

	function handleQuantizedSeeking():Void
	{
		FlxG.sound.music.pause();
		updateCurStep();
		var time:Float = FlxG.sound.music.time;
		var beat:Float = curDecBeat;
		var snap:Float = quantization / 4;
		var increase:Float = 1 / snap;
		if (FlxG.keys.pressed.UP)
		{
			var fuck:Float = MathUtil.quantize(beat, snap) - increase;
			FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
		} else {
			var fuck:Float = MathUtil.quantize(beat, snap) + increase;
			FlxG.sound.music.time = Conductor.beatToSeconds(fuck);
		}
	}

	function handleVortexInput():Void
	{
		var controlArray:Array<Bool> = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
									FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];

		if(controlArray.contains(true))
		{
			for (i in 0...controlArray.length)
			{
				if(controlArray[i])
					doANoteThing(Conductor.songPosition, i, currentType);
			}
		}

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN #if mobile || _virtualpad.buttonUp.justPressed || _virtualpad.buttonDown.justPressed #end)
		{
			FlxG.sound.music.pause();

			updateCurStep();
			var time:Float = FlxG.sound.music.time;
			var beat:Float = curDecBeat;
			var snap:Float = quantization / 4;
			var increase:Float = 1 / snap;
			if (FlxG.keys.pressed.UP #if mobile || _virtualpad.buttonUp.pressed #end)
			{
				var fuck:Float = MathUtil.quantize(beat, snap) - increase;
				time = Conductor.beatToSeconds(fuck);
			} else {
				var fuck:Float = MathUtil.quantize(beat, snap) + increase;
				time = Conductor.beatToSeconds(fuck);
			}
			FlxTween.tween(FlxG.sound.music, {time:time}, 0.1, {ease:FlxEase.circOut});
			if(vocals != null) {
				vocals.pause();
				vocals.time = FlxG.sound.music.time;
			}
			if(opponentVocals != null) {
				opponentVocals.pause();
				opponentVocals.time = FlxG.sound.music.time;
			}

			var dastrum = (curSelectedNote != null) ? curSelectedNote[0] : 0;

			var secStart:Float = sectionStartTime();
			var datime = (time - secStart) - (dastrum - secStart);
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

	function showTips():Void
	{
		tipsSubstate = new ChartingTipsSubstate();
		openSubState(tipsSubstate);
	}

	function toggleCharacters():Void
	{
		showCharacters = !showCharacters;
		opponent.visible = showCharacters;
		player.visible = showCharacters;
	}

	function exitToMenu():Void
	{
		PlayState.chartingMode = false;
		FlxG.switchState(() -> new game.states.editors.MasterEditorMenu());
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		FlxG.mouse.visible = false;
	}

	function switchTabs():Void
	{
		var mainTabNames = ['Charting', 'Events', 'Note', 'Section', 'Song'];
		var currentIndex = mainTabNames.indexOf(mainBox.selectedName);
		if (currentIndex <= -1) currentIndex = 0;

		if (FlxG.keys.pressed.SHIFT)
		{
			currentIndex--;
			if (currentIndex < 0) currentIndex = mainTabNames.length - 1;
		}
		else
		{
			currentIndex++;
			if (currentIndex >= mainTabNames.length) currentIndex = 0;
		}

		mainBox.selectedName = mainTabNames[currentIndex];
	}

	function togglePlayback():Void
	{
		if (FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			vocals?.pause();
			opponentVocals?.pause();
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
		//gridLayer.clear();
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * getSectionBeats() * 4 * zoomList[curZoom]));
    	gridBG?.screenCenter(X); //? due to hl

		#if hl
		if (gridBG != null)
		#end
		waveformSprite.x = gridBG.x + GRID_SIZE / 2;

		if(chartEditorSave.data.chart_waveformInst || chartEditorSave.data.chart_waveformVoices || chartEditorSave.data.chart_waveformOppVoices)
			updateWaveform();

		updateGrid();

		var foundPrevSec:Bool = false;
		var foundNextSec:Bool = false;

		var leHeight:Int = Std.int(gridBG.height) * -1;
		if(curSec > 0 && sectionStartTime(-1) >= 0)
		{
			prevGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * getSectionBeats(curSec - 1) * 4 * zoomList[curZoom]));
			prevGridBG.screenCenter(X);
			leHeight = Std.int(gridBG.y - prevGridBG.height);
			foundPrevSec = true;
		}
		else prevGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		prevGridBG.y = gridBG.y - prevGridBG.height;

		var leHeight2:Int = Std.int(gridBG.height);
		nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, Std.int(GRID_SIZE * getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
		nextGridBG.screenCenter(X);
		if(sectionStartTime(1) <= FlxG.sound.music.length)
		{
			leHeight2 = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
			nextGridBG.visible = true;
		}
		else
		{
			nextGridBG.visible = false;
			leHeight2 = Std.int(gridBG.height);
		}
		nextGridBG.y = gridBG.height;

		gridLayer.add(prevGridBG);
		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if(foundPrevSec)
		{
			var gridBlackPrev:FlxSprite = new FlxSprite(prevGridBG.x, prevGridBG.y).makeGraphic(Std.int(GRID_SIZE * 9), Std.int(prevGridBG.height), FlxColor.BLACK);
			gridBlackPrev.alpha = 0.4;
			gridLayer.add(gridBlackPrev);
		}

		if(foundNextSec)
		{
			var gridBlackNext:FlxSprite = new FlxSprite(nextGridBG.x, gridBG.height).makeGraphic(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height), FlxColor.BLACK);
			gridBlackNext.alpha = 0.4;
			gridLayer.add(gridBlackNext);
		}

		var topY = prevGridBG.y;
		var totalHeight = (foundNextSec ? nextGridBG.y + nextGridBG.height : gridBG.y + gridBG.height) - topY;

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
			waveformSprite.makeGraphic(Std.int(gridBG.width), Std.int(gridBG.height), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridBG.height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!chartEditorSave.data.chart_waveformInst && !chartEditorSave.data.chart_waveformVoices && !chartEditorSave.data.chart_waveformOppVoices) {
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

		if (chartEditorSave.data.chart_waveformInst) {
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
		
		if (chartEditorSave.data.chart_waveformVoices) {
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
		
		if (chartEditorSave.data.chart_waveformOppVoices) {
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
		var gSize:Int = Std.int(gridBG.width);
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

		waveformSprite.dirty = true;
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

		steps ??= 1280;

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

		array ??= [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else {
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

				} else {
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
				reloadGridLayer();
			else
				updateGrid();

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
			leftIcon.changeIcon(!_song.notes[curSec].gfSection ? healthIconP1 : healthIconGF);
			rightIcon.changeIcon(healthIconP2);
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(!_song.notes[curSec].gfSection ? healthIconP1 : healthIconGF);
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
				var selected:Int = eventDropDown.selectedIndex;
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

	function clearGroup<T:flixel.FlxBasic>(group:FlxTypedGroup<T>) {
		if (group == null) return;
		
		for (i in 0...group.length) {
			var obj = group.members[i];
			if (obj != null) {
				obj.destroy();
				group.remove(obj, true);
			}
		}
		group.clear();
	}

	var daNoteType:AttachedFlxText;
	var daEventText:AttachedFlxText;
	function updateGrid():Void
	{
		clearGroup(curRenderedNotes);
		clearGroup(curRenderedSustains);
		clearGroup(curRenderedNoteType);
		clearGroup(nextRenderedNotes);
		clearGroup(nextRenderedSustains);
		clearGroup(prevRenderedNotes);
		clearGroup(prevRenderedSustains);
	
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

		curRenderedNotes.forEachAlive((note:Note) -> note.color = selectedNotes.contains(note) ? FlxColor.BLUE : FlxColor.WHITE);
	
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
				var theType:String = '' + typeInt ?? '?';
	
				daNoteType = new AttachedFlxText(0, 0, 100, theType, 18);
				daNoteType.setFormat(Paths.font("pixel-latin.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				daNoteType.borderStyle = NONE;
				daNoteType.xAdd = -32;
				daNoteType.yAdd = 6;
				daNoteType.borderSize = 1;
				curRenderedNoteType.add(daNoteType);
				daNoteType.sprTracker = note;
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
	
				var text:String = 'Event: ${note.eventName} (${Math.floor(note.strumTime)} ms)\nValue 1: ${note.eventVal1}\nValue 2: ${note.eventVal2}';
				if(note.eventLength > 1) text = '${note.eventLength} Events:\n${note.eventName}';
	
				daEventText = new AttachedFlxText(0, 0, 400, text, 8);
				daEventText.setFormat(Paths.font("pixel-latin.ttf"), 8, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daEventText.borderStyle = NONE;
				daEventText.xAdd = -410;
				daEventText.borderSize = 1;
				if(note.eventLength > 1) daEventText.yAdd += 8;
				curRenderedNoteType.add(daEventText);
				daEventText.sprTracker = note;
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
		if(note.noteData < 0) daSus == null;
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
			note.noteType = i[3];
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
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + gridBG.x + GRID_SIZE;
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
		color = sustainColors[note.noteData];

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
			noteData = Math.floor((touch.x - gridBG.x) / GRID_SIZE) - 1;
		}
		#else
		noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;
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
			var event = eventStuff[eventDropDown.selectedIndex][0];
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
        if (undos.length >= maxUndoSteps) {
			var removed = undos.shift();
			removed = null;
		}
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
			selectBoxOutline.visible = true;
			
			var mousePos = FlxG.mouse.getWorldPosition();
			var width = mousePos.x - selectStart.x;
			var height = mousePos.y - selectStart.y;
			
			selectBox.scale.set(Math.abs(width), Math.abs(height));
			selectBox.updateHitbox();
			selectBox.x = width < 0 ? mousePos.x : selectStart.x;
			selectBox.y = height < 0 ? mousePos.y : selectStart.y;

			updateSelectBoxOutline(selectBox.x, selectBox.y, Math.abs(width), Math.abs(height));

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

	function updateSelectBoxOutline(x:Float, y:Float, width:Float, height:Float):Void 
	{
		var outlineWidth = Std.int(width + 2); //+2 for 1px border on each side
		var outlineHeight = Std.int(height + 2);
		
		selectBoxOutline.makeGraphic(outlineWidth, outlineHeight, FlxColor.TRANSPARENT, true);
		
		//Top
		selectBoxOutline.pixels.fillRect(new Rectangle(0, 0, outlineWidth, 1), FlxColor.BLUE);
		//Bottom
		selectBoxOutline.pixels.fillRect(new Rectangle(0, outlineHeight-1, outlineWidth, 1), FlxColor.BLUE);
		//Left
		selectBoxOutline.pixels.fillRect(new Rectangle(0, 0, 1, outlineHeight), FlxColor.BLUE);
		//Right
		selectBoxOutline.pixels.fillRect(new Rectangle(outlineWidth-1, 0, 1, outlineHeight), FlxColor.BLUE);
		
		selectBoxOutline.x = x - 1;
		selectBoxOutline.y = y - 1;
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
		try {
			if (CoolUtil.difficulties[PlayState.storyDifficulty] != CoolUtil.defaultDifficulty) {
				if(CoolUtil.difficulties[PlayState.storyDifficulty] == null) {
					PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
				} else {
					PlayState.SONG = Song.loadFromJson(song.toLowerCase() + "-" + CoolUtil.difficulties[PlayState.storyDifficulty], song.toLowerCase());
				}
			} else {
				PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
			}
		} catch (e:Dynamic) {
			openSubState(new Prompt('Song not found!\nPlease check the song name.', 1, function() {
				closeSubState();
			}, null, false, "OK", null));
			return;
		}
		FlxG.resetState();
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	private function saveChart()
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
			//backupManager.createBackup(Paths.formatToSongPath(_song.song) + ".json", data.trim(), "save");
			#if mobile
			SUtil.saveContent(Paths.formatToSongPath(_song.song) + ".json", data.trim());
			#else
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
			#end
		}
	}

	inline public function reloadAfterBackup():Void {
		FlxG.sound.music.stop();
		vocals?.stop();
		opponentVocals?.stop();
		
		PlayState.SONG = _song;

		FlxTransitionableState.skipNextTransIn = false;
		FlxTransitionableState.skipNextTransOut = true;

		FlxG.resetState();
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
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
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
		FlxG.log.notice("Successfully saved CHART DATA.");
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
		section ??= curSec;
		var val:Null<Float> = null;
		
		if(_song.notes[section] != null) val = _song.notes[section].sectionBeats;
		return val ?? 4;
	}

	override function destroy() {
		autoBackupTimer?.cancel();
		autoBackupTimer?.destroy();

		super.destroy();
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

	override public function update(elapsed:Float)
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
			"F2 - Toggle characters visibility\n" +
			"W/S or Mouse Wheel - Change playback position\n" +
			"A/D - Go to previous/next section\n" +
			"Left/Right - Change quantization\n" +
			"Up/Down - Change playback position with quantization\n" +
			#if FLX_PITCH
			"[ / ] - Change playback speed (SHIFT for faster change)\n" +
			#end
			"ALT + [ / ] - Reset playback speed\n" +
			"SHIFT - Move faster (3x speed)\n" +
			"CTRL + click - Select/deselect notes\n" +
			"CTRL + C - Copy selected notes\n" +
			"CTRL + V - Paste copied notes\n" +
			"CTRL + Z - Undo\n" +
			"CTRL + Y - Redo\n" +
			"Z/X - Zoom in/out\n" +
			"ENTER - Play chart\n" +
			"Q/E - Decrease/increase note length\n" +
			"SPACE - Pause/resume playback\n" +
			"TAB - Cycle through UI tabs\n" +
			"BACKSPACE - Return to editor menu\n" +
			"RIGHT CLICK - Open context menu";

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
	var bg:FlxSprite;
	var menuBg:FlxSprite;
	var buttons:Array<PsychUIButton> = [];

	public function new(x:Float, y:Float, note:Note, deleteCallback:Note->Void, copyCallback:Note->Void, pasteCallback:Void->Void)
	{
		super();
		
		closeCallback = () -> close();
		
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
		bg.scrollFactor.set();
		bg.alpha = 0.0001;
		bg.setPosition(0, 0);
		add(bg);
		
		menuBg = new FlxSprite(x, y).makeGraphic(0, 0, FlxColor.BLACK);
		menuBg.alpha = 0.8;
		menuBg.scrollFactor.set();
		add(menuBg);
		
		var buttonY = y + 5;
		createButton("Delete", x + 5, buttonY, function() {
			deleteCallback(note);
			closeMenu();
		});
		
		buttonY += 30;
		createButton("Copy", x + 5, buttonY, function() {
			copyCallback(note);
			closeMenu();
		});
		
		buttonY += 30;
		createButton("Paste", x + 5, buttonY, function() {
			pasteCallback();
			closeMenu();
		});
		
		//note properties removed for event notes due to critical error
		if (note.noteData > -1) {
			buttonY += 30;
			createButton("Properties", x + 5, buttonY, () -> openNoteProperties(note));
		}
		
		var buttonCount = note.noteData > -1 ? 4 : 3;
		menuBg.makeGraphic(90, buttonCount * 30, FlxColor.BLACK);
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function createButton(label:String, x:Float, y:Float, onClick:Void->Void)
	{
		var button = new PsychUIButton(x, y, label, onClick);
		button.scrollFactor.set();
		add(button);
		buttons.push(button);
		return button;
	}

	function closeMenu():Void
	{
		if (closeCallback != null) closeCallback();
	}

	function openNoteProperties(note:Note):Void
	{
		var parent:ChartEditorState = cast FlxG.state.subState._parentState;
		@:privateAccess {
			openSubState(new NotePropertiesSubstate(note, function(updatedNote:Note) {
				parent.saveToUndo();
				parent.updateNoteData(note, updatedNote);
				parent.updateGrid();
				closeSubState();
			}, parent.eventStuff));
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.mouse.justPressed) {
			var mousePoint = FlxG.mouse.getViewPosition(camera);
			
			if (!menuBg.getScreenBounds(null, camera).containsPoint(mousePoint))
				closeMenu();
		}
		
		if (FlxG.keys.justPressed.ESCAPE)
			closeMenu();
	}
}

class NotePropertiesSubstate extends MusicBeatSubstate
{
    var note:Note;
    var onSaveCallback:Note->Void;
    var onCloseCallback:Void->Void;
	var eventStuff:Array<Dynamic>;
    
	var descText:FlxText;
    var strumTimeStepper:PsychUINumericStepper;
    var noteDataStepper:PsychUINumericStepper;
    var sustainStepper:PsychUINumericStepper;
    var typeInput:PsychUIInputText;
    var value1Input:PsychUIInputText;
    var value2Input:PsychUIInputText;
    var eventDropdown:PsychUIDropDownMenu;
    
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
            
            strumTimeStepper = new PsychUINumericStepper(panel.x + 120, panel.y + yOffset, 10, note.strumTime, 0, 999999, 0);
			strumTimeStepper.scrollFactor.set();
            add(strumTimeStepper);
            yOffset += 30;
            
            var dataLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Note Data:");
			dataLabel.scrollFactor.set();
            add(dataLabel);
            
			noteDataStepper = new PsychUINumericStepper(panel.x + 120, panel.y + yOffset, 1, note.noteData, 0, 7, 0);
			noteDataStepper.scrollFactor.set();
            add(noteDataStepper);
            yOffset += 30;
            
            var sustainLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Sustain:");
			sustainLabel.scrollFactor.set();
            add(sustainLabel);
            
            sustainStepper = new PsychUINumericStepper(panel.x + 120, panel.y + yOffset, 10, note.sustainLength, 0, 9999, 0);
			sustainStepper.scrollFactor.set();
            add(sustainStepper);
            yOffset += 30;
            
            var typeLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Note Type:");
			typeLabel.scrollFactor.set();
            add(typeLabel);
            
            typeInput = new PsychUIInputText(panel.x + 120, panel.y + yOffset, 150, note.noteType != null ? note.noteType : "");
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
			eventDropdown = new PsychUIDropDownMenu(panel.x + 120, panel.y + yOffset, 
				eventNames, 
				function(id:Int, value:String) {
					if (id >= 0 && id < eventStuff.length) {
						var eventName = eventStuff[id][0];
						var eventDesc = eventStuff[id][1];
						descText.text = eventDesc;
						
						if (value1Input != null && value1Input.text == "") {
							var defaultValues = getDefaultEventValues(eventName);
							value1Input.text = defaultValues[0];
							value2Input.text = defaultValues[1];
						}
					}
				}
			);
            eventDropdown.selectedIndex = Std.parseInt(note.eventName);
			eventDropdown.scrollFactor.set();
			
            yOffset += 30;
            
            var val1Label = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Value 1:");
			val1Label.scrollFactor.set();
            add(val1Label);
            
            value1Input = new PsychUIInputText(panel.x + 120, panel.y + yOffset, 150, note.eventVal1 != null ? note.eventVal1 : "");
			value1Input.scrollFactor.set();
            add(value1Input);

            yOffset += 30;
            
            var val2Label = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Value 2:");
			val2Label.scrollFactor.set();
            add(val2Label);
            
            value2Input = new PsychUIInputText(panel.x + 120, panel.y + yOffset, 150, note.eventVal2 != null ? note.eventVal2 : "");
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
				eventDropdown.selectedIndex = currentEventIndex;
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
        
        var saveButton = new PsychUIButton(panel.x + 50, panel.y + yOffset, "Save", () -> {
            saveChanges();
            close();
        });
        add(saveButton);
        
        var cancelButton = new PsychUIButton(panel.x + 150, panel.y + yOffset, "Cancel", () -> close());
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