package game.scripting;

import openfl.utils.Assets as OpenFlAssets;

class HScriptSubstate extends MusicBeatSubstate
{
	public static var substate:String = "";
	
	public function new(_substate:String)
	{
		super();
		substate = _substate;
		
		// Clear existing scripts and load new ones for the specific substate
		#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
		for (sc in menuScriptArray) sc.stop();
		menuScriptArray = [];
		
		var scriptFiles:Array<String> = [];
		var folders:Array<String> = Paths.getSubstateScripts(substate);
		
		for (folder in folders) {
			#if sys
			if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
				for (file in FileSystem.readDirectory(folder)) {
					if (file.endsWith('.hx')) {
						var fullPath = haxe.io.Path.join([folder, file]);
						scriptFiles.push(fullPath);
					}
				}
			}
			#else
			var prefix = folder.replace("_append", "");
			for (asset in OpenFlAssets.list(TEXT)) {
				if (asset.startsWith(prefix) && asset.endsWith('.hx')) {
					scriptFiles.push(asset);
				}
			}
			#end
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