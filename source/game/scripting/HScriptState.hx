package game.scripting;

#if sys
import sys.FileSystem;
#end

import openfl.utils.Assets as OpenFlAssets;

class HScriptState extends MusicBeatState
{
    public var originalClassName:String = "";
    public var stateName:String = "";
    
    public function new(className:String) {
        this.originalClassName = className;
        
        var parts = className.split(".");
        this.stateName = parts[parts.length - 1];

        super();
    }

    override function create() {
        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        if (stateName != null && stateName != "") {
            var scriptFiles:Array<String> = [];
            var folders:Array<String> = Paths.getStateScripts(stateName);
            
            for (path in folders) {
                #if sys
                if (FileSystem.exists(path)) {
                    if (FileSystem.isDirectory(path)) {
                        for (file in FileSystem.readDirectory(path)) {
                            if (file.endsWith('.hx')) {
                                var fullPath = haxe.io.Path.join([path, file]);
                                scriptFiles.push(fullPath);
                            }
                        }
                    }
                    else if (path.endsWith('.hx')) {
                        scriptFiles.push(path);
                    }
                }
                #else
                if (OpenFlAssets.exists(path)) {
                    if (path.endsWith('.hx')) {
                        scriptFiles.push(path);
                    } else {
                        var prefix = path;
                        for (file in OpenFlAssets.list(AssetType.TEXT)) {
                            if (file.startsWith(prefix) && file.endsWith('.hx')) {
                                scriptFiles.push(file);
                            }
                        }
                    }
                }
                #end
            }

            for (path in scriptFiles) {
                try {
                    menuScriptArray.push(new FunkinHScript(path, this));
                    if (path.contains('contents/'))
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