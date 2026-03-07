package game.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import math.Vector3;

import game.shaders.PixelShader;

typedef NoteSplashConfig = {
    var scale:Float;
    var animations:Map<String, NoteSplashAnimConfig>;
    var no_antialiasing:Bool;
    @:optional var allowRGB:Bool;
    @:optional var allowPixel:Bool;
    @:optional var allowHSB:Bool;
    @:optional var rgb:Array<Dynamic>;
}

typedef NoteSplashAnimConfig = {
    var prefix:String;
    var fps:Array<Int>;
    var offsets:Array<Float>;
    @:optional var indices:Array<Int>;
    var noteData:Int;
}

class NoteSplash extends flixel.addons.effects.FlxSkewedSprite
{
    public static var configs:Map<String, NoteSplashConfig> = new Map();
    public static final defaultNoteSplash:String = 'noteSplashes';

    public var vec3Cache:Vector3 = new Vector3(); // for vector3 operations in modchart code
    public var defScale:FlxPoint = FlxPoint.get(1, 1); // for modcharts to keep the scaling
    
    public var colorSwap:ColorSwap = null;
    public var pixelShader:PixelShader;
    public var allowPixel:Bool = false;
    
    private var textureLoaded:String = null;

    public var config:NoteSplashConfig;
    public var inEditor:Bool = false;
    public var babyArrow:StrumNote;
    
    public var copyX:Bool = true;
    public var copyY:Bool = true;
    public var spawned:Bool = false;
    public var noteData:Int = 0;
    
    public var maxAnims(default, set):Int = 0;
    var noteDataMap:Map<Int, String> = new Map();

    public function new(x:Float = 0, y:Float = 0, ?note:Int = 0, ?texture:String = null) {
        super(x, y);

        animation = new PsychAnimationController(this);
        
        colorSwap = new ColorSwap();
        pixelShader = new PixelShader();
        shader = colorSwap.shader;

        loadSplash(texture);
    }

    public function loadSplash(texture:String) {
        if(textureLoaded != texture) {
            frames = Paths.getSparrowAtlas(texture);
            textureLoaded = texture;
            
            config = loadConfig(texture);
            
            @:privateAccess
            animation.clearAnimations();
            noteDataMap.clear();
            maxAnims = 0;
            
            if(config?.animations != null) {
                for (animName => animData in config.animations) {
                    if (animData.noteData % Note.colArray.length == 0) {
                        maxAnims++;
                    }
                }
                
                for (animName => animData in config.animations) {
                    var frameRate:Int = 24;
                    if (animData.fps != null && animData.fps.length > 1) {
                        frameRate = animData.fps[1];
                    } else if (animData.fps != null && animData.fps.length == 1) {
                        frameRate = animData.fps[0];
                    }
                    
                    if(animData.indices != null && animData.indices.length > 0) {
                        animation.addByIndices(animName, animData.prefix, animData.indices, "", frameRate, false);
                    } else {
                        animation.addByPrefix(animName, animData.prefix, frameRate, false);
                    }
                    
                    noteDataMap.set(animData.noteData, animName);
                }
            }
            
            if(config != null) {
                scale.set(config.scale, config.scale);
                defScale.copyFrom(scale);
                updateHitbox();
            }
        }
    }

    public function setupNoteSplash(x:Float, y:Float, note:Int = 0, ?texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0) {
        aliveTime = 0;

        if(texture == null) {
            texture = defaultNoteSplash;
            if(PlayState.SONG?.splashSkin?.length > 0) 
                texture = PlayState.SONG.splashSkin;
        }

        if(textureLoaded != texture) {
            loadSplash(texture);
        }
        
        var useHSB = (config?.allowHSB != false);
        
        if (useHSB && colorSwap != null) {
            colorSwap.hue = hueColor;
            colorSwap.saturation = satColor;
            colorSwap.brightness = brtColor;
        }

        antialiasing = !(config?.no_antialiasing ?? true) && ClientPrefs.globalAntialiasing;
        allowPixel = (config?.allowPixel ?? false) && PlayState.isPixelStage;

        if (allowPixel) {
            if (useHSB) {
                pixelShader.copyFromColorSwap(colorSwap);
            } else {
                pixelShader.hue = 0;
                pixelShader.saturation = 0;
                pixelShader.brightness = 0;
            }
            pixelShader.pixelAmount = PlayState.daPixelZoom;
            shader = pixelShader.shader;
        } else {
            shader = useHSB ? colorSwap.shader : null;
        }

        offset.set(10, 10);
        
        spawnSplashNote(x, y, note, texture);
    }

