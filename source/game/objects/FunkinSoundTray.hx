package game.objects;

import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.util.FlxColor;
import flixel.system.ui.FlxSoundTray;

import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.text.AntiAliasType;
#if flash
import openfl.text.GridFitType;
#end

class FunkinSoundTray extends FlxSoundTray
{
    /**
     * Volume indicator ring
     */
    var _volumeRing:Shape;

    /**
     * How wide the sound tray background is.
     */
    var _width:Int = 80;

    // Constants for better maintainability
    static final DISPLAY_TIME:Float = 0.7;
    static final SLIDE_SPEED:Float = 1.5;
    static final BG_ALPHA:Int = 0x7F000000;
    static final TRAY_HEIGHT:Int = 52;
    static final TEXT_Y_POS:Int = 38;
    static final FONT_SIZE:Int = 10;
    
    /**
	 * Ring params
	*/
    final RING_RADIUS:Float = 15;
    final RING_THICKNESS:Float = 8;
    final RING_CENTER_X:Float = 40;
    final RING_CENTER_Y:Float = 20;
    
    // Customizable colors
    public var trayColor:FlxColor = 0x7F000000;
    public var textColor:FlxColor = FlxColor.WHITE;
    public var ringColor:FlxColor = FlxColor.WHITE;
    public var outlineColor:FlxColor = FlxColor.RED;

    public var outlineThickness:Float = 1.5;

    public function new()
    {
        super();

        // Remove default flixel sound tray elements
        removeChildren();

        /**The sound used when increasing the volume.**/
        volumeUpSound = "assets/sounds/volup.ogg";

        /**The sound used when decreasing the volume.**/
        volumeDownSound = 'assets/sounds/voldown.ogg';

        // Cache sounds if not silent
        if (!silent)
        {
            FlxG.sound.cache('$volumeUpSound');
            FlxG.sound.cache('$volumeDownSound');
        }

        visible = false;
        scaleX = _defaultScale;
        scaleY = _defaultScale;
        
        // Create background
        var bg:Bitmap = new Bitmap(new BitmapData(_width, TRAY_HEIGHT, true, trayColor));
        screenCenter();
        addChild(bg);

        // Create volume text
        var text:TextField = createVolumeText();
        addChild(text);

        // Create volume ring
        _volumeRing = new Shape();
        addChild(_volumeRing);

        y = -height;
        visible = false;
    }

    /**
     * Creates and configures the volume text field
     */
    private function createVolumeText():TextField
    {
        var text:TextField = new TextField();
        text.width = _width;
        text.height = TRAY_HEIGHT;
        text.multiline = true;
        text.wordWrap = true;
        text.selectable = false;
        text.antiAliasType = AntiAliasType.ADVANCED;

        #if flash
        text.embedFonts = true;
        text.gridFitType = GridFitType.PIXEL;
        #else
        text.sharpness = 400;
        #end

        var textFormat:TextFormat = new TextFormat(FlxAssets.FONT_DEFAULT, FONT_SIZE, textColor);
        textFormat.align = TextFormatAlign.CENTER;
        text.defaultTextFormat = textFormat;
        text.text = "VOLUME";
        text.y = TEXT_Y_POS;

        return text;
    }

