package game.backend;

import game.backend.Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

import thx.semver.Version;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;

    var arrowSkin:String;
    var splashSkin:String;
	var holdCoverSkin:String;
	var stage:String;
    var validScore:Bool;

    @:optional var offset:Float;
    @:optional var format:String;
	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	@:optional var version:String;
}

class Song
{
	public static final CHART_VERSION:Version = "1.0.1";

	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var format:String = 'psych_v1';
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var holdCoverSkin:String;
	public var speed:Float = 1;
	public var stage:String;
	public var validScore:Bool = false; // МУСОР
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	private static function onLoadJson(songJson:Dynamic) // convert charts between formats
	{
		if(songJson.gfVersion == null)
		{
			if (songJson.player3 != null) {
				songJson.gfVersion = songJson.player3;
				songJson.player3 = null;
			} else if (songJson.gf != null) {
				songJson.gfVersion = songJson.gf;
				songJson.gf = null;
			}
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			if (songJson.notes != null && Std.isOfType(songJson.notes, Array))
			{
				for (secNum in 0...songJson.notes.length)
				{
					var sec:Dynamic = songJson.notes[secNum];

					var i:Int = 0;
					if (sec.sectionNotes != null && Std.isOfType(sec.sectionNotes, Array))
					{
						var notes:Array<Dynamic> = cast sec.sectionNotes;
						var len:Int = notes.length;
						while(i < len)
						{
							var note:Array<Dynamic> = notes[i];
							if(note[1] < 0)
							{
								//hl fix
								try {
									songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
								} catch (e) {}
								notes.remove(note);
								len = notes.length;
							}
							else i++;
						}
					}
				}
			}
		}
		
		final versionString:String = songJson.version != null ? Std.string(songJson.version) : "0.0.0";
		final chartVersion:Version = Version.stringToVersion(versionString);
		
		if (chartVersion < CHART_VERSION)
		{
			var sectionsData:Array<Dynamic> = cast songJson.notes;

			if (sectionsData == null) return;
			
			for (section in sectionsData)
			{
				if (section.sectionNotes != null && Std.isOfType(section.sectionNotes, Array))
				{
					var notes:Array<Dynamic> = cast section.sectionNotes;
					for (note in notes)
					{
						if (songJson.format == null) {
							final gottaHitNote = section.mustHitSection != (note[1] < 4);
							note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);
						} else {
							if (note[1] < 4)
								note[1] += 4;
							else if (note[1] < 8)
								note[1] -= 4;
						}

						if(!Std.isOfType(note[3], String))
							note[3] = game.states.editors.ChartEditorState.noteTypeList[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
					}
				}
			}
			
			songJson.version = CHART_VERSION.toString();
		}
	}

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		#if sys
		if (FileSystem.exists(Paths.json('songs/$formattedFolder/$formattedSong'))) 
			rawJson = File.getContent(Paths.json('songs/$formattedFolder/$formattedSong')).trim();
		else
		#end
			rawJson = Assets.getText(Paths.json('songs/$formattedFolder/$formattedSong')).trim();

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		var songJson:Dynamic = parseJSONshit(rawJson);
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var parsedJson:Dynamic = Json.parse(rawJson);
		var swagShit:SwagSong = null;
		
		switch (Type.typeof(parsedJson)) {
			case TObject:
				if (parsedJson.song != null && Type.typeof(parsedJson.song) == TObject)
					swagShit = cast parsedJson.song;
				else
					swagShit = cast parsedJson;
			default:
				swagShit = getDefaultSong();
		}
		
		return swagShit;
	}

	public static function getDefaultSong():SwagSong
	{
		return {
			song: 'Test',
			notes: [],
			events: [],
			bpm: 150.0,
			needsVoices: true,
			arrowSkin: '',
			splashSkin: game.objects.NoteSplash.defaultNoteSplash,//idk it would crash if i didn't
			holdCoverSkin: 'holdCovers',
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			speed: 1,
			stage: 'stage',
			validScore: true,
			version: CHART_VERSION.toString()
		};
	}
}