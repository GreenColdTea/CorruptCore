package game.scripting;

#if sys
import sys.FileSystem;
#end

import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;

class HScriptState extends MusicBeatState
{
    public var originalClassName:String = "";
    public var stateName:String = "";
    
    public function new(className:String) {
        this.originalClassName = className;
        
        var parts = className.split(".");
        stateName = parts[parts.length - 1];

        super();
    }

    override function create() {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (stateName != null && stateName != "") {
            var scriptFiles:Array<String> = [];
            var folders:Array<String> = Paths.getStateScripts(stateName);
            
            var processedFiles:Map<String, Bool> = new Map();
            
            for (path in folders) {
                var isDirectory = false;
                var isFile = false;
                
                #if sys
                if (FileSystem.exists(path)) {
                    if (FileSystem.isDirectory(path)) {
                        isDirectory = true;
                        for (file in FileSystem.readDirectory(path)) {
                            if (file.endsWith('.hx')) {
                                var fullPath = haxe.io.Path.join([path, file]);
                                if (!processedFiles.exists(fullPath)) {
                                    scriptFiles.push(fullPath);
                                    processedFiles.set(fullPath, true);
                                }
                            }
                        }
                    } else if (path.endsWith('.hx')) {
                        isFile = true;
                        if (!processedFiles.exists(path)) {
                            scriptFiles.push(path);
                            processedFiles.set(path, true);
                        }
                    }
                }
                #end
                
                if (!isDirectory && !isFile) {
                    if (OpenFlAssets.exists(path)) {
                        if (path.endsWith('.hx')) {
                            if (!processedFiles.exists(path)) {
                                scriptFiles.push(path);
                                processedFiles.set(path, true);
                            }
                        } else {
                            var prefix = path.endsWith('/') ? path : path + '/';
                            for (file in OpenFlAssets.list(TEXT)) {
                                if (file.startsWith(prefix) && file.endsWith('.hx') && !processedFiles.exists(file)) {
                                    scriptFiles.push(file);
                                    processedFiles.set(file, true);
                                }
                            }
                        }
                    }
                }
            }

            for (path in scriptFiles) {
                try {
                    menuScriptArray.push(new FunkinHScript(path, this));
                    if (path.contains('${Mods.MODS_FOLDER}/'))
                        trace('Loaded mod state script: $path');
                    else
                        trace('Loaded base game state script: $path');
                } catch (e:Dynamic) {
                    trace('Error loading script $path: $e');
                }
            }
        }
        #end

        super.create();
    }
}