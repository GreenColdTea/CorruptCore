package game.states.options;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.util.FlxStringUtil;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.ui.FlxBar;
import flixel.math.FlxPoint;

import game.objects.Character;
import game.backend.Conductor;

using StringTools;

class NoteOffsetState extends MusicBeatState
{
	var boyfriend:Character;
	var gf:Character;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;

	var coolText:FlxText;
	var rating:FlxSprite;
	var comboSpr:FlxSprite = new FlxSprite();
	var comboNums:FlxSpriteGroup;
	var dumbTexts:FlxTypedGroup<FlxText>;

	var barPercent:Float = 0;
	var delayMin:Int = -500;
	var delayMax:Int = 500;
	var timeBarBG:FlxSprite;
	var timeBar:FlxBar;
	var timeTxt:FlxText;
	var beatText:Alphabet;
	var beatTween:FlxTween;

	var changeModeText:FlxText;
	var calibrateText:FlxText;
	var helpText:FlxText;

	var calibrating:Bool = false;
	var calibrationStep:Int = 0;
	var notePressTimes:Array<Float> = [];
	var expectedTimes:Array<Float> = [];
	var calibrationStartTime:Float = 0;
	var calibrationTimer:FlxTimer;
	var calibrationProgress:FlxText;
	var calibrationResult:FlxText;
	
	var strumLine:FlxSpriteGroup;
	var strumNotes:Array<CalibrationStrum> = [];
	var calibrationNotes:Array<CalibrationNote> = [];
	var noteSpeed:Float = 0.25;
	var hitLineY:Float = 550;
	var noteSpacing:Float = 160 * 0.7;

	var spawnTimers:Array<FlxTimer> = [];
	var beatTimer:FlxTimer = null;

	override public function create()
	{
		camGame = initFunkinCamera();

		camHUD = new FlxCamera();
		camOther = new FlxCamera();

		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FlxG.camera.scroll.set(120, 130);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Delay/Combo Offset Menu", null);
		#end

		persistentUpdate = true;
		FlxG.sound.pause();
		
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);

		if(!ClientPrefs.lowQuality) {
			var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			add(stageLight);
			var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			stageLight.flipX = true;
			add(stageLight);

			var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
			stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
			stageCurtains.updateHitbox();
			add(stageCurtains);
		}

		gf = new Character(400, 130, 'gf');
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
		gf.scrollFactor.set(0.95, 0.95);
		boyfriend = new Character(770, 100, 'bf', true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(gf);
		add(boyfriend);

		coolText = new FlxText(0, 0, 0, '', 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;

		rating = new FlxSprite().loadGraphic(Paths.image('sick'));
		rating.camera = camHUD;
		rating.setGraphicSize(Std.int(rating.width * 0.6));
		rating.updateHitbox();
		rating.antialiasing = ClientPrefs.globalAntialiasing;
		
		add(rating);

		comboSpr.loadGraphic(Paths.image('combo'));
		comboSpr.camera = camHUD;
		comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.6));
		comboSpr.updateHitbox();
		comboSpr.antialiasing = ClientPrefs.globalAntialiasing;

		add(comboSpr);
		
		comboNums = new FlxSpriteGroup();
		comboNums.camera = camHUD;
		add(comboNums);

