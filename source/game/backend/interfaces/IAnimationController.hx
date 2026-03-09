package game.backend.interfaces;

import flixel.FlxCamera;
import flixel.math.FlxPoint;

interface IAnimationController
{
    function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void;
    function isAnimationFinished():Bool;
    function getAnimationName():String;
    function setCurrentFrame(frame:Int):Void;
    function getCurrentFrame():Int;
    function setCurrentFrameRate(fps:Float):Void;
    function getCurrentFrameRate():Float;
    function isAnimationNull():Bool;
    function isAnimationLooped():Bool;
    function getTotalFrames():Int;
    function isPlaying(animName:String):Bool;
    function finishAnimation():Void;
    function stopAnimation():Void;
    function update(elapsed:Float):Void;
    function draw(camera:FlxCamera):Void;
    function destroy():Void;
    function getInternalSprite():FlxSprite;
}