    /**
     * Draws a ring segment for volume indicator with outline
     */
    function drawRingWithOutline(shape:Shape, centerX:Float, centerY:Float, radius:Float, thickness:Float, 
                     startAngle:Float, endAngle:Float, fillColor:FlxColor, outlineColor:FlxColor, 
                     outlineThickness:Float = 1.5, alpha:Float = 1.0):Void
    {
        var g = shape.graphics;
        g.clear();
        
        if (endAngle <= startAngle) 
            return;
        
        final SEGMENTS:Int = 32;
        
        // Convert degrees to radians
        var startRad:Float = (startAngle - 90) * Math.PI / 180;
        var endRad:Float = (endAngle - 90) * Math.PI / 180;
        
        var innerRadius = radius - thickness / 2;
        var outerRadius = radius + thickness / 2;
        
        // Draw outline (slightly larger ring behind the main ring)
        if (outlineThickness > 0)
        {
            g.lineStyle(outlineThickness, outlineColor, alpha);
            g.beginFill(outlineColor, alpha);
            
            var outlineInnerRadius = innerRadius - outlineThickness / 2;
            var outlineOuterRadius = outerRadius + outlineThickness / 2;
            
            // Move to starting point on inner outline circle
            g.moveTo(
                centerX + Math.cos(startRad) * outlineInnerRadius,
                centerY + Math.sin(startRad) * outlineInnerRadius
            );
            
            // Draw arc along outer outline circle
            for (i in 0...SEGMENTS)
            {
                var t = i / (SEGMENTS - 1);
                var angle = startRad + t * (endRad - startRad);
                g.lineTo(
                    centerX + Math.cos(angle) * outlineOuterRadius,
                    centerY + Math.sin(angle) * outlineOuterRadius
                );
            }
            
            // Draw arc along inner outline circle (reverse direction)
            for (i in 0...SEGMENTS)
            {
                var t = (SEGMENTS - 1 - i) / (SEGMENTS - 1);
                var angle = startRad + t * (endRad - startRad);
                g.lineTo(
                    centerX + Math.cos(angle) * outlineInnerRadius,
                    centerY + Math.sin(angle) * outlineInnerRadius
                );
            }
            
            g.endFill();
        }
        
        // Draw main filled ring
        g.lineStyle(); // Reset line style for fill
        g.beginFill(fillColor, alpha);
        
        // Move to starting point on inner circle
        g.moveTo(
            centerX + Math.cos(startRad) * innerRadius,
            centerY + Math.sin(startRad) * innerRadius
        );
        
        // Draw arc along outer circle
        for (i in 0...SEGMENTS)
        {
            var t = i / (SEGMENTS - 1);
            var angle = startRad + t * (endRad - startRad);
            g.lineTo(
                centerX + Math.cos(angle) * outerRadius,
                centerY + Math.sin(angle) * outerRadius
            );
        }
        
        // Draw arc along inner circle (reverse direction)
        for (i in 0...SEGMENTS)
        {
            var t = (SEGMENTS - 1 - i) / (SEGMENTS - 1);
            var angle = startRad + t * (endRad - startRad);
            g.lineTo(
                centerX + Math.cos(angle) * innerRadius,
                centerY + Math.sin(angle) * innerRadius
            );
        }
        
        g.endFill();
    }

    /**
     * Alt method: draw segments with individual outlines
     * Creates a more defined separation between segments
     */
    function drawSegmentedRing(shape:Shape, centerX:Float, centerY:Float, radius:Float, thickness:Float,
                             startAngle:Float, endAngle:Float, fillColor:FlxColor, outlineColor:FlxColor,
                             segmentCount:Int = 10, outlineThickness:Float = 1.0):Void
    {
        var g = shape.graphics;
        g.clear();
        
        if (endAngle <= startAngle) 
            return;
            
        var segmentAngle:Float = (endAngle - startAngle) / segmentCount;
        var innerRadius = radius - thickness / 2;
        var outerRadius = radius + thickness / 2;
        
        for (i in 0...segmentCount)
        {
            var segmentStart:Float = startAngle + i * segmentAngle;
            var segmentEnd:Float = segmentStart + segmentAngle;
            
            // Skip drawing if this segment would extend beyond the total end angle
            if (segmentStart >= endAngle) break;
            if (segmentEnd > endAngle) segmentEnd = endAngle;
            
            // Convert to radians
            var segStartRad:Float = (segmentStart - 90) * Math.PI / 180;
            var segEndRad:Float = (segmentEnd - 90) * Math.PI / 180;
            
            // Draw segment outline
            g.lineStyle(outlineThickness, outlineColor, 1.0);
            g.beginFill(fillColor, 1.0);
            
            // Create segment path
            g.moveTo(
                centerX + Math.cos(segStartRad) * innerRadius,
                centerY + Math.sin(segStartRad) * innerRadius
            );
            
            // Outer arc
            g.lineTo(
                centerX + Math.cos(segStartRad) * outerRadius,
                centerY + Math.sin(segStartRad) * outerRadius
            );
            
            var midSegments:Int = 8;
            for (j in 1...midSegments)
            {
                var t:Float = j / (midSegments - 1);
                var angle:Float = segStartRad + t * (segEndRad - segStartRad);
                g.lineTo(
                    centerX + Math.cos(angle) * outerRadius,
                    centerY + Math.sin(angle) * outerRadius
                );
            }
            
            g.lineTo(
                centerX + Math.cos(segEndRad) * innerRadius,
                centerY + Math.sin(segEndRad) * innerRadius
            );
            
            // Inner arc (back to start)
            for (j in 0...midSegments)
            {
                var t:Float = (midSegments - 1 - j) / (midSegments - 1);
                var angle:Float = segStartRad + t * (segEndRad - segStartRad);
                g.lineTo(
                    centerX + Math.cos(angle) * innerRadius,
                    centerY + Math.sin(angle) * innerRadius
                );
            }
            
            g.endFill();
        }
    }

