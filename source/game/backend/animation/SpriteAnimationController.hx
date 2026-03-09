package game.backend.animation;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.util.FlxDestroyUtil;

import game.backend.interfaces.IAnimationController;

class SpriteAnimationController implements IAnimationController
{
    private var parent:FlxSprite;
    private var animOffsets:Map<String, Array<Float>>;
    
    public function new(parent:FlxSprite, animOffsets:Map<String, Array<Float>>)
    {
        this.parent = parent;
        this.animOffsets = animOffsets;
    }
    
    public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
    {
        parent.animation.play(AnimName, Force, Reversed, Frame);
        applyOffset(AnimName);
    }
    
    private function applyOffset(animName:String):Void
    {
        final offset = animOffsets.get(animName);
        if (offset != null)
        {
            parent.offset.set(offset[0], offset[1]);
        }
        else
        {
            parent.offset.set(0, 0);
        }
    }
    
    public function isAnimationFinished():Bool
    {
        return parent.animation.curAnim?.finished ?? false;
    }
    
    public function getAnimationName():String
    {
        return parent.animation.curAnim?.name;
    }
    
    public function setCurrentFrame(frame:Int):Void
    {
        if (parent.animation.curAnim != null)
            parent.animation.curAnim.curFrame = frame;
    }
    
    public function getCurrentFrame():Int
    {
        return parent.animation.curAnim?.curFrame ?? 0;
    }
    
    public function setCurrentFrameRate(fps:Float):Void
    {
        if (parent.animation.curAnim != null)
            parent.animation.curAnim.frameRate = fps;
    }
    
    public function getCurrentFrameRate():Float
    {
        return parent.animation.curAnim?.frameRate ?? 0;
    }
    
    public function isAnimationNull():Bool
    {
        return parent.animation.curAnim == null;
    }
    
    public function isAnimationLooped():Bool
    {
        return parent.animation.curAnim?.looped ?? false;
    }
    
    public function getTotalFrames():Int
    {
        return parent.animation.curAnim?.numFrames ?? 0;
    }
    
    public function isPlaying(animName:String):Bool
    {
        return parent.animation.curAnim?.name == animName;
    }
    
    public function finishAnimation():Void
    {
        parent.animation.curAnim?.finish();
    }
    
    public function stopAnimation():Void
    {
        parent.animation.stop();
    }
    
    public function update(elapsed:Float):Void {}
    
    public function draw(camera:FlxCamera):Void {}
    
    public function getInternalSprite():FlxSprite
    {
        return parent;
    }
    
    public function destroy():Void
    {
        animOffsets = null;
        parent = null;
    }
}