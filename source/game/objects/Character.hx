package game.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

#if flixel_animate
import animate.FlxAnimate;
#end

#if MODS_ALLOWED
import sys.io.File;
#end

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;

import game.backend.Section.SwagSection;

using StringTools;

typedef CharacterFile =
{
    var animations:Array<AnimArray>;
    var image:String;
    var scale:Float;
    var sing_duration:Float;
    var healthicon:String;
    var position:Array<Float>;
    var camera_position:Array<Float>;
    var flip_x:Bool;
    var no_antialiasing:Bool;
    var vocals_file:String;
    var healthbar_colors:Array<Int>;
}

typedef AnimArray =
{
    var anim:String;
    var name:String;
    var fps:Int;
    var loop:Bool;
    var indices:Array<Int>;
    var offsets:Array<Int>;
}

class Character extends #if flixel_animate FlxAnimate #else FlxSprite #end
{
    public static final templateCharacter:String = '{
		"animations": [
			{
				"loop": false,
				"offsets": [0, 0],
				"fps": 24,
				"anim": "idle",
				"indices": [],
				"name": "Dad idle dance"
			},
			{
				"offsets": [0, 0],
				"indices": [],
				"fps": 24,
				"anim": "singLEFT",
				"loop": false,
				"name": "Dad Sing Note LEFT"
			},
			{
				"offsets": [0, 0],
				"indices": [],
				"fps": 24,
				"anim": "singDOWN",
				"loop": false,
				"name": "Dad Sing Note DOWN"
			},
			{
				"offsets": [0, 0],
				"indices": [],
				"fps": 24,
				"anim": "singUP",
				"loop": false,
				"name": "Dad Sing Note UP"
			},
			{
				"offsets": [0, 0],
				"indices": [],
				"fps": 24,
				"anim": "singRIGHT",
				"loop": false,
				"name": "Dad Sing Note RIGHT"
			}
		],
		"no_antialiasing": false,
		"image": "characters/daddy/DADDY_DEAREST",
		"position": [0, 0],
		"healthicon": "face",
		"flip_x": false,
		"healthbar_colors": [161, 161, 161],
		"camera_position": [0, 0],
		"sing_duration": 6.1,
		"vocals_file": null,
		"scale": 1
	}';
    
    public var debugMode:Bool = false;
    public var isPlayer:Bool = false;
    public var curCharacter:String = DEFAULT_CHARACTER;
    public var voicelining:Bool = false;
    public var mostRecentRow:Int = 0;
    public var ghostIdx:Int = 0;
    public var ghostAnim:String = '';
    public var animGhosts:Array<FlxSprite> = [];
    public var ghostTweens:Array<FlxTween> = [];
    public var colorTween:FlxTween;
    public var holdTimer:Float = 0;
    public var animTimer:Float = 0;
    public var heyTimer:Float = 0;
    public var specialAnim:Bool = false;
    public var animationNotes:Array<Dynamic> = [];
    public var stunned:Bool = false;
    public var singDuration:Float = 4;
    public var idleSuffix:String = '';
    public var danceIdle:Bool = false;
    public var skipDance:Bool = false;
    public var healthIcon:String = 'face';
    public var animationsArray:Array<AnimArray> = [];
    public var positionArray:Array<Float> = [0, 0];
    public var cameraPosition:Array<Float> = [0, 0];
    public var hasMissAnimations:Bool = false;
    public var imageFile:String = '';
    public var jsonScale:Float = 1;
    public var noAntialiasing:Bool = false;
    public var originalFlipX:Bool = false;
    public var vocalsFile:String = '';
    public var healthColorArray:Array<Int> = [255, 0, 0];
    public var danced:Bool = false;
    public var danceEveryNumBeats:Int = 2;
    public var twitchyAnimations:Bool = false;

    public var endAnimTimer:FlxTimer = null;
    
    public static final DEFAULT_CHARACTER:String = 'bf';
    
    public var animOffsets(default, null):Map<String, Array<Float>> = new Map();
    private var settingCharacterUp:Bool = true;
    
    public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false, ?isChibiChar:Bool = false)
    {
        super(x, y);
        
        curCharacter = character;
        this.isPlayer = isPlayer;
        
        var characterPath:String = 'data/characters/' + curCharacter + '.json';
        if (!Paths.fileExists(characterPath, TEXT))
        {
            characterPath = 'data/characters/' + DEFAULT_CHARACTER + '.json';
        }
        
        final json:CharacterFile = cast Json.parse(Paths.getTextFromFile(characterPath));
        imageFile = json.image;
        
        final spriteType:String = getSpriteType(json.image);
        switch (spriteType)
        {
            case "packer":
                frames = Paths.getPackerAtlas(json.image);
            case "sparrow":
                frames = Paths.getSparrowAtlas(json.image);
            #if flixel_animate
            case "texture":
                try
                {
                    frames = Paths.getAnimateAtlas(json.image);
                }
                catch (e:haxe.Exception)
                {
                    FlxG.log.warn('Could not load atlas ${json.image}: $e');
                    trace(e.stack);
                }
            #end
        }
        
        if (json.scale != 1)
        {
            jsonScale = json.scale;
            scale.set(jsonScale, jsonScale);
            updateHitbox();
        }
        
        positionArray = json.position;
        cameraPosition = json.camera_position;
        healthIcon = json.healthicon;
        singDuration = json.sing_duration;
        vocalsFile = json.vocals_file ?? '';
        flipX = !!json.flip_x;
        
        if (json.no_antialiasing)
        {
            antialiasing = false;
            noAntialiasing = true;
        }
        
        if (json.healthbar_colors?.length > 2)
        {
            healthColorArray = json.healthbar_colors;
        }
        
        antialiasing = !noAntialiasing && ClientPrefs.globalAntialiasing;
        
        animationsArray = json.animations;
        if (animationsArray?.length > 0)
        {
            for (animData in animationsArray)
            {
                final animAnim:String = '' + animData.anim;
                final animName:String = '' + animData.name;
                final animFps:Int = animData.fps;
                final animLoop:Bool = !!animData.loop;
                final animIndices:Array<Int> = animData.indices;

                #if flixel_animate
                if (isAnimate)
                {
                    if (animIndices?.length > 0)
                    {
                        if (library?.getSymbol(animName) != null)
                            anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
                        else
                            anim.addByFrameLabelIndices(animAnim, animName, animIndices, animFps, animLoop);
                    }
                    else
                    {
                        if (library?.getSymbol(animName) != null)
                            anim.addBySymbol(animAnim, animName, animFps, animLoop);
                        else
                            anim.addByFrameLabel(animAnim, animName, animFps, animLoop);
                    }
                }
                else
                #end
                {
                    if (animIndices?.length > 0)
                        animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
                    else
                        animation.addByPrefix(animAnim, animName, animFps, animLoop);
                }

                if (animData.offsets?.length > 1)
                    animOffsets.set(animData.anim, [animData.offsets[0], animData.offsets[1]]);
            }
        }
        else
        {
            quickAnimAdd('idle', 'BF idle dance');
        }
        
        if (isChibiChar)
        {
            scale.set(scale.x / 3, scale.y / 3);
            updateHitbox();
            origin.set();
            
            x -= width * 0.5;
            y -= height;
            
            for (animData in animationsArray)
            {
                if (animData.offsets != null)
                    animOffsets.set(animData.anim, [animData.offsets[0] * scale.x, animData.offsets[1] * scale.y]);
            }
        }
        
        originalFlipX = flipX;
        hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
        
        recalculateDanceIdle();
        dance();
        
        if (isPlayer)
            flipX = !flipX;
        
        switch (curCharacter)
        {
            case 'pico-speaker':
                skipDance = true;
                loadMappedAnims();
                playAnim("shoot1");
        }
        
        initGhosts();
    }
    
    private function getSpriteType(imageName:String):String
    {
        if (Paths.fileExists('images/' + imageName + '.txt', TEXT))
            return "packer";
        
        #if flixel_animate
        if (Paths.fileExists('images/' + imageName + '/Animation.json', TEXT))
            return "texture";
        #end
        
        return "sparrow";
    }
    
    private function initGhosts():Void
    {
        for (i in 0...4)
        {
            var ghost:FlxSprite = null;
            
            #if flixel_animate
            if (isAnimate)
            {
                var animateGhost = new FlxAnimate();
                try
                {
                    animateGhost.frames = Paths.getAnimateAtlas(imageFile);
                }
                catch (e:Dynamic)
                {
                    FlxG.log.warn('Could not load ghost atlas for $imageFile: $e');
                }
                
                if (animationsArray != null)
                {
                    for (animData in animationsArray)
                    {
                        var animAnim:String = '' + animData.anim;
                        var animName:String = '' + animData.name;
                        var animFps:Int = animData.fps;
                        var animLoop:Bool = !!animData.loop;
                        var animIndices:Array<Int> = animData.indices;
                        
                        if (animIndices?.length > 0)
                            animateGhost.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
                        else if (animateGhost.library?.getSymbol(animName) != null)
                            animateGhost.anim.addBySymbol(animAnim, animName, animFps, animLoop);
                        else
                            animateGhost.anim.addByFrameLabel(animAnim, animName, animFps, animLoop);
                    }
                }
                ghost = animateGhost;
            }
            else
            #end
            {
                ghost = new FlxSprite();
                ghost.frames = frames;
                ghost.animation.copyFrom(animation);
            }
            
            ghost.visible = false;
            ghost.alpha = 0.6;
            
            animGhosts.push(ghost);
            ghostTweens.push(null);
        }
    }
    
    override function update(elapsed:Float)
    {
        if (debugMode || isAnimationNull())
        {
            super.update(elapsed);
            return;
        }
        
        switch (curCharacter)
        {
            case 'pico-speaker':
                if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
                {
                    var noteData:Int = 1;
                    if (animationNotes[0][1] > 2)
                        noteData = 3;
                    
                    noteData += FlxG.random.int(0, 1);
                    playAnim('shoot' + noteData, true);
                    animationNotes.shift();
                }
                
                if (isAnimationFinished())
                {
                    playAnim(getAnimationName(), false, false, getTotalFrames() - 3);
                }
        }
        
        if (animTimer > 0) 
        {
            animTimer -= elapsed;
            if (animTimer <= 0)
            {
                animTimer = 0;
                dance();
            }
        }
        
        if (heyTimer > 0)
        {
            heyTimer -= elapsed * PlayState.instance.playbackRate;
            if (heyTimer <= 0)
            {
                if (specialAnim && (getAnimationName() == 'hey' || getAnimationName() == 'cheer'))
                {
                    specialAnim = false;
                    dance();
                }
                heyTimer = 0;
            }
        }
        else if (specialAnim && isAnimationFinished())
        {
            specialAnim = false;
            dance();
        }
        else if (getAnimationName() != null && getAnimationName().endsWith('miss') && isAnimationFinished())
        {
            dance();
            finishAnimation();
        }
        
        var animName = getAnimationName();
        if (animName != null && animName.startsWith('sing'))
        {
            holdTimer += elapsed;
        }
        else if (isPlayer)
        {
            holdTimer = 0;
        }
        
        if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 * (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1)) * singDuration)
        {
            dance();
            holdTimer = 0;
        }
        
        if (animName != null && isAnimationFinished() && hasAnimation(animName + '-loop'))
        {
            playAnim(animName + '-loop');
        }
        
        for (ghost in animGhosts)
            ghost.update(elapsed);
        
        super.update(elapsed);
    }
    
    override public function draw()
    {
        for (ghost in animGhosts)
        {
            if (ghost.visible)
                ghost.draw();
        }
        
        super.draw();
    }
    
    public function dance():Void
    {
        if (!debugMode && !skipDance && animTimer <= 0 && !specialAnim && !voicelining)
        {
            if (danceIdle)
            {
                danced = !danced;
                playAnim(danced ? 'danceRight' + idleSuffix : 'danceLeft' + idleSuffix);
            }
            else if (hasAnimation('idle' + idleSuffix))
            {
                playAnim('idle' + idleSuffix);
            }
        }
    }
    
    public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
    {
        specialAnim = false;
        animation.play(AnimName, Force, Reversed, Frame);

        var daOffset = animOffsets.get(AnimName);
        if (animOffsets.exists(AnimName))
            offset.set(daOffset[0], daOffset[1]);
        else
            offset.set(0, 0);
        
        if (curCharacter.startsWith('gf'))
        {
            if (AnimName == 'singLEFT')
                danced = true;
            else if (AnimName == 'singRIGHT')
                danced = false;
            else if (AnimName == 'singUP' || AnimName == 'singDOWN')
                danced = !danced;
        }
    }
    
    public function playGhostAnim(GhostIdx:Int = 0, AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
    {
        if (GhostIdx < 0 || GhostIdx >= animGhosts.length) return;
        
        final ghost = animGhosts[GhostIdx];
        ghost.scale.set(scale.x, scale.y);
        ghost.x = x;
        ghost.y = y;
        ghost.flipX = flipX;
        ghost.flipY = flipY;
        ghost.alpha = alpha * 0.6;
        ghost.visible = visible;
        ghost.angle = angle;
        ghost.shader = shader;
        ghost.blend = blend;
        ghost.antialiasing = antialiasing;
        ghost.scrollFactor.copyFrom(scrollFactor);

        ghost.color = FlxColor.fromRGB(
			Std.int((healthColorArray[0]/255) * color.red),
			Std.int((healthColorArray[1]/255) * color.green),
			Std.int((healthColorArray[2]/255) * color.blue)
		);
        
        final daOffset = animOffsets.get(AnimName);
        if (daOffset != null)
            ghost.offset.set(daOffset[0], daOffset[1]);
        else
            ghost.offset.set(0, 0);

        #if flixel_animate
        if (Std.isOfType(ghost, FlxAnimate))
        {
            final animateGhost:FlxAnimate = cast ghost;
            animateGhost.anim.play(AnimName, Force, Reversed, Frame);
            animateGhost.update(0);
        }
        else
        #end
        {
            ghost.animation.play(AnimName, Force, Reversed, Frame);
        }
        
        if (GhostIdx < ghostTweens.length && ghostTweens[GhostIdx] != null)
        {
            ghostTweens[GhostIdx].cancel();
        }
        
        ghostTweens[GhostIdx] = FlxTween.tween(ghost, {alpha: 0}, 0.75,
        {
            ease: FlxEase.linear,
            onComplete: function(twn:FlxTween)
            {
                ghost.visible = false;
                ghostTweens[GhostIdx] = null;
            }
        });
    }
    
    public function quickAnimAdd(name:String, animName:String):Void
    {
        #if flixel_animate
        if (isAnimate)
            anim.addBySymbol(name, animName, 24, false);
        else
        #end
            animation.addByPrefix(name, animName, 24, false);
    }
    
    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
    {
        animOffsets.set(name, [x, y]);
    }
    
    public function hasAnimation(animName:String):Bool
    {
        return animOffsets.exists(animName);
    }
    
    public function isAnimationNull():Bool
    {
        return animation.curAnim == null;
    }
    
    public function getAnimationName():String
    {
        return animation.curAnim?.name ?? null;
    }
    
    public function isAnimationFinished():Bool
    {
        return animation.curAnim?.finished ?? true;
    }
    
    public function isAnimationLooped():Bool
    {
        return animation.curAnim?.looped ?? false;
    }
    
    public function getTotalFrames():Int
    {
        return animation.curAnim?.frames.length ?? 0;
    }
    
    public function setCurrentFrameRate(fps:Float):Void
    {
        if (animation.curAnim != null)
            animation.curAnim.frameRate = fps;
    }
    
    public function getCurrentFrameRate():Float
    {
        return animation.curAnim?.frameRate ?? 0;
    }
    
    public function setCurrentFrame(frame:Int):Void
    {
        if (animation.curAnim != null)
            animation.curAnim.curFrame = frame;
    }
    
    public function getCurrentFrame():Int
    {
        return animation.curAnim?.curFrame ?? 0;
    }
    
    public function isPlaying(animName:String):Bool
    {
        return animation.curAnim?.name == animName && !animation.curAnim?.finished;
    }
    
    public function finishAnimation():Void
    {
        animation.curAnim?.finish();
    }
    
    public function stopAnimation():Void
    {
        animation.curAnim?.stop();
    }
    
    private function loadMappedAnims():Void
    {
        try
        {
            var noteData:Array<SwagSection> = Song.loadFromJson('picospeaker', Paths.formatToSongPath(PlayState.SONG.song)).notes;
            
            for (section in noteData)
            {
                for (songNotes in section.sectionNotes)
                {
                    animationNotes.push(songNotes);
                }
            }
            
            game.stages.objects.TankmenBG.animationNotes = animationNotes;
            animationNotes.sort(sortAnims);
        }
        catch (e:Dynamic) {}
    }
    
    private function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
    {
        return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
    }
    
    public function recalculateDanceIdle():Void
    {
        var lastDanceIdle:Bool = danceIdle;
        danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));
        
        if (settingCharacterUp)
        {
            danceEveryNumBeats = (danceIdle ? 1 : 2);
        }
        else if (lastDanceIdle != danceIdle)
        {
            danceEveryNumBeats = Math.round(Math.max(danceIdle ? danceEveryNumBeats * 0.5 : danceEveryNumBeats * 2, 1));
        }
        
        settingCharacterUp = false;
    }

    public var isAnimateAtlas(get, never):Bool;
    private inline function get_isAnimateAtlas():Bool
    {
        #if flixel_animate
        return isAnimate;
        #else
        return false;
        #end
    }
    
    override public function destroy():Void
    {
        for (ghost in animGhosts)
        {
            if (ghost == null) continue;
            
            #if flixel_animate
            if (Std.isOfType(ghost, FlxAnimate))
            {
                final animateGhost:FlxAnimate = cast ghost;
                animateGhost.anim?.destroyAnimations();
                animateGhost.destroy();
            }
            else
            #end
            {
                ghost.destroy();
            }
        }
        animGhosts.resize(0);
        
        for (tween in ghostTweens)
        {
            tween?.cancel();
        }
        ghostTweens.resize(0);

        if (endAnimTimer != null) {
            endAnimTimer.cancel();
            endAnimTimer = null;
        }
        
        super.destroy();
    }
}