package game.backend;

import haxe.Json;
import haxe.format.JsonParser;

import flixel.addons.sound.FlxRhythmConductor;
import flixel.addons.sound.MusicTimeChangeEvent;

import lime.utils.Assets;

import thx.semver.Version;

import game.backend.Section.SwagSection;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

typedef ChartNote = {
	var t:Float;
	var d:Int;
	@:optional var l:Float;
	@:optional var k:String;
}

typedef ChartEvent = {
	var t:Float;
	var e:String;
	var v1:String;
	var v2:String;
}

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
	public static final CHART_VERSION:Version = "2.0.0";

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
	public var validScore:Bool = false;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	private static function onLoadJson(songJson:Dynamic) 
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
					final sec:Dynamic = songJson.notes[secNum];

					var i:Int = 0;
					if (sec.sectionNotes != null && Std.isOfType(sec.sectionNotes, Array))
					{
						final notes:Array<Dynamic> = cast sec.sectionNotes;

						var len:Int = notes.length;
						while(i < len)
						{
							var note:Array<Dynamic> = notes[i];
							if(note[1] < 0)
							{
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
		
		if (chartVersion < "1.0.1")
		{
			final sectionsData:Array<Dynamic> = cast songJson.notes;
			if (sectionsData == null) return;
			
			for (section in sectionsData)
			{
				if (section.sectionNotes != null && Std.isOfType(section.sectionNotes, Array))
				{
					final notes:Array<Dynamic> = cast section.sectionNotes;
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
							note[3] = game.states.editors.ChartEditorState.noteTypeList[note[3]];
					}
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
		
		final formattedFolder:String = SongUtil.formatToSongPath(folder);
		final formattedSong:String = SongUtil.formatToSongPath(jsonInput);

		#if sys
		if (FileSystem.exists(Paths.json('songs/$formattedFolder/$formattedSong'))) 
			rawJson = File.getContent(Paths.json('songs/$formattedFolder/$formattedSong')).trim();
		else
		#end
			rawJson = Assets.getText(Paths.json('songs/$formattedFolder/$formattedSong')).trim();
		
		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);
		
		var songJson:SwagSong = parseJSONshit(rawJson);
		songJson = cleanChart(songJson);

		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		
		if (songJson.version != "2.0.0") 
		{
			onLoadJson(songJson);
			songJson.version = CHART_VERSION.toString();
		}
		
		return songJson;
	}

	public static function cleanChart(song:SwagSong):SwagSong
	{
		if (song.notes != null) {
			for (section in song.notes) {
				if (section?.sectionNotes != null) {
					final uniqueNotes:Array<Dynamic> = [];

					for (note in section.sectionNotes) 
					{
						var isDup:Bool = false;
						for (uNote in uniqueNotes) 
						{
							if (Math.abs(uNote[0] - note[0]) < 1 && uNote[1] == note[1]) 
							{
								isDup = true;
								break;
							}
						}
						if (!isDup) uniqueNotes.push(note);
					}

					section.sectionNotes = uniqueNotes;
				}
			}
		}

		if (song.events != null) 
		{
			final timeMap:Map<String, Array<Dynamic>> = new Map();
			final newEvents:Array<Dynamic> = [];
			
			for (eventNode in song.events) 
			{
				if (eventNode == null || eventNode[1] == null) continue;
				
				final timeKey = Std.string(Math.round(eventNode[0])); 
				
				if (!timeMap.exists(timeKey))
					timeMap.set(timeKey, []);
				
				final existingSubEvents = timeMap.get(timeKey);
				for (subEvent in cast(eventNode[1], Array<Dynamic>)) 
				{
					var isSubDup:Bool = false;

					for (e in existingSubEvents) 
					{
						if (e[0] == subEvent[0] && e[1] == subEvent[1] && e[2] == subEvent[2]) 
						{
							isSubDup = true;
							break;
						}
					}
					
					if (!isSubDup) existingSubEvents.push(subEvent);
				}
			}
			
			for (timeKey in timeMap.keys())
			{
				final subEvents = timeMap.get(timeKey);
				if (subEvents.length > 0)
					newEvents.push([Std.parseFloat(timeKey), subEvents]);
			}
			
			newEvents.sort((a:Dynamic, b:Dynamic) -> {
				if (a[0] < b[0]) return -1;
				if (a[0] > b[0]) return 1;
				return 0;
			});
			
			song.events = newEvents;
		}

		return song;
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var parsedJson:Dynamic = Json.parse(rawJson);
		var swagShit:SwagSong = null;
		
		if (parsedJson.version == "2.0.0") 
		{
			swagShit = getDefaultSong();
			
			if (parsedJson.meta != null) 
			{
				swagShit.song = parsedJson.meta.song;
				swagShit.bpm = parsedJson.meta.bpm;
				swagShit.speed = parsedJson.meta.speed;
				swagShit.needsVoices = parsedJson.meta.needsVoices;
				swagShit.stage = parsedJson.meta.stage;
				
				if (parsedJson.meta.characters != null) 
				{
					swagShit.player1 = parsedJson.meta.characters.player1;
					swagShit.player2 = parsedJson.meta.characters.player2;
					swagShit.gfVersion = parsedJson.meta.characters.gfVersion;
				}
				
				if (parsedJson.meta.assets != null) 
				{
					swagShit.arrowSkin = parsedJson.meta.assets.arrowSkin;
					swagShit.splashSkin = parsedJson.meta.assets.splashSkin;
					swagShit.holdCoverSkin = parsedJson.meta.assets.holdCoverSkin;
				}
			}
			
			swagShit.notes = mapFlatNotesToSections(parsedJson.notes, parsedJson.events, parsedJson.sections, swagShit.bpm);
			swagShit.events = mapFlatEventsToEngine(parsedJson.events);
			swagShit.version = CHART_VERSION.toString();
			
		} else {
			switch (Type.typeof(parsedJson)) 
			{
				case TObject:
					if (parsedJson.song != null && Type.typeof(parsedJson.song) == TObject)
						swagShit = cast parsedJson.song;
					else
						swagShit = cast parsedJson;
				default:
					swagShit = getDefaultSong();
			}
		}
		
		return swagShit;
	}

	private static function mapFlatNotesToSections(flatNotes:Array<ChartNote>, flatEvents:Array<ChartEvent>, flatSections:Array<Dynamic>, baseBpm:Float):Array<SwagSection> {
		var sections:Array<SwagSection> = [];
		
		final timeEvents:Array<MusicTimeChangeEvent> = [
			new MusicTimeChangeEvent(0, baseBpm)
		];
		
		final bpmChangeMap:Map<Int, Float> = new Map();
		
		if (flatEvents != null) {
			for (ev in flatEvents) {
				if (ev.e == "Change BPM") 
				{
					final newBpm = Std.parseFloat(ev.v1);
					if (!Math.isNaN(newBpm)) {
						timeEvents.push(new MusicTimeChangeEvent(ev.t, newBpm));
					}
				}
			}
		}
		
		timeEvents.sort((a, b) -> return Std.int(a.time - b.time));
		
		FlxRhythmConductor.instance.setupTimeChanges(timeEvents);
		
		for (event in timeEvents) 
		{
			if (event.time >= 0) 
			{
				final secIdx = Math.floor(Conductor.getStep(event.time) / 16);
				bpmChangeMap.set(secIdx, event.bpm);
			}
		}

		var maxStep:Float = 0;
		if (flatNotes != null) {
			for (note in flatNotes) {
				final s = Conductor.getStep(note.t);
				if (s > maxStep) maxStep = s;
			}
		}
		for (ev in timeEvents) {
			final s = Conductor.getStep(ev.time);
			if (s > maxStep) maxStep = s;
		}

		final maxSectionIndex = Math.floor(maxStep / 16) + 2;
		
		var curBpm = baseBpm;
		while (sections.length <= maxSectionIndex) {
			final curIdx = sections.length;
			final isBpmChanged = bpmChangeMap.exists(curIdx);
			
			if (isBpmChanged)
				curBpm = bpmChangeMap.get(curIdx);
			
			var sMustHit = false;
			var sGf = false;
			var sAlt = false;
			var sBeats:Float = 4;

			if (flatSections != null && curIdx < flatSections.length) {
				final secData = flatSections[curIdx];
				if (secData != null) {
					sMustHit = secData.mustHit == true;
					sGf = secData.gf == true;
					sAlt = secData.alt == true;
					if (secData.beats != null) sBeats = secData.beats;
				}
			}
			
			sections.push({
				sectionNotes: [], 
				sectionBeats: sBeats, 
				mustHitSection: sMustHit, 
				changeBPM: isBpmChanged, 
				bpm: curBpm, 
				gfSection: sGf, 
				typeOfSection: 0, 
				altAnim: sAlt
			});
		}

		if (flatNotes != null) {
			for (note in flatNotes) {
				final currentStep = Conductor.getStep(note.t);
				final sectionIndex:Int = Math.floor(currentStep / 16);
				
				if (sectionIndex >= 0 && sectionIndex < sections.length) {
					final engineNote:Array<Dynamic> = [note.t, note.d, note.l ?? 0];
					if (note.k != null && note.k != "") engineNote.push(note.k);
					sections[sectionIndex].sectionNotes.push(engineNote);
				}
			}
		}
		
		return sections;
	}

	private static function mapFlatEventsToEngine(flatEvents:Array<ChartEvent>):Array<Dynamic> {
		var events:Array<Dynamic> = [];
		if (flatEvents == null) return events;
		
		final timeMap:Map<String, Array<Dynamic>> = new Map();
		
		for (ev in flatEvents) 
		{
			final timeKey = Std.string(ev.t);
			if (!timeMap.exists(timeKey)) timeMap.set(timeKey, []);
			
			final eventDetail = [ev.e, ev.v1 ?? "", ev.v2 ?? ""];
			timeMap.get(timeKey).push(eventDetail);
		}
		
		for (timeKey in timeMap.keys())
			events.push([Std.parseFloat(timeKey), timeMap.get(timeKey)]);
		
		events.sort((a:Dynamic, b:Dynamic) -> {
			if (a[0] < b[0]) return -1;
			if (a[0] > b[0]) return 1;
			return 0;
		});
		
		return events;
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
			splashSkin: game.objects.NoteSplash.defaultNoteSplash,
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