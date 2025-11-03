package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

import openfl.utils.Assets as OpenFlAssets;

using StringTools;

class CreditsState extends MusicBeatState
{
	static final CREDITS_DATA:Array<Array<String>> = [
		['CC Engine'],
		["JustX", "gct", "Creator of this fork", "", "FF0000"],
		["localisteer", "natella", "Beta-Tester, Bug Reporter and Big Guy", "https://x.com/nathanalogie", "7CA5E9"],
		["Sea3Plays", "sea3", "Active user and Bug reporter", "https://www.youtube.com/channel/UCtORhyWNUT18Trb4QrZMI0Q", "FF7F00"],
		[''],
		['Special Thanks To'],
		["MAJigsaw77", "majigsaw", "GLSL Es 300 and GLSL 330 support\n.MP4 Video Loader Library (hxvlc) and FlxGif", "https://x.com/MAJigsaw77", "5F5F5F"],
		["superpowers04", "superpowers04", "LUA JIT Fork", "https://x.com/superpowers04", "B957ED"],
		["MaybeMaru", "cheems", "Creator of Flixel-Animate", "https://x.com/maybemaru_", "dDF3DD"],
		["Slushi", "slushi", "Creator of Slushi Windows API", "https://github.com/Slushi-Github", "FFCBCF"],
		["Kriptel", "kriptel", "Creator of Rulescript", "https://x.com/kriptelpro", "8D4785"],
		["Nkreep", "nanokrip", "That guy who doesn't like Haxe", "https://x.com/narutokreep", "77F3FF"],
		[''],
		['PE Team'],
		["Shadow Mario", "shadowmario", "Main Programmer and Head of Psych Engine", "https://ko-fi.com/shadowmario", "444444"],
		["Riveren", "riveren", "Main Artist/Animator of Psych Engine", "https://x.com/riverennn", "14967B"],
		[''],
		['Former PE Members'],
		['bb-panzu', 'bb', 'Ex-Programmer of Psych Engine', 'https://x.com/bbsub3', '3E813A'],
		[''],
		['PE Contributors'],
		['iFlicky', 'flicky', 'Composer of Psync and Tea Time\nMade the Dialogue Sounds', 'https://x.com/flicky_i', '9E29CF'],
		['KadeDev', 'kade', 'Fixed some cool stuff on Chart Editor\nand other PRs', 'https://x.com/kade0912', '64A250'],
		['SqirraRNG', 'sqirra', 'Base code for\nChart Editor\'s Waveform', 'https://x.com/gedehari', 'E1843A'],
		['Keoiki', 'keoiki', 'Note Splash Animations', 'https://x.com/Keoiki_', 'D2D2D2'],
		[''],
		["Funkin' Crew"],
		['ninjamuffin99', 'ninjamuffin99', "Main Programmer of Friday Night Funkin'", 'https://x.com/ninja_muffin99', 'CF2D2D'],
		['EliteMasterEric', 'mastereric', "Programmer of Friday Night Funkin'", 'https://x.com/EliteMasterEric', 'FFBD40'],
		['PhantomArcade', 'phantomarcade', "Animator & Director of Friday Night Funkin'", 'https://x.com/PhantomArcade3K', 'FADC45'],
		['evilsk8r', 'evilsk8r', "Artist of Friday Night Funkin'", 'https://x.com/evilsk8r', '5ABD4B'],
		['kawaisprite', 'kawaisprite', "Composer of Friday Night Funkin'", 'https://x.com/kawaisprite', '378FC7']
	];

	var creditsOptions:FlxTypedGroup<Alphabet>;
	var iconArray:Array<AttachedSprite> = [];
	var creditsList:Array<Array<String>> = [];
	#if MODS_ALLOWED
	var processedMods:Array<String> = [];
	#end

	var background:FlxSprite;
	var descriptionText:FlxText;
	var descriptionBox:AttachedSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;
	var selectionTween:FlxTween;

	var curSelected:Int = -1;
	var isQuitting:Bool = false;
	var holdTime:Float = 0;
	final textOffset:Float = -75;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;
		initializeCredits();

		if (!isSoftcodedState()) {
			if(FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'));
			
			createInterface();
		}

		super.create();
	}

