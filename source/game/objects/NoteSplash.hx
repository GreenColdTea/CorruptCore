package game.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import openfl.utils.Assets as OpenFlAssets;

import lime.utils.Assets;

typedef NoteSplashConfig = {
    var scale:Float;
    var animations:Map<String, NoteSplashAnimConfig>;
    @:optional var allowRGB:Bool;
    @:optional var allowPixel:Bool;
    @:optional var rgb:Array<Dynamic>;
}

typedef NoteSplashAnimConfig = {
    var prefix:String;
    var fps:Array<Int>;
    var offsets:Array<Float>;
    @:optional var indices:Array<Int>;
    var noteData:Int;
}

class NoteSplash extends FlxSprite
{
    public static var configs:Map<String, NoteSplashConfig> = new Map();
    public static final defaultNoteSplash:String = 'noteSplashes';
    
    public var colorSwap:ColorSwap = null;
    private var textureLoaded:String = null;

    public var config:NoteSplashConfig;
    public var inEditor:Bool = false;
    public var babyArrow:StrumNote;
    
    public var copyX:Bool = true;
    public var copyY:Bool = true;
    public var spawned:Bool = false;

    public function new(x:Float = 0, y:Float = 0, ?note:Int = 0, ?texture:String = null) {
        super(x, y);

        animation = new PsychAnimationController(this);

        var skin:String = texture ?? defaultNoteSplash;
        if(PlayState.SONG?.splashSkin?.length > 0) 
            skin = PlayState.SONG.splashSkin;

        loadSplash(skin);
        
        colorSwap = new ColorSwap();
        shader = colorSwap.shader;

        setupNoteSplash(x, y, note, texture);
        antialiasing = ClientPrefs.globalAntialiasing;
    }

    public function loadSplash(texture:String) {
        if(textureLoaded != texture) {
            frames = Paths.getSparrowAtlas(texture);
            textureLoaded = texture;
            
            config = loadConfig(texture);
            
            loadAnims(texture);
            
            if(config?.animations != null) {
                for (animName => animData in config.animations) {
                    if(animation.getByName(animName) == null) {
                        if(animData.indices != null && animData.indices.length > 0) {
                            animation.addByIndices(animName, animData.prefix, animData.indices, "", animData.fps[0], false);
                        } else {
                            animation.addByPrefix(animName, animData.prefix, animData.fps[0], false);
                        }
                    }
                }
            }
        }
    }

    function loadAnims(skin:String) {
        frames = Paths.getSparrowAtlas(skin);
        for (i in 1...3) {
            animation.addByPrefix("note1-" + i, "note splash blue " + i, 24, false);
            animation.addByPrefix("note2-" + i, "note splash green " + i, 24, false);
            animation.addByPrefix("note0-" + i, "note splash purple " + i, 24, false);
            animation.addByPrefix("note3-" + i, "note splash red " + i, 24, false);
        }
    }

    public function setupNoteSplash(x:Float, y:Float, note:Int = 0, ?texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0) {
        aliveTime = 0;

        if (babyArrow != null && copyX && copyY) {
            setPosition(babyArrow.x - Note.swagWidth * 0.95, babyArrow.y - Note.swagWidth);
        } else {
            setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
        }
        
        alpha = 0.6;

        if(texture == null) {
            texture = defaultNoteSplash;
            if(PlayState.SONG?.splashSkin?.length > 0) 
                texture = PlayState.SONG.splashSkin;
        }

        if(textureLoaded != texture) {
            loadSplash(texture);
        }
        
        if(colorSwap != null) {
            colorSwap.hue = hueColor;
            colorSwap.saturation = satColor;
            colorSwap.brightness = brtColor;
        }

        offset.set(10, 10);

        playRandomAnim(note);
    }

    function playRandomAnim(note:Int) {
        var anims:Array<String> = [];
        
        if(config?.animations != null) {
            for (animName => animData in config.animations) {
                if(animData.noteData == note) {
                    anims.push(animName);
                }
            }
        }
        
        if(anims.length == 0) {
            for (i in 1...3) {
                anims.push('note$note-$i');
            }
        }
        
        if(anims.length > 0) {
            var animNum:Int = FlxG.random.int(0, anims.length - 1);
            var animName:String = anims[animNum];
            
            if(animation.getByName(animName) != null) {
                animation.play(animName, true);
                if(animation.curAnim != null) {
                    var animData = config?.animations != null ? config.animations.get(animName) : null;
                    if(animData?.fps.length > 1) {
                        animation.curAnim.frameRate = FlxG.random.int(animData.fps[0], animData.fps[1]);
                    } else {
                        animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
                    }
                    
                    if(animData?.offsets?.length >= 2) {
                        offset.x = 10 + animData.offsets[0];
                        offset.y = 10 + animData.offsets[1];
                    }
                }
            }
        }

        animation.onFinish.add((name:String) -> {
            if (!inEditor) { 
                kill();
                spawned = false;
            } else {
                animation.stop();
            }
        });
    }

    public function spawnSplashNote(x:Float, y:Float, noteData:Int, ?texture:String = null, ?playAnim:Bool = true) {
        setPosition(x, y);
        
        if(texture != null && textureLoaded != texture) {
            loadSplash(texture);
        }
        
        if(playAnim) {
            playRandomAnim(noteData);
        }
        
        alpha = 1;
        
        if(config != null) {
            scale.set(config.scale, config.scale);
            updateHitbox();
        }
        
        spawned = true;
    }
    
    var aliveTime:Float = 0;
    static var buggedKillTime:Float = 0.5;
    override function update(elapsed:Float) {
        if (spawned) {
            aliveTime += elapsed;
            if (animation.curAnim == null && aliveTime >= buggedKillTime && !inEditor) {
                kill();
                spawned = false;
            }
        }
        
        if (spawned && babyArrow != null) {
            if (copyX)
                x = babyArrow.x - Note.swagWidth * 0.95;
            if (copyY)
                y = babyArrow.y - Note.swagWidth;
        }

        super.update(elapsed);
    }

    public static function createConfig():NoteSplashConfig {
        return {
            scale: 1,
            animations: new Map(),
            allowRGB: false,
            allowPixel: false
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
}