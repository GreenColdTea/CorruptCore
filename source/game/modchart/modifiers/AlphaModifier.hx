package game.modchart.modifiers;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import math.*;
import game.modchart.*;

/**
 * Handles note and receptor visibility effects including:
 * - Stealth (partial/full invisibility)
 * - Hidden (fade out from bottom)
 * - Sudden (fade out from top) 
 * - Blink (pulsing visibility)
 * - RandomVanish (distance-based fading)
 * - Dark (receptor dimming)
 */
class AlphaModifier extends NoteModifier {
    private static final FADE_DISTANCE_Y:Float = 120; // Distance for fade effects

    override function getName():String {
        return 'stealth';
    }

    override function ignorePos():Bool {
        return true; // This modifier doesn't affect position, only visibility
    }

    override function shouldExecute(player:Int, val:Float):Bool {
        return true; // Always execute to handle submodifiers
    }

    override function ignoreUpdateReceptor():Bool {
        return false; // This modifier affects receptors
    }

    override function ignoreUpdateNote():Bool {
        return false; // This modifier affects notes
    }

    override function getSubmods():Array<String> {
        var subMods:Array<String> = [
            "noteAlpha", "alpha", "hidden", "hiddenOffset", "sudden", 
            "suddenOffset", "blink", "randomVanish", "dark", 
            "useStealthGlow", "stealthPastReceptors"
        ];
        
        // Add per-noteData variants for specific column effects
        for (i in 0...4) {
            subMods.push('noteAlpha$i');
            subMods.push('alpha$i');
            subMods.push('dark$i');
        }
        
        return subMods;
    }

    /**
     * Calculates combined hidden+sudden effect intensity
     */
    private function getHiddenSudden(player:Int = -1):Float {
        return getSubmodValue("hidden", player) * getSubmodValue("sudden", player);
    }

    /**
     * Calculates the end boundary for hidden (bottom fade) effect
     */
    private function getHiddenEnd(player:Int = -1):Float {
        var centerY = FlxG.height / 2;
        var hiddenScale = MathUtil.scale(getHiddenSudden(player), 0, 1, -1, -1.25);
        var hiddenOffset = (FlxG.height / 2) * getSubmodValue("hiddenOffset", player);
        
        return centerY + FADE_DISTANCE_Y * hiddenScale + hiddenOffset;
    }

    /**
     * Calculates the start boundary for hidden (bottom fade) effect
     */
    private function getHiddenStart(player:Int = -1):Float {
        var centerY = FlxG.height / 2;
        var hiddenScale = MathUtil.scale(getHiddenSudden(player), 0, 1, 0, -0.25);
        var hiddenOffset = (FlxG.height / 2) * getSubmodValue("hiddenOffset", player);
        
        return centerY + FADE_DISTANCE_Y * hiddenScale + hiddenOffset;
    }

    /**
     * Calculates the end boundary for sudden (top fade) effect
     */
    private function getSuddenEnd(player:Int = -1):Float {
        var centerY = FlxG.height / 2;
        var suddenScale = MathUtil.scale(getHiddenSudden(player), 0, 1, 1, 1.25);
        var suddenOffset = (FlxG.height / 2) * getSubmodValue("suddenOffset", player);
        
        return centerY + FADE_DISTANCE_Y * suddenScale + suddenOffset;
    }

    /**
     * Calculates the start boundary for sudden (top fade) effect
     */
    private function getSuddenStart(player:Int = -1):Float {
        var centerY = FlxG.height / 2;
        var suddenScale = MathUtil.scale(getHiddenSudden(player), 0, 1, 0, 0.25);
        var suddenOffset = (FlxG.height / 2) * getSubmodValue("suddenOffset", player);
        
        return centerY + FADE_DISTANCE_Y * suddenScale + suddenOffset;
    }

    // ==================== VISIBILITY CALCULATIONS ====================

