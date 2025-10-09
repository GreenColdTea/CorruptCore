package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end
import openfl.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
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
import lime.utils.Assets;

using StringTools;

class CreditsState extends MusicBeatState
{
	var curSelected:Int = -1;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<AttachedSprite> = [];
	private var creditsStuff:Array<Array<String>> = [];

	var bg:FlxSprite;
	var descText:FlxText;
	var intendedColor:Int;
	var colorTween:FlxTween;
	var descBox:AttachedSprite;

	var offsetThing:Float = -75;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;
		
		if (!isSoftcodedState())
		{
			bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
			add(bg);
			bg.screenCenter();
			
			grpOptions = new FlxTypedGroup<Alphabet>();
			add(grpOptions);

			#if MODS_ALLOWED
			var path:String = Paths.txt('modsList');
			if(FileSystem.exists(path))
			{
				var leMods:Array<String> = CoolUtil.coolTextFile(path);
				for (i in 0...leMods.length)
				{
					if(leMods.length > 1 && leMods[0].length > 0) {
						var modSplit:Array<String> = leMods[i].split('|');
						if(!Mods.ignoreModFolders.contains(modSplit[0].toLowerCase()) && !modsAdded.contains(modSplit[0]))
					{
							if(modSplit[1] == '1')
								pushModCreditsToList(modSplit[0]);
							else
								modsAdded.push(modSplit[0]);
						}
					}
				}
			}

			var arrayOfFolders:Array<String> = Mods.getModDirectories();
			arrayOfFolders.push('');
			for (folder in arrayOfFolders)
			{
				pushModCreditsToList(folder);
			}
			#end

			var pisspoop:Array<Array<String>> = [ //Name - Icon name - Description - Link - BG Color
				['CC Engine'],
				["JustX",                  "gct",           "Creator of this fork",                          "",                           "FF0000"],
				["localisteer",	            "natella",			"Beta-Tester, Bug Reporter and Big Guy",   "https://x.com/nathanalogie",	"7CA5E9"],
				["Sea3Plays",                "sea3",             "Active user and Bug reporter",           "https://www.youtube.com/channel/UCtORhyWNUT18Trb4QrZMI0Q", "FF7F00"],
				[''],
				['Special Thanks To'],
				["MAJigsaw77",			"majigsaw",			"GLSL Es 300 and GLSL 330 support\n.MP4 Video Loader Library (hxvlc) and FlxGif",    "https://x.com/MAJigsaw77",	"5F5F5F"],
				["superpowers04",		"superpowers04",	"LUA JIT Fork",												"https://x.com/superpowers04",		"B957ED"],
				["MaybeMaru",	           "cheems",			"Creator of Flixel-Animate",									"https://x.com/maybemaru_",	"dDF3DD"],
				["Slushi",	              "slushi",			"Creator of Slushi Windows API",									"https://https://github.com/Slushi-Github",	"FFCBCF"],
				["Kriptel",	             "kriptel",			"Creator of Rulescript",									"https://x.com/kriptelpro",	"8D4785"],
				["Nkreep",	          "nanokrip",			"That guy who doesn't like Haxe",   "https://x.com/narutokreep",	"77F3FF"],
				[''],
				['PE Team'],
				["Shadow Mario",		"shadowmario",		"Main Programmer and Head of Psych Engine",					"https://ko-fi.com/shadowmario",	"444444"],
				["Riveren",				"riveren",			"Main Artist/Animator of Psych Engine",						"https://x.com/riverennn",			"14967B"],
				[''],
				['Former PE Members'],
				['bb-panzu',			'bb',				'Ex-Programmer of Psych Engine',								'https://x.com/bbsub3',			'3E813A'],
				[''],
				['PE Contributors'],
				['iFlicky',				'flicky',			'Composer of Psync and Tea Time\nMade the Dialogue Sounds',		'https://x.com/flicky_i',			'9E29CF'],
				['KadeDev',				'kade',				'Fixed some cool stuff on Chart Editor\nand other PRs',			'https://x.com/kade0912',			'64A250'],
				['SqirraRNG',			'sqirra',			'Base code for\nChart Editor\'s Waveform',	'https://x.com/gedehari',			'E1843A'],
				['Keoiki',				'keoiki',			'Note Splash Animations',										'https://x.com/Keoiki_',			'D2D2D2'],
				[''],
				["Funkin' Crew"],
				['ninjamuffin99',		'ninjamuffin99',	"Main Programmer of Friday Night Funkin'",							'https://x.com/ninja_muffin99',	'CF2D2D'],
				['EliteMasterEric',		'mastereric',		"Programmer of Friday Night Funkin'",										'https://x.com/EliteMasterEric',	'FFBD40'],
				['PhantomArcade',		'phantomarcade',	"Animator & Director of Friday Night Funkin'",								'https://x.com/PhantomArcade3K',	'FADC45'],
				['evilsk8r',			'evilsk8r',			"Artist of Friday Night Funkin'",								'https://x.com/evilsk8r',			'5ABD4B'],
				['kawaisprite',			'kawaisprite',		"Composer of Friday Night Funkin'",								'https://x.com/kawaisprite',		'378FC7']
			];
			
			for(i in pisspoop){
				creditsStuff.push(i);
			}
		
			for (i in 0...creditsStuff.length)
			{
				var isSelectable:Bool = !unselectableCheck(i);
				var optionText:Alphabet = new Alphabet(FlxG.width / 2, 300, creditsStuff[i][0], !isSelectable);
				optionText.isMenuItem = true;
				optionText.targetY = i;
				optionText.changeX = false;
				optionText.snapToPosition();
				grpOptions.add(optionText);

				if(isSelectable) {
					if(creditsStuff[i][5] != null)
					{
						Mods.currentModDirectory = creditsStuff[i][5];
					}

					var icon:AttachedSprite = new AttachedSprite('credits/' + creditsStuff[i][1]);
					icon.xAdd = optionText.width + 10;
					icon.sprTracker = optionText;
		
					// using a FlxGroup is too much fuss!
					iconArray.push(icon);
					add(icon);
					Mods.currentModDirectory = '';

					if(curSelected == -1) curSelected = i;
				}
				else optionText.alignment = CENTERED;
			}
			
			descBox = new AttachedSprite();
			descBox.makeGraphic(1, 1, FlxColor.BLACK);
			descBox.xAdd = -10;
			descBox.yAdd = -10;
			descBox.alphaMult = 0.6;
			descBox.alpha = 0.6;
			add(descBox);

			descText = new FlxText(50, FlxG.height + offsetThing - 25, 1180, "", 32);
			descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER/*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
			descText.scrollFactor.set();
			//descText.borderSize = 2.4;
			descBox.sprTracker = descText;
			add(descText);

			bg.color = getCurrentBGColor();
			intendedColor = bg.color;
			changeSelection();
		}
		else
		{
			bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			add(bg);
		}

		super.create();
	}

	var quitting:Bool = false;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		if (!isSoftcodedState() && !quitting)
		{
			if(creditsStuff.length > 1)
			{
				var shiftMult:Int = 1;
				if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

				var upP = controls.UI_UP_P;
				var downP = controls.UI_DOWN_P;

				if (upP)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (downP)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}
			}

			if(controls.ACCEPT && (creditsStuff[curSelected][3] == null || creditsStuff[curSelected][3].length > 4)) {
				CoolUtil.browserLoad(creditsStuff[curSelected][3]);
			}
			if (controls.BACK)
			{
				if(colorTween != null) {
					colorTween.cancel();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxG.switchState(() -> new MainMenuState());
				quitting = true;
			}
			
			for (item in grpOptions.members)
			{
				if(!item.bold)
				{
					var lerpVal:Float = MathUtil.boundTo(elapsed * 12, 0, 1);
					if(item.targetY == 0)
					{
						var lastX:Float = item.x;
						item.screenCenter(X);
						item.x = FlxMath.lerp(lastX, item.x - 70, lerpVal);
					}
					else
					{
						item.x = FlxMath.lerp(item.x, 200 + -40 * Math.abs(item.targetY), lerpVal);
					}
				}
			}
		}
		else if (controls.BACK && !quitting)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(() -> new MainMenuState());
			quitting = true;
		}

		super.update(elapsed);
	}

	var moveTween:FlxTween = null;
	function changeSelection(change:Int = 0)
	{
		if (isSoftcodedState()) return;
		
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = creditsStuff.length - 1;
			if (curSelected >= creditsStuff.length)
				curSelected = 0;
		} while(unselectableCheck(curSelected));

		var newColor:Int =  getCurrentBGColor();
		if(newColor != intendedColor) {
			colorTween?.cancel();
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: _ -> colorTween = null
			});
		}

		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
				}
			}
		}

		descText.text = creditsStuff[curSelected][2];
		descText.y = FlxG.height - descText.height + offsetThing - 60;

		if(moveTween != null) moveTween.cancel();
		moveTween = FlxTween.tween(descText, {y : descText.y + 75}, 0.25, {ease: FlxEase.sineOut});

		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();
	}

	#if MODS_ALLOWED
	private var modsAdded:Array<String> = [];
	function pushModCreditsToList(folder:String)
	{
		if(modsAdded.contains(folder)) return;

		var creditsFile:String = null;
		if(folder != null && folder.trim().length > 0) creditsFile = Mods.getModPath(folder + '/data/credits.txt');
		else creditsFile = Mods.getModPath('data/credits.txt');

		if (FileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = File.getContent(creditsFile).split('\n');
			for(i in firstarray)
			{
				var arr:Array<String> = i.replace('\\n', '\n').split("::");
				if(arr.length >= 5) arr.push(folder);
				creditsStuff.push(arr);
			}
			creditsStuff.push(['']);
		}
		modsAdded.push(folder);
	}
	#end

	function getCurrentBGColor() {
		if (isSoftcodedState()) return FlxColor.BLACK;
		
		var bgColor:String = creditsStuff[curSelected][4];
		if(!bgColor.startsWith('0x')) {
			bgColor = '0xFF' + bgColor;
		}
		return Std.parseInt(bgColor);
	}

	private function unselectableCheck(num:Int):Bool {
		if (isSoftcodedState()) return true;
		
		return creditsStuff[num].length <= 1;
	}
}