		var seperatedScore:Array<Int> = [];
		for (i in 0...3)
		{
			seperatedScore.push(FlxG.random.int(0, 9));
		}

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite(43 * daLoop).loadGraphic(Paths.image('num' + i));
			numScore.camera = camHUD;
			numScore.setGraphicSize(Std.int(numScore.width * 0.45));
			numScore.updateHitbox();
			numScore.antialiasing = ClientPrefs.globalAntialiasing;
			comboNums.add(numScore);
			daLoop++;
		}

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.camera = camHUD;
		add(dumbTexts);
		createTexts();

		repositionCombo();

		beatText = new Alphabet(0, 0, 'Beat Hit!', true);
		beatText.scaleX = 0.6;
		beatText.scaleY = 0.6;
		beatText.x += 260;
		beatText.alpha = 0;
		beatText.acceleration.y = 250;
		beatText.visible = false;
		add(beatText);
		
		timeTxt = new FlxText(0, 600, FlxG.width, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;
		timeTxt.visible = false;
		timeTxt.camera = camHUD;

		barPercent = ClientPrefs.noteOffset;
		updateNoteDelay();
		
		timeBarBG = new FlxSprite(0, timeTxt.y + 8).loadGraphic(Paths.image('timeBar'));
		timeBarBG.setGraphicSize(Std.int(timeBarBG.width * 1.2));
		timeBarBG.updateHitbox();
		timeBarBG.camera = camHUD;
		timeBarBG.screenCenter(X);
		timeBarBG.visible = false;

		timeBar = new FlxBar(0, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this, 'barPercent', delayMin, delayMax);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800;
		timeBar.visible = false;
		timeBar.camera = camHUD;

		add(timeBarBG);
		add(timeBar);
		add(timeTxt);

		var blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.alpha = 0.6;
		blackBox.camera = camHUD;
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, "", 32);
		changeModeText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		changeModeText.scrollFactor.set();
		changeModeText.camera = camHUD;
		add(changeModeText);

		calibrateText = new FlxText(0, FlxG.height - 60, FlxG.width, "Press F for Auto-Calibration", 24);
		calibrateText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		calibrateText.camera = camHUD;
		calibrateText.borderSize = 1;
		add(calibrateText);

		helpText = new FlxText(0, FlxG.height - 30, FlxG.width, "Hold SHIFT to adjust by 10", 20);
		helpText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.LIME, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		helpText.camera = camHUD;
		helpText.borderSize = 1;
		add(helpText);

		updateMode();

		Conductor.changeBPM(128.0);
		FlxG.sound.playMusic(Paths.music('offsetSong'), 1, true);

        #if mobile
        addVirtualPad(LEFT_RIGHT, A_B_C);
        addVirtualPadCamera();
        #end

		super.create();
	}

	var holdTime:Float = 0;
	var onComboMenu:Bool = true;
	var holdingObjectType:Null<String> = null;
	var startMousePos:FlxPoint = new FlxPoint();
	var startComboOffset:FlxPoint = new FlxPoint();

	override public function update(elapsed:Float)
	{
		if (calibrating)
		{
			updateCalibration(elapsed);
			
			if (FlxG.keys.justPressed.ESCAPE)
			{
				cancelCalibration();
			}
			super.update(elapsed);
			return;
		}

		var addNum:Int = 1;
		if(FlxG.keys.pressed.SHIFT) addNum = 10;

		if(onComboMenu)
		{
			var controlArray:Array<Bool> = [
				controls.UI_LEFT_P,
				controls.UI_DOWN_P,
				controls.UI_UP_P,
				controls.UI_RIGHT_P
			];

			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
					{
						switch(i)
						{
							case 0:
								ClientPrefs.comboOffset[0] -= addNum;
							case 1:
								ClientPrefs.comboOffset[0] += addNum;
							case 2:
								ClientPrefs.comboOffset[1] += addNum;
							case 3:
								ClientPrefs.comboOffset[1] -= addNum;
							case 4:
								ClientPrefs.comboOffset[2] -= addNum;
							case 5:
								ClientPrefs.comboOffset[2] += addNum;
							case 6:
								ClientPrefs.comboOffset[3] += addNum;
							case 7:
								ClientPrefs.comboOffset[3] -= addNum;
						}
					}
				}
				repositionCombo();
			}

			if (FlxG.mouse.justPressed)
			{
				holdingObjectType = null;
				FlxG.mouse.getViewPosition(camHUD, startMousePos);
				if (startMousePos.x - comboNums.x >= 0 && startMousePos.x - comboNums.x <= comboNums.width &&
					startMousePos.y - comboNums.y >= 0 && startMousePos.y - comboNums.y <= comboNums.height)
				{
					holdingObjectType = "comboNums";
					startComboOffset.x = ClientPrefs.comboOffset[2];
					startComboOffset.y = ClientPrefs.comboOffset[3];
				}
				else if (startMousePos.x - rating.x >= 0 && startMousePos.x - rating.x <= rating.width &&
						 startMousePos.y - rating.y >= 0 && startMousePos.y - rating.y <= rating.height)
				{
					holdingObjectType = "rating";
					startComboOffset.x = ClientPrefs.comboOffset[0];
					startComboOffset.y = ClientPrefs.comboOffset[1];
				}
				else if (startMousePos.x - comboSpr.x >= 0 && startMousePos.x - comboSpr.x <= comboSpr.width &&
						 startMousePos.y - comboSpr.y >= 0 && startMousePos.y - comboSpr.y <= comboSpr.height)
				{
					holdingObjectType = "comboSpr";
					startComboOffset.x = ClientPrefs.comboOffset[4];
					startComboOffset.y = ClientPrefs.comboOffset[5];
				}
			}
			if(FlxG.mouse.justReleased) {
				holdingObjectType = null;
			}

			if(holdingObjectType != null)
			{
				if(FlxG.mouse.justMoved)
				{
					var mousePos:FlxPoint = FlxG.mouse.getViewPosition(camHUD);
					switch (holdingObjectType) {
						case "comboNums":
							ClientPrefs.comboOffset[2] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
							ClientPrefs.comboOffset[3] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
						case "rating":
							ClientPrefs.comboOffset[0] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
							ClientPrefs.comboOffset[1] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
						case "comboSpr":
							ClientPrefs.comboOffset[4] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
							ClientPrefs.comboOffset[5] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
					}
					repositionCombo();
				}
			}

			if(controls.RESET #if mobile || _virtualpad.buttonC.justPressed #end)
			{
				for (i in 0...ClientPrefs.comboOffset.length)
				{
					ClientPrefs.comboOffset[i] = 0;
				}
				repositionCombo();
			}
		}
		else
		{
			var addNum:Int = 1;
			if(FlxG.keys.pressed.SHIFT) addNum = 10;
			
			if(controls.UI_LEFT_P)
			{
				barPercent = Math.max(delayMin, Math.min(ClientPrefs.noteOffset - addNum, delayMax));
				updateNoteDelay();
			}
			else if(controls.UI_RIGHT_P)
			{
				barPercent = Math.max(delayMin, Math.min(ClientPrefs.noteOffset + addNum, delayMax));
				updateNoteDelay();
			}

			var mult:Int = addNum;
			if(controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;
				if(controls.UI_LEFT) mult = -addNum;
			}

			if(controls.UI_LEFT_R || controls.UI_RIGHT_R) holdTime = 0;

			if(holdTime > 0.5)
			{
				barPercent += 100 * elapsed * mult;
				barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));
				updateNoteDelay();
			}

			if(controls.RESET #if mobile || _virtualpad.buttonC.justPressed #end)
			{
				holdTime = 0;
				barPercent = 0;
				updateNoteDelay();
			}

			if (FlxG.keys.justPressed.F && !calibrating)
			{
				startCalibration();
			}
		}

		if(controls.ACCEPT)
		{
			onComboMenu = !onComboMenu;
			updateMode();
		}

		if(controls.BACK)
		{
			if (calibrating)
			{
				cancelCalibration();
				return;
			}

			zoomTween?.cancel();
			beatTween?.cancel();

			persistentUpdate = false;
			FlxG.switchState(() -> new OptionsState());
			if (OptionsState.onPlayState)
			{
				if (ClientPrefs.pauseMusic != "None")
					FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.pauseMusic)));
				else
					FlxG.sound.music.volume = 0;
			}
			else 
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}
			FlxG.mouse.visible = false;
		}

		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);
	}

	function updateCalibration(elapsed:Float):Void
	{
		if (!calibrating) return;
		
		Conductor.songPosition = FlxG.sound.music.time;
		
		for (note in calibrationNotes)
		{
			if (note?.exists)
			{
				note.y += noteSpeed * 45 * elapsed * 60;
				if (!note.hit && !note.missed && note.y > hitLineY + 50)
				{
					note.missed = true;
					calibrationNotes.remove(note);
					remove(note);
					note.destroy();
				}
			}
		}
		
		var keys:Array<Bool> = [
			controls.NOTE_LEFT,
			controls.NOTE_DOWN, 
			controls.NOTE_UP,
			controls.NOTE_RIGHT
		];
		
		for (i in 0...keys.length)
		{
			if (keys[i])
			{
				var pressTime = Date.now().getTime() - calibrationStartTime;

				var closestNote:CalibrationNote = null;
				var closestDistance:Float = 999999;
				
				for (note in calibrationNotes)
				{
					if (note.noteData == i && !note.hit && !note.missed)
					{
						var distance = Math.abs(note.y - hitLineY);
						if (distance < 150 && distance < closestDistance)
						{
							closestNote = note;
							closestDistance = distance;
						}
					}
				}
				
				if (closestNote != null)
				{
					closestNote.hit = true;
					notePressTimes.push(pressTime);
					
					var flightDistance:Float = hitLineY + 100;
					var speedPerSecond:Float = noteSpeed * 45 * 60;
					var flightTimeMs:Float = (flightDistance / speedPerSecond) * 1000;
					
					var expectedTime = closestNote.spawnTime + flightTimeMs;
					expectedTimes.push(expectedTime);
					
					if (strumNotes[i] != null)
					{
						strumNotes[i].playAnim('confirm', true);
						strumNotes[i].resetAnim = 0.1;
					}
					
					calibrationResult.text = 'Progress: ${notePressTimes.length}/16';
					
					calibrationNotes.remove(closestNote);
					remove(closestNote);
					closestNote.destroy();
				}
				else
				{
					if (strumNotes[i] != null)
					{
						strumNotes[i].playAnim('pressed', true);
						strumNotes[i].resetAnim = 0.1;
					}
				}
			}
		}
	}

	var zoomTween:FlxTween;
	var lastBeatHit:Int = -1;
	override public function beatHit()
	{
		super.beatHit();

		if(lastBeatHit == curBeat)
		{
			return;
		}

		if(curBeat % 2 == 0)
		{
			boyfriend.dance();
			gf.dance();
		}
		
		if(curBeat % 4 == 2)
		{
			FlxG.camera.zoom = 1.15;

			if(zoomTween != null) zoomTween.cancel();
			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1}, 1, {ease: FlxEase.circOut, onComplete: (_) ->
				{
					zoomTween = null;
				}
			});

			beatText.alpha = 1;
			beatText.y = 320;
			beatText.velocity.y = -150;
			if(beatTween != null) beatTween.cancel();
			beatTween = FlxTween.tween(beatText, {alpha: 0}, 1, {ease: FlxEase.sineIn, onComplete: (_) ->
				{
					beatTween = null;
				}
			});
		}

		lastBeatHit = curBeat;
	}

	function repositionCombo()
	{
		rating.screenCenter();
		rating.x = coolText.x + ClientPrefs.comboOffset[0] + 35;
		rating.y -= 70 + ClientPrefs.comboOffset[1];

		comboNums.screenCenter();
		comboNums.x = coolText.x - 15 + ClientPrefs.comboOffset[2];
		comboNums.y += 70 - ClientPrefs.comboOffset[3];

		comboSpr.screenCenter();
		comboSpr.x = coolText.x + ClientPrefs.comboOffset[4] + 125;
		comboSpr.y += 5 - ClientPrefs.comboOffset[5];
		reloadTexts();
	}

	function createTexts()
	{
		for (i in 0...6)
		{
			var text:FlxText = new FlxText(10, 48 + (i * 30), 0, '', 24);
			text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 2;
			dumbTexts.add(text);
			text.camera = camHUD;

			if(i > 1 || i > 3)
			{
				text.y += 24;
			}
		}
	}

	function reloadTexts()
	{
		for (i in 0...dumbTexts.length)
		{
			switch(i)
			{
				case 0: dumbTexts.members[i].text = 'Rating Offset:';
				case 1: dumbTexts.members[i].text = '[' + ClientPrefs.comboOffset[0] + ', ' + ClientPrefs.comboOffset[1] + ']';
				case 2: dumbTexts.members[i].text = 'Numbers Offset:';
				case 3: dumbTexts.members[i].text = '[' + ClientPrefs.comboOffset[2] + ', ' + ClientPrefs.comboOffset[3] + ']';
				case 4: dumbTexts.members[i].text = 'Combo Offset:';
				case 5: dumbTexts.members[i].text = '[' + ClientPrefs.comboOffset[4] + ', ' + ClientPrefs.comboOffset[5] + ']';
			}
		}
	}

	function updateNoteDelay()
	{
		ClientPrefs.noteOffset = Math.round(barPercent);
		var offsetText:String = Math.floor(barPercent) + ' ms';
		if (barPercent < 0) offsetText = Math.floor(barPercent) + ' ms';
		timeTxt.text = 'Current offset: ' + offsetText;
	}

	function updateMode()
	{
		for (vis in [rating, comboSpr, comboNums, dumbTexts])
			vis.visible = onComboMenu;

		for (unVis in [timeBarBG, timeBar, timeTxt, beatText, calibrateText, helpText])
			unVis.visible = !onComboMenu;

		changeModeText.text = onComboMenu ? '< Combo Offset (Press Accept to Switch) >' : '< Note/Beat Delay (Press Accept to Switch) >';
		changeModeText.text = changeModeText.text.toUpperCase();
		FlxG.mouse.visible = onComboMenu;
	}

	function startCalibration():Void
	{
		if (calibrating) return;
		
		trace("Starting automatic offset calibration with music...");
		
		calibrating = true;
		calibrationStep = 0;
		notePressTimes = [];
		expectedTimes = [];

		for (bomp in [rating, comboSpr, comboNums, dumbTexts, timeBarBG, timeBar, timeTxt, beatText, calibrateText, helpText])
			bomp.visible = false;
		
		if (calibrationProgress == null) {
			calibrationProgress = new FlxText(0, 50, FlxG.width, "", 32);
			calibrationProgress.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			calibrationProgress.borderSize = 2;
			calibrationProgress.camera = camHUD;
			add(calibrationProgress);
		}
		
		if (calibrationResult == null) {
			calibrationResult = new FlxText(0, 110, FlxG.width, "", 24);
			calibrationResult.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			calibrationResult.borderSize = 2;
			calibrationResult.camera = camHUD;
			add(calibrationResult);
		}
		
		calibrationProgress.visible = true;
		calibrationResult.visible = true;
		
		calibrationProgress.text = "Auto-Calibration\nPress arrow keys to the beat!";
		calibrationResult.text = "Starting on next beat...";
		
		Conductor.changeBPM(128.0);
		Conductor.songPosition = FlxG.sound.music.time;
		
		new FlxTimer().start(1, (_) -> {
			if (!calibrating) return;
			
			calibrationStartTime = Date.now().getTime();
			createStrumLine();
			spawnCalibrationNotes();
			
			calibrationResult.text = "Progress: 0/16";
		});
	}

	function createStrumLine():Void
	{
		strumLine = new FlxSpriteGroup();
		strumLine.camera = camHUD;
		add(strumLine);
		
		var strumY:Float = hitLineY;
		var strumX:Float = (FlxG.width / 2) - (noteSpacing * 2);
		
		for (i in 0...4)
		{
			var note:CalibrationStrum = new CalibrationStrum(strumX + (i * noteSpacing), strumY, i, 0);
			note.camera = camHUD;
			strumNotes.push(note);
			strumLine.add(note);
		}
	}

	function spawnCalibrationNotes():Void
	{
		calibrationNotes = [];
		spawnTimers = [];
		
		final startX = (FlxG.width / 2) - (noteSpacing * 2);
		final totalNotes:Int = 16;
		var notesSpawned:Int = 0;
		
		final curBeat = Math.floor(Conductor.songPosition / Conductor.crochet);
		final nextEvenBeat = (curBeat % 2 == 0) ? curBeat + 2 : curBeat + 1;
		final timeToNextEvenBeat = (nextEvenBeat * Conductor.crochet) - Conductor.songPosition;
		
		var startTimer = new FlxTimer().start(timeToNextEvenBeat / 1000, (_) -> {
			if (!calibrating) return;
			
			for (i in 0...totalNotes)
			{
				final noteData = i % 4;
				final beatDelay = i * 2;
				
				var noteTimer = new FlxTimer().start(beatDelay * (Conductor.crochet / 1000), (_) -> {
					if (!calibrating) return;
					
					var note = new CalibrationNote(startX + (noteData * noteSpacing), -100, noteData);
					note.camera = camHUD;
					note.scale.set(0.7, 0.7);
					note.updateHitbox();
					note.spawnTime = Date.now().getTime() - calibrationStartTime;
					
					calibrationNotes.push(note);
					add(note);
					
					notesSpawned++;
					if (notesSpawned >= totalNotes) {
						var finishTimer = new FlxTimer().start((Conductor.crochet * 2 / 1000) + 0.5, (_) -> {
							if (calibrating) finishCalibration();
						});
						spawnTimers.push(finishTimer);
					}
				});
				spawnTimers.push(noteTimer);
			}
		});
		spawnTimers.push(startTimer);
	}

	function finishCalibration():Void
	{
		calibrating = false;
		
		if (notePressTimes.length < 8)
		{
			calibrationProgress.text = "Not enough data!";
			calibrationResult.text = 'Hits: ${notePressTimes.length}/16 needed\nTry to hit more notes';
			cleanupCalibration();
			
			new FlxTimer().start(2, (_) -> {
				resetCalibrationUI();
				Conductor.songPosition = FlxG.sound.music.time;
			});
			return;
		}
		
		var delays:Array<Float> = [];

		notePressTimes.sort((a, b) -> return Std.int(a - b));
		expectedTimes.sort((a, b) -> return Std.int(a - b));
		
		var minLength = Std.int(Math.min(notePressTimes.length, expectedTimes.length));
		for (i in 0...minLength)
		{
			var delay = notePressTimes[i] - expectedTimes[i];
			if (Math.abs(delay) < 300)
			{
				delays.push(delay);
			}
		}
		
		if (delays.length == 0)
		{
			calibrationProgress.text = "Calibration failed";
			calibrationResult.text = "No valid hits detected\nTry to hit notes closer to the line";
			cleanupCalibration();
			
			new FlxTimer().start(3, (_) -> {
				resetCalibrationUI();
				Conductor.songPosition = FlxG.sound.music.time;
			});
			return;
		}
		
		var totalDelay:Float = 0;
		for (delay in delays)
		{
			totalDelay += delay;
		}

		final averageDelay:Float = totalDelay / delays.length;
		var newOffset = Math.round(averageDelay);
		var oldOffset = ClientPrefs.noteOffset;
		
		ClientPrefs.noteOffset = newOffset;
		barPercent = newOffset;
		updateNoteDelay();
		
		calibrationProgress.text = 'Calibration complete!';
		calibrationResult.text = 'New offset: ${Std.string(newOffset)} ms\n(was: ${Std.string(oldOffset)} ms)\nBased on ${delays.length} hits';
		
		ClientPrefs.saveSettings();
		cleanupCalibration();
		
		Conductor.songPosition = FlxG.sound.music.time;
		
		new FlxTimer().start(3, (_) -> {
			resetCalibrationUI();
		});
	}

	function cleanupCalibration():Void
	{
		for (timer in spawnTimers)
		{
			if (timer?.active)
				timer.cancel();
		}
		spawnTimers = [];
		
		for (note in calibrationNotes)
		{
			if (note != null)
			{
				remove(note);
				note.destroy();
			}
		}
		calibrationNotes = [];
		
		if (strumLine != null)
		{
			remove(strumLine);
			strumLine.destroy();
		}
		
		strumNotes = [];
		strumLine = null;
	}

	function resetCalibrationUI():Void
	{
		if (calibrationProgress != null) calibrationProgress.visible = false;
		if (calibrationResult != null) calibrationResult.visible = false;
		
		updateMode();
		
		calibrating = false;
	}

	function cancelCalibration():Void
	{
		calibrationTimer?.cancel();
		calibrating = false;

		for (timer in spawnTimers)
		{
			if (timer?.active)
				timer.cancel();
		}
		spawnTimers = [];
		
		if (beatTimer?.active)beatTimer.cancel();
		if (calibrationTimer?.active) calibrationTimer.cancel();
		
		cleanupCalibration();
		resetCalibrationUI();
		Conductor.songPosition = FlxG.sound.music.time;
	}
}