	function initializeCredits()
	{
		#if MODS_ALLOWED
		loadModCredits();
		#end

		for (item in CREDITS_DATA) creditsList.push(item);
	}

	#if MODS_ALLOWED
	function loadModCredits()
	{
		processedMods = [];

		// load from mods list file
		var modsListPath = Paths.txt('modsList');
		if (FileSystem.exists(modsListPath))
		{
			var modEntries = CoolUtil.coolTextFile(modsListPath);
			for (entry in modEntries)
			{
				if (modEntries.length > 1 && entry.length > 0)
				{
					var modData = entry.split('|');
					if (!Mods.ignoreModFolders.contains(modData[0].toLowerCase()) && !processedMods.contains(modData[0]))
					{
						if (modData[1] == '1')
							addModCredits(modData[0]);
						else
							processedMods.push(modData[0]);
					}
				}
			}
		}

		// load from mod directories
		var modFolders = Mods.getModDirectories();
		modFolders.push('');
		for (folder in modFolders)
		{
			addModCredits(folder);
		}
	}

	function addModCredits(folder:String)
	{
		if (processedMods.contains(folder)) return;

		var creditsFile = folder != null && folder.trim().length > 0 
			? Mods.getModPath(folder + '/data/credits.txt')
			: Mods.getModPath('data/credits.txt');

		if (FileSystem.exists(creditsFile))
		{
			var fileContent = File.getContent(creditsFile).split('\n');
			for (line in fileContent)
			{
				var creditEntry = line.replace('\\n', '\n').split("::");
				if (creditEntry.length >= 5) 
					creditEntry.push(folder);
				creditsList.push(creditEntry);
			}
			creditsList.push(['']);
		}
		processedMods.push(folder);
	}
	#end

	function createInterface()
	{
		createBackground();
		createCreditsList();
		createDescriptionPanel();
		setupInitialSelection();
	}

	function createBackground()
	{
		background = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		background.screenCenter();
		add(background);
	}

	function createCreditsList()
	{
		creditsOptions = new FlxTypedGroup<Alphabet>();
		add(creditsOptions);

		for (i in 0...creditsList.length)
		{
			var isSelectable = !isUnselectable(i);
			var option = new Alphabet(FlxG.width / 2, 300, creditsList[i][0], !isSelectable);
			option.isMenuItem = true;
			option.targetY = i;
			option.changeX = false;
			option.snapToPosition();
			
			if (!isSelectable)
				option.alignment = CENTERED;
			
			creditsOptions.add(option);

			if (isSelectable)
			{
				createIconForEntry(creditsList[i], option);
				if (curSelected == -1) 
					curSelected = i;
			}
		}
	}

	function createIconForEntry(entry:Array<String>, text:Alphabet)
	{
		if (entry[5] != null)
			Mods.currentModDirectory = entry[5];

		var icon = new AttachedSprite('credits/' + entry[1]);

		if(#if sys !FileSystem #else !OpenFlAssets #end .exists(Paths.getPath('images/credits/${entry[1]}.png', IMAGE, null, true))) 
			icon = new AttachedSprite('credits/missing_icon');

		icon.xAdd = text.width + 10;
		icon.sprTracker = text;

		iconArray.push(icon);
		add(icon);
		Mods.currentModDirectory = '';
	}

	function createDescriptionPanel()
	{
		descriptionBox = new AttachedSprite();
		descriptionBox.makeGraphic(1, 1, FlxColor.BLACK);
		descriptionBox.xAdd = -10;
		descriptionBox.yAdd = -10;
		descriptionBox.alphaMult = 0.6;
		descriptionBox.alpha = 0.6;
		add(descriptionBox);

		descriptionText = new FlxText(50, FlxG.height + textOffset - 25, 1180, "", 32);
		descriptionText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		descriptionText.scrollFactor.set();
		descriptionBox.sprTracker = descriptionText;
		add(descriptionText);
	}

	function setupInitialSelection()
	{
		background.color = getCurrentBackgroundColor();
		intendedColor = background.color;
		changeSelection();
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music?.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (!isQuitting)
		{
			if (!isSoftcodedState())
			{
				handleInput(elapsed);
				updateMenuItems(elapsed);
			}
			else if (controls.BACK)
			{
				exitState();
			}
		}

		super.update(elapsed);
	}

	function handleInput(elapsed:Float)
	{
		if (creditsList.length > 1)
		{
			var shiftMultiplier = FlxG.keys.pressed.SHIFT ? 3 : 1;
			handleSelectionInput(shiftMultiplier, elapsed);
		}

		if (controls.ACCEPT)
		{
			openSelectedLink();
		}

		if (controls.BACK)
		{
			exitState();
		}
	}

	function handleSelectionInput(shiftMultiplier:Int, elapsed:Float)
	{
		var upPressed = controls.UI_UP_P;
		var downPressed = controls.UI_DOWN_P;

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
			var lastHoldCheck = Math.floor((holdTime - 0.5) * 10);
			holdTime += elapsed;
			var newHoldCheck = Math.floor((holdTime - 0.5) * 10);

			if (holdTime > 0.5 && newHoldCheck - lastHoldCheck > 0)
			{
				changeSelection((newHoldCheck - lastHoldCheck) * (controls.UI_UP ? -shiftMultiplier : shiftMultiplier));
			}
		}
	}

