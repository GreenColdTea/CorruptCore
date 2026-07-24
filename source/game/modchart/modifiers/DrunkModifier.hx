package game.modchart.modifiers;

import flixel.FlxSprite;
import ui.*;
import game.modchart.*;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;
import math.*;

/**
 * Applies various wobble and wave effects to note positions
 * Simulates visual distortion effects like drunkenness, tipsiness, and bumpy movement
 */
class DrunkModifier extends NoteModifier {
    override function getName():String {
        return 'drunk';
    }

    /**
     * Returns all submodifiers for controlling different aspects of drunk effects
     */
    override function getSubmods():Array<String> {
        return [
            "tipsy", "tipsySpeed", "tipsyOffset", // Tipsy effect - vertical wobble
            "bumpy", "bumpyOffset", "bumpyPeriod", // Tipsy effect - vertical wobble
            "drunkSpeed", "drunkOffset", "drunkPeriod",  // Drunk effect - horizontal wobble
            "tipZ", "tipZSpeed", "tipZOffset",  // Drunk effect - horizontal wobble
            "drunkZ", "drunkZSpeed", "drunkZOffset", "drunkZPeriod"  // DrunkZ effect - Z-axis drunk wobble
        ];
    }

    /**
     * Applies various drunk effects to note positions
     * Combines multiple wave-based distortions for complex visual effects
     */
    override function getPos(
        time:Float, 
        visualDiff:Float, 
        timeDiff:Float, 
        beat:Float, 
        pos:Vector3, 
        data:Int, 
        player:Int, 
        obj:FlxSprite
    ):Vector3 {
        applyTipsyEffect(pos, data, player);
        applyDrunkEffect(pos, visualDiff, data, player);
        applyTipZEffect(pos, data, player);
        applyBumpyEffect(pos, visualDiff, player);
        
        return pos;
    }

    /**
     * Applies tipsy effect - vertical wobble using cosine waves
     * Creates up-and-down bouncing motion
     */
    private function applyTipsyEffect(pos:Vector3, noteData:Int, player:Int):Void {
        var tipsyIntensity = getSubmodValue("tipsy", player);
        
        if (tipsyIntensity != 0) {
            var speed = getSubmodValue("tipsySpeed", player);
            var offset = getSubmodValue("tipsyOffset", player);
            var currentTime = Conductor.songPosition / 1000;
            
            // Calculate vertical offset using cosine wave
            var waveAngle = currentTime * ((speed * 1.2) + 1.2) + noteData * ((offset * 1.8) + 1.8);
            var verticalOffset = tipsyIntensity * Math.cos(waveAngle) * Note.swagWidth * 0.4;
            
            pos.y += verticalOffset;
        }
    }

    /**
     * Applies drunk effect - horizontal wobble using cosine waves
     * Creates side-to-side swaying motion
     */
    private function applyDrunkEffect(pos:Vector3, visualDiff:Float, noteData:Int, player:Int):Void {
        var drunkIntensity = getValue(player);
        
        if (drunkIntensity != 0) {
            var speed = getSubmodValue("drunkSpeed", player);
            var period = getSubmodValue("drunkPeriod", player);
            var offset = getSubmodValue("drunkOffset", player);
            var currentTime = Conductor.songPosition / 1000;
            
            // Calculate horizontal offset using complex wave function
            var waveAngle = currentTime * (1 + speed) 
                          + noteData * ((offset * 0.2) + 0.2)
                          + visualDiff * ((period * 10) + 10) / FlxG.height;
            
            var horizontalOffset = drunkIntensity * Math.cos(waveAngle) * Note.swagWidth * 0.5;
            
            pos.x += horizontalOffset;
        }
    }

    /**
     * Applies tipZ effect - depth wobble using cosine waves
     * Creates forward-and-back movement in the Z-axis
     */
    private function applyTipZEffect(pos:Vector3, noteData:Int, player:Int):Void {
        var tipZIntensity = getSubmodValue("tipZ", player);
        
        if (tipZIntensity != 0) {
            var speed = getSubmodValue("tipZSpeed", player);
            var offset = getSubmodValue("tipZOffset", player);
            var currentTime = Conductor.songPosition / 1000;
            
            // Calculate Z-axis offset using cosine wave
            var waveAngle = currentTime * ((speed * 1.2) + 1.2) + noteData * ((offset * 1.8) + 3.2);
            var depthOffset = tipZIntensity * Math.cos(waveAngle) * 0.15;
            
            pos.z += depthOffset;
        }
    }

    /**
     * Applies bumpy effect - depth wobble using sine waves
     * Creates bouncing motion based on visual position
     */
    private function applyBumpyEffect(pos:Vector3, visualDiff:Float, player:Int):Void {
        var bumpyIntensity = getSubmodValue("bumpy", player);
        
        if (bumpyIntensity != 0) {
            var period = getSubmodValue("bumpyPeriod", player);
            var offset = getSubmodValue("bumpyOffset", player);
            
            // Calculate Z-axis offset using sine wave based on visual position
            var waveAngle = (visualDiff + (100.0 * offset)) / ((period * 16.0) + 16.0);
            var depthOffset = (bumpyIntensity * 40 * Math.sin(waveAngle)) / 250;
            
            pos.z += depthOffset;
        }
    }
}