class CalibrationNote extends FlxSprite
{
	public var noteData:Int = 0;
	public var hit:Bool = false;
	public var missed:Bool = false;
	public var spawnTime:Float = 0;
	
	public function new(x:Float, y:Float, noteData:Int)
	{
		super(x, y);
		this.noteData = noteData;
		
		if (Paths.fileExists('images/NOTE_assets.png', IMAGE))
		{
			frames = Paths.getSparrowAtlas('NOTE_assets');
			antialiasing = ClientPrefs.globalAntialiasing;
			
			switch(noteData)
			{
				case 0:
					animation.addByPrefix('scroll', 'purple0');
				case 1:
					animation.addByPrefix('scroll', 'blue0');
				case 2:
					animation.addByPrefix('scroll', 'green0');
				case 3:
					animation.addByPrefix('scroll', 'red0');
			}
			
			animation.play('scroll');
			setGraphicSize(Std.int(width * 0.7));
		}
		else
		{
			makeGraphic(40, 40, getNoteColor(noteData));
		}
		
		updateHitbox();
		centerOrigin();
	}
	
	function getNoteColor(noteData:Int):FlxColor
	{
		return switch(noteData)
		{
			case 0: FlxColor.fromRGB(149, 75, 210);
			case 1: FlxColor.fromRGB(255, 0, 0);
			case 2: FlxColor.fromRGB(0, 255, 255);
			case 3: FlxColor.fromRGB(255, 255, 0);
			default: FlxColor.WHITE;
		}
	}
}