	function updateMenuItems(elapsed:Float)
	{
		for (item in creditsOptions.members)
		{
			if (!item.bold)
			{
				var lerpValue = MathUtil.boundTo(elapsed * 12, 0, 1);
				if (item.targetY == 0)
				{
					var lastX = item.x;
					item.screenCenter(X);
					item.x = FlxMath.lerp(lastX, item.x - 70, lerpValue);
				}
				else
				{
					item.x = FlxMath.lerp(item.x, 200 + -40 * Math.abs(item.targetY), lerpValue);
				}
			}
		}
	}

	function openSelectedLink()
	{
		var selectedEntry = creditsList[curSelected];
		if (selectedEntry[3] != null && selectedEntry[3].length > 4)
		{
			CoolUtil.browserLoad(selectedEntry[3]);
		}
	}

	function exitState()
	{
		isQuitting = true;
		colorTween?.cancel();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		FlxG.switchState(() -> new MainMenuState());
	}

	function changeSelection(change:Int = 0)
	{
		if (isSoftcodedState()) return;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		
		do {
			curSelected = FlxMath.wrap(curSelected + change, 0, creditsList.length - 1);
		} while (isUnselectable(curSelected));

		updateBackgroundColor();
		updateSelectionDisplay();
		updateDescription();
	}

	function updateBackgroundColor()
	{
		var newColor = getCurrentBackgroundColor();
		if (newColor != intendedColor)
		{
			colorTween?.cancel();
			intendedColor = newColor;
			colorTween = FlxTween.color(background, 1, background.color, intendedColor, {
				onComplete: _ -> colorTween = null
			});
		}
	}

	function updateSelectionDisplay()
	{
		var index = 0;
		for (item in creditsOptions.members)
		{
			item.targetY = index - curSelected;
			index++;

			if (!isUnselectable(index - 1))
			{
				item.alpha = item.targetY == 0 ? 1 : 0.6;
			}
		}
	}

	function updateDescription()
	{
		descriptionText.text = creditsList[curSelected][2];
		descriptionText.y = FlxG.height - descriptionText.height + textOffset - 60;

		selectionTween?.cancel();
		selectionTween = FlxTween.tween(descriptionText, {y: descriptionText.y + 75}, 0.25, {
			ease: FlxEase.sineOut
		});

		descriptionBox.setGraphicSize(
			Std.int(descriptionText.width + 20), 
			Std.int(descriptionText.height + 25)
		);
		descriptionBox.updateHitbox();
	}

	function getCurrentBackgroundColor():Int
	{
		if (isSoftcodedState()) return FlxColor.BLACK;

		var colorString = creditsList[curSelected][4];
		if (!colorString.startsWith('0x'))
		{
			colorString = '0xFF' + colorString;
		}
		return Std.parseInt(colorString);
	}

	function isUnselectable(index:Int):Bool
	{
		if (isSoftcodedState()) return true;
		return creditsList[index].length <= 1;
	}
}