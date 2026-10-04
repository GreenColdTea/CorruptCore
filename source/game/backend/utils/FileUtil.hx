package game.backend.utils;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.io.Bytes;
import haxe.io.Path;

import openfl.utils.Assets as OpenFlAssets;

import game.backend.system.Mods;

class FileUtil
{
    public static function listDirectory(path:String):Array<String>
    {
        final result = [];

        #if MODS_ALLOWED
        final modsList = Mods.enabledMods.copy();
        
        if (Mods.currentModDirectory?.length > 0 && !modsList.contains(Mods.currentModDirectory))
            modsList.insert(0, Mods.currentModDirectory);

        for (mod in modsList) {
            if (mod == null || mod.length == 0) continue;

            final modPath = Mods.getModPath('$mod/$path');
            #if sys
            if (FileSystem.exists(modPath) && FileSystem.isDirectory(modPath)) {
                for (file in FileSystem.readDirectory(modPath)) {
                    final fullPath = Path.join([modPath, file]);
                    if (!FileSystem.isDirectory(fullPath) && !result.contains(fullPath)) result.push(fullPath);
                }
            }
            #end
        }
        #end

        final assetsPath = Paths.getPreloadPath(path);
        #if sys
        if (FileSystem.exists(assetsPath) && FileSystem.isDirectory(assetsPath)) {
            for (file in FileSystem.readDirectory(assetsPath)) {
                final fullPath = Path.join([assetsPath, file]);
                if (!FileSystem.isDirectory(fullPath) && !result.contains(fullPath)) result.push(fullPath);
            }
        }
        #end

        final prefix = assetsPath.endsWith('/') ? assetsPath : '$assetsPath/';
        for (asset in OpenFlAssets.list()) {
            if (asset.startsWith(prefix) && asset != prefix && !result.contains(asset)) {
                result.push(asset);
            }
        }

        return result;
    }

    public static function getRelativePath(absPath:String):Null<String>
    {
        #if sys
        if (absPath == null) return null;
        final cwd = Sys.getCwd().replace('\\', '/');
        final normalized = absPath.replace('\\', '/');
        return normalized.indexOf(cwd) == 0 ? normalized.substr(cwd.length) : absPath;
        #end
        return absPath;
    }

    public static function getAbsolutePath(assetPath:String):String 
    {
        #if sys
        return Sys.getCwd() + Paths.getPreloadPath(assetPath.indexOf("assets/") == 0 ? assetPath.substring(7) : assetPath);
        #else
        return assetPath;
        #end
    }

    public static function exists(path:String):Bool {
        return #if sys FileSystem.exists(path) || #end OpenFlAssets.exists(path);
    }

    public static function getContent(path:String):Null<String> {
        #if sys
        if (FileSystem.exists(path)) return File.getContent(path);
        #end
        if (OpenFlAssets.exists(path)) return OpenFlAssets.getText(path);
        return null;
    }

    public static function getBytes(path:String):Null<Bytes> {
        #if sys
        if (FileSystem.exists(path)) return File.getBytes(path);
        #end
        if (OpenFlAssets.exists(path)) return OpenFlAssets.getBytes(path);
        return null;
    }

    public static function copy(srcPath:String, dstPath:String):Void {
        #if sys
        if (FileSystem.exists(srcPath)) {
            File.copy(srcPath, dstPath);
            return;
        }

        if (OpenFlAssets.exists(srcPath)) {
            final bytes = OpenFlAssets.getBytes(srcPath);
            if (bytes != null) File.saveBytes(dstPath, bytes);
        }
        #end
    }
}