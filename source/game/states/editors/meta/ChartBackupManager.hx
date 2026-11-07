package game.states.editors.meta;

import haxe.Json;
import openfl.events.Event;
import openfl.net.FileReference;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import flixel.FlxG;
import flixel.util.FlxSort;

import game.backend.Song;
import game.objects.Prompt;
import game.states.editors.ChartEditorState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Manages backup operations for chart files, including:
 * - Automatic versioned backups
 * - Manual backup creation
 * - Backup restoration functionality
 * - Version compatibility checking
 * 
 * @author JustX/GreenColdTea
 */
class ChartBackupManager
{
    /** Current version of the backup format */
    public static final VERSION:String = "2.0";
    
    /** File extension used for backup files */
    @:unreflective public static final BACKUP_EXTENSION:String = "ccb";
    
    private var editor:ChartEditorState;
    
    public function new(editor:ChartEditorState) {
        this.editor = editor;
    }
    
    /**
     * Sanitizes a filename by replacing invalid characters with underscores
     * @param name Original filename to sanitize
     * @return Sanitized filename safe for filesystem use
     */
    private function sanitizeFileName(name:String):String {
        var invalidChars = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"];
        for (char in invalidChars) {
            name = name.replace(char, "_");
        }
        return name;
    }

	private function generateCleanChartData(songObj:Dynamic):Dynamic {
		if (songObj.events != null) {
			var eventsArray:Array<Dynamic> = cast songObj.events;
			if(eventsArray.length > 1) {
				eventsArray = eventsArray.filter((event) -> return event != null);
				eventsArray.sort((a, b) -> return FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
				songObj.events = eventsArray;
			}
		}

		final exportNotes:Array<Dynamic> = [];
		final exportSections:Array<Dynamic> = []; 
		
		if (songObj.notes != null) {
			var notesArray:Array<Dynamic> = cast songObj.notes;
			for (i in 0...notesArray.length) {
				final sec:Dynamic = notesArray[i];
				
				exportSections.push({
					mustHit: sec.mustHitSection,
					gf: sec.gfSection,
					alt: sec.altAnim,
					beats: sec.sectionBeats != null ? sec.sectionBeats : 4
				});

				if (sec.sectionNotes != null) {
					var sectionNotesArray:Array<Dynamic> = cast sec.sectionNotes;
					for (note in sectionNotesArray) {
						final noteObj:Dynamic = { t: note[0], d: note[1] };
						if (note.length > 2 && note[2] > 0) noteObj.l = note[2];
						if (note.length > 3 && note[3] != "") noteObj.k = note[3];
						exportNotes.push(noteObj);
					}
				}
			}
		}
		exportNotes.sort((a:Dynamic, b:Dynamic) -> return Std.int(a.t - b.t));

		final exportEvents:Array<Dynamic> = [];
		var accumulatedTime:Float = 0;
		var currentBpm:Float = songObj.bpm;

		if (songObj.notes != null) {
			var notesArray:Array<Dynamic> = cast songObj.notes;
			for (i in 0...notesArray.length) {
				final sec:Dynamic = notesArray[i];
				if (sec != null) {
					if (sec.changeBPM && sec.bpm != currentBpm) {
						currentBpm = sec.bpm;
						
						var alreadyExists = false;
						if (songObj.events != null) {
							var eventsArray:Array<Dynamic> = cast songObj.events;
							for (eventNode in eventsArray) {
								if (Math.abs(eventNode[0] - accumulatedTime) < 1 && eventNode[1] != null) {
									var subEventsArray:Array<Dynamic> = cast eventNode[1];
									for (subEvent in subEventsArray) {
										if (subEvent[0] == "Change BPM") alreadyExists = true;
									}
								}
							}
						}

						if (!alreadyExists) {
							exportEvents.push({
								t: accumulatedTime,
								e: "Change BPM",
								v1: Std.string(currentBpm),
								v2: ""
							});
						}
					}
					final beats = sec.sectionBeats != null ? sec.sectionBeats : 4;
					accumulatedTime += beats * (1000 * 60 / currentBpm);
				}
			}
		}

		if (songObj.events != null) {
			var eventsArray:Array<Dynamic> = cast songObj.events;
			for (eventNode in eventsArray) {
				if (eventNode[1] != null) {
					var subEventsArray:Array<Dynamic> = cast eventNode[1];
					for (subEvent in subEventsArray) {
						exportEvents.push({
							t: eventNode[0],
							e: subEvent[0],
							v1: subEvent[1],
							v2: subEvent[2]
						});
					}
				}
			}
		}
		
		exportEvents.sort((a:Dynamic, b:Dynamic) -> return Std.int(a.t - b.t));

		return {
			version: Song.CHART_VERSION.toString(),
			meta: {
				song: songObj.song,
				bpm: songObj.bpm,
				speed: songObj.speed,
				needsVoices: songObj.needsVoices,
				stage: songObj.stage,
				characters: {
					player1: songObj.player1,
					player2: songObj.player2,
					gfVersion: songObj.gfVersion
				},
				assets: {
					arrowSkin: songObj.arrowSkin,
					splashSkin: songObj.splashSkin,
					holdCoverSkin: songObj.holdCoverSkin
				}
			},
			sections: exportSections,
			notes: exportNotes,
			events: exportEvents
		};
	}
    
    /**
     * Creates a backup file with metadata and timestamp information
     * @param fileName Original source filename
     * @param data Stringified chart data to backup
     * @param type Backup type identifier ("auto" or "manual")
     */
    inline public function createBackup(fileName:String, data:String, type:String = "auto"):Void {
        #if sys
        var backupDir = getBackupDir();

        if (!FileSystem.exists(backupDir))
            FileSystem.createDirectory(backupDir);

        // Generate timestamped filename with sanitized name
        var timestamp = Date.now().toString().replace(' ', '_').replace(':', '-').replace('.', '-');
        var sanitizedFileName = sanitizeFileName(fileName.replace('.json', ''));
        var backupFileName = sanitizedFileName + '_${type}_$timestamp.$BACKUP_EXTENSION';
        
        // Structure backup metadata
        var backupData = {
            "originalFileName": fileName,
            "data": data,
            "timestamp": timestamp,
            "type": type,
            "version": VERSION
        };
        
        // Write backup file to disk
        File.saveContent(backupDir + backupFileName, Json.stringify(backupData));
        #end
    }
    
    /**
     * Creates an automatic backup with current song data
     * @param songData Dynamic object containing song chart data
     */
    inline public function createAutoBackup(songData:Dynamic):Void {
        #if sys
		var cleanSong = generateCleanChartData(songData);

        var json = {
            "song": cleanSong,
            "timestamp": Date.now().toString(),
            "version": VERSION
        };

        var data:String = Json.stringify(json);
        createBackup(sanitizeFileName(editor._song.song) + ".json", data, "auto");
        #end
    }
    
    /**
     * Creates a manual backup with system-specific implementations
     * @param songData Dynamic object containing song chart data
     */
    inline public function createManualBackup(songData:Dynamic):Void {
		var cleanSong = generateCleanChartData(songData);
		
        #if desktop
        var json = {
            "song": cleanSong,
            "timestamp": Date.now().toString(),
            "version": VERSION
        };

        var data:String = Json.stringify(json);
        var sanitizedSongName = sanitizeFileName(editor._song.song);
        var fileRef = new FileReference();
        fileRef.save(data, '${sanitizedSongName}_backup_${Date.now().toString().replace(" ", "_").replace(":", "-")}.$BACKUP_EXTENSION');
        #else
        #if sys
        var json = {
            "song": cleanSong,
            "timestamp": Date.now().toString(),
            "version": VERSION
        };

        var data:String = Json.stringify(json);
        createBackup(sanitizeFileName(editor._song.song) + ".json", data, "manual");
        #else
        editor.openSubState(new Prompt('Backup creation is only available on desktop and mobile with file system access', 1, () ->
            editor.closeSubState(), null, false, "OK", null));
        #end
        #end
    }
    
    /**
     * Initiates backup loading process with platform-specific implementation:
     * Desktop: Native file browser dialog
     * Others: Limitations prompt
     */
    inline public function loadBackup():Void {
        #if desktop
        var fileFilter = new FileFilter('Chart Backup Files', '*.$BACKUP_EXTENSION');
        var fileRef = new FileReference();
        fileRef.addEventListener(Event.SELECT, function onFileSelected(e:Event) {
            fileRef.removeEventListener(Event.SELECT, onFileSelected);
            fileRef.addEventListener(Event.COMPLETE, onBackupLoaded);
            fileRef.addEventListener(IOErrorEvent.IO_ERROR, onBackupError);
            fileRef.load();
        });
        fileRef.browse([fileFilter]);
        #else
        editor.openSubState(new Prompt('Backup loading is only available on desktop', 1, () ->
            editor.closeSubState(), null, false, "OK", null));
        #end
    }
    
    /**
     * Handles successful backup file loading
     */
    inline private function onBackupLoaded(e:Event):Void {
        var fileRef:FileReference = cast e.target;
        fileRef.removeEventListener(Event.COMPLETE, onBackupLoaded);
        fileRef.removeEventListener(IOErrorEvent.IO_ERROR, onBackupError);
        
        try {
            var data:String = fileRef.data.toString();
            var backupData:Dynamic = Json.parse(data);
            
            // Version compatibility checking
            var backupVersion = backupData.version;
            var dataVersion = null;
            
            if (backupData.data != null && Std.isOfType(backupData.data, String)) {
                try {
                    var songData = Json.parse(backupData.data);
                    dataVersion = songData.version;
                } catch (e:Dynamic) {}
            }
            
            var versionToCheck = dataVersion != null ? dataVersion : backupVersion;
            
            if (versionToCheck != null && isNewerVersion(versionToCheck, VERSION)) {
                editor.openSubState(new Prompt('This backup was created with a newer version of the editor (${versionToCheck}). Loading it may cause issues. Continue?', 0, () ->
                    loadBackupData(backupData), () -> {}, editor.ignoreWarnings, "YES", "NO"));
            } else {
                loadBackupData(backupData);
            }
        } catch (e:Dynamic) {
            editor.openSubState(new Prompt('Error loading backup: $e', 1, () ->
                editor.closeSubState(), null, false, "OK", null));
        }
    }
    
    /**
     * Compares version strings to detect newer versions
     * @param backupVersion Version string from backup file
     * @param currentVersion Current application version
     */
    private function isNewerVersion(backupVersion:String, currentVersion:String):Bool {
        var backupParts = backupVersion.split('.');
        var currentParts = currentVersion.split('.');
        
        // Compare version segments numerically
        for (i in 0...Std.int(Math.max(backupParts.length, currentParts.length))) {
            var backupPart = i < backupParts.length ? Std.parseInt(backupParts[i]) : 0;
            var currentPart = i < currentParts.length ? Std.parseInt(currentParts[i]) : 0;
            
            if (backupPart > currentPart) return true;
            if (backupPart < currentPart) return false;
        }
        
        return false;
    }
    
    /**
     * Processes loaded backup data and applies to editor
     * @param backupData Parsed backup data structure
     */
    inline private function loadBackupData(backupData:Dynamic):Void {
        try {
            var chartToLoad:Dynamic = null;

            if (backupData.data != null && Std.isOfType(backupData.data, String)) {
                var songData:Dynamic = Json.parse(backupData.data);
                if (songData.song != null) chartToLoad = songData.song;
            }
            else if (backupData.song != null) {
                chartToLoad = backupData.song;
            }

            if (chartToLoad != null) {
                if (chartToLoad.version == null || chartToLoad.version != Song.CHART_VERSION.toString()) {
                    final oldRaw = Json.stringify(chartToLoad);
                    chartToLoad = Song.parseJSONshit(oldRaw);
                } else {
                    final raw = Json.stringify(chartToLoad);
                    chartToLoad = Song.parseJSONshit(raw);
                }
                
                chartToLoad = Song.cleanChart(chartToLoad);
                editor._song = chartToLoad;
                
                editor.openSubState(new Prompt('Backup loaded successfully!\nTimestamp: ${backupData.timestamp != null ? backupData.timestamp : "Unknown"}', 1, () ->
                    editor.reloadAfterBackup(), null, false, "OK", null));
            } else {
                editor.openSubState(new Prompt('Invalid backup file format', 1, () -> editor.closeSubState(), null, false, "OK", null));
            }
        } catch (e:Dynamic) {
            editor.openSubState(new Prompt('Error parsing backup data: $e', 1, () -> editor.closeSubState(), null, false, "OK", null));
        }
    }
    
    /**
     * Handles backup file loading errors
     */
    inline private function onBackupError(e:IOErrorEvent):Void {
        var fileRef:FileReference = cast e.target;
        fileRef.removeEventListener(Event.COMPLETE, onBackupLoaded);
        fileRef.removeEventListener(IOErrorEvent.IO_ERROR, onBackupError);
        
        editor.openSubState(new Prompt('Error loading backup file', 1, () ->
            editor.closeSubState(), null, false, "OK", null));
    }
    
    /**
     * Returns the directory path for backup files
     * @return String path to backup directory
     */
    inline private function getBackupDir():String {
        return 'backups/charts/';
    }
}