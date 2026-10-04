package game.backend;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;
import haxe.format.JsonParser;
import game.backend.system.Mods;
import game.backend.utils.FileUtil;

using StringTools;

typedef WeekFile =
{
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

class WeekData {
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public var folder:String = '';
	
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var freeplayColor:Array<Int>;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "dad", [146, 113, 253]], ["Fresh", "dad", [146, 113, 253]], ["Dad Battle", "dad", [146, 113, 253]]],
			weekCharacters: ['dad', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			freeplayColor: [146, 113, 253],
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};
		return weekFile;
	}

	public function new(weekFile:WeekFile, fileName:String) {
		songs = weekFile.songs;
		weekCharacters = weekFile.weekCharacters;
		weekBackground = weekFile.weekBackground;
		weekBefore = weekFile.weekBefore;
		storyName = weekFile.storyName;
		weekName = weekFile.weekName;
		freeplayColor = weekFile.freeplayColor;
		startUnlocked = weekFile.startUnlocked;
		hiddenUntilUnlocked = weekFile.hiddenUntilUnlocked;
		hideStoryMode = weekFile.hideStoryMode;
		hideFreeplay = weekFile.hideFreeplay;
		difficulties = weekFile.difficulties;

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();

		final disabledMods:Array<String> = [];
		#if MODS_ALLOWED
		final modsListPath = Paths.txt('modsList', false);
		if (FileUtil.exists(modsListPath)) {
			final stuff = CoolUtil.coolTextFile(modsListPath);
			for (line in stuff) {
				final splitName = line.trim().split('|');
				if(splitName.length >= 2 && splitName[1] == '0') disabledMods.push(splitName[0]);
			}
		}

		final directoriesToScan:Array<String> = Mods.enabledMods.copy();
		directoriesToScan.push(""); 

		for (mod in directoriesToScan) {
			if (mod != "" && disabledMods.contains(mod)) continue;

			final weekListPath = (mod == "") ? Paths.getPreloadPath('data/weeks/weekList.txt') : Mods.getModPath('$mod/data/weeks/weekList.txt');
			final weeksFolderPath = (mod == "") ? Paths.getPreloadPath('data/weeks') : Mods.getModPath('$mod/data/weeks');

			if (FileUtil.exists(weekListPath)) {
				final listContent = FileUtil.getContent(weekListPath);
				if (listContent != null) {
					final list = listContent.trim().replace('\r', '').split('\n');
					for (weekName in list) {
						if (weekName == null || weekName.trim().length == 0) continue;
						
						final path = (mod == "") ? Paths.getPreloadPath('data/weeks/$weekName.json') : Mods.getModPath('$mod/data/weeks/$weekName.json');
						if (FileUtil.exists(path) && !weeksLoaded.exists(weekName)) {
							addWeek(weekName, path, isStoryMode);
						}
					}
				}
			}

			#if sys
			if (FileSystem.exists(weeksFolderPath) && FileSystem.isDirectory(weeksFolderPath)) {
				var files = FileSystem.readDirectory(weeksFolderPath);
				files.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
				
				for (file in files) {
					if (!file.endsWith('.json') || file == 'weekList.json') continue;
					
					final weekName = haxe.io.Path.withoutExtension(file);
					final path = haxe.io.Path.join([weeksFolderPath, file]);
					
					if (!weeksLoaded.exists(weekName)) {
						addWeek(weekName, path, isStoryMode);
					}
				}
			}
			#end
		}
		#else
		final sexList:Array<String> = CoolUtil.coolTextFile(Paths.txt('weeks/weekList'));
		for (weekName in sexList) {
			if (weekName == null || weekName.trim().length == 0) continue;
			final path = Paths.getPath('data/weeks/$weekName.json', TEXT, null, true);
			if (FileUtil.exists(path)) addWeek(weekName, path, isStoryMode);
		}

		final weekFiles = FileUtil.listDirectory('data/weeks');
		for (file in weekFiles) {
			if (!file.endsWith('.json') || file.endsWith('weekList.json')) continue;
			final weekName = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(file));
			if (!weeksLoaded.exists(weekName)) addWeek(weekName, file, isStoryMode);
		}
		#end
	}

    private static function addWeek(weekToCheck:String, path:String, isStoryMode:Null<Bool>)
    {
        if(!weeksLoaded.exists(weekToCheck))
        {
            final week:WeekFile = getWeekFile(path);
            if(week != null)
            {
                final weekFile = new WeekData(week, weekToCheck);
                
                #if MODS_ALLOWED
                if (path.contains(Mods.MODS_FOLDER)) {
                    final modFolder = path.split(Mods.MODS_FOLDER + '/')[1];
                    if (modFolder != null)
                        weekFile.folder = modFolder.split('/')[0];
                }
                #end

                if((isStoryMode == null) || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))
                {
                    weeksLoaded.set(weekToCheck, weekFile);
                    weeksList.push(weekToCheck);
                }
            }
        }
    }

	private static function getWeekFile(path:String):WeekFile {
		final rawJson = FileUtil.getContent(path);
		if(rawJson?.length > 0) return cast Json.parse(rawJson);
		return null;
	}

	public static function getWeekFileName():String {
		return weeksList[PlayState.storyWeek];
	}

	public static function getCurrentWeek():WeekData {
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		#if MODS_ALLOWED
		Mods.currentModDirectory = '';
		if(data?.folder?.length > 0)
			Mods.currentModDirectory = data.folder;
		#end
	}

	public static function loadTheFirstEnabledMod()
	{
		#if MODS_ALLOWED
		Mods.currentModDirectory = '';
		#end
	}
}