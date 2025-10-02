package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;

import math.*;
import game.modchart.*;

/**
 * Creates a rhythmic wobbling effect on notes based on the beat
 * Notes move horizontally in sync with the music beat for visual emphasis
 */
class BeatModifier extends NoteModifier {
    override function getName():String {
        return 'beat';
    }

    /**
     * Calculates and applies beat-based horizontal movement to note positions
     * Creates a wobble effect that accelerates and decelerates with each beat
     * 
     * @param time Note strum time
     * @param visualDiff Visual position difference (strumTime - currentTime with scroll speed)
     * @param timeDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision
     * @param pos Current position vector to modify
     * @param data Note direction/column
     * @param player Player index (0 = BF, 1 = Dad, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with beat wobble applied
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
        // Early return if modifier is disabled for this player
        if (getValue(player) == 0) {
            return pos;
        }

        var wobbleAmount = calculateBeatWobble(visualDiff);
        pos.x += getValue(player) * wobbleAmount;
        
        return pos;
    }

    /**
     * Calculates the horizontal wobble amount based on current beat progression
     * Uses smooth acceleration and deceleration for natural movement
     */
    private function calculateBeatWobble(visualDiff:Float):Float {
        // Animation timing constants
        final ACCELERATION_TIME:Float = 0.3;  // Time spent accelerating (in beats)
        final TOTAL_CYCLE_TIME:Float = 0.7;   // Total beat cycle time (in beats)

        @:privateAccess
        var currentBeat:Float = PlayState.instance.curBeat + ACCELERATION_TIME;

        // Don't apply effect for negative beats (before song starts)
        if (currentBeat < 0) {
            return 0;
        }

        var beatProgress = getNormalizedBeatProgress(currentBeat, TOTAL_CYCLE_TIME);
        
        // Return 0 if we're outside the active wobble portion of the cycle
        if (beatProgress >= TOTAL_CYCLE_TIME) {
            return 0;
        }

        var wobbleIntensity = calculateWobbleIntensity(beatProgress, ACCELERATION_TIME, TOTAL_CYCLE_TIME);
        var directionalShift = applyWobbleDirection(wobbleIntensity, visualDiff);
        
        return directionalShift;
    }

    /**
     * Normalizes the beat value to a 0-1 range within the cycle
     * Handles beat wrapping and fractional beat calculations
     */
    private function getNormalizedBeatProgress(currentBeat:Float, cycleTime:Float):Float {
        var isEvenBeat = (currentBeat % 2) != 0;
        var fractionalBeat = currentBeat - Math.floor(currentBeat);
        
        // Ensure we have a continuous 0-1 progression
        fractionalBeat += 1;
        fractionalBeat -= Math.floor(fractionalBeat);
        
        return fractionalBeat;
    }

    /**
     * Calculates the intensity of wobble using easing functions
     * Applies smooth acceleration and deceleration
     */
    private function calculateWobbleIntensity(beatProgress:Float, accelTime:Float, totalTime:Float):Float {
        var intensity:Float = 0;
        
        if (beatProgress < accelTime) {
            // Acceleration phase - ease in
            intensity = MathUtil.scale(beatProgress, 0, accelTime, 0, 1);
            intensity *= intensity; // Quadratic ease in
        } else {
            // Deceleration phase - ease out
            intensity = MathUtil.scale(beatProgress, accelTime, totalTime, 1, 0);
            intensity = 1 - (1 - intensity) * (1 - intensity); // Quadratic ease out
        }
        
        return intensity;
    }

    /**
     * Applies directional and positional factors to the wobble intensity
     * Creates the final horizontal shift value
     */
    private function applyWobbleDirection(wobbleIntensity:Float, visualDiff:Float):Float {
        @:privateAccess
        var isEvenBeat = (PlayState.instance.curBeat % 2) != 0;
        
        // Alternate direction on even/odd beats
        if (isEvenBeat) {
            wobbleIntensity *= -1;
        }

        // Apply sine wave based on visual position for wave-like effect
        var baseShift = 40 * wobbleIntensity;
        var waveEffect = FlxMath.fastSin((visualDiff / 30) + Math.PI / 2);
        
        return baseShift * waveEffect;
    }
}