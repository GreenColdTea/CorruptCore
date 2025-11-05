package game.backend;

import game.backend.Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

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
}

class Song
{
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
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
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

        // thanks to heaven that shadowmario added format variable to the new charts
		if (songJson.format != null)
		{
			var sectionsData:Array<SwagSection> = songJson.notes;

			if (sectionsData == null) return;
			
			for (section in sectionsData)
			{
				for (note in section.sectionNotes)
				{
					var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
					note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);
				}
			}
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

		#if MODS_ALLOWED
		var moddyFile:String = Mods.modsJson(formattedFolder + '/' + formattedSong);
		if(FileSystem.exists(moddyFile)) {
			rawJson = File.getContent(moddyFile).trim();
		}
		#end

		#if MODS_ALLOWED
		rawJson ??= File.getContent(Paths.json(formattedFolder + '/' + formattedSong)).trim();
		#else
		rawJson ??= Assets.getText(Paths.json(formattedFolder + '/' + formattedSong)).trim();
		#end

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
				if (parsedJson.format != null)
					swagShit = cast parsedJson;
				else if (parsedJson.song != null && Type.typeof(parsedJson.song) == TObject)
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
			splashSkin: 'noteSplashes',//idk it would crash if i didn't
			holdCoverSkin: 'holdCovers',
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			speed: 1,
			stage: 'stage',
			validScore: false
		};
	}
}
