package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

import lime.app.Application;

import game.states.backend.Achievements;
import game.states.editors.MasterEditorMenu;

using StringTools;

class MainMenuState extends MusicBeatState
{
	static var MENU_OPTIONS = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		#if ACHIEVEMENTS_ALLOWED 'awards', #end
		'credits',
		'options'
	];

	var menuItems:FlxTypedGroup<FlxSprite>;
	var background:FlxSprite;
	var overlay:FlxSprite;
	var versionText:FlxText;
	var camFollow:FlxObject;

	public static var curSelected:Int = 0;

	var isTransitioning:Bool = false;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		WeekData.loadTheFirstEnabledMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		initCamera();

		if (!isSoftcodedState())
		{
			if(!FlxG.sound.music.playing) FlxG.sound.playMusic(Paths.music('freakyMenu'));

			createMenuStuff();

			FlxG.camera.follow(camFollow, null, 0.17);

			#if ACHIEVEMENTS_ALLOWED
			checkFridayNightAchievement();
			#end
		}

		super.create();
	}

	function initCamera()
	{
		persistentUpdate = persistentDraw = true;
		initFNFCamera();
		add(camFollow = new FlxObject(0, 0, 1, 1));
	}

	function createMenuStuff()
	{
		createBackground();
		createMenuItems();
		createVersionText();
	}

	function createBackground()
	{
		var yScroll = Math.max(0.25 - (0.05 * (MENU_OPTIONS.length - 4)), 0.1);

		background = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		background.scrollFactor.set(0, yScroll);
		background.setGraphicSize(Std.int(background.width * 1.175));
		background.updateHitbox();
		background.screenCenter();
		background.antialiasing = ClientPrefs.globalAntialiasing;
		add(background);

		overlay = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		overlay.scrollFactor.set(0, yScroll);
		overlay.setGraphicSize(Std.int(overlay.width * 1.175));
		overlay.updateHitbox();
		overlay.screenCenter();
		overlay.visible = false;
		overlay.antialiasing = ClientPrefs.globalAntialiasing;
		overlay.color = 0xFFfd719b;
		add(overlay);
	}

	function createMenuItems()
	{
		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var itemSpacing = 140;
		var baseOffset = 108 - Math.max(MENU_OPTIONS.length - 4, 0) * 80;

		for (i in 0...MENU_OPTIONS.length)
		{
			var menuItem = createMenuItem(i, baseOffset + i * itemSpacing);
			menuItems.add(menuItem);
		}

		changeSelection();
	}

	function createMenuItem(id:Int, yPos:Float):FlxSprite
	{
		var menuItem = new FlxSprite(0, yPos);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + MENU_OPTIONS[id]);
		menuItem.antialiasing = ClientPrefs.globalAntialiasing;
		menuItem.animation.addByPrefix('idle', MENU_OPTIONS[id] + " basic", 24);
		menuItem.animation.addByPrefix('selected', MENU_OPTIONS[id] + " white", 24);
		menuItem.animation.play('idle');
		menuItem.centerOffsets();
		menuItem.screenCenter(X);
		menuItem.updateHitbox();
		menuItem.ID = id;

		var scrollFactor = (MENU_OPTIONS.length - 4) * 0.135;
		if (MENU_OPTIONS.length < 6) scrollFactor = 0;
		menuItem.scrollFactor.set(0, scrollFactor);

		return menuItem;
	}

	function createVersionText()
	{
		versionText = new FlxText(12, FlxG.height - 36, 0, getVersionString(), 12);
		versionText.scrollFactor.set();
		versionText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionText);
	}

	function getVersionString():String
	{
		var baseVersion = "Based on Psych Engine v0.6.3";
		var customVersion = "CorruptCore Engine v" + Application.current.meta.get('version');
		return '$baseVersion\n$customVersion';
	}

	#if ACHIEVEMENTS_ALLOWED
	function checkFridayNightAchievement()
	{
		var currentDate = Date.now();
		if (currentDate.getDay() == 5 && currentDate.getHours() >= 18) {
			var achieveID = Achievements.getAchievementIndex('friday_night_play');
			if (!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) {
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				unlockAchievement();
			}
		}
	}

	function unlockAchievement()
	{
		add(new AchievementObject('friday_night_play', new FlxCamera()));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
	}
	#end

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music?.volume < 0.8)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (!isTransitioning)
		{
			if (!isSoftcodedState())
			{
				handleInput();
			}
		}

		super.update(elapsed);
	}

	function handleInput()
	{
		if (controls.UI_UP_P)
			changeSelection(-1);
		else if (controls.UI_DOWN_P)
			changeSelection(1);
		else if (controls.BACK)
			exitToTitle();
		else if (controls.ACCEPT)
			selectMenuItem();
		#if desktop
		else if (FlxG.keys.anyJustPressed(ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'))))
			openEditors();
		#end
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));

		menuItems.members[curSelected].animation.play('idle');
		menuItems.members[curSelected].updateHitbox();

		curSelected = FlxMath.wrap(curSelected + change, 0, MENU_OPTIONS.length - 1);

		var selectedItem = menuItems.members[curSelected];
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();

		camFollow.setPosition(
			selectedItem.getGraphicMidpoint().x,
			selectedItem.getGraphicMidpoint().y - (MENU_OPTIONS.length > 4 ? MENU_OPTIONS.length * 8 : 0)
		);
	}

	function exitToTitle()
	{
		isTransitioning = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		FlxG.switchState(() -> new TitleState());
	}

	function selectMenuItem()
	{
		isTransitioning = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		if (ClientPrefs.flashing)
			FlxFlicker.flicker(overlay, 1.1, 0.15, false);

		FlxFlicker.flicker(menuItems.members[curSelected], 1, 0.06, false, false, (_) ->
		{
			transitionToSelectedState();
		});

		fadeOutUnselectedItems();
	}

	function fadeOutUnselectedItems()
	{
		for (item in menuItems.members)
		{
			if (item.ID != curSelected)
			{
				FlxTween.tween(item, {alpha: 0}, 0.4, {
					ease: FlxEase.quadOut,
					onComplete: (_) -> item.kill()
				});
			}
		}
	}

	function transitionToSelectedState()
	{
		switch (MENU_OPTIONS[curSelected])
		{
			case 'story_mode':
				FlxG.switchState(() -> new StoryMenuState());
			case 'freeplay':
				FlxG.switchState(() -> new FreeplayState());
			#if MODS_ALLOWED
			case 'mods':
				FlxG.switchState(() -> new ModsMenuState());
			#end
			#if ACHIEVEMENTS_ALLOWED
			case 'awards':
				FlxG.switchState(() -> new AchievementsMenuState());
			#end
			case 'credits':
				FlxG.switchState(() -> new CreditsState());
			case 'options':
				LoadingState.loadAndSwitchState(() -> new OptionsState());
				OptionsState.onPlayState = false;
		}
	}

	#if desktop
	function openEditors()
	{
		isTransitioning = true;
		FlxG.switchState(() -> new MasterEditorMenu());
	}
	#end
}