class CalibrationStrum extends FlxSprite
{
	public var noteData:Int = 0;
	public var resetAnim:Float = 0;
	
	private var player:Int;
	public static var swagWidth:Float = 160 * 0.7;

	public function new(x:Float, y:Float, leData:Int, player:Int) {
		this.noteData = leData;
		this.player = player;
		super(x, y);
		
		loadStrumTexture();
		playAnim('static');
	}

	function loadStrumTexture():Void {
		var skin:String = 'NOTE_assets';
		
		if(Paths.fileExists('images/NOTE_assets.png', IMAGE)) {
			frames = Paths.getSparrowAtlas(skin);
			
			setGraphicSize(Std.int(width * 0.7));
			updateHitbox();
			antialiasing = ClientPrefs.globalAntialiasing;
			
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		} else {
			makeGraphic(50, 50, getNoteColor(noteData));
		}
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		if(animation.getByName(anim) != null) {
			animation.play(anim, force);
			centerOffsets();
			centerOrigin();
		}
	}

	function getNoteColor(noteData:Int):FlxColor {
		return switch(Math.abs(noteData) % 4) {
			case 0: FlxColor.PURPLE;
			case 1: FlxColor.BLUE;
			case 2: FlxColor.GREEN;
			case 3: FlxColor.RED;
			default: FlxColor.WHITE;
		};
	}
}