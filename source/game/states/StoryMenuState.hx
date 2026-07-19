package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import game.backend.WeekData;
import game.states.objects.MenuItem;
import game.states.objects.MenuCharacter;

using StringTools;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	static var lastDifficultyName:String = '';
	static var curWeek:Int = 0;

	var scoreText:FlxText;
	var weekTitleText:FlxText;
	var tracklistText:FlxText;
	var background:FlxSprite;
	var yellowBg:FlxSprite;

	var weekTextGroup:FlxTypedGroup<MenuItem>;
	var weekCharactersGroup:FlxTypedGroup<MenuCharacter>;
	var lockGroup:FlxTypedGroup<FlxSprite>;
	var difficultyGroup:FlxGroup;

	var difficultySpr:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;

	var curDifficulty:Int = 1;
	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	var isMovingBack:Bool = false;
	var isWeekSelected:Bool = false;
	var isSelectionLocked:Bool = false;

	var loadedWeeks:Array<WeekData> = [];
	var difficultyTween:FlxTween;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);
		
		if (curWeek >= WeekData.weeksList.length) curWeek = 0;
		
		persistentUpdate = persistentDraw = true;
		loadAvailableWeeks();

		if (!isSoftcodedState())
		{
			if(FlxG.sound.music == null || !FlxG.sound.music.playing) 
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			
			createMenuInterface();
			setupInitialDisplay();
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		super.create();
	}

	function loadAvailableWeeks()
	{
		for (i in 0...WeekData.weeksList.length)
		{
			var week:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var locked:Bool = isWeekLocked(WeekData.weeksList[i]);
			
			if (!locked || !week.hiddenUntilUnlocked)
			{
				loadedWeeks.push(week);
			}
		}
	}

	function createMenuInterface()
	{
		createWeekSelection();
		createVisualElements();
		createTextElements();
		createWeekCharacters();
		createDifficultySelector();
	}

	function createTextElements()
	{
		scoreText = new FlxText(10, 10, 0, "WEEK SCORE: 0", 32);
		scoreText.setFormat("VCR OSD Mono", 32);

		weekTitleText = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		weekTitleText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, RIGHT);
		weekTitleText.alpha = 0.7;

		add(scoreText);
		add(weekTitleText);
	}

	function createVisualElements()
	{
		yellowBg = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		add(yellowBg);

		background = new FlxSprite(0, 56);
		add(background);

		var blackBar = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBar);

		var tracksSprite = new FlxSprite(FlxG.width * 0.07, background.y + 425).loadGraphic(Paths.image('Menu_Tracks'));
		add(tracksSprite);

		tracklistText = new FlxText(FlxG.width * 0.05, 0, 0, "", 32);
		tracklistText.alignment = CENTER;
		tracklistText.font = Paths.font("vcr.ttf");
		tracklistText.color = 0xFFe55777;
		tracklistText.y = tracksSprite.y + 60;
		add(tracklistText);
	}

	function createWeekSelection()
	{
		weekTextGroup = new FlxTypedGroup<MenuItem>();
		lockGroup = new FlxTypedGroup<FlxSprite>();

		add(weekTextGroup);
		add(lockGroup);

		var uiTexture = Paths.getSparrowAtlas('campaign_menu_UI_assets');

		for (i in 0...loadedWeeks.length)
		{
			var week = loadedWeeks[i];
			var locked = isWeekLocked(week.fileName);

			createWeekItem(week, i, locked, uiTexture);
		}
	}

	function createWeekItem(week:WeekData, index:Int, locked:Bool, uiTexture:FlxAtlasFrames)
	{
		var weekItem = new MenuItem(0, 56 + 396, week.fileName);
		weekItem.y += ((weekItem.height + 25) * index);
		weekItem.targetY = index;
		weekItem.screenCenter(X);
		weekTextGroup.add(weekItem);

		if (locked)
		{
			createLock(weekItem, index, uiTexture);
		}
	}

	function createLock(weekItem:MenuItem, index:Int, uiTexture:FlxAtlasFrames)
	{
		var lock = new FlxSprite(weekItem.width + 10 + weekItem.x);
		lock.frames = uiTexture;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.ID = index;
		lockGroup.add(lock);
	}

	function createDifficultySelector()
	{
		difficultyGroup = new FlxGroup();
		add(difficultyGroup);

		var uiTexture = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var firstWeekItem = weekTextGroup.members[0];

		leftArrow = new FlxSprite(firstWeekItem.x + firstWeekItem.width + 235, firstWeekItem.y + 10);
		leftArrow.frames = uiTexture;
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		difficultyGroup.add(leftArrow);

		difficultySpr = new FlxSprite(0, leftArrow.y);
		difficultyGroup.add(difficultySpr);

		rightArrow = new FlxSprite(leftArrow.x + 376, leftArrow.y);
		rightArrow.frames = uiTexture;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrow.animation.play('idle');
		difficultyGroup.add(rightArrow);

		initializeDifficulty();
	}

	function createWeekCharacters()
	{
		weekCharactersGroup = new FlxTypedGroup<MenuCharacter>();
		add(weekCharactersGroup);

		for (i in 0...3)
		{
			var character = new MenuCharacter((FlxG.width * 0.25) * (1 + i) - 150, '');
			character.y += 70;
			weekCharactersGroup.add(character);
		}
		updateWeekCharacters();
	}

	function initializeDifficulty()
	{
		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		
		if (lastDifficultyName == '') lastDifficultyName = CoolUtil.defaultDifficulty;
		
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));
		updateDifficultyDisplay();
	}

	function setupInitialDisplay()
	{
		updateWeekCharacters();
		updateWeekDisplay();
		updateDifficulty();
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		
		if (!isSoftcodedState())
			updateWeekDisplay();
		
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if (!isSoftcodedState())
		{
			updateScoreDisplay(elapsed);
			handleUserInput();
			updateLockPositions();
		}

		super.update(elapsed);
	}

	function updateScoreDisplay(elapsed:Float)
	{
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, MathUtil.boundTo(elapsed * 30, 0, 1)));
		
		if (Math.abs(intendedScore - lerpScore) < 10)
			lerpScore = intendedScore;

		scoreText.text = "WEEK SCORE:" + lerpScore;
	}

	function updateWeekCharacters()
	{
		var characters = loadedWeeks[curWeek].weekCharacters;
		for (i in 0...weekCharactersGroup.length)
			weekCharactersGroup.members[i].changeCharacter(i < characters.length ? characters[i] : '');
	}

	function handleUserInput()
	{
		if (!isMovingBack && !isWeekSelected && FlxG.state.subState == null)
		{
			handleWeekSelection();
			handleDifficultySelection();
			handleSpecialActions();
			handleNavigation();
		}
	}

	function handleWeekSelection()
	{
		var upPressed = controls.UI_UP_P;
		var downPressed = controls.UI_DOWN_P;

		if (upPressed)
		{
			changeWeek(-1);
		}

		if (downPressed)
		{
			changeWeek(1);
		}

		if (FlxG.mouse.deltaWheel.y != 0)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			changeWeek(Math.round(-FlxG.mouse.deltaWheel.y));
			updateDifficulty();
		}
	}

	function handleDifficultySelection()
	{
		updateArrowAnimations();

		var leftPressed = controls.UI_LEFT_P;
		var rightPressed = controls.UI_RIGHT_P;
		var upPressed = controls.UI_UP_P;
		var downPressed = controls.UI_DOWN_P;

		if (rightPressed)
			changeDifficulty(1);
		else if (leftPressed)
			changeDifficulty(-1);
		else if (upPressed || downPressed)
			updateDifficulty();
	}

	function updateArrowAnimations()
	{
		rightArrow.animation.play(controls.UI_RIGHT ? 'press' : 'idle');
		leftArrow.animation.play(controls.UI_LEFT ? 'press' : 'idle');
	}

	function handleSpecialActions()
	{
		if (FlxG.keys.justPressed.CONTROL)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if (controls.RESET)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
		}
		else if (controls.ACCEPT)
		{
			selectWeek();
		}
	}

	function handleNavigation()
	{
		if (controls.BACK && !isMovingBack && !isWeekSelected)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			isMovingBack = true;
			FlxG.switchState(() -> new MainMenuState());
		}
	}

	function updateLockPositions()
	{
		lockGroup.forEach(function(lock:FlxSprite)
		{
			lock.y = weekTextGroup.members[lock.ID].y;
			lock.visible = (lock.y > FlxG.height / 2);
		});
	}

	function selectWeek()
	{
		if (isWeekLocked(loadedWeeks[curWeek].fileName))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		if (isSelectionLocked) return;

		isSelectionLocked = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		weekTextGroup.members[curWeek].startFlashing();
		
		for (character in weekCharactersGroup.members)
		{
			if (character.character != '' && character.hasConfirmAnimation)
				character.animation.play('confirm');
		}

		// prepare playlist
		var songNames = loadedWeeks[curWeek].songs.map(song -> song[0]);
		PlayState.storyPlaylist = songNames;
		PlayState.isStoryMode = true;
		isWeekSelected = true;

		// load first song
		var difficultyPath = CoolUtil.getDifficultyFilePath(curDifficulty) ?? '';
		PlayState.storyDifficulty = curDifficulty;
		PlayState.SONG = Song.loadFromJson(
			PlayState.storyPlaylist[0].toLowerCase() + difficultyPath, 
			PlayState.storyPlaylist[0].toLowerCase()
		);

		// reset campaign stats
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;

		new FlxTimer().start(1, _ -> {
			LoadingState.loadAndSwitchState(() -> new PlayState(), true);
		});
	}

	function changeDifficulty(change:Int = 0)
	{
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, CoolUtil.difficulties.length - 1);
		updateDifficulty();
	}

	function updateDifficulty()
	{
		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var difficultyName = CoolUtil.difficulties[curDifficulty];
		lastDifficultyName = difficultyName;

		updateDifficultyDisplay();
		updateWeekScore();
	}

	function updateDifficultyDisplay()
	{
		var difficultyName = CoolUtil.difficulties[curDifficulty];
		var difficultyImg = Paths.image('menudifficulties/' + Paths.formatToSongPath(difficultyName));

		if (difficultySpr.graphic != difficultyImg)
		{
			difficultySpr.loadGraphic(difficultyImg);
			difficultySpr.x = leftArrow.x + 60;
			difficultySpr.x += (320 - difficultySpr.width) / 3;
			difficultySpr.alpha = 0;
			difficultySpr.y = leftArrow.y - 10;

			difficultyTween?.cancel();
			difficultyTween = FlxTween.tween(difficultySpr, 
				{y: leftArrow.y + 10, alpha: 1}, 0.07,
				{onComplete: _ -> difficultyTween = null}
			);
		}
	}

	function changeWeek(change:Int = 0)
	{
		if(loadedWeeks.length <= 1) return;

		FlxG.sound.play(Paths.sound('scrollMenu'));

		curWeek = FlxMath.wrap(curWeek + change, 0, loadedWeeks.length - 1);
		updateWeekDisplay();
	}

	function updateWeekDisplay()
	{
		var week = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(week);

		updateWeekTitle(week);
		updateWeekSelection();
		updateWeekBackground(week);
		updateWeekDifficulties(week);
		updateWeekCharacters();
		updateTracklist(week);
		updateWeekScore();
	}

	function updateWeekTitle(week:WeekData)
	{
		weekTitleText.text = week.storyName.toUpperCase();
		weekTitleText.x = FlxG.width - (weekTitleText.width + 10);
	}

	function updateWeekSelection()
	{
		var weekUnlocked = !isWeekLocked(loadedWeeks[curWeek].fileName);

		for (i in 0...weekTextGroup.members.length)
		{
			var item = weekTextGroup.members[i];
			item.targetY = i - curWeek;
			item.alpha = (item.targetY == 0 && weekUnlocked) ? 1 : 0.6;
		}
	}

	function updateWeekBackground(week:WeekData)
	{
		var backgroundAsset = week.weekBackground;
		
		if (backgroundAsset == null || backgroundAsset.length < 1)
		{
			background.visible = false;
		}
		else
		{
			background.loadGraphic(Paths.image('menubackgrounds/menu_' + backgroundAsset));
			background.visible = true;
		}
	}

	function updateWeekDifficulties(week:WeekData)
	{
		var weekUnlocked = !isWeekLocked(week.fileName);
		difficultyGroup.visible = weekUnlocked;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var difficultyString = week.difficulties;

		if (difficultyString != null && difficultyString.trim().length > 0)
		{
			var difficulties = difficultyString.split(',')
				.map(diff -> diff.trim())
				.filter(diff -> diff.length > 0);

			if (difficulties.length > 0)
				CoolUtil.difficulties = difficulties;
		}

		if (CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		else
			curDifficulty = 0;

		var storedPosition = CoolUtil.difficulties.indexOf(lastDifficultyName);
		if (storedPosition > -1)
			curDifficulty = storedPosition;

		PlayState.storyWeek = curWeek;
	}

	function updateTracklist(week:WeekData)
	{
		var trackNames = week.songs.map(song -> song[0]);
		tracklistText.text = trackNames.join('\n').toUpperCase();
		tracklistText.screenCenter(X);
		tracklistText.x -= FlxG.width * 0.35;
	}

	function updateWeekScore()
	{
		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}

	function isWeekLocked(weekName:String):Bool
	{
		var week = WeekData.weeksLoaded.get(weekName);
		return (!week.startUnlocked && week.weekBefore.length > 0 && 
			(!weekCompleted.exists(week.weekBefore) || !weekCompleted.get(week.weekBefore)));
	}
}