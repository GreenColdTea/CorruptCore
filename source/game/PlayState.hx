package game;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.graphics.FlxGraphic;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxAxes;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.effects.particles.FlxEmitter;
import flixel.effects.particles.FlxParticle;
import flixel.util.FlxSave;

import haxe.Json;
import lime.utils.Assets;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.display.StageQuality;
import openfl.filters.BitmapFilter;
import openfl.events.KeyboardEvent;
import openfl.utils.Assets as OpenFlAssets;

import game.scripting.FunkinLua;

#if HSCRIPT_ALLOWED
import game.scripting.FunkinHScript;
#end

import game.backend.Section.SwagSection;
import game.backend.Rating;
import game.backend.Song.SwagSong;
import game.backend.StageData;

import game.objects.AttachedSprite;
import game.objects.Character;
import game.objects.DialogueBoxPsych;
import game.objects.HealthIcon;
import game.objects.Note;
import game.objects.Note.EventNote;
import game.objects.NoteSplash;
import game.objects.NoteHoldCover;
import game.objects.StrumLine;
import game.objects.StrumNote;

#if VIDEOS_ALLOWED
import game.objects.FunkinVideoSprite;
#end

import game.shaders.*;
import game.shaders.WiggleEffect.WiggleEffectType;

import game.states.backend.Achievements;
import game.states.editors.ChartEditorState;
import game.states.editors.CharacterEditorState;

#if !flash 
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if VIDEOS_ALLOWED
import hxvlc.flixel.FlxVideo;
#end

#if MODCHART_ALLOWED
import game.modchart.*;
import game.modchart.ModManager;
#end

#if target.threaded
import sys.thread.Thread;
#end

using StringTools;

class PlayState extends MusicBeatState
{
	public static final STRUM_X = 42;
	public static final STRUM_X_MIDDLESCROLL = -278;

	private var noteRows:Array<Array<Array<Note>>> = [[],[],[]];

	private var shutdownThread:Bool = false;
	private var gameFroze:Bool = false;
	private var requiresSyncing:Bool = false;
	private var lastCorrectSongPos:Float = -1.0;

