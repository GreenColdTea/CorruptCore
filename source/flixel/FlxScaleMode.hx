package flixel;

import flixel.FlxG;
import flixel.system.scaleModes.BaseScaleMode;

using game.backend.utils.MathUtil;

/**
 * Scale mode that allows for wide screen support.
 * Uses GCD to normalize aspect ratio
 */
class FlxScaleMode extends BaseScaleMode
{
    public static var allowWideScreen(default, set):Bool = true;

    public static var allowedRatios:Array<{w:Int, h:Int}> = [
        {w:16, h:9},
        {w:21, h:9},
        {w:32, h:9}
    ];
    
    override function updateGameSize(Width:Int, Height:Int):Void
    {
        if (shouldUseWideScreen(Width, Height))
        {
            super.updateGameSize(Width, Height);
        }
        else
        {
            final targetRatio = FlxG.width / FlxG.height;
            final screenRatio = Width / Height;
            
            if (screenRatio < targetRatio)
                gameSize.set(Width, Math.floor(Width / targetRatio));
            else
                gameSize.set(Math.floor(Height * targetRatio), Height);
        }
    }

    override function updateGamePosition():Void
    {
        if (shouldUseWideScreen(FlxG.stage.stageWidth, FlxG.stage.stageHeight))
        {
            FlxG.game.x = 0;
            FlxG.game.y = 0;
        }
        else
        {
            super.updateGamePosition();
        }
    }

    static function set_allowWideScreen(value:Bool):Bool
    {
        if (allowWideScreen == value) return value;
            
        allowWideScreen = value;
        resetScaleMode();
        return value;
    }

    /**
     * Checks if current screen resolution matches allowed wide ratios
     */
    static function shouldUseWideScreen(w:Int, h:Int):Bool
    {
        if (!ClientPrefs.noBordersScreen || !allowWideScreen) return false;

        var d = MathUtil.gcd(w, h);
        var rw = Math.floor(w / d);
        var rh = Math.floor(h / d);

        for (ratio in allowedRatios)
        {
            if (ratio.w == rw && ratio.h == rh)
                return true;
        }
        return false;
    }

    static function resetScaleMode()
    {
        var currentType = Type.getClass(FlxG.scaleMode);
        FlxG.scaleMode = Type.createInstance(currentType, []);
    }
}
