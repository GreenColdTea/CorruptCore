package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.TransitionData;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;

import game.states.backend.Achievements;
import game.states.editors.MasterEditorMenu;

using StringTools;

class MainMenuState extends MusicBeatState
{
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;
	
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		#if ACHIEVEMENTS_ALLOWED 'awards', #end
		'credits',
		'options'
	];

	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;
	var debugKeys:Array<FlxKey>;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end
		WeekData.loadTheFirstEnabledMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end
		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		camGame = initFNFCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.add(camAchievement, false);

		persistentUpdate = persistentDraw = true;

		if (!isSoftcodedState())
		{
			var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);
			var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
			bg.scrollFactor.set(0, yScroll);
			bg.setGraphicSize(Std.int(bg.width * 1.175));
			bg.updateHitbox();
			bg.screenCenter();
			bg.antialiasing = ClientPrefs.globalAntialiasing;
			add(bg);

			camFollow = new FlxObject(0, 0, 1, 1);
			camFollowPos = new FlxObject(0, 0, 1, 1);
			add(camFollow);
			add(camFollowPos);

			magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
			magenta.scrollFactor.set(0, yScroll);
			magenta.setGraphicSize(Std.int(magenta.width * 1.175));
			magenta.updateHitbox();
			magenta.screenCenter();
			magenta.visible = false;
			magenta.antialiasing = ClientPrefs.globalAntialiasing;
			magenta.color = 0xFFfd719b;
			add(magenta);
			
			menuItems = new FlxTypedGroup<FlxSprite>();
			add(menuItems);

			var scale:Float = 1;
			for (i in 0...optionShit.length)
			{
				var offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
				var menuItem:FlxSprite = new FlxSprite(0, (i * 140)  + offset);
				menuItem.scale.x = scale;
				menuItem.scale.y = scale;
				menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
				menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
				menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
				menuItem.animation.play('idle');
				menuItem.ID = i;
				menuItem.screenCenter(X);
				menuItems.add(menuItem);
				var scr:Float = (optionShit.length - 4) * 0.135;
				if(optionShit.length < 6) scr = 0;
				menuItem.scrollFactor.set(0, scr);
				menuItem.antialiasing = ClientPrefs.globalAntialiasing;
				menuItem.updateHitbox();
			}

			var versionShit:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + '0.6.3', 12);
			versionShit.scrollFactor.set();
			versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(versionShit);
			var versionShit:FlxText = new FlxText(12, FlxG.height - 24, 0, "CorruptCore Engine v" + Application.current.meta.get('version'), 12);
			versionShit.scrollFactor.set();
			versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(versionShit);

			changeItem();

			#if ACHIEVEMENTS_ALLOWED
			Achievements.loadAchievements();
			var leDate = Date.now();
			if (leDate.getDay() == 5 && leDate.getHours() >= 18) {
				var achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
				if(!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2])) {
					Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
					giveAchievement();
					ClientPrefs.saveSettings();
				}
			}
			#end

			FlxG.camera.follow(camFollow, null, 0.6);
		}
		else
		{
			if(FlxG.sound.music == null) {
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			}
		}

		super.create();
	}

	#if ACHIEVEMENTS_ALLOWED
	function giveAchievement() {
		add(new AchievementObject('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		trace('Giving achievement "friday_night_play"');
	}
	#end

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
			if (FreeplayState.vocals != null)
				FreeplayState.vocals.volume += 0.5 * elapsed;
		}

		if (!isSoftcodedState() && !selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxG.switchState(() -> new TitleState());
			}

			if (controls.ACCEPT)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				if (optionShit[curSelected] == 'donate')
				{
					CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
				}
				else
				{
					selectedSomethin = true;

					if (ClientPrefs.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					FlxFlicker.flicker(menuItems.members[curSelected], 1, 0.06, false, false, function(flick:FlxFlicker)
					{
						switch (optionShit[curSelected])
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
					});

					for (i in 0...menuItems.members.length)
					{
						if (i == curSelected)
							continue;
						FlxTween.tween(menuItems.members[i], {alpha: 0}, 0.4, {
							ease: FlxEase.quadOut,
							onComplete: function(twn:FlxTween)
							{
								menuItems.members[i].kill();
							}
						});
					}
				}
			}
			#if desktop
			else if (FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				FlxG.switchState(() -> new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(huh:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		menuItems.members[curSelected].animation.play('idle');
		menuItems.members[curSelected].updateHitbox();
		menuItems.members[curSelected].screenCenter(X);

		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.members[curSelected].animation.play('selected');
		menuItems.members[curSelected].centerOffsets();
		menuItems.members[curSelected].screenCenter(X);

		camFollow.setPosition(menuItems.members[curSelected].getGraphicMidpoint().x,
			menuItems.members[curSelected].getGraphicMidpoint().y - (menuItems.length > 4 ? menuItems.length * 8 : 0));
	}
}