    function playDefaultAnim():String {
        var anim:String = noteDataMap.get(noteData);
        if (anim != null && animation.exists(anim)) {
            animation.play(anim, true);
            
            var animData = config?.animations?.get(anim);
            if (animData != null) {
                if (animData.offsets != null && animData.offsets.length >= 2) {
                    offset.x = 10 + animData.offsets[0];
                    offset.y = 10 + animData.offsets[1];
                }
                
                if (animation.curAnim != null && animData.fps != null && animData.fps.length >= 2) {
                    var minFps:Int = animData.fps[0];
                    var maxFps:Int = animData.fps[1];
                    if (minFps < 0) minFps = 0;
                    if (maxFps < 0) maxFps = 0;
                    animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
                }
            }
        }
        
        return anim;
    }

    public function spawnSplashNote(x:Float, y:Float, noteData:Int, ?texture:String = null, ?randomize:Bool = true) {
        setPosition(x, y);

        if (babyArrow != null)
            setPosition(babyArrow.x - Note.swagWidth * 0.95, babyArrow.y - Note.swagWidth);

        if (randomize && maxAnims > 1)
            noteData = noteData % Note.colArray.length + (FlxG.random.int(0, maxAnims - 1) * Note.colArray.length);

        this.noteData = noteData;
        playDefaultAnim();

        animation.onFinish.add((_) -> {
            if (!inEditor) {
                kill();
                spawned = false;
            } else {
                animation.stop();
            }
        });

        spawned = true;
    }
    
    var aliveTime:Float = 0;
    static var buggedKillTime:Float = 0.5;
    
    override function update(elapsed:Float) {
        if (spawned) 
        {
            aliveTime += elapsed;
            if (animation.curAnim == null && aliveTime >= buggedKillTime && !inEditor) {
                kill();
                spawned = false;
            }
        }
        
        if (babyArrow != null) {
            if (copyX)
                x = babyArrow.x - Note.swagWidth * 0.95;
            if (copyY)
                y = babyArrow.y - Note.swagWidth;
        }

        super.update(elapsed);
    }

    function set_maxAnims(value:Int) {
        if (value > 0)
            noteData = Std.int(FlxMath.wrap(noteData, 0, (value * Note.colArray.length) - 1));
        else
            noteData = 0;

        return maxAnims = value;
    }

    public static function createConfig():NoteSplashConfig {
        return {
            scale: 1,
            animations: new Map(),
            no_antialiasing: false,
            allowRGB: false,
            allowPixel: true,
            allowHSB: true
        };
    }

    public static function addAnimationToConfig(config:NoteSplashConfig, scale:Float, name:String, prefix:String, fps:Array<Int>, offsets:Array<Float>, indices:Array<Int>, noteData:Int):NoteSplashConfig {
        config.scale = scale;
        config.animations.set(name, {
            prefix: prefix,
            fps: fps,
            offsets: offsets,
            indices: indices,
            noteData: noteData
        });
        return config;
    }

    public static function loadConfig(texture:String):NoteSplashConfig {
        if(configs.exists(texture)) {
            return configs.get(texture);
        }
        
        var config:NoteSplashConfig = createConfig();
        
        var path:String = 'images/$texture.json';
        if(Paths.fileExists(path, TEXT)) {
            try {
                var rawJson:String = Paths.getTextFromFile(path);
                var jsonData:Dynamic = haxe.Json.parse(rawJson);
                
                config.scale = Reflect.hasField(jsonData, "scale") ? Reflect.field(jsonData, "scale") : 1;
                config.allowPixel = Reflect.hasField(jsonData, "allowPixel") ? Reflect.field(jsonData, "allowPixel") : false;
                config.allowHSB = Reflect.hasField(jsonData, "allowHSB") ? Reflect.field(jsonData, "allowHSB") : true;
                config.no_antialiasing = Reflect.hasField(jsonData, "no_antialiasing") ? Reflect.field(jsonData, "no_antialiasing") : false;
                
                if(Reflect.hasField(jsonData, "animations")) {
                    var animsData:Dynamic = Reflect.field(jsonData, "animations");
                    for (field in Reflect.fields(animsData)) {
                        var animData:Dynamic = Reflect.field(animsData, field);
                        var animConfig:NoteSplashAnimConfig = {
                            prefix: Reflect.hasField(animData, "prefix") ? Reflect.field(animData, "prefix") : "",
                            fps: Reflect.hasField(animData, "fps") ? Reflect.field(animData, "fps") : [22, 26],
                            offsets: Reflect.hasField(animData, "offsets") ? Reflect.field(animData, "offsets") : [0, 0],
                            noteData: Reflect.hasField(animData, "noteData") ? Reflect.field(animData, "noteData") : 0
                        };
                        
                        if(Reflect.hasField(animData, "indices")) {
                            animConfig.indices = Reflect.field(animData, "indices");
                        }
                        
                        config.animations.set(field, animConfig);
                    }
                }
            } catch(e:Dynamic) {
                trace('Error loading NoteSplash config: $e');
            }
        }
        
        configs.set(texture, config);
        return config;
    }

    public static function getSplashSkinPostfix():String {
        return '';
    }
    
    override function destroy() {
        if (defScale != null) {
            defScale.put();
            defScale = null;
        }
        
        super.destroy();
    }
}