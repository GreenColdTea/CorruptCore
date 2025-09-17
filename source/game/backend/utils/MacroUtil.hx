package game.backend.utils;

#if macro
import sys.FileSystem;
import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
#end

using StringTools;

class MacroUtil {
    public static var defines(get, null):Map<String, Dynamic>;
	private static inline function get_defines() return __getDefines();
	private static macro function __getDefines() {
		#if display
		return macro $v{[]};
		#else
		return macro $v{Context.getDefines()};
		#end
	}

    /**
     * Macro for automatically adding scripts to resources
     * Finds all .hx files in specified folders and adds them to resources
     */
    macro public static function addScriptResources():Array<Expr> {
        #if macro
        var resources = [];
        var basePaths = ["scripts/"];
        
        #if MODS_ALLOWED
        if (FileSystem.exists("mods/")) {
            for (mod in FileSystem.readDirectory("mods/")) {
                var modPath = Path.join(["mods", mod, "scripts"]);
                if (FileSystem.exists(modPath) && FileSystem.isDirectory(modPath)) {
                    basePaths.push(modPath + "/");
                }
            }
        }
        #end
        
        // Function for recursively adding files
        function addFiles(path:String) {
            if (!FileSystem.exists(path)) return;
            
            for (file in FileSystem.readDirectory(path)) {
                var fullPath = Path.join([path, file]);
                if (FileSystem.isDirectory(fullPath)) {
                    addFiles(fullPath + "/");
                } else if (file.endsWith(".hx")) {
                    try {
                        var content = File.getContent(fullPath);
                        var resourceName = fullPath
                            .replace("/", "_")
                            .replace("\\", "_")
                            .replace(".", "_")
                            .replace(":", "_");
                        
                        // Add resource
                        Context.addResource(resourceName, haxe.io.Bytes.ofString(content));
                        
                        // For debugging
                        trace('Added script resource: $resourceName ($fullPath)');
                        
                        // Add to return array
                        resources.push(macro $v{resourceName} => $v{content});
                    } catch (e:Dynamic) {
                        Context.error('Failed to process script file: $fullPath - $e', Context.currentPos());
                    }
                }
            }
        }
        
        // Process all base paths
        for (path in basePaths) {
            addFiles(path);
        }
        
        return resources;
        #else
        return [];
        #end
    }
    
    /**
     * Macro for adding specific files to resources
     * @param paths Array of file paths to add
     */
    macro public static function addSpecificResources(paths:Array<String>):Array<Expr> {
        #if macro
        var resources = [];
        
        for (path in paths) {
            if (FileSystem.exists(path)) {
                try {
                    var content = File.getContent(path);
                    var resourceName = path
                        .replace("/", "_")
                        .replace("\\", "_")
                        .replace(".", "_")
                        .replace(":", "_");
                    
                    Context.addResource(resourceName, haxe.io.Bytes.ofString(content));
                    resources.push(macro $v{resourceName} => $v{content});
                    
                    trace('Added resource: $resourceName ($path)');
                } catch (e:Dynamic) {
                    Context.error('Failed to add resource: $path - $e', Context.currentPos());
                }
            } else {
                Context.warning('File not found: $path', Context.currentPos());
            }
        }
        
        return resources;
        #else
        return [];
        #end
    }
    
    /**
     * Macro for checking file existence and adding them to resources
     * with fallback resources if files are not found
     */
    macro public static function addResourcesWithFallback(primaryPaths:Array<String>, fallbackContent:Map<String, String>):Array<Expr> {
        #if macro
        var resources = [];
        
        for (path in primaryPaths) {
            if (FileSystem.exists(path)) {
                try {
                    var content = File.getContent(path);
                    var resourceName = path
                        .replace("/", "_")
                        .replace("\\", "_")
                        .replace(".", "_")
                        .replace(":", "_");
                    
                    Context.addResource(resourceName, haxe.io.Bytes.ofString(content));
                    resources.push(macro $v{resourceName} => $v{content});
                } catch (e:Dynamic) {
                    Context.error('Failed to add resource: $path - $e', Context.currentPos());
                }
            } else if (fallbackContent.exists(path)) {
                // Use fallback content
                var resourceName = path
                    .replace("/", "_")
                    .replace("\\", "_")
                    .replace(".", "_")
                    .replace(":", "_");
                
                var content = fallbackContent.get(path);
                Context.addResource(resourceName, haxe.io.Bytes.ofString(content));
                resources.push(macro $v{resourceName} => $v{content});
                
                Context.warning('Using fallback content for: $path', Context.currentPos());
            } else {
                Context.error('File not found and no fallback provided: $path', Context.currentPos());
            }
        }
        
        return resources;
        #else
        return [];
        #end
    }
	
	// Taken from cne
	macro public static function generateReflectionLike(totalArguments:Int, funcName:String, argsName:String) {
		#if macro
		totalArguments++;

		var funcCalls = [];
		for(i in 0...totalArguments) {
			var args = [
				for(d in 0...i) macro $i{argsName}[$v{d}]
			];

			funcCalls.push(macro $i{funcName}($a{args}));
		}

		var expr = {
			pos: Context.currentPos(),
			expr: ESwitch(
				macro ($i{argsName}.length),
				[
					for(i in 0...totalArguments) {
						values: [macro $v{i}],
						expr: funcCalls[i],
						guard: null,
					}
				],
				macro throw "Too many arguments"
			)
		}

		return expr;
		#end
	}
}