package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
import sys.thread.Thread;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxGridOverlay;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.sound.FlxSound;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import lime.app.Application;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import haxe.Json;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

import game.scripting.FunkinLua;
import game.substates.options.GraphicsSettingsSubState;

using StringTools;

typedef TitleData =
{
	titlex:Float,
	titley:Float,
	startx:Float,
	starty:Float,
	gfx:Float,
	gfy:Float,
	backgroundSprite:String,
	bpm:Int
}

class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;
	var credTextShit:Alphabet;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	var mustUpdate:Bool = false;

	var titleJSON:TitleData;

	public static var updateVersion:String = '';

	public static var needsFullReset:Bool = false;

	public static function resetStaticVariables():Void {
		initialized = false;
		updateVersion = '';
		closedState = false;
		playJingle = false;
		needsFullReset = false;
	}

	override public function create():Void
	{
		if (needsFullReset) {
			resetStaticVariables();
			needsFullReset = false;
		}

		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		credGroup = new FlxGroup();
		textGroup = new FlxGroup();

		curWacky = FlxG.random.getObject(getIntroTextShit());

		swagShader = new ColorSwap();
		super.create();

		#if CHECK_FOR_UPDATES
		if(ClientPrefs.checkForUpdates && !closedState) {
			trace('checking for update');
			var http = new haxe.Http("https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/main/gitVersion.txt");

			http.onData = function (data:String)
			{
				updateVersion = data.split('\n')[0].trim();
				var curVersion:String = Application.current.meta.get('version').trim();
				trace('version online: ' + updateVersion + ', your version: ' + curVersion);
				if(updateVersion != curVersion) {
					trace('versions arent matching!');
					mustUpdate = true;
				}
			}

			http.onError = (error) -> trace('error: $error');

			http.request();
		}
		#end

		titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));

		persistentUpdate = persistentDraw = true;
		
		if (!isSoftcodedState())
		{
			#if FREEPLAY
			FlxG.switchState(() -> new FreeplayState());
			#elseif CHARTING
			FlxG.switchState(() -> new ChartEditorState());
			#else
			if(FlxG.save.data.flashing == null && !FlashingState.leftState) {
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				FlxG.switchState(() -> new FlashingState());
			} else {
				sickBeats = 0;

				if (initialized)
					startIntro();
				else
					new FlxTimer().start(1, (_) -> startIntro());
			}
			#end
		}
		else
		{
			skippedIntro = true;
		}
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		if (isSoftcodedState()) return;

		clearAll();

		if(!initialized && FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

		Conductor.changeBPM(titleJSON.bpm);
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();
		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none")
			bg.loadGraphic(Paths.image(titleJSON.backgroundSprite));
		else
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.globalAntialiasing;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.updateHitbox();
		add(logoBl);

		swagShader = new ColorSwap();

		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;
		add(gfDance);
		gfDance.shader = swagShader.shader;
		logoBl.shader = swagShader.shader;

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);
		#if MODS_ALLOWED
		var imageLoaded = false;

		for (ext in Paths.IMAGE_EXTS) {
			var path = '${Mods.MODS_FOLDER}/${Mods.currentModDirectory}/images/titleEnter.$ext';
			if (!FileSystem.exists(path)) {
				path = '${Mods.MODS_FOLDER}/images/titleEnter.$ext';
			}
			if (!FileSystem.exists(path)) {
				path = Paths.getPath('images/titleEnter.$ext');
			}
			
			if (FileSystem.exists(path)) {
				var xmlPath = StringTools.replace(path, '.$ext', '.xml');
				var titleXml:String = null;
				
				if (FileSystem.exists(xmlPath)) {
					titleXml = File.getContent(xmlPath);
				} else {
					var assetXmlPath = StringTools.replace(Paths.getPath('images/titleEnter.$ext'), '.$ext', '.xml');
					if (Assets.exists(assetXmlPath))
						titleXml = Assets.getText(assetXmlPath);
				}
				
				if (titleXml != null) {
					titleText.frames = FlxAtlasFrames.fromSparrow(BitmapData.fromFile(path), titleXml);
					imageLoaded = true;
					break;
				}
			}
		}
		
		if (!imageLoaded) {
			trace('Could not load titleEnter image with any extension: ${Paths.IMAGE_EXTS}');
		}
		#else
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		#end
		
		var animFrames:Array<FlxFrame> = [];
		@:privateAccess {
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (animFrames.length > 0) {
			newTitle = true;
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		} else {
			newTitle = false;
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		
		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		credGroup = new FlxGroup();
		add(credGroup);

		textGroup = new FlxGroup();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		add(ngSpr);
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.globalAntialiasing;

		FlxTween.tween(credTextShit, {y: credTextShit.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

		sickBeats = 0;

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	function clearAll():Void {
		if (logoBl != null) {
			remove(logoBl);
			logoBl.destroy();
			logoBl = null;
		}
		if (gfDance != null) {
			remove(gfDance);
			gfDance.destroy();
			gfDance = null;
		}
		if (titleText != null) {
			remove(titleText);
			titleText.destroy();
			titleText = null;
		}
		if (credGroup != null) {
			remove(credGroup);
			credGroup.destroy();
			credGroup = null;
		}
		if (textGroup != null) {
			textGroup.destroy();
			textGroup = null;
		}
		if (ngSpr != null) {
			remove(ngSpr);
			ngSpr.destroy();
			ngSpr = null;
		}
		if (blackScreen != null) {
			blackScreen.destroy();
			blackScreen = null;
		}
		if (credTextShit != null) {
			credTextShit.destroy();
			credTextShit = null;
		}
		if (swagShader != null) {
			swagShader = null;
		}
	}

	function getIntroTextShit():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
			swagGoodArray.push(i.split('--'));

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		if (!isSoftcodedState())
		{
			var pressedEnter:Bool = false;
			final gamepad:FlxGamepad = FlxG.gamepads.lastActive;

			pressedEnter = FlxG.keys.justPressed.ENTER || controls.ACCEPT;
			
			if (gamepad != null)
				pressedEnter = pressedEnter || gamepad.justPressed.START #if switch || gamepad.justPressed.B #end;
			
			for (touch in FlxG.touches.list) {
				if (touch.justPressed) {
					pressedEnter = true;
					break;
				}
			}
			
			if (newTitle) {
				titleTimer += MathUtil.boundTo(elapsed, 0, 1);
				if (titleTimer > 2) titleTimer -= 2;
			}

			if (initialized && !transitioning && skippedIntro)
			{
				if (newTitle && !pressedEnter)
				{
					var timer:Float = titleTimer;
					if (timer >= 1) timer = (-timer) + 2;
					timer = FlxEase.quadInOut(timer);
					titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
					titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
				}
				
				if(pressedEnter)
				{
					titleText.color = FlxColor.WHITE;
					titleText.alpha = 1;
					
					titleText?.animation.play('press');
					FlxG.camera.flash(ClientPrefs.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
					FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
					transitioning = true;

					new FlxTimer().start(1, (_) ->
					{
						FlxG.switchState(mustUpdate ? () -> new OutdatedState() : () -> new MainMenuState());
						closedState = true;
					});
				}
			}

			if (initialized && pressedEnter && !skippedIntro)
				skipIntro();

			if(swagShader != null)
			{
				if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
				if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
			}
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		if (credGroup == null || textGroup == null) return;
		
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			credGroup.add(money);
			textGroup.add(money);
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if (credGroup == null || textGroup == null) return;
		
		var coolText:Alphabet = new Alphabet(0, 0, text, true);
		coolText.screenCenter(X);
		coolText.y += (textGroup.length * 60) + 200 + offset;
		credGroup.add(coolText);
		textGroup.add(coolText);
	}

	function deleteCoolText()
	{
		if (textGroup != null) {
			while (textGroup.members.length > 0)
			{
				credGroup?.remove(textGroup.members[0], true);
				textGroup.remove(textGroup.members[0], true);
			}
		}
	}

	private var sickBeats:Int = 0;
	public static var closedState:Bool = false;
	
	override function beatHit()
	{
		super.beatHit();

		if (!isSoftcodedState())
		{
			logoBl?.animation?.play('bump', true);

			if(gfDance != null) {
				danceLeft = !danceLeft;
				gfDance.animation.play(danceLeft ? 'danceRight' : 'danceLeft');
			}

			if(!closedState) {
				sickBeats++;
				switch (sickBeats)
				{
					case 1:
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
					case 2:
						createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
					case 4:
						addMoreText('present');
					case 5:
						deleteCoolText();
					case 6:
						createCoolText(['In association', 'with'], -40);
					case 8:
						addMoreText('newgrounds', -40);
						if (ngSpr != null) ngSpr.visible = true;
					case 9:
						deleteCoolText();
						if (ngSpr != null) ngSpr.visible = false;
					case 10:
						createCoolText([curWacky[0]]);
					case 12:
						addMoreText(curWacky[1]);
					case 13:
						deleteCoolText();
					case 14:
						addMoreText('Friday');
					case 15:
						addMoreText('Night');
					case 16:
						addMoreText('Funkin');
					case 17:
						skipIntro();
				}
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	
	function skipIntro():Void
	{
		if (isSoftcodedState())
		{
			skippedIntro = true;
			return;
		}

		var ret = callOnMenuScript("onIntroSkip", [(!skippedIntro)]);
		if (!skippedIntro #if SCRIPTABLE_STATES && ret != ScriptResult.Function_Stop #end)
		{
			if (playJingle)
			{
				transitioning = true;

				remove(credGroup);
				remove(ngSpr);
				FlxG.camera.flash(FlxColor.WHITE, 3);
				sound?.onComplete = () -> {
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
					transitioning = false;
				};

				playJingle = false;
			}
			else
			{
				remove(credGroup);
				remove(ngSpr);
				FlxG.camera.flash(FlxColor.WHITE, 3.4);
			}
			skippedIntro = true;
			callOnMenuScript("onIntroSkipPost", []);
		}
	}
}