package game.backend.animation;

#if flixel_animate
import animate.FlxAnimate;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxColor;
import openfl.geom.ColorTransform;

import game.backend.interfaces.IAnimationController;
import game.objects.Character;

class AnimateAnimationController implements IAnimationController
{
    private var character:Character;
    private var atlas:FlxAnimate;
    private var animOffsets:Map<String, Array<Float>>;
    
    public function new(character:Character, atlas:FlxAnimate, animOffsets:Map<String, Array<Float>>)
    {
        this.character = character;
        this.atlas = atlas;
        this.animOffsets = animOffsets;
    }
    
    public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
    {
        atlas.anim.play(AnimName, Force, Reversed, Frame);
        atlas.update(0);
        applyOffset(AnimName);
    }
    
    private function applyOffset(animName:String):Void
    {
        final offset = animOffsets.get(animName);
        if (offset != null)
        {
            atlas.offset.set(offset[0], offset[1]);
        }
        else
        {
            atlas.offset.set(0, 0);
        }
    }
    
    public function isAnimationFinished():Bool
    {
        return atlas.anim.finished;
    }
    
    public function getAnimationName():String
    {
        return atlas.anim.curAnim?.name;
    }
    
    public function setCurrentFrame(frame:Int):Void
    {
        if (atlas.anim.curAnim != null)
        {
            atlas.anim.curAnim.curFrame = frame;
            atlas.update(0);
        }
    }
    
    public function getCurrentFrame():Int
    {
        return atlas.anim.curAnim?.curFrame ?? 0;
    }
    
    public function setCurrentFrameRate(fps:Float):Void
    {
        if (atlas.anim.curAnim != null)
            atlas.anim.curAnim.frameRate = fps;
    }
    
    public function getCurrentFrameRate():Float
    {
        return atlas.anim.curAnim?.frameRate ?? 0;
    }
    
    public function isAnimationNull():Bool
    {
        return atlas.anim.curAnim == null;
    }
    
    public function isAnimationLooped():Bool
    {
        return atlas.anim.curAnim?.looped ?? false;
    }
    
    public function getTotalFrames():Int
    {
        return atlas.anim.curAnim?.numFrames ?? 0;
    }
    
    public function isPlaying(animName:String):Bool
    {
        return atlas.anim.curAnim?.name == animName;
    }
    
    public function finishAnimation():Void
    {
        atlas.anim.finish();
    }
    
    public function stopAnimation():Void
    {
        atlas.anim.stop();
    }
    
    public function update(elapsed:Float):Void
    {
        atlas.update(elapsed);
        syncTransform();
    }
    
    private function syncTransform():Void
    {
        atlas.x = character.x;
        atlas.y = character.y;
        atlas.scale.set(character.scale.x, character.scale.y);
        atlas.angle = character.angle;
        atlas.alpha = character.alpha;
        atlas.visible = character.visible;
        atlas.flipX = character.flipX;
        atlas.flipY = character.flipY;
        atlas.antialiasing = character.antialiasing;
        atlas.scrollFactor.copyFrom(character.scrollFactor);
        atlas.shader = character.shader;
        atlas.blend = character.blend;
        atlas.color = character.color;
    }
    
    public function draw(camera:FlxCamera):Void
    {
        syncTransform();
        atlas.draw();
    }
    
    public function getInternalSprite():FlxSprite
    {
        return atlas;
    }
    
    public function destroy():Void
    {
        animOffsets = null;
        atlas = null;
        character = null;
    }
}
#end