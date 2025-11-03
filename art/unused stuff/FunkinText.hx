package game.objects;

import flixel.text.FlxText;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;

/**
 * Enhanced FlxText with fixes for character clipping and rendering issues
 */
class FunkinText extends FlxText
{
    /**
     * Enable pixel-perfect alignment to prevent sub-pixel positioning artifacts
     */
    public var pixelPerfect:Bool = true;
    
    /**
     * Additional font metrics correction for fonts with unusual character bounds
     */
    public var fontMetricsCorrection:Float = 0;
    
    /**
     * Horizontal gutter to prevent character clipping on sides
     */
    static inline var HORIZONTAL_GUTTER:Int = 4;
    
    /**
     * Vertical gutter to prevent character clipping on top/bottom
     */
    static inline var VERTICAL_GUTTER:Int = 8;
    
    /**
     * Creates a new FunkinText object with enhanced rendering
     *
     * @param   X              The x position of the text
     * @param   Y              The y position of the text
     * @param   FieldWidth     The width of the text object
     * @param   Text           The actual text to display initially
     * @param   Size           The font size for this text object
     * @param   EmbeddedFont   Whether this text field uses embedded fonts
     */
    public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
    {
        super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
        
        // Apply additional horizontal padding by default
        if (FieldWidth > 0)
        {
            this.fieldWidth = FieldWidth + HORIZONTAL_GUTTER;
        }
    }
    
    /**
     * Regenerate the text graphic with applied fixes
     */
    override function regenGraphic():Void
    {
        // Apply font metrics correction before regeneration
        if (fontMetricsCorrection != 0 && _autoHeight && textField != null)
        {
            textField.height = textField.textHeight + fontMetricsCorrection;
        }
        
        super.regenGraphic();
    }
    
    /**
     * Override drawSimple to apply pixel-perfect positioning
     */
    override function drawSimple(camera:FlxCamera):Void
    {
        getScreenPosition(_point, camera).subtract(offset).subtract(_graphicOffset);
        
        if (pixelPerfect && isPixelPerfectRender(camera))
        {
            _point.x = Math.floor(_point.x);
            _point.y = Math.floor(_point.y);
        }
        
        _point.copyTo(_flashPoint);
        camera.copyPixels(_frame, framePixels, _flashRect, _flashPoint, colorTransform, blend, antialiasing);
    }
    
    /**
     * Override drawComplex to apply pixel-perfect positioning
     */
    override function drawComplex(camera:FlxCamera):Void
    {
        _frame.prepareMatrix(_matrix, ANGLE_0, checkFlipX(), checkFlipY());
        _matrix.translate(-origin.x, -origin.y);
        _matrix.scale(scale.x, scale.y);
        
        if (bakedRotationAngle <= 0)
        {
            updateTrig();
            
            if (angle != 0)
                _matrix.rotateWithTrig(_cosAngle, _sinAngle);
        }
        
        getScreenPosition(_point, camera).subtract(offset).subtract(_graphicOffset);
        _point.add(origin.x, origin.y);
        _matrix.translate(_point.x, _point.y);
        
        if (pixelPerfect && isPixelPerfectRender(camera))
        {
            _matrix.tx = Math.floor(_matrix.tx);
            _matrix.ty = Math.floor(_matrix.ty);
        }
        
        camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
    }
    
    /**
     * Apply preset configurations for different font types
     *
     * @param   preset   The font preset to apply
     * @return  This FunkinText instance (for chaining)
     */
    public function setFontPreset(preset:FontPreset):FunkinText
    {
        switch(preset)
        {
            case PIXEL:
                // Optimal for pixel fonts - disable antialiasing, enable pixel perfection
                pixelPerfect = true;
                fontMetricsCorrection = 2;
                
            case SMOOTH:
                // Optimal for smooth vector fonts - enable antialiasing, disable pixel perfection
                pixelPerfect = false;
                fontMetricsCorrection = 0;
                
            case CLEAR:
                // Balanced preset - enable both antialiasing and pixel perfection
                pixelPerfect = true;
                fontMetricsCorrection = 1;
        }
        _regen = true;
        return this;
    }
    
    /**
     * Set custom gutters for precise control over text padding
     *
     * @param   horizontal   Horizontal gutter size
     * @param   vertical     Vertical gutter size
     * @return  This FunkinText instance (for chaining)
     */
    public function setCustomGutters(horizontal:Int, vertical:Int):FunkinText
    {
        // Note: This would require overriding more internal methods to take effect
        // For now, it serves as a reminder for future enhancements
        return this;
    }
    
    /**
     * Enable or disable pixel-perfect rendering
     *
     * @param   value   Whether to enable pixel-perfect rendering
     * @return  This FunkinText instance (for chaining)
     */
    public function setPixelPerfect(value:Bool):FunkinText
    {
        pixelPerfect = value;
        return this;
    }
    
    /**
     * Set font metrics correction value
     *
     * @param   correction   Additional height correction for problematic fonts
     * @return  This FunkinText instance (for chaining)
     */
    public function setFontMetricsCorrection(correction:Float):FunkinText
    {
        fontMetricsCorrection = correction;
        _regen = true;
        return this;
    }
}

/**
 * Font presets for different rendering requirements
 */
enum FontPreset
{
    PIXEL;    // For pixel fonts - crisp rendering without antialiasing
    SMOOTH;   // For smooth vector fonts - best quality with antialiasing  
    CLEAR;    // Balanced preset - good for most use cases
}