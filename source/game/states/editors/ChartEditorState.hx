package game.states.editors;

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

import game.states.editors.meta.MetaNote;
import game.states.editors.meta.ChartBackupManager;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end


enum abstract WaveformTarget(String)
{
	var INST = 'inst';
	var PLAYER = 'voc';
	var OPPONENT = 'opp';
}

#if (flixel < "5.3.0")
@:access(flixel.system.FlxSound._sound)
#else
@:access(flixel.sound.FlxSound._sound)
#end
@:access(openfl.media.Sound.__buffer)
class ChartEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	public static final GRID_SIZE:Int = 40;
	public static final GRID_COLUMNS_PER_PLAYER:Int = 4;
	public static final GRID_PLAYERS:Int = 2;
	public static final GRID_COLUMNS_TOTAL:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
	public final CAM_OFFSET:Int = 180;

	private var tempBpm:Float = 0;

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
	public var ignoreWarnings = false;
	
	var curNoteTypes:Array<String> = [];
	var undos = [];
	var redos = [];
	var maxUndoSteps:Int = 50;
	/*var eventStuff:Array<Array<String>> =
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

	var eventStuff:Array<Array<String>> =
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

	var _file:FileReference;
    var postfix:String = '';
    
	var mainBox:PsychUIBox;
	var mainBoxPosition:FlxPoint = FlxPoint.get(875, 50);
	var infoBox:PsychUIBox;
	var infoBoxPosition:FlxPoint = FlxPoint.get(50, 145);

	var infoText:FlxText;

	var mouseDownPos:FlxPoint = new FlxPoint();
	var mouseDownTime:Float = 0;
	var isMouseDown:Bool = false;
	var dragThreshold:Float = 5;

	public static var goToPlayState:Bool = false;
	public static var curSec:Int = 0;
	private static var lastSong:String = '';

	var waveformTarget:WaveformTarget = INST;

	var followPoint:FlxPoint;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var mustHitIndicator:FlxSprite;

	var highlight:FlxSprite;

	var dummyArrow:FlxSprite;

	var curRenderedNotes:FlxTypedGroup<MetaNote>;
	var nextRenderedNotes:FlxTypedGroup<MetaNote>;
	var prevRenderedNotes:FlxTypedGroup<MetaNote>;

	var gridBG:FlxSprite;
	var prevGridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	public var _song:SwagSong;

	var curSelectedNote:Array<Dynamic> = null;

	var playbackSpeed:Float = 1;

	var vocals:FlxSound = null;
	var opponentVocals:FlxSound = null;

	var eventIcon:FlxSprite;
	var playerIcon:HealthIcon;
	var opponentIcon:HealthIcon;

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

	var gridColors:Dynamic = {
		background: 0xFF0C1020,
		mainLines: 0xFF1C2038,
		secondaryLines: 0xFF141830,
		beatLines: 0xFF2C4880,
		sectionLines: 0xFF3C5888
	};

	var waveformColors:Map<WaveformTarget, FlxColor> = [
		INST => 0xFF4A88C8,
		PLAYER => 0xFF4AC84A,
		OPPONENT => 0xFFC84A4A
	];

	var selectBox:FlxSprite;
	var selectBoxOutline:FlxSprite;
	var selecting = false;
	var selectStart:FlxPoint = new FlxPoint();
	var selectedNotes:Array<MetaNote> = [];

	var clipboardNotes:Array<Dynamic> = [];

	var waveform:FlxSprite;
	var currentWaveformSound:FlxSound = null;

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
	
	static var vortex:Bool = false;
	public var mouseQuant:Bool = false;

	var player:Character;
	var opponent:Character;
	var showCharacters:Bool = false;

	var tipsSubstate:ChartingTipsSubstate = null;

	var chartEditorSave:FlxSave;

	var camUI:FlxCamera;

	var cachedSectionTimes:Array<Float> = [];
	
	override function create()
	{
		Paths.clearStoredMemory();

		#if desktop
		FlxG.stage.addEventListener(MouseEvent.RIGHT_MOUSE_DOWN, (e:MouseEvent) -> e.preventDefault());
		#end

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
			_song = Song.getDefaultSong();

			addSection();
			PlayState.SONG = _song;
		}

		initFunkinCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		chartEditorSave = new FlxSave();
		chartEditorSave.bind('chart_editor_data', CoolUtil.getSavePath());

		FlxG.mouse.visible = true;
		PlayState.chartingMode = true;

		backupManager = new ChartBackupManager(this);

		mouseDownPos = FlxPoint.get();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = chartEditorSave.data.chart_vortex;
		ignoreWarnings = chartEditorSave.data.ignoreWarnings;
		
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.color = gridColors.background;
		bg.scrollFactor.set();
		add(bg);

		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		gridLayer.add(gridBG = new FlxSprite());
		gridLayer.add(prevGridBG = new FlxSprite());
		gridLayer.add(nextGridBG = new FlxSprite());

		waveform = new FlxSprite(gridBG.x + GRID_SIZE, gridBG.y).makeGraphic(1, 1, 0xFF4A3C88);
		waveform.scrollFactor.x = 0;
		waveform.visible = false;
		add(waveform);

		eventIcon = new FlxSprite(GRID_SIZE + 375).loadGraphic(Paths.image('editors/eventArrow'));
		eventIcon.scrollFactor.set();
		eventIcon.setGraphicSize(30, 30);
		eventIcon.camera = camUI;
		add(eventIcon);

		opponentIcon = new HealthIcon('dad');

		playerIcon = new HealthIcon('bf');
		playerIcon.flipX = true;

		for (icons in [opponentIcon, playerIcon]) {
			icons.scrollFactor.set();
			icons.scale.set(0.35, 0.35);
			icons.camera = camUI;
			add(icons);
		}

		opponentIcon.targetScale = opponentIcon.scale.x;
		playerIcon.targetScale = playerIcon.scale.x;

		opponentIcon.setPosition(eventIcon.x + 90, eventIcon.y - 10);
		playerIcon.setPosition(opponentIcon.x + 162, opponentIcon.y);

		mustHitIndicator = flixel.util.FlxSpriteUtil.drawTriangle(new FlxSprite(0, eventIcon.y + 20).makeGraphic(20, 20, FlxColor.TRANSPARENT), 0, 0, 20);
		mustHitIndicator.antialiasing = ClientPrefs.globalAntialiasing;
		mustHitIndicator.scrollFactor.set();
		mustHitIndicator.offset.x += mustHitIndicator.width / 2;
		mustHitIndicator.flipY = true;
		mustHitIndicator.camera = camUI;
		add(mustHitIndicator);

		curRenderedNotes = new FlxTypedGroup<MetaNote>();
		nextRenderedNotes = new FlxTypedGroup<MetaNote>();
		prevRenderedNotes = new FlxTypedGroup<MetaNote>();

		if(curSec >= _song.notes.length) curSec = _song.notes.length - 1;

		tempBpm = _song.bpm;

		addSection();

		updateJsonData();
		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		_cacheSections();
		reloadGridLayer();
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * (GRID_COLUMNS_TOTAL + 1)), 4);
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
		for (i in 0...GRID_COLUMNS_TOTAL){
			var note:StrumNote = new StrumNote(gridBG.x + GRID_SIZE * (i+1), strumLine.y, i % GRID_COLUMNS_PER_PLAYER, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.scrollFactor.set(1, 1);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
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
		FlxG.camera.followLead.set();

		add(curRenderedNotes);
		add(nextRenderedNotes);
		add(prevRenderedNotes);

		if(lastSong != currentSongName) changeSection();
		lastSong = currentSongName;

		loadJSONEvents();

		zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.y -= 500;
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

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

		autoBackupTimer = new FlxTimer();
		autoBackupTimer.start(backupInterval, (tmr:FlxTimer) -> {
			backupManager.createAutoBackup(_song);
			tmr.reset(backupInterval);
		}, 0);

		Paths.clearUnusedMemory();

		super.create();
	}

	function loadJSONEvents()
	{
		var songName:String = Paths.formatToSongPath(_song.song);
		var file:String = Paths.json('songs/$songName/events');
		
		if (_song.events == null || _song.events.length == 0) {
			try
			{
				var events:SwagSong = Song.loadFromJson('events', songName);
				_song.events = events.events;
				changeSection(curSec);
			} catch (e) {
				_song.events = [];
			}
		}
	}

	var sliderBg:FlxSprite;
	var pressF1Text:FlxText;
	var positionSlider:PsychUISlider;
	var timeText:FlxText;
	function createSongSlider() {
		sliderBg = new FlxSprite(0, FlxG.height - 60).makeGraphic(FlxG.width, 60, FlxColor.BLACK);
		sliderBg.alpha = 0.85;
		sliderBg.scrollFactor.set();
		sliderBg.updateHitbox();
		sliderBg.cameras = [camUI];
		add(sliderBg);

		pressF1Text = new FlxText(sliderBg.x, sliderBg.y + 45, 0, "Press F1 to open tips", 8);
		pressF1Text.setFormat(Paths.font("pixel-latin.ttf"), 8, FlxColor.WHITE, LEFT);
		pressF1Text.scrollFactor.set();
		pressF1Text.cameras = [camUI];
		add(pressF1Text);

		timeText = new FlxText(10, FlxG.height - 30, FlxG.width - 22.5, "00:00:00 / 00:00:00", 16);
		timeText.setFormat(null, 16, FlxColor.WHITE, CENTER);
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
		positionSlider.scrollFactor.set();
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
			timeText.text = '$currentTime / $totalTime';
		} else {
			timeText.text = "00:00:00 / 00:00:00";
		}
	}

	var stepperBPM:PsychUINumericStepper;
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
	function addSongUI():Void
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

		var loadSongJsonButton:PsychUIButton = new PsychUIButton(reloadSong.x, saveButton.y + 30, "Load Chart", function()
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.sound.music.pause();
				vocals?.pause();
				opponentVocals?.pause();
			}
			
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function() {
				_song.song = UI_songTitle.text;
				var songName = Paths.formatToSongPath(_song.song);
				
				openSubState(new ChartSelectorSubstate(songName, (selectedSong:String, selectedChart:String) -> {
					loadJson(selectedChart, selectedSong);
				}));
			}, null, ignoreWarnings, "OK", "CANCEL"));
		});

		var loadBackupButton:PsychUIButton = new PsychUIButton(loadSongJsonButton.x, loadSongJsonButton.y + 30, "Load Backup", () ->
			backupManager.loadBackup()
		);

		var createBackupButton:PsychUIButton = new PsychUIButton(loadBackupButton.x - 90, loadBackupButton.y, "Create Backup", () ->
			backupManager.createManualBackup(_song)
		);

		var saveEvents:PsychUIButton = new PsychUIButton(saveButton.x, loadSongJsonButton.y, 'Save Events', function ()
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

		stepperBPM = new PsychUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		stepperBPM.onValueChange = () -> {
			tempBpm = stepperBPM.value;
			if (!check_changeBPM.checked) metronomeStepper.value = stepperBPM.value;
			Conductor.mapBPMChanges(_song);
			Conductor.changeBPM(stepperBPM.value);
			
			var startRedistributeFrom = 0;
			for (i in 0..._song.notes.length) {
				if (_song.notes[i].changeBPM)
					startRedistributeFrom = i + 1;
				else
					break;
			}
			reassignNotesBetweenSections(startRedistributeFrom);
			
			updateWaveform();
			updateGrid();
		};

		var stepperSpeed:PsychUINumericStepper = new PsychUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		stepperSpeed.onValueChange = () -> _song.speed = stepperSpeed.value;
		var directories:Array<String> = [#if MODS_ALLOWED Mods.getModPath('data/characters/'), Mods.getModPath(Mods.currentModDirectory + '/data/characters/'), #end  Paths.getPreloadPath('data/characters/')];
		#if MODS_ALLOWED
		for(mod in Mods.getGlobalMods())
			directories.push(Mods.getModPath(mod + '/data/characters/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('data/characters/')];
		#end

		var tempMap:Map<String, Bool> = new Map<String, Bool>();
		var characters:Array<String> = CoolUtil.coolTextFile( Paths.txt('characterList'));
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
		});
		player2DropDown.selectedLabel = _song.player2;

		#if MODS_ALLOWED
		var directories:Array<String> = [Mods.getModPath('stages/'), Mods.getModPath(Mods.currentModDirectory + '/stages/'),  Paths.getPreloadPath('stages/')];
		for(mod in Mods.getGlobalMods())
			directories.push(Mods.getModPath(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end

		tempMap.clear();
		var stageFile:Array<String> = CoolUtil.coolTextFile( Paths.txt('stageList'));
		var stages:Array<String> = [];
		for (i in 0...stageFile.length) {
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
		tab_group_song.add(loadSongJsonButton);
		tab_group_song.add(createBackupButton);
		tab_group_song.add(loadBackupButton);
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
	}

	var stepperBeats:PsychUINumericStepper;
	var check_mustHitSection:PsychUICheckBox;
	var check_gfSection:PsychUICheckBox;
	var check_changeBPM:PsychUICheckBox;
	var stepperSectionBPM:PsychUINumericStepper;
	var check_altAnim:PsychUICheckBox;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	function addSectionUI():Void
	{
		var tab_group_section = mainBox.getTab('Section').menu;

		check_mustHitSection = new PsychUICheckBox(10, 15, "Must Hit Section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;
		check_mustHitSection.onClick = () -> {
			_song.notes[curSec].mustHitSection = check_mustHitSection.checked;
			updateGrid();
			updateHeads();
		}

		check_gfSection = new PsychUICheckBox(10, check_mustHitSection.y + 22, "GF Section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;
		check_gfSection.onClick = () -> {
			_song.notes[curSec].gfSection = check_gfSection.checked;
			updateGrid();
			updateHeads();
		}

		check_altAnim = new PsychUICheckBox(check_gfSection.x + 120, check_gfSection.y, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;
		check_altAnim.name = 'check_altAnim';
		check_altAnim.onClick = () -> _song.notes[curSec].altAnim = check_altAnim.checked;

		stepperBeats = new PsychUINumericStepper(10, 100, 1, 4, 1, 6, 2);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		stepperBeats.onValueChange = () -> {
			saveToUndo();

			_song.notes[curSec].sectionBeats = stepperBeats.value;
			reassignNotesBetweenSections(curSec);
			reloadGridLayer();
		};

		check_changeBPM = new PsychUICheckBox(10, stepperBeats.y + 30, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';
		check_changeBPM.onClick = () -> {
			saveToUndo();
			
			_song.notes[curSec].changeBPM = check_changeBPM.checked;
			
			if (!check_changeBPM.checked) {
				reassignNotesBetweenSections(curSec);
				metronomeStepper.value = stepperBPM.value;
			} else {
				reassignNotesBetweenSections(curSec);
				_song.notes[curSec].bpm = stepperSectionBPM.value;
				metronomeStepper.value = stepperSectionBPM.value;
			}
			
			reloadGridLayer();
			updateGrid();
			updateNoteUI();
			FlxG.log.add('changed bpm');
		};

		stepperSectionBPM = new PsychUINumericStepper(10, check_changeBPM.y + 20, 1, stepperBPM.value ?? Conductor.bpm, 0, 999, 1);
		stepperSectionBPM.value = check_changeBPM.checked ? _song.notes[curSec].bpm : stepperBPM.value ?? Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';
		stepperSectionBPM.onValueChange = () -> {
   			 _song.notes[curSec].bpm = stepperSectionBPM.value;
			if (check_changeBPM.checked) {
				reassignNotesBetweenSections(curSec);
				metronomeStepper.value = stepperSectionBPM.value;
			}

			updateGrid();
			updateNoteUI();
		};

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
			saveToUndo();
			
			if(notesCopied == null || notesCopied.length < 1) return;

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * GRID_COLUMNS_PER_PLAYER * (curSec - sectionToCopy));
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
			saveToUndo();

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
			saveToUndo();
			
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note:Array<Dynamic> = _song.notes[curSec].sectionNotes[i];
				var isPlayerSide:Bool = note[1] < GRID_COLUMNS_PER_PLAYER;
				
				note[1] += isPlayerSide ? GRID_COLUMNS_PER_PLAYER : -GRID_COLUMNS_PER_PLAYER;
				
				note[1] = Math.max(0, Math.min(note[1], GRID_COLUMNS_PER_PLAYER * 2 - 1));
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
				var strum = note[0] + Conductor.stepCrochet * (getSectionBeats(daSec) * GRID_COLUMNS_PER_PLAYER * value);


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
					strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * GRID_COLUMNS_PER_PLAYER * value);
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
				boob -= (boob > (GRID_COLUMNS_PER_PLAYER - 1)) ? GRID_COLUMNS_PER_PLAYER : -GRID_COLUMNS_PER_PLAYER;

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
				var boob = note[1] % GRID_COLUMNS_PER_PLAYER;
				boob = (GRID_COLUMNS_PER_PLAYER - 1) - boob;
				if (note[1] > (GRID_COLUMNS_PER_PLAYER - 3)) boob += GRID_COLUMNS_PER_PLAYER;

				note[1] = boob;
				var copiedNote:Array<Dynamic> = [note[0], boob, note[2], note[3]];
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
	var strumTimeInputText:PsychUIInputText;
	var noteTypeDropDown:PsychUIDropDownMenu;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = mainBox.getTab('Note').menu;

		stepperSusLength = new PsychUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 16);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		stepperSusLength.onValueChange = () -> {
			if (selectedNotes.length > 0)
			{
				for (note in selectedNotes)
				{
					if (note.chartNoteData > -1)
					{
						note.songData[2] = stepperSusLength.value;
						note.sustainLength = stepperSusLength.value;
						note.setSustainLength(stepperSusLength.value, Conductor.stepCrochet, zoomList[curZoom]);
					}
				}
				updateGrid();
			}
			else if (curSelectedNote != null && curSelectedNote[2] != null)
			{
				curSelectedNote[2] = stepperSusLength.value;
				updateGrid();
			}
		}

		strumTimeInputText = new PsychUIInputText(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			curNoteTypes.push(noteTypeList[key]);
			key++;
		}

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_notetypes/'));
		#if MODS_ALLOWED
		directories.push(Mods.modFolders('custom_notetypes/'));
		#end

		#if sys
		var allowedExtensions:Array<String> = [];
		#if LUA_ALLOWED allowedExtensions.push('lua'); #end
		#if HSCRIPT_ALLOWED allowedExtensions = allowedExtensions.concat(Paths.HSCRIPT_EXTS); #end

		for (directory in directories) {
			if (FileSystem.exists(directory)) {
				final files = FileSystem.readDirectory(directory);
				final scriptFiles = files.filter(file -> {
					final lastDot = file.lastIndexOf('.');
					if (lastDot == -1) return false;

					final ext = file.substr(lastDot + 1).toLowerCase();
					return allowedExtensions.contains(ext);
				});
				
				for (file in scriptFiles) {
					final nameWithoutExt = file.substr(0, file.lastIndexOf('.'));
					if (!curNoteTypes.contains(nameWithoutExt)) {
						curNoteTypes.push(nameWithoutExt);
						key++;
					}
				}
			}
		}
		#end
		#end

		var displayNameList:Array<String> = curNoteTypes.copy();
		for (i in 1...displayNameList.length) {
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new PsychUIDropDownMenu(10, 105, displayNameList, function(id:Int, type:String)
		{
			if (selectedNotes.length > 0) {
				for (note in selectedNotes) {
					if (note.chartNoteData > -1) {
						note.songData[3] = curNoteTypes[id];
						note.noteType = curNoteTypes[id];
					}
				}
				updateGrid();
			}
			else if (curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = curNoteTypes[id];
				updateGrid();
			}
		});

		strumTimeInputText.onChange = function(old, curTxt) {
			var newTime = Std.parseFloat(curTxt);
			if (Math.isNaN(newTime)) newTime = 0;
			
			if (selectedNotes.length > 0) {
				var timeDiff = newTime - selectedNotes[0].strumTime;
				for (note in selectedNotes) {
					note.setStrumTime(note.strumTime + timeDiff);
					note.songData[0] = note.strumTime;
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
	function addEventsUI():Void
	{
		var tab_group_event = mainBox.getTab('Events').menu;

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_events/'));
		#if MODS_ALLOWED
		directories.push(Mods.modFolders('custom_events/'));
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
					if (note.chartNoteData < 0) {
						if (note.songData[1][0] != null) {
							note.songData[1][0][0] = eventName;
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
					if (note.chartNoteData < 0) {
						if (note.songData[1][0] != null) {
							note.songData[1][0][1] = curText;
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
					if (note.chartNoteData < 0) {
						if (note.songData[1][0] != null) {
							note.songData[1][0][2] = curText;
						}
					}
				}
				updateGrid();
			} else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
				curSelectedNote[1][curEventSelected][2] = curText;
				updateGrid();
			}
		};

		var removeButton:PsychUIButton = new PsychUIButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null)
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
			if(curSelectedNote != null && curSelectedNote[2] == null)
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
		if(curSelectedNote != null && curSelectedNote[2] == null)
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
	function addChartingUI() {
		var tab_group_chart = mainBox.getTab('Charting').menu;

		chartEditorSave.data.chart_waveformInst ??= false;
		chartEditorSave.data.chart_waveformVoices ??= false;
		chartEditorSave.data.chart_waveformOppVoices ??= false;

		if (chartEditorSave.data.chart_waveformInst)
			waveformTarget = INST;
		else if (chartEditorSave.data.chart_waveformVoices)
			waveformTarget = PLAYER;
		else if (chartEditorSave.data.chart_waveformOppVoices)
			waveformTarget = OPPONENT;

		waveformUseInstrumental = new PsychUICheckBox(10, 90, "Waveform (Instrumental)", 100);
		waveformUseInstrumental.checked = chartEditorSave.data.chart_waveformInst;
		waveformUseInstrumental.onClick = function()
		{
			waveformUseVoices.checked = false;
			waveformUseOppVoices.checked = false;
			chartEditorSave.data.chart_waveformVoices = false;
			chartEditorSave.data.chart_waveformOppVoices = false;
			chartEditorSave.data.chart_waveformInst = waveformUseInstrumental.checked;
			waveformTarget = INST;
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
			waveformTarget = PLAYER;
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
			waveformTarget = OPPONENT;
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
		instVolume.onValueChange = () -> FlxG.sound.music.volume = instVolume.value;

		voicesVolume = new PsychUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		voicesVolume.onValueChange = () -> vocals.volume = voicesVolume.value;

		voicesOppVolume = new PsychUINumericStepper(instVolume.x + 200, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesOppVolume.value = vocals.volume;
		voicesOppVolume.name = 'voices_opp_volume';
		voicesOppVolume.onValueChange = () -> opponentVocals.volume = voicesOppVolume.value;
		
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

	function loadSong():Void
	{
		FlxG.sound?.music?.stop();

		vocals?.stop();
		vocals?.destroy();

		opponentVocals?.stop();
		opponentVocals?.destroy();

		currentWaveformSound = null;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		
		try
		{
			var playerVocals = Paths.voices(currentSongName, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1);
			if (playerVocals != null)
				vocals.load(playerVocals);
			else
				vocals.load(Paths.voices(currentSongName));
		}
		catch (e:Dynamic)
		{
			trace("Could not load player vocals: " + e);
		}
		
		vocals.autoDestroy = false;
		FlxG.sound.list.add(vocals);

		opponentVocals = new FlxSound();
		try
		{
			var oppVocals = Paths.voices(currentSongName, (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2);
			if(oppVocals != null) opponentVocals.load(oppVocals);
		}
		catch (e:Dynamic)
		{
			trace("Could not load opponent vocals: " + e);
		}
		
		opponentVocals.autoDestroy = false;
		FlxG.sound.list.add(opponentVocals);

		generateSong();
		_cacheSections();
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
			Reflect.setField(characterData, 'vocalsP' + Std.string(i), data.vocals_file ?? '');
		}
	}

	function generateSong() {
		FlxG.sound.playMusic(Paths.inst(currentSongName), instVolume?.value ?? 0.6);
		if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst?.checked) FlxG.sound.music.volume = 0;

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

	public function UIEvent(id:String, sender:Dynamic)
	{
		switch (id)
		{
			case PsychUIBox.DROP_EVENT:
				chartEditorSave.data.mainBoxPosition = [mainBox.x, mainBox.y];
				chartEditorSave.data.infoBoxPosition = [infoBox.x, infoBox.y];
		}
	}

	function sectionStartTime(add:Int = 0):Float
	{
		if (cachedSectionTimes == null || cachedSectionTimes.length == 0) _cacheSections();
		
		var index = curSec + add;
		if (index < 0) index = 0;
		if (index >= cachedSectionTimes.length) index = cachedSectionTimes.length - 1;
		
		if (cachedSectionTimes.length > index && index >= 0)
			return cachedSectionTimes[index];
		return 0;
	}

	function isMouseOverUI():Bool {
		return FlxG.mouse.overlaps(mainBox) || 
			FlxG.mouse.overlaps(infoBox) || 
			FlxG.mouse.overlaps(positionSlider) ||
			FlxG.mouse.overlaps(sliderBg);
	}

	var iconJustFlashed:Bool = false;
	var lastConductorPos:Float;
	var colorSine:Float = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		FlxG.mouse.visible = true;

		curStep = recalculateSteps();

		final conductorTime = Conductor.songPosition;
		final blockInput = PsychUIInputText.focusOn != null;
		final mouseOverUI = isMouseOverUI();

		for (icons in [playerIcon, opponentIcon])
			icons.updateIconScale(elapsed);

		var beatProgress = (Conductor.songPosition % Conductor.crochet) / Conductor.crochet;
		if (beatProgress < 0.1 && !iconJustFlashed && FlxG.sound.music.playing) {
			for (icons in [playerIcon, opponentIcon])
				icons.flash(0.47, 0.35);
			iconJustFlashed = true;
		} else if (beatProgress > 0.1 && FlxG.sound.music.playing) {
			iconJustFlashed = false;
		}
		
		updateMusicPlayback();

		updateSongSlider();
		
		if (!blockInput) {
			ClientPrefs.toggleVolumeKeys();
			handleKeyboardInput();
			handleMouseInput(mouseOverUI);
		} else {
			ClientPrefs.toggleVolumeKeys(false);
		}

		_song.bpm = tempBpm;

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
		final musicLength = FlxG.sound.music.length;

		if(curTime < 0) {
			FlxG.sound.music.pause();
			curTime = 0;
			FlxG.sound.music.time = curTime;
		} else if(curTime >= musicLength) { 
			FlxG.sound.music.pause();
			curTime = musicLength;
			FlxG.sound.music.time = curTime;
			Conductor.songPosition = curTime;
			
			if(vocals != null) {
				vocals.pause();
				vocals.time = curTime;
			}
			if(opponentVocals != null) {
				opponentVocals.pause();
				opponentVocals.time = curTime;
			}
		}
		
		Conductor.songPosition = curTime;
			
		if(!disableAutoScrolling.checked) {
			if (Math.ceil(strumLine.y) > gridBG.height)
			{
				if (_song.notes[curSec + 1] == null)
				{
					addSection();
				}

				changeSection(curSec + 1, false);
			} else if(strumLine.y < 0) {
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
		
		for (i in 0...GRID_COLUMNS_TOTAL) {
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		if (quant?.exists) quant.update(elapsed);
	}

	function handleKeyboardInput():Void
	{
		if (FlxG.keys.justPressed.ESCAPE) {
			PlayState.SONG = _song;

			FlxG.sound.music.pause();
			vocals?.pause();
			opponentVocals?.pause();
			FlxG.switchState(() -> new game.states.editors.EditorPlayState(sectionStartTime()));
		}
		
		if (FlxG.keys.justPressed.ENTER) {
			FlxG.mouse.visible = false;
			PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals?.stop();
			opponentVocals?.pause();

			StageData.loadDirectory(_song);
			LoadingState.loadAndSwitchState(() -> new PlayState());
		}
		
		if(curSelectedNote != null) {
			if (Std.isOfType(curSelectedNote[1], Int) && curSelectedNote[1] > -1) {
				if (FlxG.keys.justPressed.E) changeNoteSustain(Conductor.stepCrochet);
				if (FlxG.keys.justPressed.Q) changeNoteSustain(-Conductor.stepCrochet);
			}
		}
		
		if (FlxG.keys.justPressed.F1) showTips();
		if (FlxG.keys.justPressed.F2) toggleCharacters();
		if (FlxG.keys.justPressed.BACKSPACE #if android || FlxG.android.justReleased.BACK #end) exitToMenu();
		
		if(FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
			--curZoom;
			updateZoom();
		}
		if(FlxG.keys.justPressed.X && curZoom < zoomList.length-1) {
			curZoom++;
			updateZoom();
		}
		
		if (FlxG.keys.justPressed.TAB) switchTabs();
		
		if (FlxG.keys.justPressed.SPACE) togglePlayback();
		
		if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
			resetSection(FlxG.keys.pressed.SHIFT);
		
		var shiftThing:Int = (FlxG.keys.pressed.SHIFT) ? 4 : 1;
		if (FlxG.keys.justPressed.D && !(FlxG.keys.pressed.SHIFT || FlxG.keys.pressed.CONTROL)) 
			changeSection(curSec + shiftThing);
		if (FlxG.keys.justPressed.A && !(FlxG.keys.pressed.SHIFT || FlxG.keys.pressed.CONTROL))
			changeSection((curSec <= 0) ? 0 : curSec - shiftThing);
		
		if (FlxG.keys.pressed.W || (FlxG.keys.pressed.S && !FlxG.keys.pressed.CONTROL))
			handlePlaybackSeeking();

		if(FlxG.keys.justPressed.RIGHT) {
			curQuant++;
			if(curQuant > quantizations.length - 1)
				curQuant = 0;

			quantization = quantizations[curQuant];
		}

		if(FlxG.keys.justPressed.LEFT) {
			curQuant--;
			if(curQuant < 0)
				curQuant = quantizations.length-1;

			quantization = quantizations[curQuant];
		}
		quant.animation.play('q', true, false, curQuant);
		
		if(!vortex)
		{
			if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) {
				handleQuantizedSeeking();
			}
		}
		
		if(vortex) handleVortexInput();
		
		if (FlxG.keys.pressed.CONTROL) {
			if (FlxG.keys.justPressed.C && curSelectedNote != null) 
			{
				var noteData = curSelectedNote[1];
				var isEvent = noteData == -1 || Std.isOfType(noteData, Array);
				
				var note:MetaNote;
				if (isEvent) {
					note = new MetaNote(curSelectedNote[0], -1, curSelectedNote);
				} else {
					note = new MetaNote(curSelectedNote[0], noteData % GRID_COLUMNS_PER_PLAYER, curSelectedNote);
					note.sustainLength = curSelectedNote[2];
					note.noteType = curSelectedNote[3];
				}
				
				copyNote(note);
			}

			if (FlxG.keys.justPressed.V) pasteNote();
			if (FlxG.keys.justPressed.Z) undo();
			if (FlxG.keys.justPressed.Y) redo();

			if (FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.A) selectAllNotesInSection();
		}

		if ((FlxG.keys.justPressed.DELETE || (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.D)) && selectedNotes.length > 0)
		{
			saveToUndo();
			
			for (note in selectedNotes) {
				_deleteSingleNote(note);
				note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
			}
			selectedNotes.resize(0);
			
			updateGrid();
		}
	}

	function selectAllNotesInSection():Void {
		for (note in selectedNotes) {
			note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
		}
		selectedNotes.resize(0);
		
		curRenderedNotes.forEachAlive((note:MetaNote) -> {
			selectedNotes.push(note);
			note.color = FlxColor.BLUE;
		});
		
		updateNoteUI();
	}

	function handleMouseInput(mouseOverUI:Bool):Void
	{
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
		if (FlxG.mouse.justPressed && !FlxG.mouse.justPressedRight)
		{
			isMouseDown = true;
			mouseDownPos.set(FlxG.mouse.x, FlxG.mouse.y);
			mouseDownTime = Date.now().getTime();
			
			var clickedNote:MetaNote = getNoteUnderMouse();
			if (clickedNote != null)
			{
				if (FlxG.mouse.pressed)
				{
					if (FlxG.keys.pressed.CONTROL)
					{
						if (selectedNotes.contains(clickedNote))
						{
							clickedNote.color = clickedNote.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
							selectedNotes.remove(clickedNote);
						}
						else
						{
							selectedNotes.push(clickedNote);
							clickedNote.color = FlxColor.BLUE;
						}
					}
					else
					{
						for (note in selectedNotes) {
							note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
						}
						selectedNotes = [clickedNote];
						clickedNote.color = FlxColor.BLUE;
						
						selectNote(clickedNote);
					}
				}
			}
			else
			{
				if (!FlxG.keys.pressed.CONTROL && !FlxG.keys.pressed.ALT)
				{
					for (note in selectedNotes) {
						note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
					}
					selectedNotes.resize(0);
					
					selecting = true;
					var mousePos = FlxG.mouse.getWorldPosition();
					selectStart.set(mousePos.x, mousePos.y);
					
					selectBox.visible = true;
					selectBox.x = mousePos.x;
					selectBox.y = mousePos.y;
					selectBox.scale.set(0, 0);
				}
			}
		}
	}

	function handleMouseRelease():Void
	{
		if (FlxG.mouse.justReleased && isMouseDown)
		{
			isMouseDown = false;
			
			final mouseUpPos = FlxG.mouse.getWorldPosition();
			final distance = Math.sqrt(Math.pow(mouseUpPos.x - mouseDownPos.x, 2) + 
									Math.pow(mouseUpPos.y - mouseDownPos.y, 2));
			
			if (selecting)
			{
				selecting = false;
				selectBox.visible = false;
				selectBoxOutline.visible = false;
				
				if (distance > dragThreshold)
				{
					var selectionBox = new FlxRect(
						selectBox.x, 
						selectBox.y, 
						selectBox.scale.x, 
						selectBox.scale.y
					);
					
					if (!FlxG.keys.pressed.CONTROL)
					{
						for (note in selectedNotes) {
							note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
						}
						selectedNotes.resize(0);
					}
					
					curRenderedNotes.forEachAlive((note:MetaNote) -> {
						var noteRect = new FlxRect(note.x, note.y, note.width, note.height);
						if (selectionBox.overlaps(noteRect)) {
							if (!selectedNotes.contains(note)) {
								selectedNotes.push(note);
								note.color = FlxColor.BLUE;
							}
						}
					});
					
					if (selectedNotes.length == 1 && !FlxG.keys.pressed.CONTROL)
						selectNote(selectedNotes[0]);
				}
				else
				{
					if (!FlxG.keys.pressed.CONTROL && dummyArrow.visible)
					{
						var noteData = Math.floor((FlxG.mouse.x - gridBG.x) / GRID_SIZE) - 1;
						var noteStrum = getStrumTime(dummyArrow.y, false) + sectionStartTime();
						addNote(noteStrum, noteData, currentType);
					}
				}
			}
		}
	}

	function getNoteUnderMouse():MetaNote
	{
		var noteUnderMouse:MetaNote = null;
		
		curRenderedNotes.forEachAlive(function(note:MetaNote) {
			if (note == null || !note.visible) return;
			
			if (FlxG.mouse.overlaps(note)) {
				if (noteUnderMouse == null || note.strumTime < noteUnderMouse.strumTime) {
					noteUnderMouse = note;
				}
			}
		});
		
		return noteUnderMouse;
	}

	function handleRightClick():Void
	{
		for (note in selectedNotes) {
			note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
		}
		selectedNotes.resize(0);
		
		var clickedNote:MetaNote = getNoteUnderMouse();
		if (clickedNote != null) deleteNote(clickedNote);
	}

	function handleMouseWheel():Void
	{
		FlxG.sound.music.pause();
		if (!mouseQuant)
		{
			var newTime = FlxG.sound.music.time - (FlxG.mouse.wheel * Conductor.stepCrochet * 0.8);
			if (newTime <= 0) newTime = 0;
			if (newTime > FlxG.sound.music.length) newTime = FlxG.sound.music.length;

			FlxG.sound.music.time = newTime;
		}
		else
		{
			final beat:Float = curDecBeat;
			final snap:Float = quantization / 4;
			final increase:Float = 1 / snap;
			if (FlxG.mouse.wheel > 0)
			{
				var fuck:Float = MathUtil.quantize(beat, snap) - increase;
				if (fuck <= 0) fuck = 0;
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
		final playedSound = [false, false, false, false, false, false, false, false];
		
		curRenderedNotes.forEachAlive((note:MetaNote) -> {
			note.alpha = 1;
			
			if (curSelectedNote != null)
				updateNoteColor(note, elapsed);
			
			if (note.strumTime <= Conductor.songPosition && note.strumTime + note.sustainLength > Conductor.songPosition)
				activeNotes.set(note.mustPress ? "player" : "opponent", true);
			
			if (note.strumTime <= Conductor.songPosition)
				handleNotePlayback(note, playedSound);
		});
		
		updateCharacterDanceStates(activeNotes);
	}

	function updateNoteColor(note:MetaNote, elapsed:Float):Void
	{
		if (selectedNotes.contains(note)) {
			note.color = FlxColor.BLUE;
		} else if (curSelectedNote != null && note.songData == curSelectedNote) {
			colorSine += elapsed;
			final colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
			note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999);
		} else {
			note.color = FlxColor.WHITE;
		}
	}

	function handleNotePlayback(note:MetaNote, playedSound:Array<Bool>):Void
	{
		note.alpha = 0.4;
		if (note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.chartNoteData > -1) {
			var data:Int = note.noteData;

			var originalData:Int = note.chartNoteData;
			
			if (strumLineNotes.members[originalData] != null) {
				strumLineNotes.members[originalData].playAnim('confirm', true);
				strumLineNotes.members[originalData].resetAnim = ((note.sustainLength / 1000) + 0.15) / playbackSpeed;
			}
			
			var isPlayerNote:Bool = originalData >= GRID_COLUMNS_PER_PLAYER;
			if (!playedSound[originalData]) {
				playNoteSound(note, data, isPlayerNote);
				playCharacterAnimation(note, data, isPlayerNote);
			}
			
			playedSound[originalData] = true;
		}
	}

	function playNoteSound(note:MetaNote, data:Int, isPlayerNote:Bool):Void
	{
		if ((playSoundBf.checked && isPlayerNote) || (playSoundDad.checked && !isPlayerNote)) {
			var soundToPlay = 'hitsound';
			if (_song.player1 == 'gf') {
				soundToPlay = 'GF_' + Std.string(data + 1);
			}
			FlxG.sound.play(Paths.sound(soundToPlay)).pan = isPlayerNote ? 0.3 : -0.3;
		}
	}

	function playCharacterAnimation(note:MetaNote, data:Int, isPlayerNote:Bool):Void
	{
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

	function updatePlaybackSpeed():Void
	{
		#if FLX_PITCH
		final holdingShift = FlxG.keys.pressed.SHIFT;
		final holdingLB = FlxG.keys.pressed.LBRACKET;
		final holdingRB = FlxG.keys.pressed.RBRACKET;
		final pressedLB = FlxG.keys.justPressed.LBRACKET;
		final pressedRB = FlxG.keys.justPressed.RBRACKET;

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
			"Section: " + Math.max(0, curSec) +
			"\n\nBeat: " + Std.string(curDecBeat <= 0 ? 0 : curDecBeat).substring(0,4) +
			"\n\nStep: " + Math.max(0, curStep) +
			"\n\nBeat Snap: " + quantization + "th";
	}

	function updateCharacterAnimations(elapsed:Float):Void
	{
	}

	function handlePlaybackSeeking():Void
	{
		FlxG.sound.music.pause();

		var holdingShift:Float = 1;
		if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
		else if (FlxG.keys.pressed.SHIFT) holdingShift = 3;

		var daTime:Float = 700 * FlxG.elapsed * holdingShift;

		if (FlxG.keys.pressed.W)
			FlxG.sound.music.time = Math.max(0, FlxG.sound.music.time - daTime);
		else
			FlxG.sound.music.time = Math.min(FlxG.sound.music.length, FlxG.sound.music.time + daTime);

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

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
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
				player = new Character(750, 435, _song.player1, true, true);
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

	function reloadGridLayer() {
		_cacheSections();

		var gridHeight:Int = 0;
		var nextGridHeight:Int = 0;
		var songLength:Float = FlxG.sound.music?.length ?? 0;
		var currentBeats:Float = getSectionBeats();
		
		final sectionEndTime:Float = cachedSectionTimes[curSec] + (currentBeats * (1000 * 60 / _song.bpm));
		
		if (sectionEndTime > songLength && songLength > 0) {
			final timeRemaining:Float = songLength - cachedSectionTimes[curSec];
			final beatsRemaining:Float = timeRemaining / (1000 * 60 / _song.bpm);

			gridHeight = Std.int(GRID_SIZE * beatsRemaining * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom]);
			currentBeats = beatsRemaining;
		} else {
			gridHeight = Std.int(GRID_SIZE * currentBeats * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom]);
		}
		
		if (gridHeight < GRID_SIZE) gridHeight = GRID_SIZE;
		
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (GRID_COLUMNS_TOTAL + 1), gridHeight, true, gridColors.mainLines, gridColors.secondaryLines);
		gridBG.screenCenter(X);
		waveform.x = gridBG.x + GRID_SIZE;
		
		updateWaveformIfNeeded();
		updateGrid();

		var foundPrevSec:Bool = false;
		var foundNextSec:Bool = false;

		if(curSec > 0 && sectionStartTime(-1) >= 0) {
			var prevGridHeight:Int = Std.int(GRID_SIZE * getSectionBeats(curSec - 1) * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom]);
			if (prevGridHeight < GRID_SIZE) prevGridHeight = GRID_SIZE;

			prevGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (GRID_COLUMNS_TOTAL + 1), prevGridHeight, true, gridColors.background, gridColors.mainLines);
			prevGridBG.screenCenter(X);
			foundPrevSec = true;
		} else {
			prevGridBG.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		}
		prevGridBG.y = gridBG.y - prevGridBG.height;

		if(sectionStartTime(1) < songLength) {
			final nextFullBeats:Float = getSectionBeats(curSec + 1);
			final nextSectionEndTime:Float = cachedSectionTimes[curSec + 1] + (nextFullBeats * (1000 * 60 / _song.bpm));

			var nextBeats:Float = nextFullBeats;
			
			if (nextSectionEndTime > songLength && songLength > 0) {
				final nextTimeRemaining:Float = songLength - cachedSectionTimes[curSec + 1];
				final nextBeatsRemaining:Float = nextTimeRemaining / (1000 * 60 / _song.bpm);

				nextGridHeight = Std.int(GRID_SIZE * nextBeatsRemaining * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom]);
				nextBeats = nextBeatsRemaining;
			} else {
				nextGridHeight = Std.int(GRID_SIZE * nextBeats * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom]);
			}
			
			if (nextGridHeight < GRID_SIZE) nextGridHeight = GRID_SIZE;
			
			nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (GRID_COLUMNS_TOTAL + 1), nextGridHeight, true, gridColors.background, gridColors.mainLines);
			nextGridBG.screenCenter(X);
			foundNextSec = true;
		} else {
			nextGridBG.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		}
		nextGridBG.y = gridBG.y + gridBG.height;

		for (sprite in gridLayer) {
			if (sprite != gridBG && sprite != prevGridBG && sprite != nextGridBG) {
				sprite?.destroy();
			}
		}

		gridLayer?.add(prevGridBG);
		gridLayer?.add(nextGridBG);
		gridLayer?.add(gridBG);

		if(foundPrevSec) {
			var gridBlackPrev:FlxSprite = new FlxSprite(prevGridBG.x, prevGridBG.y).makeGraphic(Std.int(GRID_SIZE * (GRID_COLUMNS_TOTAL + 1)), Std.int(prevGridBG.height), FlxColor.BLACK);
			gridBlackPrev.alpha = 0.4;
			gridLayer?.add(gridBlackPrev);
		}

		if(foundNextSec) {
			var gridBlackNext:FlxSprite = new FlxSprite(nextGridBG.x, gridBG.y + gridBG.height).makeGraphic(Std.int(GRID_SIZE * (GRID_COLUMNS_TOTAL + 1)), Std.int(nextGridHeight), FlxColor.BLACK);
			gridBlackNext.alpha = 0.4;
			gridLayer?.add(gridBlackNext);
		}

		final topY = prevGridBG.y;
		final bottomY = (foundNextSec ? nextGridBG.y + nextGridHeight : gridBG.y + gridHeight);
		final totalHeight = bottomY - topY;

		var gridLineLeft = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(2, Std.int(totalHeight), gridColors.sectionLines);
		gridLineLeft.y = topY + 1;
		gridLayer.add(gridLineLeft);

		for (i in 0...GRID_PLAYERS - 1) {
			var gridLineRight = new FlxSprite(gridBG.x + GRID_SIZE + (GRID_SIZE * GRID_COLUMNS_PER_PLAYER) * (i + 1)).makeGraphic(2, Std.int(totalHeight), gridColors.sectionLines);
			gridLineRight.y = topY + 1;
			gridLayer.add(gridLineRight);
		}

		function addBeatSeparators(grid:FlxSprite, beats:Float, x:Float, y:Float, width:Float, height:Float) {
			final beatHeight:Float = GRID_SIZE * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom];
			final maxBeats:Float = height / beatHeight;
			
			final drawBeats:Float = Math.min(beats, maxBeats);
			for (i in 1...Std.int(drawBeats)) {
				final beatY:Float = y + (beatHeight * i);

				if (beatY < y + height - 1) {
					var beatsep:FlxSprite = new FlxSprite(x, beatY).makeGraphic(1, 1, gridColors.beatLines);
					beatsep.scale.x = width;
					beatsep.updateHitbox();
					if(vortex) gridLayer.add(beatsep);
				}
			}
		}

		if(vortex) {
			addBeatSeparators(gridBG, currentBeats, gridBG.x, gridBG.y, gridBG.width, gridHeight);
			
			if(foundPrevSec) {
				final prevBeats:Float = getSectionBeats(curSec - 1);
				final prevHeight:Float = prevGridBG.height;
				addBeatSeparators(prevGridBG, prevBeats, prevGridBG.x, prevGridBG.y, prevGridBG.width, prevHeight);
			}
			
			if(foundNextSec) {
				final nextFullBeats:Float = getSectionBeats(curSec + 1);
				addBeatSeparators(nextGridBG, nextFullBeats, nextGridBG.x, nextGridBG.y, nextGridBG.width, nextGridHeight);
			}
		}
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() / 4);
	}

	function changeNoteSustain(value:Float):Void
	{
		if (selectedNotes.length > 0)
		{
			for (note in selectedNotes)
			{
				if (note.chartNoteData > -1 && note.songData[2] != null)
				{
					note.songData[2] += value;
					note.songData[2] = Math.max(note.songData[2], 0);
					note.setSustainLength(note.songData[2], Conductor.stepCrochet, zoomList[curZoom]);
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

	private function addSection(sectionBeats:Float = 4):Void
	{
		var sec:SwagSection = {
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: false,
			gfSection: false,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.push(sec);
		_cacheSections();
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
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
			_cacheSections();

			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = cachedSectionTimes[curSec];
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

			reloadGridLayer();
			updateSectionUI();

			if (sec == 0)
				metronomeStepper.value = _song.notes[curSec].changeBPM ? _song.notes[curSec].bpm : stepperBPM.value;
			else if (_song.notes[curSec].changeBPM)
				metronomeStepper.value = _song.notes[curSec].bpm;

			updateWaveform();
		}
		else
		{
			changeSection();
		}

		Conductor.songPosition = FlxG.sound.music.time;
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

		updateHeads(false);
	}

	var _lastSec:Int = -1;
	var _lastGfSection:Null<Bool> = null;
	var _lastMustHit:Null<Bool> = null;
	function updateHeads(ignoreCheck:Bool = true):Void
	{
		if(_lastGfSection == _song.notes[curSec].gfSection && _lastSec == curSec && _lastMustHit == _song.notes[curSec].mustHitSection && !ignoreCheck) return;

		final char1:CharacterFile = loadHealthIconFromCharacter(_song.player1);
		final char2:CharacterFile = loadHealthIconFromCharacter(_song.player2);
		final char3:CharacterFile = loadHealthIconFromCharacter(_song.gfVersion);
		
		final healthIconP1:String = !characterFailed ? char1.healthicon : 'face';
		final healthIconP2:String = !characterFailed ? char2.healthicon : 'face';
		final healthIconGF:String = !characterFailed ? char3.healthicon : 'face';
		
		playerIcon.changeIcon(healthIconP1);
		opponentIcon.changeIcon(healthIconP2);

		if (_song.notes[curSec].gfSection)
		{
			if (_song.notes[curSec].mustHitSection) playerIcon.changeIcon(healthIconGF);
			else opponentIcon.changeIcon(healthIconGF);
		}

		playerIcon.updateHitbox();
    	opponentIcon.updateHitbox();

		if(mustHitIndicator != null) mustHitIndicator.x = (_song.notes[curSec].mustHitSection ? playerIcon.x : opponentIcon.x) + GRID_SIZE * 1.76;

		_lastSec = curSec;
		_lastGfSection = _song.notes[curSec].gfSection;
		_lastMustHit = _song.notes[curSec].mustHitSection;
	}

	var characterFailed:Bool = false;
	function loadHealthIconFromCharacter(char:String):CharacterFile {
		characterFailed = false;

		var characterPath:String = 'characters/$char';
		var path:String = '';
		var rawJson:String = '';
		
		path = Paths.json(characterPath);

		var fileExists:Bool = #if sys FileSystem.exists(path) || #end OpenFlAssets.exists(path);
		if (!fileExists) {
			path = Paths.json('characters/' + Character.DEFAULT_CHARACTER);
			characterFailed = true;
		}
		
		try {
			rawJson = #if sys FileSystem.exists(path) ? File.getContent(path) : #end OpenFlAssets.getText(path);
		} catch (e:Dynamic) {
			trace('Error loading character file: ' + e);
			path = Paths.json('characters/' + Character.DEFAULT_CHARACTER);
			characterFailed = true;
			
			rawJson = #if sys FileSystem.exists(path) ? File.getContent(path) : #end OpenFlAssets.getText(path);
		}
		
		return cast Json.parse(rawJson);
	}

	function updateNoteUI():Void
	{
		if (selectedNotes.length > 0)
		{
			var firstNote = selectedNotes[0];
			var allSameSustain:Bool = true;
			var allSameType:Bool = true;
			var allSameEvent:Bool = true;
			var firstEventName = null;
			var firstEventVal1 = null;
			var firstEventVal2 = null;

			for (note in selectedNotes)
			{
				if (note.songData[2] != firstNote.songData[2]) allSameSustain = false;
				if (note.songData[3] != firstNote.songData[3]) allSameType = false;
				
				if (note.chartNoteData < 0)
				{
					if (firstEventName == null)
					{
						if (note.songData[1][0] != null) {
							firstEventName = note.songData[1][0][0];
							firstEventVal1 = note.songData[1][0][1];
							firstEventVal2 = note.songData[1][0][2];
						}
					}
					else if (note.songData[1][0][0] != firstEventName || note.songData[1][0][1] != firstEventVal1 || note.songData[1][0][2] != firstEventVal2) {
						allSameEvent = false;
					}
				}
			}

			if (firstNote.chartNoteData > -1)
			{
				stepperSusLength.value = allSameSustain ? firstNote.songData[2] : 0;
				
				if (firstNote.songData[3] != null && firstNote.songData[3].length > 0) {
					var typeIndex = curNoteTypes.indexOf(firstNote.songData[3]);
					currentType = typeIndex >= 0 ? typeIndex : 0;
					noteTypeDropDown.selectedLabel = currentType + '. ' + firstNote.songData[3];
				} else {
					currentType = 0;
					noteTypeDropDown.selectedLabel = '';
				}
				strumTimeInputText.text = '';
			}
			else
			{
				if (firstNote.songData[1][0] != null) {
					eventDropDown.selectedLabel = allSameEvent ? firstNote.songData[1][0][0] : '[Multiple]';
					value1InputText.text = allSameEvent ? firstNote.songData[1][0][1] : '';
					value2InputText.text = allSameEvent ? firstNote.songData[1][0][2] : '';
				}
				strumTimeInputText.text = '';
				
				if (allSameEvent && firstNote.songData[1][0] != null) {
					var selectedEventIndex = -1;
					for (i in 0...eventStuff.length) {
						if (eventStuff[i][0] == firstNote.songData[1][0][0]) {
							selectedEventIndex = i;
							break;
						}
					}
					if (selectedEventIndex != -1) {
						descText.text = eventStuff[selectedEventIndex][1];
					}
				} else {
					descText.text = "Multiple Events Selected";
				}
			}
		}
		else if (curSelectedNote != null)
		{
			if(curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if(curSelectedNote[3] != null) {
					if (curSelectedNote[3].length > 0) {
						currentType = curNoteTypes.indexOf(curSelectedNote[3]);
						if(currentType <= 0) {
							noteTypeDropDown.selectedLabel = '';
						} else {
							noteTypeDropDown.selectedLabel = currentType + '. ' + curSelectedNote[3];
						}
					} else {
						currentType = 0;
						noteTypeDropDown.selectedLabel = '';
					}
				} else {
					currentType = 0;
					noteTypeDropDown.selectedLabel = '';
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
			currentType = 0;
			noteTypeDropDown.selectedLabel = '';
			eventDropDown.selectedLabel = '';
			value1InputText.text = '';
			value2InputText.text = '';
			strumTimeInputText.text = '';
		}
	}

	function updateGrid():Void
	{
		clearGroup(curRenderedNotes);
		clearGroup(nextRenderedNotes);
		clearGroup(prevRenderedNotes);

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

		curRenderedNotes.forEachAlive((note:MetaNote) -> note.color = selectedNotes.contains(note) ? FlxColor.BLUE : FlxColor.WHITE);

		var beats:Float = getSectionBeats();
		var sectionStart:Float = sectionStartTime();
		var sectionEnd:Float = sectionStartTime(1);
		var songLength:Float = FlxG.sound.music != null ? FlxG.sound.music.length : 0;
		
		for (i in _song.notes[curSec].sectionNotes) {
			var noteData:Int = i[1];
			
			if (songLength > 0 && i[0] > songLength) continue;
			
			var note:MetaNote = createMetaNote(i, false);
			curRenderedNotes.add(note);
			
			if (note.sustainLength > 0) {
				note.setSustainLength(note.sustainLength, Conductor.stepCrochet, zoomList[curZoom]);
			}
			
			note.mustPress = note.chartNoteData >= GRID_COLUMNS_PER_PLAYER;
		}

		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in _song.events) {
			if(i[0] >= startThing && i[0] < endThing) {
				if (songLength > 0 && i[0] > songLength) continue;
				
				var note:MetaNote = createMetaNote(i, false);
				curRenderedNotes.add(note);
			}
		}

		var nextBeats:Float = getSectionBeats(1);
		if(curSec < _song.notes.length-1) {
			for (i in _song.notes[curSec+1].sectionNotes) {
				if (songLength > 0 && i[0] > songLength) continue;
				
				var note:MetaNote = createMetaNote(i, true, false);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0) {
					note.setSustainLength(note.sustainLength, Conductor.stepCrochet, zoomList[curZoom]);
				}
			}
		}

		var prevBeats:Float = getSectionBeats(-1); 
		if(curSec > 0) {
			for (i in _song.notes[curSec-1].sectionNotes) {
				var note:MetaNote = createMetaNote(i, false, true);
				note.alpha = 0.6;
				prevRenderedNotes.add(note);
				if (note.sustainLength > 0) {
					note.setSustainLength(note.sustainLength, Conductor.stepCrochet, zoomList[curZoom]);
				}
			}
		}

		var nextStartThing:Float = sectionStartTime(1);
		var nextEndThing:Float = sectionStartTime(2);
		for (i in _song.events) {
			if(i[0] >= nextStartThing && i[0] < nextEndThing) {
				if (songLength > 0 && i[0] > songLength) continue;
				
				var note:MetaNote = createMetaNote(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}

		var prevStartThing:Float = sectionStartTime(-1);
		var prevEndThing:Float = sectionStartTime();
		for (i in _song.events) {
			if(i[0] >= prevStartThing && i[0] < prevEndThing) {
				var note:MetaNote = createMetaNote(i, false, true);
				note.alpha = 0.6;
				prevRenderedNotes.add(note);
			}
		}
	}

	function createMetaNote(data:Array<Dynamic>, isNextSection:Bool, isPrevSection:Bool = false):MetaNote
	{
		var daStrumTime = data[0];
		var daSus:Dynamic = data[2];

		var note:MetaNote = null;
		
		var sec:SwagSection = _song.notes[curSec];
		if(isNextSection) sec = _song.notes[curSec+1];
		if(isPrevSection) sec = _song.notes[curSec-1];
		
		if (Std.isOfType(data[1], Array))
		{
			note = new EventMetaNote(daStrumTime, data);
			note.chartNoteData = -1;
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			
			note.x = gridBG.x;
			note.mustPress = false;
		}
		else
		{
			var noteDataInt:Int = data[1];
			
			var isPlayerNote = noteDataInt >= GRID_COLUMNS_PER_PLAYER;
			var visualColumn:Int = noteDataInt % GRID_COLUMNS_PER_PLAYER;
			
			note = new MetaNote(daStrumTime, noteDataInt, data);
			
			if(daSus != null) {
				note.sustainLength = daSus;
				note.noteType = data[3];
			}
			
			note.changeNoteData(noteDataInt);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();

			if (isPlayerNote) note.x = Math.floor(visualColumn * GRID_SIZE) + gridBG.x + GRID_SIZE + (GRID_COLUMNS_PER_PLAYER * GRID_SIZE);
			else note.x = Math.floor(visualColumn * GRID_SIZE) + gridBG.x + GRID_SIZE;
			
			note.mustPress = isPlayerNote;

			if (note.noteType != null && note.noteType.length > 0 && note.noteType != '')
			{
				var typeIndex:Int = curNoteTypes.indexOf(note.noteType);
				if (typeIndex > 0)
					note.findNoteTypeText(typeIndex);
				else if (typeIndex == -1)
					note.findNoteTypeText(-1);
			}
		}

		var num:Int = 0;
		if(isNextSection) num = 1;
		if(isPrevSection) num = -1;
		var beats:Float = getSectionBeats(curSec + num);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		
		return note;
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

	function selectNote(note:MetaNote):Void
	{
		var noteDataToCheck:Dynamic = null;

		if (note.songData != null && note.songData[1] != null)
			noteDataToCheck = note.songData[1];
		else
			noteDataToCheck = note.chartNoteData;

		curSelectedNote = null;

		if (FlxG.keys.pressed.CONTROL)
		{
			if (selectedNotes.contains(note))
			{
				note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
				selectedNotes.remove(note);
			}
			else
			{
				selectedNotes.push(note);
				note.color = FlxColor.BLUE;
			}
			return;
		}

		if(Std.isOfType(noteDataToCheck, Array))
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
		else
		{
			var originalData:Int = noteDataToCheck;
			
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i.length > 2 && i[0] == note.strumTime && i[1] == originalData)
				{
					curSelectedNote = i;
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

	function deleteNote(note:MetaNote):Void
	{
		saveToUndo();
		
		if (selectedNotes.contains(note))
		{
			selectedNotes.remove(note);
			note.color = note.chartNoteData == -1 ? FlxColor.BLUE : FlxColor.WHITE;
		}
		
		if (note.songData != null)
		{
			if (note.chartNoteData > -1) {
				for (section in _song.notes) {
					if (section.sectionNotes.contains(note.songData)) {
						section.sectionNotes.remove(note.songData);
						break;
					}
				}
			} else {
				_song.events.remove(note.songData);
			}
		}
		else
		{
			var noteDataToCheck = note.chartNoteData;
			if (note.chartNoteData > -1) {
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
		
		updateGrid();
	}

	private function _deleteSingleNote(note:MetaNote):Void
	{
		saveToUndo();
		
		if (note.songData != null)
		{
			if (note.chartNoteData > -1) {
				for (section in _song.notes) {
					if (section.sectionNotes.contains(note.songData)) {
						section.sectionNotes.remove(note.songData);
						break;
					}
				}
			} else {
				_song.events.remove(note.songData);
			}
		}
		else
		{
			var noteDataToCheck = note.chartNoteData;
			if (note.chartNoteData > -1) {
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
			curRenderedNotes.forEachAlive(function(note:MetaNote)
			{
				var checkData = d % GRID_COLUMNS_PER_PLAYER;
				var isPlayerNote = d >= GRID_COLUMNS_PER_PLAYER;
				
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y+1)) && 
					note.noteData == checkData && 
					note.mustPress == isPlayerNote)
				{
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
		
		var noteStrum:Float = 0;
		if (strum != null) {
			noteStrum = strum;
		} else {
			final mouseYInGrid:Float = FlxG.mouse.y - gridBG.y;
			final gridHeight:Float = gridBG.height;
			final relativePosition:Float = Math.max(0, Math.min(mouseYInGrid / gridHeight, 1));
			
			final currentBeats:Float = getSectionBeats(curSec);
			final currentSectionLength:Float = currentBeats * (1000 * 60 / _song.bpm);
			
			noteStrum = sectionStartTime() + relativePosition * currentSectionLength;
		}
		
		var noteData:Int = 0;
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
		var daType = type ?? currentType;
		
		var noteTypeString = (daType > 0 && daType < curNoteTypes.length) ? curNoteTypes[daType] : "";

		if (data != null) noteData = data;

		if(noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([
				noteStrum, 
				noteData,
				noteSus, 
				noteTypeString
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
			var mirroredData = noteData >= GRID_COLUMNS_PER_PLAYER ? noteData - GRID_COLUMNS_PER_PLAYER : noteData + GRID_COLUMNS_PER_PLAYER;
			_song.notes[curSec].sectionNotes.push([noteStrum, mirroredData, noteSus, noteTypeString]);
		}

		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
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
		
		var beats:Float = getSectionBeats();
		var totalTime = beats * Conductor.stepCrochet * GRID_COLUMNS_PER_PLAYER;
		
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, totalTime);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}
	
	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
	{
		var totalTime = beats * Conductor.stepCrochet * GRID_COLUMNS_PER_PLAYER;
		var value:Float = strumTime / totalTime;
		return GRID_SIZE * beats * GRID_COLUMNS_PER_PLAYER * zoomList[curZoom] * value + gridBG.y;
	}

	function copyNote(note:MetaNote):Void
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

		selectedNotes.resize(0);
		
		updateGrid();
	}

	function pasteNote():Void
	{
		if (clipboardNotes == null || clipboardNotes.length == 0) {
			FlxG.log.add("Clipboard is empty");
			return;
		}
		
		saveToUndo();
		
		var startSec:Int = findSectionForTime(Conductor.songPosition);
		if (startSec < 0) startSec = curSec;
		
		final sectionStartTime:Float = cachedSectionTimes[startSec];
		final timeShift:Float = Conductor.songPosition - clipboardNotes[0][0];
		
		for (noteData in clipboardNotes)
		{
			var newData = noteData.copy();
			newData[0] += timeShift;
			
			var targetSec:Int = findSectionForTime(newData[0]);
			if (targetSec != startSec) {
				var originalSectionTime:Float = noteData[0] - cachedSectionTimes[findSectionForTime(noteData[0])];
				var originalSectionBeats:Float = getSectionBeats(findSectionForTime(noteData[0]));
				
				var targetSectionBeats:Float = getSectionBeats(startSec);
				var newSectionTime:Float = (originalSectionTime / originalSectionBeats) * targetSectionBeats;
				
				newData[0] = sectionStartTime + newSectionTime * (1000 * 60 / _song.bpm);
				targetSec = findSectionForTime(newData[0]);
			}
			
			if (Std.isOfType(newData[1], Array))
			{
				_song.events.push(newData);
			}
			else
			{
				if (targetSec >= 0 && targetSec < _song.notes.length)
					_song.notes[targetSec].sectionNotes.push(newData);
				else
					_song.notes[startSec].sectionNotes.push(newData);
			}
		}
		
		updateGrid();
		trace("Pasted " + clipboardNotes.length + " notes");
	}

	function reassignNotesBetweenSections(changedSection:Int):Void {
		_cacheSections();
		
		var notesToRedistribute:Array<Dynamic> = [];
		for (i in changedSection..._song.notes.length) {
			if (_song.notes[i]?.sectionNotes != null) {
				for (note in _song.notes[i].sectionNotes) {
					if (note != null) {
						notesToRedistribute.push(note);
					}
				}
				_song.notes[i].sectionNotes = [];
			}
		}
		
		if (notesToRedistribute.length > 0) {
			notesToRedistribute.sort((a, b) -> {
				if (a == null || b == null) return 0;
				return Reflect.compare(a[0], b[0]);
			});
		}
		
		for (note in notesToRedistribute) {
			if (note == null) continue;
			
			var noteTime:Float = note[0];
			var targetSection = findSectionForTime(noteTime);
			if (targetSection >= 0 && targetSection < _song.notes.length) {
				if (_song.notes[targetSection] == null) {
					_song.notes[targetSection] = {
						sectionBeats: 4,
						bpm: _song.bpm,
						changeBPM: false,
						mustHitSection: false,
						gfSection: false,
						sectionNotes: [],
						typeOfSection: 0,
						altAnim: false
					};
				}
				
				_song.notes[targetSection].sectionNotes ??= [];
				_song.notes[targetSection].sectionNotes.push(note);
			}
		}
		
		for (section in _song.notes) {
			if (section?.sectionNotes != null) {
				section.sectionNotes = section.sectionNotes.filter(function(note):Bool {
					return note != null;
				});
				
				if (section.sectionNotes.length > 1) {
					section.sectionNotes.sort((a, b) -> {
						if (a == null || b == null) return 0;
						return Reflect.compare(a[0], b[0]);
					});
				}
			}
		}
	}

	function findSectionForTime(time:Float):Int {
		if (_song.notes == null || _song.notes.length == 0) return 0;
		
		for (i in 0..._song.notes.length) {
			final sectionStart = cachedSectionTimes[i];
			final sectionEnd = cachedSectionTimes[i + 1];
			
			final epsilon:Float = 0.001;
			if (time >= sectionStart - epsilon && time < sectionEnd - epsilon) {
				return i;
			}
		}
		
		return _song.notes.length - 1;
	}

	function updateSelectionBox()
	{
		if (selecting && isMouseDown) {
			selectBox.visible = true;
			selectBoxOutline.visible = true;
			
			var mousePos = FlxG.mouse.getWorldPosition();
			var width = mousePos.x - selectStart.x;
			var height = mousePos.y - selectStart.y;
			
			if (Math.abs(width) > 1 || Math.abs(height) > 1)
			{
				selectBox.scale.set(Math.abs(width), Math.abs(height));
				selectBox.updateHitbox();
				selectBox.x = width < 0 ? mousePos.x : selectStart.x;
				selectBox.y = height < 0 ? mousePos.y : selectStart.y;

				updateSelectBoxOutline(selectBox.x, selectBox.y, Math.abs(width), Math.abs(height));
			}
			else
			{
				selectBox.visible = false;
				selectBoxOutline.visible = false;
			}
		}
	}

	function updateSelectBoxOutline(x:Float, y:Float, width:Float, height:Float):Void 
	{
		var outlineWidth = Std.int(width + 2);
		var outlineHeight = Std.int(height + 2);
		
		selectBoxOutline.makeGraphic(outlineWidth, outlineHeight, FlxColor.TRANSPARENT, true);
		
		selectBoxOutline.pixels.fillRect(new Rectangle(0, 0, outlineWidth, 1), FlxColor.BLUE);
		selectBoxOutline.pixels.fillRect(new Rectangle(0, outlineHeight-1, outlineWidth, 1), FlxColor.BLUE);
		selectBoxOutline.pixels.fillRect(new Rectangle(0, 0, 1, outlineHeight), FlxColor.BLUE);
		selectBoxOutline.pixels.fillRect(new Rectangle(outlineWidth-1, 0, 1, outlineHeight), FlxColor.BLUE);
		
		selectBoxOutline.x = x - 1;
		selectBoxOutline.y = y - 1;
	}

	private function copySingleNote(note:MetaNote):Void
	{
		var noteData = getNoteData(note);
		if (noteData != null) clipboardNotes.push(noteData);
	}

	private function getNoteData(note:MetaNote):Array<Dynamic>
	{
		if (note.songData != null) {
			return note.songData.copy();
		}
		
		if (note.chartNoteData > -1) {
			return [
				note.strumTime,
				note.chartNoteData,
				note.sustainLength,
				note.noteType ?? ""
			];
		} else {
			return [
				note.strumTime,
				note.songData[1]
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

	function loadJson(chartName:String, songName:String):Void
	{
		try {
			trace('Loading chart: $chartName for song: $songName');
			
			PlayState.SONG = Song.loadFromJson(chartName, songName);
			
			_song = PlayState.SONG;
			currentSongName = Paths.formatToSongPath(_song.song);
			
			FlxG.resetState();
		} catch (e:Dynamic) {
			trace("Error loading chart: " + e + " | Stack: " + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			
			openSubState(new Prompt('Failed to load chart: $chartName\n\nSong: $songName\n\nError: ${Std.string(e)}', 1, 
				() -> closeSubState(), null, false, "OK", null));
		}
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	private function saveChart()
	{
		 if(_song.events?.length > 1) {
			_song.events = _song.events.filter(function(event):Bool {
				return event != null;
			});
			_song.events.sort(sortByTime);
		}

		_song.version = Song.CHART_VERSION.toString();
		
		Reflect.deleteField(_song, "format");
		Reflect.deleteField(_song, "offset");
		
		var json = {
			"song": _song
		};

		final data:String = Json.stringify(json, "\t");
		if (data?.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
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
		if(_song.events?.length > 1) {
			_song.events = _song.events.filter(function(event):Bool {
				return event != null;
			});
			_song.events.sort(sortByTime);
		}

		var eventsSong:Dynamic = {
			events: _song.events
		};
		var json = {
			"song": eventsSong
		}

		final data:String = Json.stringify(json, "\t");
		if (data?.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
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
		FlxG.log.error("Problem saving Level data");
	}

	function getSectionBeats(?section:Null<Int> = null):Float
	{
		if (_song == null || _song.notes == null) return 4;
		
		section ??= curSec;
		
		if (section < 0 || section >= _song.notes.length) return 4;
		
		var sec = _song.notes[section];
		if (sec == null) return 4;
		
		return sec.sectionBeats ?? 4;
	}

	private function _cacheSections()
	{
		cachedSectionTimes = [];
		if (_song == null || _song.notes == null || _song.notes.length == 0) {
			cachedSectionTimes[0] = 0;
			return;
		}
		
		var time:Float = 0;
		var bpm:Float = _song.bpm;
		
		for (i in 0..._song.notes.length)
		{
			var section = _song.notes[i];
			if(section == null) {
				cachedSectionTimes[i] = time;
				continue;
			}
			
			if(section.changeBPM && section.bpm > 0)
				bpm = section.bpm;
				
			cachedSectionTimes[i] = time;
			time += (getSectionBeats(i) * (1000 * 60 / bpm));
		}
		cachedSectionTimes[_song.notes.length] = time;
	}

	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function updateWaveform() {
		#if (lime_cffi && !macro)
		var shouldShowWaveform = chartEditorSave.data.chart_waveformInst || 
                           chartEditorSave.data.chart_waveformVoices || 
                           chartEditorSave.data.chart_waveformOppVoices;
    
		if(!shouldShowWaveform || curSec < 0 || curSec >= cachedSectionTimes.length)
		{
			waveform.visible = false;
			return;
		}

		waveform.visible = true;
		waveform.y = gridBG.y;
		var width:Int = Std.int(GRID_SIZE * GRID_COLUMNS_TOTAL);
		var height:Int = Std.int(gridBG.height);
		if(Std.int(waveform.height) != height && waveform?.pixels != null)
		{
			waveform.pixels.dispose();
			waveform.pixels.disposeImage();
			waveform.makeGraphic(width, height, FlxColor.TRANSPARENT);
		}
		waveform.pixels.fillRect(new Rectangle(0, 0, width, height), FlxColor.TRANSPARENT);

		wavData[0][0].resize(0);
		wavData[0][1].resize(0);
		wavData[1][0].resize(0);
		wavData[1][1].resize(0);

		var sound:FlxSound = switch(waveformTarget)
		{
			case INST:
				FlxG.sound.music;
			case PLAYER:
				vocals;
			case OPPONENT:
				opponentVocals;
			case _: null;
		}
		
		if (sound?._sound?.__buffer != null)
		{
			var bytes:Bytes = sound._sound.__buffer.data.toBytes();
			wavData = waveformData(sound._sound.__buffer, bytes, cachedSectionTimes[curSec] - Conductor.offset, cachedSectionTimes[curSec+1] - Conductor.offset, 1, wavData, height);
		}

		var waveformColor:FlxColor = waveformColors.exists(waveformTarget) ? waveformColors.get(waveformTarget) : FlxColor.WHITE;

		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);
		var size:Float = 1;

		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (index in 0...length)
		{
			var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			 waveform.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), index * size, (lmin + rmin) + (lmax + rmax), size), waveformColor);
		}
		#else
		waveform.visible = false;
		#end
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

		var simpleSample:Bool = true;
		var v1:Bool = false;

		array ??= [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0)
					if (sample > lmax) lmax = sample;
				else
					if (sample < lmin) lmin = sample;

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

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else
				{
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

	function updateWaveformIfNeeded():Void
	{
		var shouldShowWaveform = chartEditorSave.data.chart_waveformInst || 
							chartEditorSave.data.chart_waveformVoices || 
							chartEditorSave.data.chart_waveformOppVoices;
		
		if(shouldShowWaveform) updateWaveform();
		else waveform.visible = false;
	}

	override function destroy() {
		autoBackupTimer?.cancel();
		autoBackupTimer?.destroy();

		mouseDownPos?.put();

		super.destroy();
	}

}

@:allow(ChartEditorState)
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
			"CTRL + [ / ] - Fine playback speed adjustment\n" +
			"SHIFT - Move faster (3x speed)\n" +
			"CTRL + click - Select/deselect notes\n" +
			"CTRL + C - Copy selected notes\n" +
			"CTRL + V - Paste copied notes\n" +
			"CTRL + Z - Undo\n" +
			"CTRL + Y - Redo\n" +
			"DELETE/CTRL + D - Delete selected notes\n" +
			"Z/X - Zoom in/out\n" +
			"ENTER - Play chart in PlayState\n" +
			"ESCAPE - Play chart in Editor PlayState\n" +
			"Q/E - Decrease/increase note sustain length\n" +
			"SPACE - Pause/resume playback\n" +
			"TAB - Cycle through UI tabs (SHIFT for reverse)\n" +
			"R - Reset section (SHIFT for reset to start)\n" +
			"BACKSPACE - Return to editor menu\n" +
			"RIGHT CLICK - Delete note under cursor\n" +
			"Click + Drag - Select multiple notes\n" +
			"CTRL + SHIFT + A - Select all notes in current section";

		var tipTextArray:Array<String> = text.split('\n');
		var grpTexts:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();
		add(grpTexts);

		// calculate total height for vertical centering --math brouu
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
		
		var closeText:FlxText = new FlxText(0, FlxG.height - (lineHeight - 5), FlxG.width, "Press F1/ESC to close tips", 16);
		closeText.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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

@:allow(ChartEditorState)
class ChartSelectorSubstate extends MusicBeatSubstate
{
	var charts:Array<String> = [];
	var grpCharts:FlxTypedGroup<FlxSprite>;
	var curSelected:Int = 0;
	var scrollOffset:Int = 0;
	var maxVisibleItems:Int = 8;
	var itemHeight:Float = 40;
	var onSelectChart:String->String->Void;
	var currentSong:String;
	var bg:FlxSprite;
	var tipText:FlxText;
	var countText:FlxText;
	var scrollBar:FlxSprite;
	var scrollBarBg:FlxSprite;

	public function new(songName:String, callback:String->String->Void)
	{
		super();
		currentSong = songName;
		onSelectChart = callback;
	}

	override function create()
	{
		super.create();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.8;
		bg.scrollFactor.set();
		add(bg);

		var listBg = new FlxSprite(50, 80).makeGraphic(FlxG.width - 100, FlxG.height - 180, 0xFF202020);
		listBg.alpha = 0.9;
		listBg.scrollFactor.set();
		add(listBg);

		var titleText = new FlxText(0, 30, FlxG.width, 'Select Chart for: "$currentSong"', 28);
		titleText.setFormat(null, 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		grpCharts = new FlxTypedGroup<FlxSprite>();
		add(grpCharts);

		scrollBarBg = new FlxSprite(FlxG.width - 80, 80).makeGraphic(8, Std.int(listBg.height), 0xFF404040);
		scrollBarBg.scrollFactor.set();
		add(scrollBarBg);

		scrollBar = new FlxSprite(FlxG.width - 80, 80).makeGraphic(8, 50, 0xFF888888);
		scrollBar.scrollFactor.set();
		add(scrollBar);

		tipText = new FlxText(0, FlxG.height - 40, FlxG.width, "ENTER to select | ESC to cancel | Mouse Wheel to scroll", 16);
		tipText.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 1.5;
		add(tipText);

		var loadingText = new FlxText(0, FlxG.height / 2 - 10, FlxG.width, "Loading charts...", 20);
		loadingText.setFormat(null, 20, FlxColor.WHITE, CENTER);
		loadingText.screenCenter(X);
		add(loadingText);

		haxe.Timer.delay(() -> {
			remove(loadingText);
			loadChartList();
			updateList();
			updateScrollBar();
		}, 100);
		
		camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
	}

	function loadChartList()
	{
		charts = [];
		
		try {
			final songPath:String = 'data/songs/$currentSong';
			final fullPath:String = Paths.getPreloadPath(songPath);
			
			#if sys
			if (FileSystem.exists(fullPath) && FileSystem.isDirectory(fullPath)) {
				for (file in FileSystem.readDirectory(fullPath)) {
					if (file.endsWith('.json') && file != 'events.json') {
						var chartName = file.substr(0, file.length - 5);
						charts.push(chartName);
					}
				}
			}
			#end
			
			#if MODS_ALLOWED
			var modDirs = [Mods.currentModDirectory];
			for (mod in modDirs) {
				if (mod == null || mod.length == 0) continue;
				
				var modPath = Mods.getModPath('$mod/data/songs/$currentSong');
				if (FileSystem.exists(modPath) && FileSystem.isDirectory(modPath)) {
					for (file in FileSystem.readDirectory(modPath)) {
						if (file.endsWith('.json') && file != 'events.json' && !charts.contains(file.substr(0, file.length - 5))) {
							var chartName = file.substr(0, file.length - 5);
							charts.push(chartName);
						}
					}
				}
			}
			#end
			
			for (file in OpenFlAssets.list(TEXT).filter(f -> f.startsWith('$fullPath/$currentSong'))) {
				if (file.endsWith('.json')) {
					var parts = file.split('/');
					if (parts.length >= 3) {
						var fileName = parts[parts.length - 1];
						if (fileName != 'events.json') {
							var chartName = fileName.substr(0, fileName.length - 5);
							if (!charts.contains(chartName)) {
								charts.push(chartName);
							}
						}
					}
				}
			}
		} catch (e:Dynamic) {
			trace("Error scanning charts: " + e);
		}
		
		charts.sort(function(a, b):Int {
			var difficulties = CoolUtil.defaultDifficulties.map(d -> d.toLowerCase());
			var aIndex = difficulties.indexOf(a.toLowerCase());
			var bIndex = difficulties.indexOf(b.toLowerCase());
			
			if (aIndex >= 0 && bIndex >= 0) return aIndex - bIndex;
			if (aIndex >= 0) return -1;
			if (bIndex >= 0) return 1;
			return Reflect.compare(a.toLowerCase(), b.toLowerCase());
		});
		
		var uniqueCharts:Array<String> = [];
		for (chart in charts) {
			if (!uniqueCharts.contains(chart)) {
				uniqueCharts.push(chart);
			}
		}
		charts = uniqueCharts;
		
		trace('Found ${charts.length} charts for $currentSong: $charts');
	}

	function updateList()
	{
		grpCharts.clear();
		
		if (charts.length == 0) {
			var noChartsText = new FlxText(60, 120, FlxG.width - 120, 'No charts found for: "$currentSong"\n\nMake sure the song folder exists in:\ndata/songs/$currentSong/', 20);
			noChartsText.setFormat(null, 20, 0xFFAAAAAA, LEFT);
			noChartsText.scrollFactor.set();
			add(noChartsText);
			return;
		}
		
		scrollOffset = Std.int(Math.max(0, Math.min(scrollOffset, charts.length - maxVisibleItems)));
		
		final startY:Float = 90;
		final itemWidth:Float = FlxG.width - 140;
		for (i in 0...maxVisibleItems) {
			var index = i + scrollOffset;
			if (index >= charts.length) break;
			
			var chartName = charts[index];
			
			var bgItem = new FlxSprite(60, startY + i * itemHeight).makeGraphic(Std.int(itemWidth), Std.int(itemHeight - 4), 0xFF303030);
			bgItem.scrollFactor.set();
			bgItem.alpha = index == curSelected ? 0.8 : 0.5;
			add(bgItem);
			
			var itemText = new FlxText(70, startY + i * itemHeight + 8, itemWidth - 20, chartName, 14);
			
			if (index == curSelected) {
				itemText.setFormat(null, 14, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				itemText.borderSize = 1.5;
			} else {
				itemText.setFormat(null, 14, FlxColor.WHITE, LEFT);
			}
			
			var iconText = "";
			var iconColor = FlxColor.WHITE;
			
			if (chartName == currentSong) {
				iconText = "[DEFAULT]";
				iconColor = FlxColor.LIME;
			} else if (chartName.toLowerCase().endsWith('-easy')) {
				iconText = "[EASY]";
				iconColor = FlxColor.CYAN;
			} else if (chartName.toLowerCase().endsWith('-normal')) {
				iconText = "[NORMAL]";
				iconColor = FlxColor.YELLOW;
			} else if (chartName.toLowerCase().endsWith('-hard')) {
				iconText = "[HARD]";
				iconColor = FlxColor.RED;
			}
			
			if (iconText.length > 0) {
				var icon = new FlxText(itemWidth - 100, startY + i * itemHeight + 8, 100, iconText, 14);
				icon.setFormat(null, 14, iconColor, RIGHT);
				icon.scrollFactor.set();
				add(icon);
			}
			
			itemText.scrollFactor.set();
			add(itemText);
		}
		
		if (countText != null) remove(countText);
		countText = new FlxText(60, 60, FlxG.width - 120, 
			'Charts: ${curSelected + 1}/${charts.length}  |  Scroll: ${scrollOffset + 1}-${Math.min(scrollOffset + maxVisibleItems, charts.length)}', 14);
		countText.setFormat(null, 14, 0xFFAAAAAA, LEFT);
		countText.scrollFactor.set();
		add(countText);
	}

	function updateScrollBar()
	{
		if (charts.length <= maxVisibleItems) {
			scrollBarBg.visible = false;
			scrollBar.visible = false;
			return;
		}
		
		scrollBarBg.visible = true;
		scrollBar.visible = true;
		
		final scrollableHeight = scrollBarBg.height;
		final thumbHeight = Math.max(30, scrollableHeight * (maxVisibleItems / charts.length));
		final maxScroll = charts.length - maxVisibleItems;
		final scrollRatio = scrollOffset / maxScroll;
		
		scrollBar.setGraphicSize(8, Std.int(thumbHeight));
		scrollBar.updateHitbox();
		scrollBar.y = scrollBarBg.y + scrollRatio * (scrollableHeight - thumbHeight);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (charts.length > 0)
		{
			final oldSelected = curSelected;
			final oldScroll = scrollOffset;
			
			if (controls.UI_UP_P)
				changeSelection(-1);
			if (controls.UI_DOWN_P)
				changeSelection(1);
			
			if (controls.UI_LEFT_P)
				changeSelection(-maxVisibleItems);
			if (controls.UI_RIGHT_P)
				changeSelection(maxVisibleItems);
			
			if (FlxG.mouse.wheel != 0) {
				scrollOffset -= Std.int(FlxG.mouse.wheel);
				scrollOffset = Std.int(Math.max(0, Math.min(scrollOffset, charts.length - maxVisibleItems)));
				if (scrollOffset != oldScroll) {
					updateList();
					updateScrollBar();
				}
			}
			
			if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(scrollBarBg)) {
				var localY = FlxG.mouse.y - scrollBarBg.y;
				var scrollableHeight = scrollBarBg.height - scrollBar.height;
				var scrollRatio = localY / scrollableHeight;
				scrollOffset = Math.round(scrollRatio * (charts.length - maxVisibleItems));
				scrollOffset = Std.int(Math.max(0, Math.min(scrollOffset, charts.length - maxVisibleItems)));
				
				updateList();
				updateScrollBar();
			}
			
			if (controls.ACCEPT) {
				selectCurrent();
			}
			
			if (controls.BACK #if android || FlxG.android.justReleased.BACK #end)
				close();
			
			if (FlxG.mouse.justPressed) {
				for (i in 0...maxVisibleItems) {
					var index = i + scrollOffset;
					if (index >= charts.length) break;
					
					var bgY = 90 + i * itemHeight;
					if (FlxG.mouse.y >= bgY && FlxG.mouse.y < bgY + itemHeight - 4 &&
						FlxG.mouse.x >= 60 && FlxG.mouse.x < 60 + (FlxG.width - 140)) {
						
						curSelected = index;
						selectCurrent();
						break;
					}
				}
			}
			
			if (oldSelected != curSelected || oldScroll != scrollOffset) {
				if (curSelected < scrollOffset) {
					scrollOffset = curSelected;
				} else if (curSelected >= scrollOffset + maxVisibleItems) {
					scrollOffset = curSelected - maxVisibleItems + 1;
				}
				
				if (oldSelected != curSelected || oldScroll != scrollOffset) {
					updateList();
					updateScrollBar();
					if (oldSelected != curSelected) {
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					}
				}
			}
		}
		else
		{
			if (controls.BACK #if android || FlxG.android.justReleased.BACK #end || controls.ACCEPT)
				close();
		}
	}

	function changeSelection(change:Int)
	{
		if (charts.length == 0) return;
		
		curSelected += change;
		
		if (curSelected < 0) curSelected = charts.length - 1;
		if (curSelected >= charts.length) curSelected = 0;
	}

	function selectCurrent()
	{
		if (charts.length == 0) return;
		
		final selectedChart = charts[curSelected];
		onSelectChart(currentSong, selectedChart);
		close();
	}
}