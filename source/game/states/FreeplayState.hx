package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import lime.utils.Assets;

import game.objects.HealthIcon;
import game.states.editors.ChartEditorState;

using StringTools;

class FreeplayState extends MusicBeatState
{
	static final DEFAULT_COLOR:FlxColor = 0xFF9271FD;

	var songs:Array<SongMetadata> = [];
	var grpSongs:FlxTypedGroup<Alphabet>;
	var iconArray:Array<HealthIcon> = [];

	var background:FlxSprite;
	var scoreBackground:FlxSprite;
	var scoreText:FlxText;
	var difficultyText:FlxText;
	var helpText:FlxText;

	var curDifficulty:Int = 0;

	static var curSelected:Int = 0;
	static var lastDifficultyName:String = '';

	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;
	var intendedColor:Int;
	var colorTween:FlxTween;

	var instPlaying:Int = -1;
	var holdTime:Float = 0;
	public static var vocals:FlxSound = null;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		loadAvailableSongs();

		if (!isSoftcodedState())
		{
			if(!FlxG.sound.music.playing) FlxG.sound.playMusic(Paths.music('freakyMenu'));
			
			createMenuInterface();
			setupNavigation();
		}

		super.create();
	}

	function loadAvailableSongs()
	{
		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i])) continue;

			var week:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(week);
			
			for (song in week.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];
				
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		WeekData.loadTheFirstEnabledMod();
	}

	function createMenuInterface()
	{
		createBackground();
		createSongList();
		createScoreDisplay();
		createHelpText();
	}

	function createBackground()
	{
		background = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		background.antialiasing = ClientPrefs.globalAntialiasing;
		background.screenCenter();
		add(background);

		if (songs.length > 0)
		{
			background.color = songs[curSelected].color;
			intendedColor = background.color;
		}
	}

	function createSongList()
	{
		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText = new Alphabet(90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			
			var maxWidth = 980;
			if (songText.width > maxWidth)
				songText.scaleX = maxWidth / songText.width;
			
			songText.snapToPosition();
			grpSongs.add(songText);

			Mods.currentModDirectory = songs[i].folder;
			var icon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			iconArray.push(icon);
			add(icon);
		}
		WeekData.setDirectoryFromWeek();
	}

	function createScoreDisplay()
	{
		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBackground = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBackground.alpha = 0.6;
		add(scoreBackground);

		difficultyText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		difficultyText.font = scoreText.font;
		add(difficultyText);

		add(scoreText);

		if (lastDifficultyName == '')
			lastDifficultyName = CoolUtil.defaultDifficulty;
		
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));
		
		updateSelection();
		updateDifficulty();
	}

	function createHelpText()
	{
		var textBackground = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		textBackground.alpha = 0.6;
		add(textBackground);

		#if PRELOAD_ALL
		var helpString = "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var textSize = 16;
		#else
		var helpString = "Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		var textSize = 18;
		#end

		helpText = new FlxText(textBackground.x, textBackground.y + 4, FlxG.width, helpString, textSize);
		helpText.setFormat(Paths.font("vcr.ttf"), textSize, FlxColor.WHITE, RIGHT);
		helpText.scrollFactor.set();
		add(helpText);
	}

	function setupNavigation()
	{
		if (songs.length > 0)
		{
			curSelected = Std.int(Math.min(curSelected, songs.length - 1));
			updateSelection();
		}
	}

	override function closeSubState()
	{
		if (!isSoftcodedState())
			updateSelection(0, false);
		
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var week:WeekData = WeekData.weeksLoaded.get(name);
		return (!week.startUnlocked && week.weekBefore.length > 0 && 
			(!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore)));
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music?.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (!isSoftcodedState())
		{
			updateScoreDisplay(elapsed);
			handleInput(elapsed);
		}

		super.update(elapsed);
	}

	function updateScoreDisplay(elapsed:Float)
	{
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, MathUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, MathUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2)
			ratingSplit.push('');
		
		while (ratingSplit[1].length < 2)
			ratingSplit[1] += '0';

		scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionScoreDisplay();
	}

	function handleInput(elapsed:Float)
	{
		if (songs.length == 0 || FlxG.state.subState != null) return;

		var upPressed = controls.UI_UP_P;
		var downPressed = controls.UI_DOWN_P;
		var leftPressed = controls.UI_LEFT_P;
		var rightPressed = controls.UI_RIGHT_P;
		var accepted = controls.ACCEPT;
		var spacePressed = FlxG.keys.justPressed.SPACE;
		var controlPressed = FlxG.keys.justPressed.CONTROL;
		var resetPressed = controls.RESET;
		var backPressed = controls.BACK;

		var shiftMultiplier = FlxG.keys.pressed.SHIFT ? 3 : 1;

		handleSelectionInput(upPressed, downPressed, shiftMultiplier, elapsed);
		handleDifficultyInput(leftPressed, rightPressed, upPressed, downPressed);
		handleSpecialInput(spacePressed, controlPressed, resetPressed, backPressed, accepted, shiftMultiplier);
	}

	function handleSelectionInput(upPressed:Bool, downPressed:Bool, shiftMultiplier:Int, elapsed:Float)
	{
		if (songs.length > 1)
		{
			if (upPressed)
			{
				changeSelection(-shiftMultiplier);
				holdTime = 0;
			}
			if (downPressed)
			{
				changeSelection(shiftMultiplier);
				holdTime = 0;
			}

			if (controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				{
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMultiplier : shiftMultiplier));
					updateDifficulty();
				}
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeSelection(-shiftMultiplier * FlxG.mouse.wheel, false);
				updateDifficulty();
			}
		}
	}

	function handleDifficultyInput(leftPressed:Bool, rightPressed:Bool, upPressed:Bool, downPressed:Bool)
	{
		if (CoolUtil.difficulties.length < 1) return;

		if (leftPressed)
			changeDifficulty(-1);
		else if (rightPressed)
			changeDifficulty(1);
		else if (upPressed || downPressed)
			updateDifficulty();
	}

	function handleSpecialInput(spacePressed:Bool, controlPressed:Bool, resetPressed:Bool, backPressed:Bool, accepted:Bool, shiftMultiplier:Int)
	{
		if (backPressed)
		{
			persistentUpdate = false;
			colorTween?.cancel();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(() -> new MainMenuState());
		}
		else if (controlPressed)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if (spacePressed)
		{
			previewSong();
		}
		else if (accepted)
		{
			startSong(FlxG.keys.pressed.SHIFT);
		}
		else if (resetPressed)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}

	function previewSong()
	{
		#if PRELOAD_ALL
		if (instPlaying != curSelected)
		{
			FlxG.sound.music.volume = 0;
			Mods.currentModDirectory = songs[curSelected].folder;
			var formattedSong = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
			PlayState.SONG = Song.loadFromJson(formattedSong, songs[curSelected].songName.toLowerCase());

			FlxG.sound?.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
			instPlaying = curSelected;
		}
		#end
	}

	function startSong(shiftPressed:Bool)
	{
		persistentUpdate = false;

		var songPath = Paths.formatToSongPath(songs[curSelected].songName);
		var formattedSong = Highscore.formatSong(songPath, curDifficulty);

		PlayState.SONG = Song.loadFromJson(formattedSong, songPath);
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = curDifficulty;

		colorTween?.cancel();
		
		LoadingState.loadAndSwitchState(() -> {
			return shiftPressed ? new ChartEditorState() : new PlayState();
		});

		FlxG.sound.music.volume = 0;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (playSound) 
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		updateSelection();
	}

	function updateSelection(change:Int = 0, updateDiff:Bool = true)
	{
		if (change != 0)
			curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);

		if (songs.length > 0)
		{
			updateBackgroundColor();
			updateSongDisplay();
			updateWeekData();

			if (updateDiff)
				updateDifficulty();
		}
	}

	function updateBackgroundColor()
	{
		var newColor = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			colorTween?.cancel();
			intendedColor = newColor;
			colorTween = FlxTween.color(background, 1, background.color, intendedColor, {
				onComplete: (_) -> colorTween = null
			});
		}
	}

	function updateSongDisplay()
	{
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		for (i in 0...iconArray.length)
			iconArray[i].alpha = 0.6;
		
		if (iconArray.length > curSelected)
			iconArray[curSelected].alpha = 1;

		var index = 0;
		for (item in grpSongs.members)
		{
			item.targetY = index - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
			index++;
		}
	}

	function updateWeekData()
	{
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr = WeekData.getCurrentWeek().difficulties;
		
		if (diffStr != null && diffStr.trim().length > 0)
		{
			var diffs = diffStr.split(',');
			var i = diffs.length - 1;
			while (i > 0)
			{
				if (diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1) 
						diffs.remove(diffs[i]);
				}
				--i;
			}

			if (diffs.length > 0 && diffs[0].length > 0)
				CoolUtil.difficulties = diffs;
		}
		
		if (CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		else
			curDifficulty = 0;

		var newPos = CoolUtil.difficulties.indexOf(lastDifficultyName);
		if (newPos > -1)
			curDifficulty = newPos;
	}

	function changeDifficulty(change:Int = 0)
	{
		if (CoolUtil.difficulties.length > 1)
		{
			curDifficulty = FlxMath.wrap(curDifficulty + change, 0, CoolUtil.difficulties.length - 1);
			updateDifficulty();
		}
	}

	function updateDifficulty()
	{
		if (CoolUtil.difficulties.length > 0)
		{
			curDifficulty = FlxMath.wrap(curDifficulty, 0, CoolUtil.difficulties.length - 1);
			lastDifficultyName = CoolUtil.difficulties[curDifficulty];
		}
		else
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		difficultyText.text = CoolUtil.difficulties.length <= 1 ? CoolUtil.difficultyString() : '< ' + CoolUtil.difficultyString() + ' >';
		positionScoreDisplay();
	}

	function positionScoreDisplay()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBackground.scale.x = FlxG.width - scoreText.x + 6;
		scoreBackground.x = FlxG.width - (scoreBackground.scale.x / 2);
		difficultyText.x = Std.int(scoreBackground.x + (scoreBackground.width / 2) - (difficultyText.width / 2));
	}
}

class SongMetadata
{
	public var songName:String;
	public var week:Int;
	public var songCharacter:String;
	public var color:Int;
	public var folder:String;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;

		this.folder ??= '';
	}
}