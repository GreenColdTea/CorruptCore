package game.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;

import openfl.media.Sound;

import lime.utils.Assets;

@:access(openfl.display.BitmapData)
class FunkinCache
{
    public static var dumpExclusions:Array<String> = [];
    public static var localTrackedAssets:Array<String> = [];
    public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
    public static var missingAssets:Map<String, Bool> = [];
    public static var currentTrackedSounds:Map<String, Sound> = [];

    public static function initExclusions() {
        dumpExclusions.push(Paths.getPath('music/freakyMenu.${Paths.SOUND_EXT}'));
    }

    public static function excludeAsset(key:String) {
        if (!dumpExclusions.contains(key))
            dumpExclusions.push(key);
    }

    public static function clearUnusedMemory(cleanMajor:Bool = true) {
        if (FlxG.state != null && FlxG.state is game.PlayState) 
            cleanMajor = false; 

        missingAssets.clear();

        final keysToRemove:Array<String> = [];
        for (key in currentTrackedAssets.keys()) {
            if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) {
                final graphic = currentTrackedAssets.get(key);
                if (graphic != null)
                    destroyGraphic(graphic);

                keysToRemove.push(key);
                openfl.Assets.cache.removeBitmapData(key); 
            }
        }
        
        for (key in keysToRemove)
            currentTrackedAssets.remove(key);

        MemoryUtil.forceGC(cleanMajor);
    }

    @:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
    public static function clearStoredMemory() {
        final protectedGfx:Array<FlxGraphic> = getProtectedGraphics();

        final flxgKeysToRemove:Array<String> = [];
        for (key in FlxG.bitmap._cache.keys()) {
            if (!currentTrackedAssets.exists(key)) {
                if (key?.indexOf('text') != -1)
                    continue;

                final graphic = FlxG.bitmap.get(key);

                if (graphic != null && protectedGfx.contains(graphic))
                    continue;

                if (graphic != null)
                    destroyGraphic(graphic);

                flxgKeysToRemove.push(key);
            }
        }

        for (key in flxgKeysToRemove)
            FlxG.bitmap.removeByKey(key);

        final soundKeysToRemove:Array<String> = [];
        for (key => asset in currentTrackedSounds) {
            if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) {
                openfl.Assets.cache.removeSound(key);
                soundKeysToRemove.push(key);
            }
        }
        
        for (key in soundKeysToRemove)
            currentTrackedSounds.remove(key);

        FlxG.bitmap.clearUnused();
        
        final protectedLibs:Array<String> = ["default", "preload"];

        @:privateAccess
        for (libName in Assets.libraries.keys()) {
            if (!protectedLibs.contains(libName) && libName != null) 
                openfl.Assets.cache.clear(libName);
        }
        
        localTrackedAssets.resize(0);
        MemoryUtil.compact();
        MemoryUtil.forceGC();
    }
    
    public static function freeGraphicsFromMemory() {
        final protectedGfx:Array<FlxGraphic> = getProtectedGraphics();

        for (key in currentTrackedAssets.keys()) {
            if (!dumpExclusions.contains(key)) {
                final graphic:FlxGraphic = currentTrackedAssets.get(key);
                if(!protectedGfx.contains(graphic)) {
                    destroyGraphic(graphic);
                    currentTrackedAssets.remove(key);
                }
            }
        }
    }

    private static function getProtectedGraphics():Array<FlxGraphic> {
        final protectedGfx:Array<FlxGraphic> = [];
        
        function checkForGraphics(spr:Dynamic) {
            try {
                final grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
                if (grp != null) {
                    for (member in grp)
                        checkForGraphics(member);
                    return;
                }
            }
            catch(e:Dynamic) {}

            try {
                final gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
                if (gfx != null && !protectedGfx.contains(gfx)) 
                    protectedGfx.push(gfx);
            }
            catch(e:Dynamic) {}
        }

        if (FlxG.state != null) {
            for (member in FlxG.state.members) 
                checkForGraphics(member);
                
            if (FlxG.state.subState != null) {
                for (member in FlxG.state.subState.members)
                    checkForGraphics(member);
            }
        }
        
        return protectedGfx;
    }

    public static inline function destroyGraphic(graphic:FlxGraphic) {
        if (graphic?.bitmap != null) {
            graphic.bitmap.__texture?.dispose();
            
            if (graphic.bitmap.image != null) {
                graphic.bitmap.image.data = null;
                graphic.bitmap.image = null;
            }
            
            graphic.bitmap.disposeImage();
            graphic.bitmap.dispose();
            
            FlxG.bitmap.remove(graphic);
            graphic.destroy();
        }
    }
}