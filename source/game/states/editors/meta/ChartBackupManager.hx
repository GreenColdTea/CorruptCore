package game.states.editors.meta;

import haxe.Json;
import openfl.events.Event;
import openfl.net.FileReference;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import flixel.FlxG;

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
    public static final VERSION:String = "1.0";
    
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
        File.saveContent(backupDir + backupFileName, Json.stringify(backupData, "\t"));
        #end
    }
    
    /**
     * Creates an automatic backup with current song data
     * @param songData Dynamic object containing song chart data
     */
    inline public function createAutoBackup(songData:Dynamic):Void {
        #if sys
        var json = {
            "song": songData,
            "timestamp": Date.now().toString(),
            "version": VERSION
        };

        var data:String = Json.stringify(json, "\t");
        createBackup(sanitizeFileName(editor._song.song) + ".json", data, "auto");
        #end
    }
    
    /**
     * Creates a manual backup with system-specific implementations:
     * - Desktop: Native file save dialog
     * - Systems with file access: Direct filesystem write
     * - Others: Fallback prompt about limitations
     * @param songData Dynamic object containing song chart data
     */
    inline public function createManualBackup(songData:Dynamic):Void {
        #if desktop
        var json = {
            "song": songData,
            "timestamp": Date.now().toString(),
            "version": VERSION
        };

        var data:String = Json.stringify(json, "\t");
        var sanitizedSongName = sanitizeFileName(editor._song.song);
        var fileRef = new FileReference();
        fileRef.save(data, '${sanitizedSongName}_backup_${Date.now().toString().replace(" ", "_").replace(":", "-")}.$BACKUP_EXTENSION');
        #else
        #if sys
        var json = {
            "song": songData,
            "timestamp": Date.now().toString(),
            "version": VERSION
        };

        var data:String = Json.stringify(json, "\t");
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
            // Handle different backup file formats
            if (backupData.data != null && Std.isOfType(backupData.data, String)) {
                var songData:Dynamic = Json.parse(backupData.data);
                if (songData.song != null) {
                    editor._song = songData.song;
                    editor.openSubState(new Prompt('Backup loaded successfully!\nTimestamp: ${backupData.timestamp != null ? backupData.timestamp : "Unknown"}', 1, () ->
                        editor.reloadAfterBackup(), null, false, "OK", null));
                } else {
                    editor.openSubState(new Prompt('Invalid backup file format', 1, () -> editor.closeSubState(), null, false, "OK", null));
                }
            }
            else if (backupData.song != null) {
                editor._song = backupData.song;
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
        return SUtil.getPath() + 'backups/charts/';
    }
}