    override function update(MS:Float):Void
    {
        if (_timer > 0)
        {
            _timer -= (MS / 1000);
        }
        else if (y > -height)
        {
            var deltaY:Float = (MS / 1000) * height * SLIDE_SPEED;
            y = Math.max(-height, y - deltaY);
            
            if (y <= -height)
            {
                visible = false;
                active = false;
                saveSoundSettings();
            }
        }
    }

    /**
     * Saves sound settings to save data
     */
    private function saveSoundSettings():Void
    {
        #if FLX_SAVE
        if (FlxG.save.isBound)
        {
            FlxG.save.data.mute = FlxG.sound.muted;
            FlxG.save.data.volume = FlxG.sound.volume;
            FlxG.save.flush();
        }
        #end
    }

    /**
     * Makes the little volume tray slide out.
     *
     * @param up Whether the volume is increasing.
     */
    override function show(up:Bool = false):Void
    {
        if (!silent)
        {
            try
            {
                var sound = FlxG.assets.getSound(Std.string(up ? volumeUpSound : volumeDownSound), true);
                if (sound != null)
                    FlxG.sound.play(sound);
            }
            catch (e:Dynamic)
            {
                trace("Sound not found: " + (up ? volumeUpSound : volumeDownSound));
            }
        }

        _timer = DISPLAY_TIME;
        y = 0;
        visible = true;
        active = true;
        
        var globalVolume:Int = FlxG.sound.muted ? 0 : Math.round(FlxG.sound.logToLinear(FlxG.sound.volume) * 10);
        globalVolume = Std.int(Math.max(0, Math.min(10, globalVolume)));

        // Draw volume ring with outline
        var volumeAngle:Float = 360 * (globalVolume / 10);
        if (globalVolume > 0) {
            // Ver 1: Continuous ring with outline
            /*drawRingWithOutline(_volumeRing, RING_CENTER_X, RING_CENTER_Y, RING_RADIUS, RING_THICKNESS, 
                    0, volumeAngle, ringColor, outlineColor, outlineThickness, 1.0);*/
            
            drawSegmentedRing(_volumeRing, RING_CENTER_X, RING_CENTER_Y, RING_RADIUS, RING_THICKNESS,
                    0, volumeAngle, ringColor, outlineColor, globalVolume, 1.0);
        } else {
            // Clear when volume is 0
            _volumeRing.graphics.clear();
        }
    }

    /**
     * Centers the sound tray on screen
     */
    override function screenCenter():Void
    {
        scaleX = _defaultScale;
        scaleY = _defaultScale;

        var stageWidth:Float = Lib.current.stage.stageWidth;
        x = (stageWidth - _width * _defaultScale) * 0.5 - FlxG.game.x;
    }

    // Compatibility methods for Flixel 6.0.0+
    #if (flixel > "6.0.0")
    override function showAnim(volume:Float, ?sound:FlxSoundAsset, duration:Float = 1.0, label:String = "VOLUME"):Void
    {
        if (!silent && sound != null)
        {
            try
            {
                FlxG.sound.play(sound.resolveSound(true, true));
            }
            catch (e:Dynamic)
            {
                trace("Sound not found: " + sound);
            }
        }

        _timer = duration;
        y = 0;
        visible = true;
        active = true;

        var globalVolume:Int = FlxG.sound.muted ? 0 : Math.round(FlxG.sound.logToLinear(FlxG.sound.volume) * 10);
        globalVolume = Std.int(Math.max(0, Math.min(10, globalVolume)));

        var volumeAngle:Float = 360 * (globalVolume / 10);

        if (globalVolume > 0)
        {
            drawSegmentedRing(
                _volumeRing,
                RING_CENTER_X,
                RING_CENTER_Y,
                RING_RADIUS,
                RING_THICKNESS,
                0,
                volumeAngle,
                ringColor,
                outlineColor,
                globalVolume,
                1.0
            );
        }
        else
        {
            _volumeRing.graphics.clear();
        }
    }

    override function showIncrement():Void
    {
        final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
        showAnim(volume, silent ? null : volumeUpSound, DISPLAY_TIME, "VOLUME");
    }

    override function showDecrement():Void
    {
        final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
        showAnim(volume, silent ? null : volumeDownSound, DISPLAY_TIME, "VOLUME");
    }

    override function updateSize():Void 
    {
        screenCenter();
    }
    #end
}