	public var videoStartTime:Float = 0;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], // 0-19%
		['Bad', 0.4], // 20-39%
		['Okay', 0.55], // 40-54%
		['Nice', 0.7],  // 55-69%
		['Good', 0.8],  // 70-79%
		['Great', 0.9],  // 80-89%
		['Awesome!', 0.95], // 90-94%
		['Sick!!', 0.98],  // 95-97%
		['Perfect!!!', 1]  // 98-100%
	];

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	public var skipArrowStartTween:Bool = false; //for lua

	public var boyfriendMap:Map<String, Character> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	public var variables:Map<String, Dynamic> = new Map();
	public var cameraShaders:Map<String, FlxRuntimeShader> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartSprites:Map<String, ModchartSprite> = new Map();
	public var runtimeShaders:Map<String, Array<String>> = new Map();
	#if flixel_animate
	public var modchartAnimateSprites:Map<String, ModchartAnimateSprite> = new Map();
	#end
	public var modchartBackdrops:Map<String, ModchartBackdrop> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, ModchartText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();

	private var characterScripts:Map<String, Array<Dynamic>> = new Map();

	#if MODCHART_ALLOWED
	public var modManager:ModManager;
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public static var isPixelStage(default, set):Bool = false;

	public var spawnTime:Float = 2000;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var notesSustains:FlxTypedGroup<Sustain>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	private var strumLine:FlxSprite;

	//Handles the new epic mega sexy cam code that i've done
	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:StrumLine;
	public var playerStrums:StrumLine;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	public var grpHoldCovers:FlxTypedGroup<NoteHoldCover>;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;

	private var curSong:String = "";

	public var gfSpeed:Int = 1;

	@:isVar public var health(default, set):Float = 1;
	public var displayHealth:Float = 1;
	public var combo:Int = 0;

	public var healthBarBG:AttachedSprite;
	public var healthBar:FlxBar;

	public var songPercent(get, never):Float;
	
	public var timeBarBG:AttachedSprite;
	public var timeBar:FlxBar;

	public var ratingsData:Array<Rating> = [];
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;

	private var generatedMusic:Bool = false;
	private var updateTime:Bool = true;
	@:isVar public var endingSong(default, set):Bool = false;
	public var startingSong:Bool = false;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	//botplay text thingie
	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	//health icons
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	//game cameras
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var camPause:FlxCamera;
	public var camSubState:FlxCamera;
	public var cameraSpeed:Float = 1;

	var dialogue:Array<String> = ['blah blah blah', 'coolswag'];
	var dialogueJson:DialogueFile = null;

	//song result properties
	@:isVar public var songScore(default, set):Int = 0;
	@:isVar public var songHits(default, set):Int = 0;
	@:isVar public var songMisses(default, set):Int = 0;

	public var scoreTxt:FlxText;
	public var timeTxt:FlxText;
	private var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	private var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	public static var instance:PlayState;

	// Lua shit
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var luaArray:Array<FunkinLua> = [];

	public var introSoundsSuffix:String = '';

	//Hscript stuff
	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<FunkinHScript> = [];
	#end

	//VideoSprite stuff
	#if VIDEOS_ALLOWED
	var video:FunkinVideoSprite;
	#end

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;

	// Less laggy controls
	private var keysArray:Array<Dynamic>;
	private var controlArray:Array<String>;

	public var songName:String;

	private var curStepText:FlxText;
	private var curBeatText:FlxText;

	private var precacheList:Map<String, String> = new Map<String, String>();
	
	// stores the last judgement object
	public static var lastRating:FlxSprite;
	// stores the last combo sprite object
	public static var lastCombo:FlxSprite;
	// stores the last combo score objects in an array
	public static var lastScore:Array<FlxSprite> = [];

	// Callbacks for game.stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	private static function set_isPixelStage(value:Bool):Bool {
		if (isPixelStage == value) 
			return value;

		isPixelStage = value;
		instance?.updatePixelStage();
		return value;
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
			FlxG.sound.list.forEach((sound:FlxSound) -> if (sound != null) sound.pitch = value);
		
		playbackRate = value;
		FlxG.animationTimeScale = value;
		trace('Anim speed: ' + FlxG.animationTimeScale);
		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000 * value;
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0;
		#end
		return playbackRate;
	}

	function set_health(value:Float):Float {
		if (this.health == value) return value;
		this.health = FlxMath.bound(value, 0, 2);
		if (this.health <= 0 && !practiceMode && !isDead) {
			doDeathCheck(true);
		}
		return this.health;
	}

	function set_songScore(value:Int):Int {
		if (this.songScore == value) return value;
		this.songScore = value;
		updateScore(false);
		return value;
	}

	function set_songMisses(value:Int):Int {
		if (this.songMisses == value) return value;
		this.songMisses = value;
		RecalculateRating(true);
		return value;
	}

	function set_songHits(value:Int):Int {
		if (this.songHits == value) return value;
		this.songHits = value;
		RecalculateRating(false);
		return value;
	}

	function set_totalPlayed(value:Int):Int {
		if (this.totalPlayed == value) return value;
		this.totalPlayed = value;
		RecalculateRating(false);
		return value;
	}

	function set_totalNotesHit(value:Float):Float {
		if (this.totalNotesHit == value) return value;
		this.totalNotesHit = value;
		RecalculateRating(false);
		return value;
	}

	function set_paused(value:Bool):Bool {
		if (this.paused == value) return value;
		this.paused = value;
		if (this.paused) {
			#if VIDEOS_ALLOWED video?.bitmap.pause(); #end
			FlxG.sound.list.forEach(s -> s?.pause());

			FlxTimer.globalManager.forEach(t -> if (!t.finished) t.active = false);
			FlxTween.globalManager.forEach(t -> if (!t.finished) t.active = false);

			callOnScripts('onPause', []);
		} else {
			#if VIDEOS_ALLOWED video?.bitmap.resume(); #end
			FlxG.sound.list.forEach(s -> s?.resume());

			FlxTimer.globalManager.forEach(t -> if (!t.finished) t.active = true);
			FlxTween.globalManager.forEach(t -> if (!t.finished) t.active = true);
			
			if (!startingSong)
				resyncVocals();
			
			callOnScripts('onResume', []);
			runSongSyncThread();
			#if DISCORD_ALLOWED
			if (startTimer?.finished) {
				DiscordClient.changePresence(detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			} else {
				DiscordClient.changePresence(detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
			#end
		}
		return this.paused;
	}

	function set_endingSong(value:Bool):Bool {
		if (this.endingSong == value) return value;
		this.endingSong = value;
		if (value) {
			camZooming = false;
			updateTime = false;
			canPause = false;
			inCutscene = false;
			timeBarBG.visible = false;
			timeBar.visible = false;
			timeTxt.visible = false;
		}
		return value;
	}

	function get_songPercent():Float {
		var curTime = Math.max(0, Conductor.songPosition - ClientPrefs.noteOffset);
		return curTime / songLength;
	}

	override public function create()
	{
		//trace('Playback Rate: ' + playbackRate);

		// for lua
		instance = this;

		startCallback = startCountdown;
		endCallback = endSong;

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));
		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed', 1);

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		controlArray = [
			'NOTE_LEFT',
			'NOTE_DOWN',
			'NOTE_UP',
			'NOTE_RIGHT'
		];

		displayHealth = health;

		//Ratings
		ratingsData.push(new Rating('sick')); //default rating

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.85;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.6;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0.2;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}

		FlxG.sound?.music?.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initFunkinCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camPause = new FlxCamera();
		camSubState = new FlxCamera();

		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		camPause.bgColor.alpha = 0;
		camSubState.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		FlxG.cameras.add(camPause, false);
		FlxG.cameras.add(camSubState, false);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpHoldCovers = new FlxTypedGroup<NoteHoldCover>();

		persistentUpdate = true;
		persistentDraw = true;

		SONG ??= Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		#if DISCORD_ALLOWED
		storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1) {
			SONG.stage = StageData.vanillaSongStage(songName);
		}
		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		//Stage couldn't be found, create a dummy stage for preventing a crash
		stageData ??= {
			directory: "",
			defaultZoom: 0.9,
			isPixelStage: false,

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1
		};

		defaultCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		//Fucks sake should have done it since the start :rolling_eyes:
		boyfriendCameraOffset ??= [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		opponentCameraOffset ??= [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		girlfriendCameraOffset ??= [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		if (Paths.formatToSongPath(SONG.song) != 'tutorial')
			camZooming = true;

		switch (curStage)
		{
			case 'stage': new game.stages.StageWeek1(); //Week 1
			#if INCLUDE_BASE_GAME
			case 'spooky': new game.stages.Spooky(); //Week 2
			case 'philly': new game.stages.Philly(); //Week 3
			case 'limo': new game.stages.Limo(); //Week 4
			case 'mall': new game.stages.Mall(); //Week 5 - Cocoa, Eggnog
			case 'mallEvil': new game.stages.MallEvil(); //Week 5 - Winter Horrorland
			case 'school': new game.stages.School(); //Week 6 - Senpai, Roses
			case 'schoolEvil': new game.stages.SchoolEvil(); //Week 6 - Thorns
			case 'tank': new game.stages.Tank(); //Week 7 - Ugh, Guns, Stress
			#end
		}

		switch(Paths.formatToSongPath(SONG.song))
		{
			case 'stress':
				GameOverSubstate.characterName = 'bf-holding-gf-dead';
		}

		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);

		switch(curStage)
		{
			
		}

		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		add(luaDebugGroup);

		// "GLOBAL" SCRIPTS
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Mods.getModPath('scripts/'));
		if(Mods.currentModDirectory?.length > 0)
			foldersToCheck.insert(0, Mods.getModPath(Mods.currentModDirectory + '/scripts/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Mods.getModPath(mod + '/scripts/'));
		#end

		for (folder in foldersToCheck) {
			#if sys
			if (FileSystem.exists(folder)) {
				final allFiles = FileSystem.readDirectory(folder);

				#if LUA_ALLOWED
				final luaFiles = allFiles.filter(file -> file.endsWith(".lua") && !file.contains("/states/") && !file.contains("/substates/"));
				for (file in luaFiles) {
					if (!filesPushed.contains(file)) {
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
				#end

				#if HSCRIPT_ALLOWED
				final hscriptFiles = allFiles.filter(file -> 
					Lambda.exists(Paths.HSCRIPT_EXTS, ext -> file.endsWith('.$ext')) && !file.contains("/states/") && !file.contains("/substates/")
				);
				for (file in hscriptFiles) {
					if (!filesPushed.contains(file)) {
						hscriptArray.push(new FunkinHScript(folder + file));
						filesPushed.push(file);
					}
				}
				#end
			}
			#end

			final assetFiles = OpenFlAssets.list().filter(f -> f.startsWith(folder));

			#if LUA_ALLOWED
			final luaAssets = assetFiles.filter(file -> file.endsWith(".lua"));
			for (file in luaAssets) {
				final fileName = file.substring(file.lastIndexOf("/") + 1);
				if (!filesPushed.contains(fileName) && !file.contains("/states/") &&
					!file.contains("/substates/")) {
					luaArray.push(new FunkinLua(file));
					filesPushed.push(fileName);
				}
			}
			#end

			#if HSCRIPT_ALLOWED
			final hscriptAssets = assetFiles.filter(file -> Lambda.exists(Paths.HSCRIPT_EXTS, ext -> file.endsWith('.$ext')));
			for (file in hscriptAssets) {
				final fileName = file.substring(file.lastIndexOf("/") + 1);
				if (!filesPushed.contains(fileName) && !file.contains("/states/") &&
					!file.contains("/substates/")) {
					hscriptArray.push(new FunkinHScript(file));
					filesPushed.push(fileName);
				}
			}
			#end
		}

		// STAGE SCRIPTS
		startLuasOnFolder('data/stages/' + curStage + '.lua');
		for (ext in Paths.HSCRIPT_EXTS)
			startHScriptOnFolder('data/stages/' + curStage + '.$ext');

		if (!stageData.hide_girlfriend)
		{
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
			startCharacterScripts(gf.curCharacter);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterScripts(dad.curCharacter);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterScripts(boyfriend.curCharacter);

		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}

		switch(curStage)
		{
			
		}

		var file:String = Paths.json('songs/$songName/dialogue'); //Checks for json/Psych Engine dialogue
		if (OpenFlAssets.exists(file) #if sys || FileSystem.exists(file) #end) {
			dialogueJson = DialogueBoxPsych.parseDialogue(file);
		}

		var file:String = Paths.txt('songs/$songName/${songName}Dialogue'); //Checks for vanilla/Senpai dialogue
		if (OpenFlAssets.exists(file) #if sys || FileSystem.exists(file) #end) {
			dialogue = CoolUtil.coolTextFile(file);
		}

		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;

		strumLine = new FlxSprite(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if(ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.downScroll) timeTxt.y = FlxG.height - 44;
		if(ClientPrefs.timeBarType == 'Song Name') timeTxt.text = SONG.song;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height / 4);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = showTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 200; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		strumLineNotes = new FlxTypedGroup<StrumNote>();

		if(ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		var holdCover:NoteHoldCover = new NoteHoldCover();
		grpHoldCovers.add(holdCover);
		holdCover.alpha = 0.0;

		notesSustains = new FlxTypedGroup<Sustain>();

		generateSong(SONG.song);

		#if MODCHART_ALLOWED
		modManager = new ModManager(this);
		#end

		// After all characters being loaded, it makes then invisible 0.01s later so that the player won't freeze when you change characters
		// add(strumLine);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBarBG = new AttachedSprite('healthBar');
		healthBarBG.y = FlxG.height * 0.89;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !ClientPrefs.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		add(healthBarBG);
		if(ClientPrefs.downScroll) healthBarBG.y = 0.11 * FlxG.height;

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT,
			Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8),
			this, 'displayHealth', 0, 2);
		healthBar.scrollFactor.set();
		// healthBar
		healthBar.visible = !ClientPrefs.hideHud;
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		add(healthBar);
		healthBarBG.sprTracker = healthBar;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.hideHud;
		iconP1.alpha = ClientPrefs.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.hideHud;
		iconP2.alpha = ClientPrefs.healthBarAlpha;
		add(iconP2);
		reloadHealthBarColors();

		scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);

		//for better notes visibility
		add(strumLineNotes);
		add(notesSustains);
		add(notes);
		add(grpNoteSplashes);
		add(grpHoldCovers);

		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		add(botplayTxt);
		if(ClientPrefs.downScroll) {
			botplayTxt.y = timeBarBG.y - 78;
		}

		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		grpHoldCovers.cameras = [camHUD];
		notesSustains.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];

		// if (SONG.song == 'South')
		// FlxG.camera.alpha = 0.7;
		// UI_camera.zoom = 1;

		// cameras = [FlxG.cameras.list[1]];
		startingSong = true;
		
		for (ext in Paths.HSCRIPT_EXTS) {
			for (notetype in noteTypeMap.keys())
			{
				startLuasOnFolder('custom_notetypes/' + notetype + '.lua');
				startHScriptOnFolder('custom_notetypes/' + notetype + '.$ext');
			}
			for (event in eventPushedMap.keys())
			{
				startLuasOnFolder('custom_events/' + event + '.lua');
				startHScriptOnFolder('custom_events/' + event + '.$ext');
			}
		}

		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		// SONG SPECIFIC SCRIPTS
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/songs/' + Paths.formatToSongPath(SONG.song) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Mods.getModPath('data/songs/' + Paths.formatToSongPath(SONG.song) + '/'));
		if(Mods.currentModDirectory?.length > 0)
			foldersToCheck.insert(0, Mods.getModPath(Mods.currentModDirectory + '/data/songs/' + Paths.formatToSongPath(SONG.song) + '/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Mods.getModPath(mod + '/data/songs/' + Paths.formatToSongPath(SONG.song) + '/' ));
		#end

		for (folder in foldersToCheck) {
			#if sys
			if (FileSystem.exists(folder)) {
				final allFiles = FileSystem.readDirectory(folder);
				
				#if LUA_ALLOWED
				final luaFiles = allFiles.filter(file -> file.endsWith(".lua"));
				for (file in luaFiles) {
					if (!filesPushed.contains(file)) {
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
				#end
				
				#if HSCRIPT_ALLOWED
				final hscriptFiles = allFiles.filter(file -> Lambda.exists(Paths.HSCRIPT_EXTS, ext -> file.endsWith("." + ext)));
				for (file in hscriptFiles) {
					if (!filesPushed.contains(file)) {
						hscriptArray.push(new FunkinHScript(folder + file));
						filesPushed.push(file);
					}
				}
				#end
			}
			#end
			
			final assetFiles = OpenFlAssets.list().filter(f -> f.startsWith(folder));
			
			#if LUA_ALLOWED
			final luaAssets = assetFiles.filter(file -> file.endsWith(".lua"));
			for (file in luaAssets) {
				final fileName = file.substring(file.lastIndexOf("/") + 1);
				if (!filesPushed.contains(fileName)) {
					luaArray.push(new FunkinLua(file));
					filesPushed.push(fileName);
				}
			}
			#end
			
			#if HSCRIPT_ALLOWED
			final hscriptAssets = assetFiles.filter(file -> Lambda.exists(Paths.HSCRIPT_EXTS, ext -> file.endsWith("." + ext)));
			for (file in hscriptAssets) {
				final fileName = file.substring(file.lastIndexOf("/") + 1);
				if (!filesPushed.contains(fileName)) {
					hscriptArray.push(new FunkinHScript(file));
					filesPushed.push(fileName);
				}
			}
			#end
		}

		startCallback();
		RecalculateRating();

		// Add curStep and curBeat display
		if (chartingMode) {
			var curStepText = new FlxText(20, 20, 200, "curStep: " + curStep, 20);
			curStepText.setFormat("VCR OSD Mono", 20, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			curStepText.cameras = [camOther];
			curStepText.borderSize = 1.25;
			add(curStepText);

			var curBeatText = new FlxText(20, 50, 200, "curBeat: " + curBeat, 20);
			curBeatText.setFormat("VCR OSD Mono", 20, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			curBeatText.cameras = [camOther];
			curBeatText.borderSize = 1.25;
			add(curBeatText);

			if (!ClientPrefs.downScroll) {
				curStepText.y += 500;
				curBeatText.y += 500;
			}

			// Update this texts in update()
			this.curStepText = curStepText;
			this.curBeatText = curBeatText;
		}

		//PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if(ClientPrefs.hitsoundVolume > 0) precacheList.set('hitsound', 'sound');
		
		for (i in 1...4) precacheList.set('missnote$i', 'sound');

		if (PauseSubState.songName != null) {
			precacheList.set(PauseSubState.songName, 'music');
		} else if(ClientPrefs.pauseMusic != 'None') {
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');
		}

		precacheList.set('alphabet', 'image');
	
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence.
		DiscordClient.changePresence(detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		
		stagesFunc((stage:BaseStage) -> stage.createPost());
		callOnScripts('onCreatePost');

		cacheCountdown();
		cachePopUpScore();
		for (key => type in precacheList)
		{
			//trace('Key $key is type $type');
			switch(type)
			{
				case 'image':
					Paths.image(key);
				case 'sound':
					Paths.sound(key);
				case 'music':
					Paths.music(key);
			}
		}
		
		super.create();
	}

	public function addTextToDebug(text:String, color:FlxColor) {
		luaDebugGroup.forEachAlive((spr:DebugLuaText) -> spr.y += 20);

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup, color));
	}

	public function reloadHealthBarColors() {
		healthBar.createFilledBar(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));

		healthBar.updateBar();

		callOnScripts("onHealthBarColorUpdate", null);
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		function addScript(scriptPath:String, scriptArray:Array<Dynamic>, createScript:String->Dynamic):Void {
			var finalPath:String = null;
			#if MODS_ALLOWED
			var modPath = Mods.modFolders(scriptPath);
			if (FileSystem.exists(modPath)) {
				finalPath = modPath;
			} 
			else 
			#end
			{
				finalPath = Paths.getPreloadPath(scriptPath);
				if (#if sys !FileSystem.exists(finalPath) || #end !OpenFlAssets.exists(finalPath)) finalPath = null;
			}

			if (finalPath == null) return;

			for (script in scriptArray)
				if (script.scriptName == finalPath) return;

			var newScript = createScript(finalPath);
			scriptArray.push(newScript);

			var scripts = characterScripts.get(name);
			if (scripts == null) {
				scripts = [];
				characterScripts.set(name, scripts);
			}
			
			scripts.push(newScript);
		}

		#if LUA_ALLOWED
		addScript('data/characters/$name.lua', luaArray, (path) -> new FunkinLua(path));
		#end
		#if HSCRIPT_ALLOWED
		for (ext in Paths.HSCRIPT_EXTS)
			addScript('data/characters/$name.$ext', hscriptArray, (path) -> new FunkinHScript(path));
		#end
	}

	function removeCharacterScripts(characterName:String):Void 
	{
		final scripts = characterScripts.get(characterName);
		if (scripts == null) return;

		for (script in scripts) {
			if (Std.isOfType(script, FunkinLua)) {
				luaArray.remove(cast script);
			} else if (Std.isOfType(script, FunkinHScript)) {
				hscriptArray.remove(cast script);
			}
			script.stop();
		}
		characterScripts.remove(characterName);
	}

	public function getLuaObject(tag:String, text:Bool = true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		#if flixel_animate
		if(modchartAnimateSprites.exists(tag)) return modchartAnimateSprites.get(tag);
		#end
		if(modchartBackdrops.exists(tag)) return modchartBackdrops.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		if(variables.exists(tag)) return variables.get(tag);
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function playVideo(name:String, isNotMidPartSong:Bool = false)
	{
		#if VIDEOS_ALLOWED
		inCutscene = isNotMidPartSong;
		canPause = !isNotMidPartSong;

		var filePath = (name.startsWith("https://") ? name : Paths.video(name));
		
		var fileExists = #if sys FileSystem.exists(filePath) || #end OpenFlAssets.exists(filePath) || name.startsWith("https://");
		
		if(!fileExists) {
			FlxG.log.warn('Couldnt find video file: $name');
			if(isNotMidPartSong) startAndEnd();
			return;
		}

		video = new FunkinVideoSprite(0, 0, true);
		video.antialiasing = ClientPrefs.globalAntialiasing;
		video.cameras = [camOther];
		add(video);

		video.onFormat(() -> {
			video.setGraphicSize(0, FlxG.height);
			video.updateHitbox();
			video.screenCenter(FlxAxes.X);
		});

		video.onEnd(() -> {
			callOnScripts('onVideoCompleted', [name]);
			canPause = true;
			
			if(isNotMidPartSong) startAndEnd();
		});

		if(video.loadVideo(filePath)) {
			video.playDelayed();
			videoStartTime = Conductor.songPosition;
		} else {
			FlxG.log.warn('Failed to load video: $name');
			if(isNotMidPartSong) startAndEnd();
		}
		#else
		FlxG.log.warn('Platform not supported!');
		if(isNotMidPartSong) startAndEnd();
		#end
	}

	function startAndEnd()
	{
		if(endingSong) endSong();
		else startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = () -> {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = () -> {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		introAssets.set('default', ['ready', 'set', 'go']);
		introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

		var introAlts:Array<String> = introAssets.get('default');
		if (isPixelStage) introAlts = introAssets.get('pixel');
		
		for (asset in introAlts)
			Paths.image(asset);
		
		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if(ret != ScriptResult.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			#if MODCHART_ALLOWED
			modManager.registerDefaultModifiers();
			#end

			final keysAmount:Int = 4;
			final strumLineX:Float = ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
			final strumLineY:Float = ClientPrefs.downScroll ? (FlxG.height - 150) : 50;

			opponentStrums = new StrumLine(strumLineX, strumLineY, 0, keysAmount, ClientPrefs.downScroll);
			playerStrums = new StrumLine(strumLineX + (FlxG.width / 2), strumLineY, 1, keysAmount, ClientPrefs.downScroll);

			for (i in 0...playerStrums.members.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.members.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
			}

			#if MODCHART_ALLOWED
			Modcharts.loadModchart(modManager, SONG.song);
			#end

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', null);

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				introAssets.set('default', ['ready', 'set', 'go']);
				introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

				var introAlts:Array<String> = introAssets.get('default');
				var antialias:Bool = ClientPrefs.globalAntialiasing;
				if(isPixelStage) {
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
					case 1:
						countdownReady = new FlxSprite().loadGraphic(Paths.image(introAlts[0]));
						countdownReady.cameras = [camHUD];
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (PlayState.isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * daPixelZoom));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						insert(members.indexOf(notes), countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownReady);
								countdownReady.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
					case 2:
						countdownSet = new FlxSprite().loadGraphic(Paths.image(introAlts[1]));
						countdownSet.cameras = [camHUD];
						countdownSet.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * daPixelZoom));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						insert(members.indexOf(notes), countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownSet);
								countdownSet.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
					case 3:
						countdownGo = new FlxSprite().loadGraphic(Paths.image(introAlts[2]));
						countdownGo.cameras = [camHUD];
						countdownGo.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * daPixelZoom));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						insert(members.indexOf(notes), countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownGo);
								countdownGo.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
					case 4:
				}

				notes.forEachAlive(function(note:Note) {
					if(ClientPrefs.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if(ClientPrefs.middleScroll && !note.mustPress) {
							note.alpha *= 0.35;
						}
					}
				});
				stagesFunc((stage:BaseStage) -> stage.countdownTick(swagCounter));
				callOnScripts('onCountdownTick', [swagCounter]);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	public function addBehindGF(obj:FlxObject)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxObject)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad (obj:FlxObject)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				invalidateNote(daNote);

				unspawnNotes.splice(i, 1);
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				invalidateNote(daNote);
			}
			--i;
		}
	}

	public function updateScore(miss:Bool = false)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == ScriptResult.Function_Stop) return;

		scoreTxt.text = 'Score: ' + songScore
		+ ' | Misses: ' + songMisses
		+ ' | Rating: ' + ratingName
		+ (ratingName != '?' ? ' (${Highscore.floorDecimal(ratingPercent * 100, 2)}%) - $ratingFC' : '');

		if(ClientPrefs.scoreZoom && !miss && !cpuControlled)
		{
			scoreTxtTween?.cancel();
			scoreTxt.scale.x = 1.075;
			scoreTxt.scale.y = 1.075;
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: (_) -> scoreTxtTween = null
			});
		}
		callOnScripts('onUpdateScore', [miss]);
	}

	public function setSongTime(time:Float)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();

		FlxG.sound.music.time = time - Conductor.offset;
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.play();

		if (Conductor.songPosition < vocals.length)
		{
			vocals.time = time - Conductor.offset;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
			vocals.play();
		}
		else vocals.pause();

		if (Conductor.songPosition < opponentVocals.length)
		{
			opponentVocals.time = time - Conductor.offset;
			#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
			opponentVocals.play();
		}
		else opponentVocals.pause();

		Conductor.songPosition = time;
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();

		vocals.onComplete = () -> {
			if (vocals != null) {
				vocals.stop();
				vocals.volume = 0;
			}
		};

		opponentVocals.onComplete = () -> {
			if (opponentVocals != null) {
				opponentVocals.stop();
				opponentVocals.volume = 0;
			}
		};

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		camZoomingOnSection = true;

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');

		runSongSyncThread();
	}

	var debugNum:Int = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		final songData = SONG;
		Conductor.changeBPM(songData.bpm);

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.load(playerVocals ?? Paths.voices(songData.song));
				
				var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if(oppVocals != null) opponentVocals.load(oppVocals);
			}
		}
		catch(e:Dynamic) {}

		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		#if FLX_PITCH
		FlxG.sound.list.forEach((sound:FlxSound) -> if (sound != null) sound.pitch = playbackRate);
		#end

		inst = new FlxSound();
		try {
			inst.load(Paths.inst(songData.song));
		}
		catch(e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;
		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped
		var oldNote:Note = null;
		var daBpm:Float = Conductor.bpm;

		var songName:String = Paths.formatToSongPath(SONG.song);
		var file:String = Paths.json('songs/$songName/events');
		try {
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:EventNote = {
						strumTime: newEventNote[0] + ClientPrefs.noteOffset,
						event: newEventNote[1],
						value1: newEventNote[2],
						value2: newEventNote[3]
					};
					subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		} 
		catch (e) {}

		for (section in noteData)
		{
			if (section.changeBPM && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i in 0...section.sectionNotes.length)
			{
				final songNotes:Array<Dynamic> = section.sectionNotes[i];

				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var holdLength:Float = songNotes[2];

				var gottaHitNote:Bool = (songNotes[1] >= 4);

				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = holdLength;
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.row = Conductor.secsToRow(daStrumTime);
				swagNote.noteType = !Std.isOfType(songNotes[3], String) ? game.states.editors.ChartEditorState.noteTypeList[songNotes[3]] : songNotes[3];

				var idx = swagNote.gfNote ? 2 : gottaHitNote ? 0 : 1;
				noteRows[idx][swagNote.row] ??= [];

				noteRows[idx][swagNote.row].push(swagNote);

				swagNote.scrollFactor.set();
				
				unspawnNotes.push(swagNote);

				if(swagNote.sustainLength > 0) 
				{
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
					var sustainNote:Note = new Note(daStrumTime, daNoteData, oldNote, true);
					sustainNote.mustPress = swagNote.mustPress;
					sustainNote.gfNote = swagNote.gfNote;
					sustainNote.noteType = swagNote.noteType;
					sustainNote.scrollFactor.set();
					sustainNote.parent = swagNote;
					
					sustainNote.sustainLength = swagNote.sustainLength; 

					unspawnNotes.push(sustainNote);
					swagNote.tail.push(sustainNote);

					if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
					else if(ClientPrefs.middleScroll)
					{
						sustainNote.x += 310;
						if(daNoteData > 1) //Up and Right
						{
							sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.middleScroll)
				{
					swagNote.x += 310;
					if(daNoteData > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}

				if(!noteTypeMap.exists(swagNote.noteType)) {
					noteTypeMap.set(swagNote.noteType, true);
				}

				oldNote = swagNote;
			}
			daBeats += 1;
		}
		for (event in songData.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				var subEvent:EventNote = {
					strumTime: newEventNote[0] + ClientPrefs.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}
		}

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);
		if(eventNotes.length > 1) { //No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);
		}
		checkEventNote();
		generatedMusic = true;
	}

	function eventPushed(event:EventNote) {
		switch(event.event) {
			case 'Change Character':
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event.value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				precacheList.set(event.value1, 'sound'); //Precache sound
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		if(!eventPushedMap.exists(event.event)) {
			eventPushedMap.set(event.event, true);
		}
	}

	function eventNoteEarlyTrigger(event:EventNote):Float {
		var returnedValue:Float = callOnScripts('eventEarlyTrigger', [event.event]);
		if(returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	override function openSubState(SubState:FlxSubState) {
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
    	super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused) paused = false;
		
		super.closeSubState();
	}

	override public function onFocus():Void
	{
		shutdownThread = false;
		runSongSyncThread();

		#if DISCORD_ALLOWED
		if (health > 0 && !paused && FlxG.autoPause)
		{
			if (Conductor.songPosition > 0.0)
			{
				DiscordClient.changePresence(detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
			}
			else
			{
				DiscordClient.changePresence(detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
		}
		#end

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		shutdownThread = true;

		#if DISCORD_ALLOWED
		if (health > 0 && !paused && iconP2 != null && FlxG.autoPause)
		{
			final songName:String = SONG.song != null ? SONG.song.replace("-", " ") : "";
			DiscordClient.changePresence(detailsPausedText, songName, iconP2.getCharacter());
		}
		#end

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		//trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else voc.pause();
		}
	}

	@:isVar public var paused(default, set):Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var freezeCamera:Bool = false;
	var canPause:Bool = true;

	override public function update(elapsed:Float)
	{
		/*if (FlxG.keys.justPressed.NINE)
		{
			iconP1.swapOldIcon();
		}*/
		if (chartingMode) {
			if (curStepText != null) curStepText.text = "curStep: " + curStep;
			if (curBeatText != null) curBeatText.text = "curBeat: " + curBeat;
		}
		callOnScripts('onUpdate', [elapsed]);

		switch (curStage)
		{
			
		}

		if(!inCutscene && !paused && !freezeCamera) {
			FlxG.camera.followLerp = 0.044 * cameraSpeed * playbackRate;
			if(!startingSong && !endingSong && boyfriend.getAnimationName().startsWith('idle')) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		} else FlxG.camera.followLerp = 0;

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if(botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			final ret:Dynamic = callOnScripts('onPause', [], false);
			if(ret != ScriptResult.Function_Stop)
				openPauseMenu();
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
		{
			openChartEditor();
		}

		//for health bar smoothing
		displayHealth = FlxMath.lerp(displayHealth, health, 0.1 * playbackRate);
		if (health >= 2) displayHealth = 2;

		iconP1.updateIconScale(elapsed);
		iconP2.updateIconScale(elapsed);

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(displayHealth, 0, 2, 100, 0) * 0.01)) + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(displayHealth, 0, 2, 100, 0) * 0.01)) - (150 * iconP2.scale.x) / 2 - iconOffset * 2;

		iconP1.animation.curAnim.curFrame = healthBar.percent < 20 ? 1 : 0;
		iconP2.animation.curAnim.curFrame = healthBar.percent > 80 ? 1 : 0;

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene) {
			FlxG.camera.followLerp = 0;
			persistentUpdate = false;
			paused = true;
			canResync = false;
			cancelMusicFadeTween();
			FlxG.switchState(() -> new CharacterEditorState(dad?.curCharacter ?? SONG.player2));
		}

		if (startedCountdown && !paused)
		{
			if (startingSong)
			{
				Conductor.songPosition += elapsed * 1000 * playbackRate;
			}
			else
			{
				if (FlxG.sound.music?.playing)
					Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
				else
					Conductor.songPosition += elapsed * 1000 * playbackRate;

				if (Conductor.songPosition >= Conductor.offset)
				{
					Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));

					final timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
					if (timeDiff > 1000 * playbackRate)
						Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
				}
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.noteOffset);
			var songCalc:Float = (songLength - curTime);
			if(ClientPrefs.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if(secondsTotal < 0) secondsTotal = 0;

			if(ClientPrefs.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}

		#if MODCHART_ALLOWED
		modManager.updateTimeline(curDecStep);
		modManager.update(elapsed);
		#end

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				if (dunceNote.isSustainNote)
				{
					dunceNote.visible = false;
					
					final sustain = new Sustain(dunceNote);
					dunceNote.holdNote = sustain;
					notesSustains.add(sustain);
				}

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		#if MODCHART_ALLOWED
		opponentStrums?.forEachAlive((strum:StrumNote) ->
		{
			var pos = modManager.getPos(0, 0, 0, curDecBeat, strum.noteData, 1, strum, [], strum.vec3Cache);
			modManager.updateObject(curDecBeat, strum, pos, 1);
			strum.x = pos.x;
			strum.y = pos.y;
		});

		playerStrums?.forEachAlive((strum:StrumNote) ->
		{
			var pos = modManager.getPos(0, 0, 0, curDecBeat, strum.noteData, 0, strum, [], strum.vec3Cache);
			modManager.updateObject(curDecBeat, strum, pos, 0);
			strum.x = pos.x;
			strum.y = pos.y;
		});

		/*grpNoteSplashes?.forEachAlive((splash:NoteSplash) -> {
			if (splash.babyArrow != null) {
				var player:Int = -1;
				if (playerStrums.members.contains(splash.babyArrow)) player = 0;
				else if (opponentStrums.members.contains(splash.babyArrow)) player = 1;
				
				if (player != -1) {
					var pos = modManager.getPos(0, 0, 0, curDecBeat, splash.noteData, player, splash, [], splash.vec3Cache);
					modManager.updateObject(curDecBeat, splash, pos, player);
					splash.x = pos.x;
					splash.y = pos.y;
				}
			}
		});*/

		grpHoldCovers?.forEachAlive((cover:NoteHoldCover) -> {
			if (cover.curNote != null) {
				var player = cover.curNote.mustPress ? 0 : 1;
				var pos = modManager.getPos(0, 0, 0, curDecBeat, cover.curNote.noteData, player, cover, [], cover.vec3Cache);
				modManager.updateObject(curDecBeat, cover, pos, player);
				cover.x = pos.x;
				cover.y = pos.y;
			}
		});
		#end

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled) {
					keyShit();
				} else {
					playerDance();
				}

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						notes.forEachAlive(function(daNote:Note)
						{
							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if(!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = null;
							if (daNote.noteData >= 0 && daNote.noteData < strumGroup.length)
								strum = strumGroup.members[daNote.noteData];

							if (strum == null) return; // Skip this note if the strum is missing

							var strumX:Float = strumGroup.members[daNote.noteData].x;
							var strumY:Float = strumGroup.members[daNote.noteData].y;
							var strumAngle:Float = strumGroup.members[daNote.noteData].angle;
							var strumDirection:Float = strumGroup.members[daNote.noteData].direction;
							var strumAlpha:Float = strumGroup.members[daNote.noteData].alpha;
							var strumScroll:Bool = strumGroup.members[daNote.noteData].downScroll;

							@:privateAccess
							var strumDirSin:Float = strumGroup.members[daNote.noteData]._dirSin;

							@:privateAccess
							var strumDirCos:Float = strumGroup.members[daNote.noteData]._dirCos;
							
							strumX += daNote.offsetX;
							strumY += daNote.offsetY;
							strumAngle += daNote.offsetAngle;
							strumAlpha *= daNote.multAlpha;

							final pN:Int = daNote.mustPress ? 0 : 1;
							var hasMods:Bool = false;
							#if MODCHART_ALLOWED
							final revMod = cast(modManager.get('reverse'), game.modchart.modifiers.ReverseModifier);
							if (revMod != null)
								strumScroll = revMod.getReverseValue(daNote.noteData, pN) >= 0.5;

							var pos = modManager.getPos(daNote.strumTime, modManager.getVisPos(Conductor.songPosition, daNote.strumTime, songSpeed, daNote.multSpeed),
								daNote.strumTime - Conductor.songPosition, curDecBeat, daNote.noteData, pN, daNote, [], daNote.vec3Cache);
							
							modManager.updateObject(curDecBeat, daNote, pos, pN);

							pos.x += daNote.offsetX;
							pos.y += daNote.offsetY;
							daNote.x = pos.x;
							daNote.y = pos.y;

							hasMods = modManager.activeMods[pN].length > 0;
							if (hasMods)
							{
								daNote.copyX = false;
								daNote.copyY = false;
							}

							if (daNote.isSustainNote)
							{
								var futureSongPos = Conductor.songPosition + 75;
								var diff = daNote.strumTime - futureSongPos;
								var vDiff = modManager.getVisPos(futureSongPos, daNote.strumTime, songSpeed, daNote.multSpeed);

								var nextPos = modManager.getPos(daNote.strumTime, vDiff, diff, Conductor.getStep(futureSongPos) / 4, daNote.noteData, pN, daNote, [],
									daNote.vec3Cache);
								nextPos.x += daNote.offsetX;
								nextPos.y += daNote.offsetY;
								var diffX = (nextPos.x - pos.x);
								var diffY = (nextPos.y - pos.y);
								var rad = Math.atan2(diffY, diffX);
								var deg = rad * (180 / Math.PI);

								daNote.mAngle = (deg != 0 ? deg + 90 : 0);

								if (daNote.animation?.curAnim?.name.endsWith('end') && hasMods)
								{
									final reverseMod = cast(modManager.get('reverse'), game.modchart.modifiers.ReverseModifier);
									if (reverseMod != null)
									{
										final shouldFlip = reverseMod.getReverseValue(daNote.noteData, pN) >= 0.5;
										if (daNote.flipX != shouldFlip)
											daNote.flipX = shouldFlip;
									}
								}
							}
							#end

							daNote.distance = (0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed * daNote.multSpeed);
							
							if (daNote.isSustainNote && daNote.wasGoodHit)
								daNote.distance = Math.min(0, daNote.distance);

							if (!strumScroll)
								daNote.distance *= -1;

							if (daNote.copyAngle)
								daNote.angle = strumDirection - 90 + strumAngle;

							if(daNote.copyAlpha)
								daNote.alpha = strumAlpha;

							if(daNote.copyX)
								daNote.x = strumX + strumDirCos * daNote.distance;

							if(daNote.copyY)
							{
								daNote.y = strumY + daNote.correctionOffset + strumDirSin * daNote.distance;
							}

							if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote) {
								opponentNoteHit(daNote);
							}

							if (daNote.mustPress) {
								if (cpuControlled && daNote.canBeHit && !daNote.wasGoodHit && !daNote.blockHit) {
									if (daNote.strumTime <= Conductor.songPosition) {
										goodNoteHit(daNote);
									}
								}
								
								if (daNote.isSustainNote && daNote.wasGoodHit && !daNote.ignoreNote) {
									final isHeld:Bool = cpuControlled ? true : getControl(controlArray[daNote.noteData]);
									
									var noteEndTime:Float = daNote.strumTime;
									if (daNote.parent != null) {
										noteEndTime = daNote.parent.strumTime + daNote.parent.sustainLength;
									} else if (daNote.sustainLength > 0) {
										noteEndTime = daNote.strumTime + daNote.sustainLength;
									}

									final char:Character = daNote.gfNote ? gf : boyfriend;
									
									if (!isHeld && Conductor.songPosition <= noteEndTime) {
										daNote.wasGoodHit = false;
										vocals.volume = 0;

										final strum = playerStrums.members[daNote.noteData];
										if (NoteHoldCover.activeCovers.exists(strum))
											NoteHoldCover.activeCovers.get(strum).finishCover();
										
										if (char?.hasMissAnimations) {
											final daAlt = (daNote.noteType == 'Alt Animation') ? '-alt' : '';
											final animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daAlt;
											char.playAnim(animToPlay, true);
										}
									} else if (isHeld) {
										final strum = playerStrums.members[daNote.noteData];

										strum.playAnim('confirm', true);
										strum.resetAnim = 0.15;
										if (char != null) char.holdTimer = 0;
										if (!practiceMode) health += 4.0 * elapsed * daNote.hitHealth * healthGain;
									}

									if (Conductor.songPosition >= noteEndTime && !endingSong) {
										if (!char?.specialAnim) {
											final singAnim = singAnimations[Std.int(Math.abs(daNote.noteData))];
											final endAnim = singAnim + '-end';
											
											if (char.hasAnimation(endAnim)) {
												char.playAnim(endAnim, true);
												char.endAnimTimer?.cancel();

												final duration = !char.isAnimationNull() ? char.getTotalFrames() / char.getCurrentFrameRate() : 0.5;
												char.endAnimTimer = new FlxTimer().start(duration, _ -> {
													if (char?.getAnimationName() == endAnim && !char?.specialAnim)
														char.dance();
													char.endAnimTimer = null;
												});
											}
										}
										char.holdTimer = 0;
										invalidateNote(daNote);
									}
								}
							} else {
								if (daNote.isSustainNote && daNote.wasGoodHit) {
									final char:Character = daNote.gfNote ? gf : dad;
									
									if (char?.endAnimTimer != null) {
										char.endAnimTimer.cancel();
										char.endAnimTimer = null;
									}
									
									final strum = opponentStrums.members[daNote.noteData];
									strum.playAnim('confirm', true);
									strum.resetAnim = 0.15;
									if (char != null) char.holdTimer = 0;

									var noteEndTime:Float = daNote.strumTime;
									if (daNote.parent != null) {
										noteEndTime = daNote.parent.strumTime + daNote.parent.sustainLength;
									} else if (daNote.sustainLength > 0) {
										noteEndTime = daNote.strumTime + daNote.sustainLength;
									}

									if (Conductor.songPosition >= noteEndTime && !endingSong) {
										if (!char?.specialAnim) {
											final singAnim = singAnimations[Std.int(Math.abs(daNote.noteData))];
											final endAnim = singAnim + '-end';
											
											if (char.hasAnimation(endAnim)) {
												char.playAnim(endAnim, true);
												char.endAnimTimer?.cancel();

												final duration = !char.isAnimationNull() ? char.getTotalFrames() / char.getCurrentFrameRate() : 0.5;
												char.endAnimTimer = new FlxTimer().start(duration, _ -> {
													if (char?.getAnimationName() == endAnim && !char?.specialAnim)
														char.dance();
													char.endAnimTimer = null;
												});
											}
										}
										char.holdTimer = 0;
										invalidateNote(daNote);
									}
								}
							}

							if (daNote.isSustainNote && daNote.holdNote != null)
							{
								daNote.holdNote.hit = daNote.wasGoodHit;
								
								if (daNote.wasGoodHit)
									daNote.holdNote.timeStuff = Conductor.songPosition - daNote.strumTime;
								
								daNote.strum = strumGroup.members[daNote.noteData];

								daNote.holdNote.updateVisuals((songSpeed * daNote.multSpeed), strumScroll);
								daNote.holdNote.updatePos();
							}

							// Kill extremely late notes and cause misses
							var killTime:Float = daNote.strumTime;
							if(daNote.isSustainNote && daNote.parent != null)
								killTime = daNote.parent.strumTime + daNote.parent.sustainLength;

							if (Conductor.songPosition > noteKillOffset + killTime)
							{
								if (daNote.mustPress && !cpuControlled &&!daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit)) {
									noteMiss(daNote);
								}

								daNote.active = false;
								daNote.visible = false;

								invalidateNote(daNote);
							}
						});
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnScripts('cameraX', camFollow.x);
		setOnScripts('cameraY', camFollow.y);
		setOnScripts('botPlay', cpuControlled);

		callOnScripts('onUpdatePost', [elapsed]);
	}

	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		// 1 / 1000 chance for Gitaroo Man easter egg
		/*if (FlxG.random.bool(0.1))
		{
			// gitaroo man easter egg
			cancelMusicFadeTween();
			FlxG.switchState(() -> new GitarooPause());
		}
		else {*/

		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(detailsPausedText, SONG.song.replace("-", " "), iconP2.getCharacter());
		#end
	}

	function openChartEditor()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;
		canResync = false;
		cancelMusicFadeTween();
		FlxG.switchState(() -> new ChartEditorState());
		chartingMode = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, false);
			if(ret != ScriptResult.Function_Stop) {
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;

				#if VIDEOS_ALLOWED
				video?.destroy();
				video = null;
				#end

				FlxG.sound.list.forEach((sound:FlxSound) -> sound?.stop());

				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();

				openSubState(new GameOverSubstate(boyfriend));

				// FlxG.switchState(() -> new GameOverState(boyfriend.getViewPosition().x, boyfriend.getViewPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his own variable because it's only used here
				DiscordClient.changePresence("Game Over - " + detailsText, SONG.song.replace('-', ' ') + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end

				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				break;
			}

			var value1:String = eventNotes[0].value1 ?? '';
			var value2:String = eventNotes[0].value2 ?? '';

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String) {
		switch(eventName) {
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value) || value < 1) value = 1;
				gfSpeed = value;

			case 'Add Camera Zoom':
				if(ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;

						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					var val1:Float = Std.parseFloat(value1);
					var val2:Float = Std.parseFloat(value2);
					if(Math.isNaN(val1)) val1 = 0;
					if(Math.isNaN(val2)) val2 = 0;

					isCameraOnForcedPos = false;
					if(!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
						camFollow.x = val1;
						camFollow.y = val2;
						isCameraOnForcedPos = true;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = Std.parseFloat(split[0].trim()) ?? 0;
					var intensity:Float = Std.parseFloat(split[1].trim()) ?? 0;
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				var oldCharName:String = null;
    			var newCharName:String = value2;

				switch(charType) {
					case 0:
						if (boyfriend.curCharacter != newCharName) 
						{
							oldCharName = boyfriend.curCharacter;

							if(!boyfriendMap.exists(value2))
								addCharacterToList(value2, charType);

							final lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if (dad.curCharacter != newCharName) 
						{
							oldCharName = dad.curCharacter;
							
							if(!dadMap.exists(value2))
								addCharacterToList(value2, charType);

							final wasGf:Bool = dad.curCharacter.startsWith('gf');
							final lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf')) {
								if(wasGf && gf != null) {
									gf.alpha = 1;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if (gf != null)
						{
							if(gf.curCharacter != newCharName)
							{
								oldCharName = gf.curCharacter;

								if(!gfMap.exists(value2))
									addCharacterToList(value2, charType);

								final lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

				if (oldCharName != null)
					removeCharacterScripts(oldCharName);

			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if(val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2 / playbackRate, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Lyrics':
				var split = value1.split("--");
				var text = value1;
				var color = FlxColor.WHITE;
				if(split.length > 1){
					text = split[0];
					color = FlxColor.fromString(split[1]);
				}
				var duration:Float = Std.parseFloat(value2);
				if (Math.isNaN(duration) || duration <= 0)
					duration = text.length * 0.5;

				writeLyrics(text, duration, color);

			case 'Set Property':
				var killMe:Array<String> = value1.split('.');
				if(killMe.length > 1) {
					FunkinLua.setVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe, true, true), killMe[killMe.length-1], value2);
				} else {
					FunkinLua.setVarInArray(this, value1, value2);
				}

			case 'Play Sound':
				var volume:Float = 1.0;
				if (value2 != null) {
					volume = Std.parseFloat(value2);
					if (Math.isNaN(volume)) volume = 1.0;
				}
				FlxG.sound.play(Paths.sound(value1), volume);

			case 'Play Video':
				var videoName:String = value1;
				playVideo(videoName);
		}
		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2));
		callOnScripts('onEvent', [eventName, value1, value2]);
	}

	function moveCameraSection(?sec:Null<Int>):Void
	{
		sec ??= curSection;
		if(sec < 0) sec = 0;

		if(SONG.notes[sec] == null) return;
		
		#if hl
		if (gf != null && SONG.notes[sec].gfSection)
		{
			var gfMidpoint = gf.getMidpoint();
			camFollow.setPosition(
				gfMidpoint.x + gf.cameraPosition[0] + girlfriendCameraOffset[0],
				gfMidpoint.y + gf.cameraPosition[1] + girlfriendCameraOffset[1]
			);
			isCameraOnForcedPos = false;
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}
		#else
		if (gf != null && SONG.notes[sec].gfSection)
		{
			camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			tweenCamIn();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}
		#end

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		callOnScripts('onMoveCamera', [isDad ? 'dad' : 'boyfriend']);
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(isDad)
		{
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					(_) -> cameraTwn = null
				});
			}
		}
	}

	function tweenCamIn() {
		if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				(_) -> cameraTwn = null
			});
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = endSong; //In case you want to change it in a specific song.

		updateTime = false;

		FlxG.sound.list.forEach((sound:FlxSound) -> {
			if (sound != null && sound.playing) {
				sound.stop();
				sound.volume = 0;
			}
		});

		if(ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, (_) -> endCallback());
		}
	}


	public var transitioning = false;
	public function endSong()
	{
		//Should kill you if you tried to cheat
		if(!startingSong) {
			notes.forEach(function(daNote:Note) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}

			if(doDeathCheck()) {
				return false;
			}
		}

		endingSong = true;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) {
			return false;
		} else {
			var achieve:String = checkForAchievement(['week1_nomiss', 'week2_nomiss', 'week3_nomiss', 'week4_nomiss',
				'week5_nomiss', 'week6_nomiss', 'week7_nomiss', 'ur_bad',
				'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);

			if(achieve != null) {
				startAchievement(achieve);
				return false;
			}
		}
		#end

		var ret:Dynamic = callOnScripts('onEndSong', [], false);
		if(ret != ScriptResult.Function_Stop && !transitioning) {
			#if !switch
			var percent:Float = ratingPercent;
			if(Math.isNaN(percent)) percent = 0;
			Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);
			#end
			
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					WeekData.loadTheFirstEnabledMod();

					canResync = false;
					cancelMusicFadeTween();

					FlxG.switchState(() -> new StoryMenuState());

					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);

					LoadingState.loadAndSwitchState(() -> new PlayState());
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				WeekData.loadTheFirstEnabledMod();
				canResync = false;
				cancelMusicFadeTween();
				FlxG.switchState(() -> new FreeplayState());
				changedDifficulty = false;
			}
			transitioning = true;
		}
		return true;
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementObject = null;
	function startAchievement(achieve:String) {
		achievementObj = new AchievementObject(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}
	function achievementEnd():Void
	{
		achievementObj = null;
		if(endingSong && !inCutscene) {
			endSong();
		}
	}
	#end

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	@:isVar public var totalPlayed(default, set):Int = 0;
	@:isVar public var totalNotesHit(default, set):Float = 0.0;

	public var showCombo:Bool = true;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	private function cachePopUpScore()
	{
		var pixelShitPart1:String = '';
		var pixelShitPart2:String = '';
		if (isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		Paths.image(pixelShitPart1 + "sick" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "good" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "bad" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "shit" + pixelShitPart2);
		Paths.image(pixelShitPart1 + "combo" + pixelShitPart2);
		
		for (i in 0...10) {
			Paths.image(pixelShitPart1 + 'num' + i + pixelShitPart2);
		}
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);
		//trace(noteDiff, ' ' + Math.abs(note.strumTime - Conductor.songPosition));

		// boyfriend.playAnim('hey');
		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;
		//

		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		var comboMult:Float = 1.0;
		if (combo >= 50) comboMult = 1.1;
		if (combo >= 100) comboMult = 1.2;
		if (combo >= 200) comboMult = 1.3;
    
    	score = Math.round(score * comboMult);

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.increase();
		note.rating = daRating.name;
		score = daRating.score;

		if(daRating.noteSplash && !note.noteSplashDisabled)
		{
			spawnNoteSplashOnNote(note);
		}

		if(!practiceMode && !cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';

		if (PlayState.isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.image(pixelShitPart1 + daRating.image + pixelShitPart2));
		rating.cameras = [camHUD];
		rating.screenCenter();
		rating.x = coolText.x + ClientPrefs.comboOffset[0] + 35;
		rating.y -= 35 + ClientPrefs.comboOffset[1];
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
		rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
		rating.visible = (!ClientPrefs.hideHud && showRating);

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.x = coolText.x + ClientPrefs.comboOffset[4] + 125;
		comboSpr.y += ClientPrefs.comboOffset[5] + 35;
		comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		comboSpr.visible = (!ClientPrefs.hideHud && showCombo);
		comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;

		insert(members.indexOf(strumLineNotes), rating);
		
		if (!ClientPrefs.comboStacking)
		{
			lastRating?.kill();
			lastRating = rating;
		}

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.6));
			rating.antialiasing = ClientPrefs.globalAntialiasing;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.6));
			comboSpr.antialiasing = ClientPrefs.globalAntialiasing;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.7));

			rating.y -= 50;
			comboSpr.y -= 50;
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		if(combo >= 1000) {
			seperatedScore.push(Math.floor(combo / 1000) % 10);
		}
		seperatedScore.push(Math.floor(combo / 100) % 10);
		seperatedScore.push(Math.floor(combo / 10) % 10);
		seperatedScore.push(combo % 10);

		var daLoop:Int = 0;
		var xThing:Float = 0;
		if (combo > 0 && combo % 10 == 0)
		{
			insert(members.indexOf(strumLineNotes), comboSpr);
		}
		if (!ClientPrefs.comboStacking)
		{
			lastCombo?.kill();
			lastCombo = comboSpr;
		}
		if (lastScore != null)
		{
			while (lastScore.length > 0)
			{
				lastScore[0].kill();
				lastScore.remove(lastScore[0]);
			}
		}
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
			numScore.cameras = [camHUD];
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 15 + ClientPrefs.comboOffset[2];
			numScore.y += 105 - ClientPrefs.comboOffset[3];
			
			if (!ClientPrefs.comboStacking)
				lastScore.push(numScore);

			if (!PlayState.isPixelStage)
			{
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.45));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom * 0.75));
				numScore.y -= 50;
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
			numScore.visible = !ClientPrefs.hideHud;

			//if (combo >= 10 || combo == 0)
			if(showComboNum)
				insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: (_) -> numScore?.destroy(),
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});

			daLoop++;
			if(numScore.x > xThing) xThing = numScore.x;
		}
		comboSpr.x = xThing + 50;
		/*
			trace(combo);
			trace(seperatedScore);
		 */

		coolText.text = Std.string(seperatedScore);
		// add(coolText);

		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
			startDelay: Conductor.crochet * 0.001 / playbackRate
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
			onComplete:(_) ->
			{
				coolText?.destroy();
				comboSpr?.destroy();

				rating?.destroy();
			},
			startDelay: Conductor.crochet * 0.002 / playbackRate
		});
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		//trace('Pressed: ' + eventKey);

		if (!cpuControlled && startedCountdown && !paused && key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			if(!boyfriend.stunned && generatedMusic && !endingSong)
			{
				var ret:Dynamic = callOnScripts('preKeyPress', [key]);
				if(ret == ScriptResult.Function_Stop) return;

				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				//var notesDatas:Array<Int> = [];
				var notesStopped:Bool = false;

				var sortedNotesList:Array<Note> = [];
				var hasHittableSustain:Bool = false;
				var sustainToCatch:Note = null;

				notes.forEachAlive(function(daNote:Note)
				{
					if (strumsBlocked[daNote.noteData] != true && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.blockHit)
					{
						if(daNote.noteData == key)
						{
							if (!daNote.isSustainNote && !daNote.wasGoodHit) {
								sortedNotesList.push(daNote);
							} else if (daNote.isSustainNote && !daNote.wasGoodHit) { 
								hasHittableSustain = true;
								if (sustainToCatch == null) sustainToCatch = daNote;
							}
						}
						canMiss = true;
					}
				});
				sortedNotesList.sort(sortHitNotes);

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}

					}
				}
				else if (hasHittableSustain && sustainToCatch != null) {
					sustainToCatch.parent?.extraData.set('tailCaught', true);
				}
				else {
					callOnScripts('onGhostTap', [key]);
					if (canMiss) {
						noteMissPress(key);
					}
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if(strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			callOnScripts('onKeyPress', [key]);
		}
		//trace('pressed: ' + controlArray);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		var ret:Dynamic = callOnScripts('preKeyRelease', [key]);
		if(ret == ScriptResult.Function_Stop) return;

		if(!cpuControlled && startedCountdown && !paused && key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			callOnScripts('onKeyRelease', [key]);
		}
	}

	function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function handleControllerInput():Void
	{
		if(!ClientPrefs.controllerMode || !startedCountdown || paused) return;

		var parsedArray:Array<Bool> = parseKeys('_P');
		for (i in 0...parsedArray.length)
		{
			if(parsedArray[i] && strumsBlocked[i] != true)
			{
				var key:Int = i;
				if(!cpuControlled && key > -1)
				{
					if(!boyfriend.stunned && generatedMusic && !endingSong)
					{
						var lastTime:Float = Conductor.songPosition;
						Conductor.songPosition = FlxG.sound.music.time;

						var canMiss:Bool = !ClientPrefs.ghostTapping;
						var pressNotes:Array<Note> = [];
						var notesStopped:Bool = false;

						var sortedNotesList:Array<Note> = [];
						notes.forEachAlive(function(daNote:Note)
						{
							if (strumsBlocked[daNote.noteData] != true && daNote.canBeHit && daNote.mustPress && 
								!daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit)
							{
								if(daNote.noteData == key)
								{
									sortedNotesList.push(daNote);
								}
								canMiss = true;
							}
						});
						sortedNotesList.sort(sortHitNotes);

						if (sortedNotesList.length > 0) {
							for (epicNote in sortedNotesList)
							{
								for (doubleNote in pressNotes) {
									if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
										invalidateNote(doubleNote);
									} else
										notesStopped = true;
								}

								if (!notesStopped) {
									goodNoteHit(epicNote);
									pressNotes.push(epicNote);
								}
							}
						}
						else if (canMiss) {
							noteMissPress(key);
						}

						keysPressed[key] = true;
						Conductor.songPosition = lastTime;
					}

					var spr:StrumNote = playerStrums.members[key];
					if(strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
					{
						spr.playAnim('pressed');
						spr.resetAnim = 0;
					}
				}
			}
		}

		var releasedArray:Array<Bool> = parseKeys('_R');
		for (i in 0...releasedArray.length)
		{
			if(releasedArray[i] || strumsBlocked[i] == true)
			{
				var key:Int = i;
				if(!cpuControlled && key > -1)
				{
					var spr:StrumNote = playerStrums.members[key];
					if(spr != null)
					{
						spr.playAnim('static');
						spr.resetAnim = 0;
					}
				}
			}
		}
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if(key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes
	private function keyShit():Void
	{
		// HOLDING
		var parsedHoldArray:Array<Bool> = parseKeys();

		handleControllerInput();

		// FlxG.watch.addQuick('asdfa', upP);
		if (startedCountdown && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0) {
				for (daNote in notes) { // I can't do a filter here, that's kinda awesome
					var canHit:Bool = (daNote != null && !strumsBlocked[daNote.noteData] && daNote.canBeHit
						&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit);

					if (canHit && daNote.isSustainNote) {
						var released:Bool = !parsedHoldArray[daNote.noteData];
						
						if (!released) {
							if (daNote.parent?.wasGoodHit || daNote.parent?.extraData.exists('tailCaught')) {
								goodNoteHit(daNote);
							}
						}
					}
				}
			}

			if (parsedHoldArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			} else {
				playerDance();
			}
		}

		handleControllerInput();
	}

	private function parseKeys(?suffix:String = ''):Array<Bool>
	{
		var ret:Array<Bool> = [];
		for (i in 0...controlArray.length)
		{
			ret[i] = Reflect.getProperty(controls, controlArray[i] + suffix);
		}
		return ret;
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				invalidateNote(daNote);
			}
		});
		combo = 0;

		health -= totalPlayed < 10 ? daNote.missHealth * healthLoss * 0.5 : daNote.missHealth * healthLoss;
		
		if(instakillOnMiss)
		{
			doDeathCheck(true);
		}

		//For testing purposes
		//trace(daNote.missHealth);
		songMisses++;
		vocals.volume = 0;
		if(!practiceMode) songScore -= 10;

		totalPlayed++;
		RecalculateRating(true);

		var char:Character = boyfriend;
		if(daNote.gfNote) {
			char = gf;
		}

		if(char != null && char.hasMissAnimations)
		{
			if(char.animTimer <= 0 && !char.voicelining){
				var daAlt = '';
				if(daNote.noteType == 'Alt Animation') daAlt = '-alt';

				var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daAlt;
				char.playAnim(animToPlay, true);
			}
		}

		callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1, anim:Bool = true):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.ghostTapping) return; //fuck it

		if (!boyfriend.stunned)
		{
			health -= 0.02 * healthLoss;
			if(instakillOnMiss)
			{
				vocals.volume = 0;
				doDeathCheck(true);
			}

			if (combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if(!practiceMode) songScore -= 10;
			if(!endingSong) songMisses++;
			totalPlayed++;
			RecalculateRating(true);

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.4, 0.6));

			if(boyfriend.hasMissAnimations && anim) {
				if(boyfriend.animTimer <= 0 && !boyfriend.voicelining)
					boyfriend.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}
			vocals.volume = 0;
		}
		callOnScripts('noteMissPress', [direction]);
	}

	function opponentNoteHit(note:Note):Void
	{
		var result:Dynamic = callOnLuas('preOpponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != ScriptResult.Function_Stop) result = callOnHScript('preOpponentNoteHit', [note]);

		if(result == ScriptResult.Function_Stop) return;

		if(note.noteType == 'Hey!' && dad.animOffsets.exists('hey')) {
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		} else if(!note.noAnimation) {
			var altAnim:String = note.animSuffix;

			if (SONG.notes[curSection] != null)
			{
				if (SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection) {
					altAnim = '-alt';
				}
			}

			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))] + altAnim;
			if(note.gfNote) {
				char = gf;
			}

			char.holdTimer = 0;

			if(char != null && !char.voicelining)
			{
				if (!note.isSustainNote
					&& noteRows[note.gfNote ? 2 : note.mustPress ? 0 : 1][note.row] != null
					&& noteRows[note.gfNote ? 2 : note.mustPress ? 0 : 1][note.row].length > 1)
				{
					// potentially have jump anims?
					var chord = noteRows[note.gfNote ? 2 : note.mustPress ? 0 : 1][note.row];
					var animNote = chord[0];
					var realAnim = singAnimations[Std.int(Math.abs(animNote.noteData))] + altAnim;
					if (char.mostRecentRow != note.row) {
						char.playAnim(realAnim, true);
					}

					if (note != animNote) {
						char.playGhostAnim(chord.indexOf(note) - 1, animToPlay, true);
					}

					char.mostRecentRow = note.row;
				}
				else
					char.playAnim(animToPlay, true);
			}

			final endAnim = singAnimations[Std.int(Math.abs(note.noteData))] + altAnim + '-end';
			
			if (!note.isSustainNote && note.sustainLength <= 0 && char?.hasAnimation(endAnim)) {
				char.endAnimTimer?.cancel();

				var duration:Float = (Conductor.stepCrochet * (0.0011 / playbackRate) * char.singDuration) - 0.01;
				if (duration <= 0.02) duration = 0.02;

				char.endAnimTimer = new FlxTimer().start(duration, _ -> {
					if (char.getAnimationName() == animToPlay && !char.specialAnim) {
						char.playAnim(endAnim, true);
						char.specialAnim = true;

						final endDuration:Float = !char.isAnimationNull() ? char.getTotalFrames() / char.getCurrentFrameRate() : 0.5;
						char.endAnimTimer = new FlxTimer().start(endDuration, _ -> {
							if (char.getAnimationName() == endAnim && char.specialAnim) {
								char.specialAnim = false;
								char.dance();
							}
							char.endAnimTimer = null;
						});
					}
				});
			}
		}

		if (SONG.needsVoices)
			if(opponentVocals.length <= 0) vocals.volume = 1;

		iconP2.flash(1.12, 1);

		var time:Float = 0.15;
		if(note.isSustainNote && !note.animation?.curAnim?.name?.endsWith('end')) {
			time += 0.15;
		}
		StrumPlayAnim(true, Std.int(Math.abs(note.noteData)), time);
		note.hitByOpponent = true;

		spawnHoldCoverOnNote(note);

		stagesFunc((stage:BaseStage) -> stage.opponentNoteHit(note));

		callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		callOnHScript('opponentNoteHit', [note]);

		if (!note.isSustainNote) invalidateNote(note);
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if(cpuControlled && (note.ignoreNote || note.hitCausesMiss)) return;

			if (!cpuControlled && note.isSustainNote && note.parent != null && note.parent.alive && !note.parent.wasGoodHit) {
				noteMiss(note.parent);
				
				note.parent.active = false;
				note.parent.visible = false;
				invalidateNote(note.parent);
			}

			var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
			var leData:Int = Math.round(Math.abs(note.noteData));
			var leType:String = note.noteType;

			var result:Dynamic = callOnLuas('preGoodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
			if(result != ScriptResult.Function_Stop) result = callOnHScript('preGoodNoteHit', [note]);

			if(result == ScriptResult.Function_Stop) return;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled)
			{
				FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);
			}

			if(note.hitCausesMiss) {
				noteMiss(note);
				if(!note.noteSplashDisabled && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}

				if(!note.noMissAnimation)
				{
					switch(note.noteType) {
						case 'Hurt Note': //Hurt note
							if(boyfriend.animation.getByName('hurt') != null) {
								boyfriend.playAnim('hurt', true);
								boyfriend.specialAnim = true;
							}
					}
				}

				note.wasGoodHit = true;
				if (!note.isSustainNote) invalidateNote(note);
				return;
			}

			if (!note.noteWasHit) {
				if (!note.isSustainNote)
				{
					combo += 1;
					popUpScore(note);
				}
				else
				{
					if(!practiceMode && !cpuControlled) songScore += Math.round(50 * note.ratingMod);
				}
				health += note.hitHealth * healthGain;
			}

			if(!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))] + note.animSuffix;

				var char:Character = boyfriend;
				char.holdTimer = 0;
				if(note.gfNote)
				{
					if(gf != null)
					{
						gf.playAnim(animToPlay, true);
						gf.holdTimer = 0;
					}
				}
				else if(char.animTimer <= 0 && !char.voicelining)
				{
					if (!note.isSustainNote && noteRows[note.gfNote ? 2 : note.mustPress ? 0 : 1][note.row]!=null && noteRows[note.gfNote ? 2 : note.mustPress ? 0 : 1][note.row].length > 1)
					{
						// potentially have jump anims?
						var chord = noteRows[note.gfNote ? 2 : note.mustPress ? 0 : 1][note.row];
						var animNote = chord[0];
						var realAnim = singAnimations[Std.int(Math.abs(note.noteData))] + note.animSuffix;
						if (char.mostRecentRow != note.row)
							char.playAnim(realAnim, true);

						if (note != animNote)
							char.playGhostAnim(chord.indexOf(note) - 1, animToPlay, true);

						char.mostRecentRow = note.row;
					}
					else
						char.playAnim(animToPlay, true);

					if(note.noteType == 'Hey!') {
						if(char.animOffsets.exists('hey')) {
							char.playAnim('hey', true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}

						if(gf != null && gf.animOffsets.exists('cheer')) {
							gf.playAnim('cheer', true);
							gf.specialAnim = true;
							gf.heyTimer = 0.6;
						}
					}
				}

				final targetChar:Character = (note.gfNote && gf != null) ? gf : char;
				final endAnim = singAnimations[Std.int(Math.abs(note.noteData))] + note.animSuffix + '-end';
				
				if (!note.isSustainNote && note.sustainLength <= 0 && targetChar.hasAnimation(endAnim)) {
					targetChar.endAnimTimer?.cancel();

					var duration:Float = (Conductor.stepCrochet * (0.0011 / playbackRate) * targetChar.singDuration) - 0.01;
					if (duration <= 0.02) duration = 0.02;

					targetChar.endAnimTimer = new FlxTimer().start(duration, _ -> {
						if (targetChar.getAnimationName() == animToPlay && !targetChar.specialAnim) {
							targetChar.playAnim(endAnim, true);
							targetChar.specialAnim = true;

							final endDuration:Float = !targetChar.isAnimationNull() ? targetChar.getTotalFrames() / targetChar.getCurrentFrameRate() : 0.5;
							targetChar.endAnimTimer = new FlxTimer().start(endDuration, _ -> {
								if (targetChar.getAnimationName() == endAnim && targetChar.specialAnim) {
									targetChar.specialAnim = false;
									targetChar.dance();
								}
								targetChar.endAnimTimer = null;
							});
						}
					});
				}
			}

			if(cpuControlled) {
				var time:Float = 0.15;
				if(note.isSustainNote && !note.animation?.curAnim?.name?.endsWith('end')) {
					time += 0.15;
				}
				StrumPlayAnim(false, Std.int(Math.abs(note.noteData)), time);
			} else {
				var spr = playerStrums.members[note.noteData];
				spr?.playAnim('confirm', true);
			}
			note.wasGoodHit = true;
			vocals.volume = 1;

			iconP1.flash(1.12, 1);

			if (!note.noteWasHit)
				spawnHoldCoverOnNote(note);

			note.noteWasHit = true;

			stagesFunc((stage:BaseStage) -> stage.goodNoteHit(note));

			callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
			callOnHScript('goodNoteHit', [note]);

			if (!note.isSustainNote) invalidateNote(note);
		}
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null, ?strum:StrumNote) {
		var hue:Float = 0;
		var sat:Float = 0;
		var brt:Float = 0;
		if (data > -1 && data < ClientPrefs.arrowHSV.length)
		{
			hue = ClientPrefs.arrowHSV[data][0] / 360;
			sat = ClientPrefs.arrowHSV[data][1] / 100;
			brt = ClientPrefs.arrowHSV[data][2] / 100;
			if(note != null) {
				hue = note.noteSplashHue;
				sat = note.noteSplashSat;
				brt = note.noteSplashBrt;
			}
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.babyArrow = strum;
		splash.setupNoteSplash(x, y, data, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	public function spawnHoldCoverOnNote(note:Note) {
		if(!ClientPrefs.noteHoldCovers) return;

		var endNote:Note = note;
		if (note.parent?.tail?.length > 0) {
			endNote = note.isSustainNote ? note.parent.tail[note.parent.tail.length - 1] : note.tail[note.tail.length - 1];
		}

		//to prevent crash when its null
		if (endNote == null || !endNote.active || endNote.animation == null || endNote.animation.curAnim == null
			|| !StringTools.endsWith(endNote.animation.curAnim.name, 'end')) return;

		if (endNote != null) {
			endNote.extraData ??= new Map<String, Dynamic>();

			var leSplash:NoteHoldCover = endNote.extraData['holdCover'];
			if (leSplash == null) {
				spawnHoldCover(endNote);
			} else {
				leSplash.alpha = 1;
			}
		}
	}

	public function spawnHoldCover(note:Note) {
		//same as above
		if (note == null || !note.active || note.animation == null || note.animation.curAnim == null
			|| !StringTools.endsWith(note.animation.curAnim.name, 'end')) return;

		var parentNote = note.parent;
		var noteData = parentNote != null ? parentNote.noteData : note.noteData;

		var strum:StrumNote = (note.mustPress ? playerStrums : opponentStrums).members[noteData];

		var hueColor:Float = 0;
		var satColor:Float = 0;
		var brtColor:Float = 0;

		if (strum != null) {
			var dynStrum:Dynamic = cast strum;
			if (dynStrum.colorSwap != null) {
				hueColor = dynStrum.colorSwap.hue;
				satColor = dynStrum.colorSwap.saturation;
				brtColor = dynStrum.colorSwap.brightness;
			}
		}

		if (NoteHoldCover.activeCovers.exists(strum)) {
			var existingCover = NoteHoldCover.activeCovers.get(strum);
			existingCover.setupHoldCover(strum, note, hueColor, satColor, brtColor);
			return;
		}

		var holdCover:NoteHoldCover = grpHoldCovers.recycle(NoteHoldCover);
		holdCover.startCrochet = Conductor.stepCrochet / playbackRate;
		holdCover.frameRate = Math.floor((isPixelStage ? 20 : 24) / 100 * Conductor.bpm);

		holdCover.setupHoldCover(strum, note, hueColor, satColor, brtColor);
		grpHoldCovers.add(holdCover);

		note.extraData ??= new Map<String, Dynamic>();
		note.extraData['holdCover'] = holdCover;
	}

	override function destroy() {
		stagesFunc((stage:BaseStage) -> stage.destroy());
		
		for (lua in luaArray) {
			lua.safeCall('onDestroy', []);
			lua.stop();
		}
		luaArray = [];

		#if HSCRIPT_ALLOWED
		for (sc in hscriptArray) {
			sc.call("onDestroy", []);
			sc.stop();
		}
		hscriptArray = [];

		FunkinLua.hscript = null;
		#end

		for (name in characterScripts.keys())
			removeCharacterScripts(name);

		characterScripts.clear();
		characterScripts = null;

		isPixelStage = false;

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		FlxG.animationTimeScale = 1;
		#if FLX_PITCH
		FlxG.sound.list.forEach((sound:FlxSound) -> if (sound != null) sound.pitch = 1);
		#end

		instance = null;
		shutdownThread = true;
		FlxG.signals.preUpdate.remove(checkForResync);

		super.destroy();
	}

	public static function cancelMusicFadeTween() {
		FlxG.sound?.music?.fadeTween?.cancel();
		FlxG.sound.music.fadeTween = null;
	}

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();
		if (SONG.needsVoices && FlxG.sound.music.time >= -ClientPrefs.noteOffset)
		{
			var timeSub:Float = Conductor.songPosition - Conductor.offset;
			var syncTime:Float = 20 * playbackRate;
			if (Math.abs(FlxG.sound.music.time - timeSub) > syncTime ||
			(vocals.length > 0 && Math.abs(vocals.time - timeSub) > syncTime) ||
			(opponentVocals.length > 0 && Math.abs(opponentVocals.time - timeSub) > syncTime))
			{
				resyncVocals();
			}
		}

		if(curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;

	var lastBeatHit:Int = -1;
	override function beatHit()
	{
		super.beatHit();

		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		iconP1.flash(1.2, 1);
		iconP2.flash(1.2, 1);

		characterBopper(curBeat);

		switch (curStage)
		{

		}

		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat); //DAWGG?????
		callOnScripts('onBeatHit');
	}

	var camZoomingOnSection:Bool = false;
	override function sectionHit()
	{
		super.sectionHit();

		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
			{
				moveCameraSection();
			}

			if (camZoomingOnSection && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[curSection].bpm);
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		
		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	public function characterBopper(beat:Int):Void
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();

		callOnScripts('characterBopper', [beat]);
	}

	public function playerDance():Void
	{
		var anim:String = boyfriend?.getAnimationName();
		if(boyfriend != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
			boyfriend.dance();
	}

	public function startLuasOnFolder(luaFile:String):Bool
	{
		#if LUA_ALLOWED
		var fileName = luaFile.substring(luaFile.lastIndexOf("/") + 1);
		
		final alreadyLoaded = Lambda.exists(luaArray, script -> {
			final scriptFileName = script.scriptName.substring(script.scriptName.lastIndexOf("/") + 1);
			return scriptFileName == fileName;
		});
		
		if (alreadyLoaded) return false;
		
		var actualPath:String = null;
		#if MODS_ALLOWED
		var modPath = Mods.modFolders(luaFile);
		if (FileSystem.exists(modPath)) {
			actualPath = modPath;
		} else
		#end
		{
			final basePath = Paths.getPreloadPath(luaFile);
			#if sys
			if (FileSystem.exists(basePath)) actualPath = basePath;
			#end
			if (actualPath == null && OpenFlAssets.exists(luaFile)) actualPath = luaFile;
		}
		
		if (actualPath != null) {
			luaArray.push(new FunkinLua(actualPath));
			return true;
		}
		#end
		
		return false;
	}

	public function startHScriptOnFolder(hscriptFile:String):Bool
	{
		#if HSCRIPT_ALLOWED
		var fileName = hscriptFile.substring(hscriptFile.lastIndexOf("/") + 1);

		final alreadyLoaded = Lambda.exists(hscriptArray, script -> {
			final scriptFileName = script.scriptName.substring(script.scriptName.lastIndexOf("/") + 1);
			return scriptFileName == fileName;
		});
		
		if (alreadyLoaded) return false;
		
		var actualPath:String = null;
		#if MODS_ALLOWED
		var modPath = Mods.modFolders(hscriptFile);
		if (FileSystem.exists(modPath)) {
			actualPath = modPath;
		} else
		#end
		{
			final basePath = Paths.getPreloadPath(hscriptFile);
			#if sys
			if (FileSystem.exists(basePath)) actualPath = basePath;
			#end
			if (actualPath == null && OpenFlAssets.exists(hscriptFile)) actualPath = hscriptFile;
		}
		
		if (actualPath != null) {
			hscriptArray.push(new FunkinHScript(actualPath));
			return true;
		}
		#end
		
		return false;
	}
	public function setOnHScript(variable:String, arg:Dynamic) {
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray) {
			script.set(variable, arg);
		}
		#end
	}
	public function callOnHScript(event:String, args:Array<Dynamic>, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal = ScriptResult.Function_Continue;
		#if HSCRIPT_ALLOWED
		exclusions ??= [];
		excludeValues ??= [];

		for (sc in hscriptArray) {
			if(exclusions.contains(sc.scriptName))
				continue;

			var myValue = sc.call(event, args);
			if(myValue == ScriptResult.Function_Stop_Lua && !ignoreStops)
				break;
			
			if(myValue != ScriptResult.Function_Continue)
				returnVal = myValue;
		}
		#end
		return returnVal;
	}
	
	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal = ScriptResult.Function_Continue;
		args ??= [];
		exclusions ??= [];
		excludeValues ??= [ScriptResult.Function_Continue];

		var result = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if(result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function setOnScripts(variable:String, arg:Dynamic) {
		setOnLuas(variable, arg);
		#if HSCRIPT_ALLOWED
		setOnHScript(variable, arg);
		#end
	}

	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal = ScriptResult.Function_Continue;
		#if LUA_ALLOWED
		exclusions ??= [];
		excludeValues ??= [];

		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			var myValue = script.safeCall(event, args);
			if(myValue == ScriptResult.Function_Stop_Lua && !ignoreStops)
				break;
			
			if(myValue != ScriptResult.Function_Continue)
				returnVal = myValue;
		}
		#end
		return returnVal;
	}

	public function setOnLuas(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		spr = isDad ? opponentStrums.members[id] : playerStrums.members[id];

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	var lyricText:FlxText;
	var lyricTween:FlxTween;

	function writeLyrics(text:String, duration:Float, color:FlxColor)
	{
		if (lyricText != null) {
			var old:FlxText = cast lyricText;
			FlxTween.tween(old, {alpha: 0}, 0.2, {onComplete: (_) ->
			{
				remove(old);
				old.destroy();
			}});
			lyricText = null;
		}
		if (lyricTween != null) {
			lyricTween.cancel();
			lyricTween = null;
		}
		if (text.trim() != '' && duration > 0 && color.alphaFloat > 0) {
			lyricText = new FlxText(0, 0, FlxG.width, text);
			switch (SONG.song.toLowerCase()) {
				default:
                    lyricText.setFormat("VCR OSD Mono", 24, color, CENTER, OUTLINE, FlxColor.BLACK);
			}
			lyricText.alpha = 0;
			lyricText.screenCenter(XY);
			lyricText.y += 250;
			lyricText.cameras = [camOther];
			add(lyricText);
			lyricTween = FlxTween.tween(lyricText, {alpha: color.alphaFloat}, 0.2, {onComplete: (_) ->
			{
				lyricTween = FlxTween.tween(lyricText, {alpha: 0}, 0.2, {startDelay: duration, onComplete: (twn:FlxTween) ->
				{
					remove(lyricText);
					lyricText.destroy();
					lyricText = null;
					if(lyricTween == twn) lyricTween = null;
				}});
			}});
		}
	}

	public function invalidateNote(note:Note):Void {
		if (note.holdNote != null) {
			note.holdNote.kill();
			notesSustains.remove(note.holdNote, true);
			note.holdNote.destroy();
			note.holdNote = null;
		}

		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function updatePixelStage() {
		introSoundsSuffix = isPixelStage ? '-pixel' : '';
		
		for (note in unspawnNotes)
			note?.reloadNote();
		
		notes?.forEachAlive((note:Note) -> note.reloadNote());
		playerStrums?.forEachAlive((strum:StrumNote) -> strum.reloadNote());
		opponentStrums?.forEachAlive((strum:StrumNote) -> strum.reloadNote());
		grpHoldCovers?.forEach((cover:NoteHoldCover) -> cover.reloadCover());
	}

	public var ratingPercent:Float = 0;
	public var ratingName:String = '?';
	public var ratingFC:String = '';
	public function RecalculateRating(badHit:Bool = false)
	{
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);

		var ret:Dynamic = callOnScripts('onRecalculateRating', [], false);
		if(ret != ScriptResult.Function_Stop)
		{
			updateScore(badHit);
			
			if (totalPlayed < 1) {
				ratingPercent = 0;
				ratingName = '?';
			} else {
				var totalPossible:Float = totalPlayed * 1.0;
				var actualScore:Float = totalNotesHit;
				ratingPercent = Math.min(1, Math.max(0, actualScore / totalPossible));

				if(ratingPercent >= 1) {
					ratingName = ratingStuff[ratingStuff.length-1][0];
				} else {
					for (i in 0...ratingStuff.length-1) {
						if(ratingPercent < ratingStuff[i][1]) {
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			if (songMisses == 0) {
				if (shits == 0 && bads == 0 && goods == 0)
					ratingFC = "MFC";
				else if (bads == 0 && shits == 0)
					ratingFC = "GFC";
				else if (shits == 0)
					ratingFC = "FC";
				else
					ratingFC = "FC";
			} else if (songMisses < 5)
				ratingFC = "SDCB";
			else
				ratingFC = "Clear";
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null):String
	{
		if(chartingMode) return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice', false) || ClientPrefs.getGameplaySetting('botplay', false));
		for (i in 0...achievesToCheck.length) {
			var achievementName:String = achievesToCheck[i];
			if(!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled) {
				var unlock:Bool = false;
				
				if (achievementName.contains(WeekData.getWeekFileName()) && achievementName.endsWith('nomiss')) // any FC achievements, name should be "weekFileName_nomiss", e.g: "weekd_nomiss";
				{
					if(isStoryMode && campaignMisses + songMisses < 1 && CoolUtil.difficultyString() == 'HARD'
						&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
						unlock = true;
				}
				switch(achievementName)
				{
					case 'ur_bad' if(ratingPercent < 0.2 && !practiceMode):
						unlock = true;
					case 'ur_good' if(ratingPercent >= 1 && !usedPractice):
						unlock = true;
					case 'roadkill_enthusiast' if(Achievements.henchmenDeath >= 100):
						unlock = true;
					case 'oversinging' if(boyfriend.holdTimer >= 10 && !usedPractice):
						unlock = true;
					case 'hype' if(!boyfriendIdled && !usedPractice):
						unlock = true;
					case 'two_keys' if(!usedPractice):
						var howManyPresses:Int = 0;
						for (j in 0...keysPressed.length) {
							if(keysPressed[j]) howManyPresses++;
						}

						if(howManyPresses <= 2) unlock = true;
					case 'toastie':
						if(/*ClientPrefs.framerate <= 60 &&*/ !ClientPrefs.shaders && ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing) {
							unlock = true;
						}
					case 'debugger' if(Paths.formatToSongPath(SONG.song) == 'test' && !usedPractice):
						unlock = true;
				}

				if(unlock) {
					Achievements.unlockAchievement(achievementName);
					return achievementName;
				}
			}
		}
		return null;
	}
	#end

	function checkForResync()
	{
		if (paused) return;

		if (requiresSyncing)
		{
			requiresSyncing = false;
			setSongTime(lastCorrectSongPos);
		}

		gameFroze = false;
	}

	public function runSongSyncThread()
	{
		#if target.threaded
		Thread.create(() -> {
			while (!endingSong && !paused && !shutdownThread)
			{
				if (requiresSyncing) continue;

				if (gameFroze)
				{
					lastCorrectSongPos = Conductor.songPosition;
					requiresSyncing = true;
					continue;
				}
				gameFroze = true;

				Sys.sleep(0.25);
			}
		});
		#end

		if (!FlxG.signals.preUpdate.has(checkForResync)) FlxG.signals.preUpdate.add(checkForResync);
	}
}
