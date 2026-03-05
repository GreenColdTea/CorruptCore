package game.shaders;

import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;

class PixelShader
{
    public var shader:Pixelating = new Pixelating();
    public var pixelAmount(default, set):Float = 1;

    public var hue(default, set):Float = 0;
    public var saturation(default, set):Float = 0;
    public var brightness(default, set):Float = 0;

    public var enabled:Bool = true;

    public function copyFromColorSwap(colorSwap:ColorSwap)
    {
        if (colorSwap != null)
        {
            hue = colorSwap.hue;
            saturation = colorSwap.saturation;
            brightness = colorSwap.brightness;
        }
    }

    private function set_hue(value:Float):Float
    {
        hue = value;
        shader.uHue = value;
        return value;
    }

    private function set_saturation(value:Float):Float
    {
        saturation = value;
        shader.uSaturation = value;
        return value;
    }

    private function set_brightness(value:Float):Float
    {
        brightness = value;
        shader.uBrightness = value;
        return value;
    }

    public function set_pixelAmount(value:Float):Float
    {
        pixelAmount = value;
        shader.uBlocksizeX = value;
        shader.uBlocksizeY = value;
        return value;
    }

    public function new()
    {
        pixelAmount = PlayState.isPixelStage ? PlayState.daPixelZoom : 1;
    }
}

class Pixelating extends FlxShader
{
    @:isVar
    public var uBlocksizeX(get, set):Float = 1;
    @:isVar
    public var uBlocksizeY(get, set):Float = 1;
    @:isVar
    public var uHue(get, set):Float = 0;
    @:isVar
    public var uSaturation(get, set):Float = 0;
    @:isVar
    public var uBrightness(get, set):Float = 0;

    function get_uBlocksizeX() return blocksizeX.value[0];
    function set_uBlocksizeX(val:Float) return blocksizeX.value[0] = val;
    
    function get_uBlocksizeY() return blocksizeY.value[0];
    function set_uBlocksizeY(val:Float) return blocksizeY.value[0] = val;
    
    function get_uHue() return hue.value[0];
    function set_uHue(val:Float) return hue.value[0] = val;
    
    function get_uSaturation() return saturation.value[0];
    function set_uSaturation(val:Float) return saturation.value[0] = val;
    
    function get_uBrightness() return brightness.value[0];
    function set_uBrightness(val:Float) return brightness.value[0] = val;

    @:glFragmentSource('
        #pragma header
        uniform float blocksizeX;
        uniform float blocksizeY;
        uniform float hue;
        uniform float saturation;
        uniform float brightness;

        vec3 rgb2hsv(vec3 c)
        {
            vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
            vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

            float d = q.x - min(q.w, q.y);
            float e = 1.0e-10;
            return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
        }

        vec3 hsv2rgb(vec3 c)
        {
            vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
            return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
        }

        void main()
        {
            vec2 uv = openfl_TextureCoordv;
            
            vec2 blocks = openfl_TextureSize / vec2(blocksizeX, blocksizeY);
            vec2 pixelatedUV = floor(uv * blocks) / blocks;
            vec4 color = flixel_texture2D(bitmap, pixelatedUV);
            
            if (color.a == 0.0) {
                gl_FragColor = color * openfl_Alphav;
                return;
            }

            vec3 hsv = rgb2hsv(color.rgb);
            hsv.x += hue;
            hsv.y += saturation;
            hsv.z *= (1.0 + brightness);
            hsv.y = clamp(hsv.y, 0.0, 1.0);
            hsv.z = clamp(hsv.z, 0.0, 1.0);
            vec3 corrected = hsv2rgb(hsv);

            gl_FragColor = vec4(corrected, color.a);
        }
    ')

    public function new()
    {
        super();
        
        blocksizeX.value = [1.0];
        blocksizeY.value = [1.0];
        hue.value = [0.0];
        saturation.value = [0.0];
        brightness.value = [0.0];
    }
}