    /**
     * Calculates overall visibility based on all alpha effects
     */
    private function getVisibility(yPos:Float, player:Int, note:Note):Float {
        var alpha:Float = 0;
        var distFromCenter = yPos;

        // Skip stealth effects for notes past receptors if configured
        if (yPos < 0 && getSubmodValue("stealthPastReceptors", player) == 0) {
            return 1.0;
        }

        var currentTime = Conductor.songPosition / 1000;

        // Apply hidden (bottom fade) effect
        if (getSubmodValue("hidden", player) != 0) {
            var hiddenAdjust = MathUtil.clamp(
                MathUtil.scale(yPos, getHiddenStart(player), getHiddenEnd(player), 0, -1),
                -1, 0
            );
            alpha += getSubmodValue("hidden", player) * hiddenAdjust;
        }

        // Apply sudden (top fade) effect
        if (getSubmodValue("sudden", player) != 0) {
            var suddenAdjust = MathUtil.clamp(
                MathUtil.scale(yPos, getSuddenStart(player), getSuddenEnd(player), 0, -1),
                -1, 0
            );
            alpha += getSubmodValue("sudden", player) * suddenAdjust;
        }

        // Apply base stealth effect
        if (getValue(player) != 0) {
            alpha -= getValue(player);
        }

        // Apply blinking effect
        if (getSubmodValue("blink", player) != 0) {
            var blinkFactor = MathUtil.quantize(FlxMath.fastSin(currentTime * 10), 0.3333);
            alpha += MathUtil.scale(blinkFactor, 0, 1, -1, 0);
        }

        // Apply random vanish (distance-based fading) effect
        if (getSubmodValue("randomVanish", player) != 0) {
            var realFadeDist:Float = 240;
            var vanishAdjust = MathUtil.scale(
                Math.abs(distFromCenter), 
                realFadeDist, 
                2 * realFadeDist, 
                -1, 0
            ) * getSubmodValue("randomVanish", player);
            alpha += vanishAdjust;
        }

        return MathUtil.clamp(alpha + 1, 0, 1);
    }

    /**
     * Calculates glow intensity based on visibility
     */
    private function getGlow(visibility:Float):Float {
        var glow = MathUtil.scale(visibility, 1, 0.5, 0, 1.3);
        return MathUtil.clamp(glow, 0, 1);
    }

    /**
     * Calculates alpha transparency based on visibility
     */
    private function getAlpha(visibility:Float):Float {
        var alpha = MathUtil.scale(visibility, 0.5, 0, 1, 0);
        return MathUtil.clamp(alpha, 0, 1);
    }

    // ==================== NOTE VISIBILITY UPDATES ====================

    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        var actualPlayer = note.mustPress ? 0 : 1;
        
        // Get current note position (excluding reverse modifier for accurate Y calculation)
        @:privateAccess
        var currentPos = modMgr.getPos(
            note.strumTime, 
            modMgr.getVisPos(Conductor.songPosition, note.strumTime, PlayState.instance.songSpeed),
            note.strumTime - Conductor.songPosition,
            PlayState.instance.curBeat, 
            note.noteData,
            actualPlayer, 
            note, 
            ["reverse"] // Exclude reverse modifier from position calculation
        );

        // Calculate base alpha modifiers
        var alphaMod = (1 - getSubmodValue("alpha", actualPlayer)) 
                     * (1 - getSubmodValue('alpha${note.noteData}', actualPlayer)) 
                     * (1 - getSubmodValue("noteAlpha", actualPlayer)) 
                     * (1 - getSubmodValue('noteAlpha${note.noteData}', actualPlayer));

        var visibility = getVisibility(currentPos.y, actualPlayer, note);

        // Apply stealth glow effect or direct alpha
        if (getSubmodValue("dontUseStealthGlow", actualPlayer) == 0) {
            note.colorSwap.daAlpha = getAlpha(visibility);
            note.colorSwap.flash = getGlow(visibility);
        } else {
            note.colorSwap.daAlpha = visibility;
        }
        
        // Apply additional alpha modifications
        note.colorSwap.daAlpha *= alphaMod;
    }

    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        var alpha = (1 - getSubmodValue("alpha", player)) 
                  * (1 - getSubmodValue('alpha${receptor.noteData}', player));

        // Apply dark (dimming) effect
        if (getSubmodValue("dark", player) != 0 || getSubmodValue('dark${receptor.noteData}', player) != 0) {
            alpha = alpha * (1 - getSubmodValue("dark", player)) 
                          * (1 - getSubmodValue('dark${receptor.noteData}', player));
        }

        @:privateAccess
        receptor.colorSwap.daAlpha = alpha;
    }
}