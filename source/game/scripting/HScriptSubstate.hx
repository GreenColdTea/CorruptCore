package game.scripting;

import openfl.utils.Assets as OpenFlAssets;
#if sys
import sys.FileSystem;
#end

class HScriptSubstate extends MusicBeatSubstate
{
	public static var substate:String = "";
	
	public function new(_substate:String)
	{
		super();
		substate = _substate;
		
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		for (sc in menuScriptArray) sc.stop();
		menuScriptArray = [];
		
		var scriptFiles:Array<String> = [];
		var folders:Array<String> = Paths.getSubstateScripts(substate);
		
		var processedFiles:Map<String, Bool> = new Map();
		
		for (folder in folders) {
			var isDirectory = false;
			var isFile = false;
			
			#if sys
			if (FileSystem.exists(folder)) {
				if (FileSystem.isDirectory(folder)) {
					isDirectory = true;
					for (file in FileSystem.readDirectory(folder)) {
						if (file.endsWith('.hx')) {
							var fullPath = haxe.io.Path.join([folder, file]);
							if (!processedFiles.exists(fullPath)) {
								scriptFiles.push(fullPath);
								processedFiles.set(fullPath, true);
							}
						}
					}
				} else if (folder.endsWith('.hx')) {
					isFile = true;
					if (!processedFiles.exists(folder)) {
						scriptFiles.push(folder);
						processedFiles.set(folder, true);
					}
				}
			}
			#end
			
			if (!isDirectory && !isFile) {
				if (OpenFlAssets.exists(folder)) {
					if (folder.endsWith('.hx')) {
						if (!processedFiles.exists(folder)) {
							scriptFiles.push(folder);
							processedFiles.set(folder, true);
						}
					} else {
						var prefix = folder.replace("_append", "");
						for (asset in OpenFlAssets.list(TEXT)) {
							if (asset.startsWith(prefix) && asset.endsWith('.hx') && !processedFiles.exists(asset)) {
								scriptFiles.push(asset);
								processedFiles.set(asset, true);
							}
						}
					}
				}
			}
		}

		for (path in scriptFiles) {
			menuScriptArray.push(new FunkinHScript(path, this));
			if (path.contains('${Mods.MODS_FOLDER}/'))
				trace('Loaded mod substate script: $path');
			else
				trace('Loaded base game substate script: $path');
		}
		#end
	}
}