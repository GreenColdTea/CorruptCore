package game.modchart.modifiers;

import flixel.math.FlxPoint;

import game.modchart.Modifier.ModifierOrder;
import game.objects.*;
import math.Vector3;

/**
 * Applies various scaling transformations to notes and receptors
 * Handles miniaturization, stretching, squishing, and per-column scaling effects
 */
class ScaleModifier extends NoteModifier {
    override function getName():String {
        return 'mini';
    }

    /**
     * Sets execution order to before reverse operations for proper transformation order
     */
    override function getOrder():Int {
        return PRE_REVERSE;
    }

    /**
     * Always execute this modifier to handle submodifiers even when base value is 0
     */
    override function shouldExecute(player:Int, val:Float):Bool {
        return true;
    }

    override function ignorePos():Bool {
        return true; // This modifier doesn't affect position, only scale
    }

    override function ignoreUpdateReceptor():Bool {
        return false; // This modifier affects receptors
    }

    override function ignoreUpdateNote():Bool {
        return false; // This modifier affects notes
    }

    override function ignoreUpdateSplash():Bool {
        return false; // This modifier affects splash effects
    }

    override function ignoreUpdateHoldCover():Bool {
        return false; // This modifier affects hold covers
    }

    /**
     * Returns all submodifiers supported by this modifier
     * Includes per-noteData variants for column-specific effects
     */
    override function getSubmods():Array<String> {
        var subMods:Array<String> = [
            "squish",   // Global squish effect
            "stretch",  // Global stretch effect
            "miniX",    // Global X-axis miniaturization
            "miniY"     // Global Y-axis miniaturization
        ];

        // Add per-column submodifiers for fine-tuned control
        for (i in 0...4) {
            subMods.push('mini${i}X');    // X-axis mini for specific column
            subMods.push('mini${i}Y');    // Y-axis mini for specific column
            subMods.push('squish${i}');   // Squish effect for specific column
            subMods.push('stretch${i}');  // Stretch effect for specific column
        }

        return subMods;
    }

    /**
     * Calculates the final scale by applying all scaling effects
     * 
     * @param sprite The game object (note or receptor) being scaled
     * @param baseScale The original scale of the object
     * @param noteData Note direction/column (0-3)
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     * @return Modified scale point with all effects applied
     */
    private function getScale(sprite:FlxSprite, baseScale:FlxPoint, noteData:Int, player:Int):FlxPoint {
        var finalScale = baseScale.clone();
        var originalYScale = finalScale.y; // Preserve for sustain notes

        applyMiniEffects(finalScale, noteData, player);
        applyStretchAndSquishEffects(finalScale, noteData, player);

        // Sustain notes maintain their original Y scale for visual consistency
        if (Std.isOfType(sprite, Note) && cast(sprite, Note).isSustainNote) {
            finalScale.y = originalYScale;
        }

        return finalScale;
    }

    /**
     * Applies miniaturization effects to the scale
     * Reduces size on X and Y axes with per-column control
     */
    private function applyMiniEffects(scale:FlxPoint, noteData:Int, player:Int):Void {
        // Apply base mini effect (affects both axes)
        final baseMini:Float = getValue(player);
        scale.x *= 1 - baseMini;
        scale.y *= 1 - baseMini;

        // Apply axis-specific mini effects
        final miniX:Float = getSubmodValue("miniX", player) + getSubmodValue('mini${noteData}X', player);
        final miniY:Float = getSubmodValue("miniY", player) + getSubmodValue('mini${noteData}Y', player);

        scale.x *= 1 - miniX;
        scale.y *= 1 - miniY;
    }

    /**
     * Applies stretch and squish distortion effects to the scale
     * Creates non-uniform scaling for visual distortion effects
     */
    private function applyStretchAndSquishEffects(scale:FlxPoint, noteData:Int, player:Int):Void {
        final stretch:Float = getSubmodValue("stretch", player) + getSubmodValue('stretch${noteData}', player);
        final squish:Float = getSubmodValue("squish", player) + getSubmodValue('squish${noteData}', player);

        // Calculate stretch factors (vertical stretch, horizontal compression)
        final stretchFactorX = FlxMath.lerp(1, 0.5, stretch); // Horizontal compression
        final stretchFactorY = FlxMath.lerp(1, 2, stretch);   // Vertical stretch

        // Calculate squish factors (horizontal stretch, vertical compression)  
        final squishFactorX = FlxMath.lerp(1, 2, squish);     // Horizontal stretch
        final squishFactorY = FlxMath.lerp(1, 0.5, squish);   // Vertical compression

        // Current implementation uses angle 0, so trigonometric functions simplify
        // These would be more complex with rotation, but currently:
        // sin(0) = 0, cos(0) = 1
        final angle = 0;
        final sinAngle = Math.sin(angle * Math.PI / 180); // = 0
        final cosAngle = Math.cos(angle * Math.PI / 180); // = 1

        // Apply stretch effects (simplified due to angle 0)
        scale.x *= (sinAngle * stretchFactorY) + (cosAngle * stretchFactorX); // = stretchFactorX
        scale.y *= (cosAngle * stretchFactorY) + (sinAngle * stretchFactorX); // = stretchFactorY

        // Apply squish effects (simplified due to angle 0)
        scale.x *= (sinAngle * squishFactorY) + (cosAngle * squishFactorX); // = squishFactorX
        scale.y *= (cosAngle * squishFactorY) + (sinAngle * squishFactorX); // = squishFactorY
    }

    /**
     * Updates note scale based on all scaling effects
     * Sustain notes preserve their original Y scale for visual consistency
     */
    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        var baseScale = FlxPoint.weak(note.defScale.x, note.defScale.y);
        var finalScale = getScale(note, baseScale, note.noteData, player);

        // Sustain notes always maintain their original Y scale
        if (note.isSustainNote) {
            finalScale.y = note.defScale.y;
        }

        note.scale.copyFrom(finalScale);

        if (note.isSustainNote && note.holdNote != null) {
            note.holdNote.scale.x = finalScale.x;
        }

        finalScale.putWeak();
        baseScale.putWeak();
    }

    /**
     * Updates receptor scale based on all scaling effects
     */
    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        var baseScale = FlxPoint.weak(receptor.defScale.x, receptor.defScale.y);
        var finalScale = getScale(receptor, baseScale, receptor.noteData, player);

        receptor.scale.copyFrom(finalScale);
        finalScale.putWeak();
        baseScale.putWeak();
    }

    override function updateSplash(beat:Float, splash:NoteSplash, pos:Vector3, player:Int) {
        if (splash.babyArrow != null) {
            var baseScale = FlxPoint.weak(splash.defScale.x, splash.defScale.y);
            var finalScale = getScale(splash, baseScale, splash.noteData, player);

            splash.scale.copyFrom(finalScale);
            finalScale.putWeak();
            baseScale.putWeak();
        }
    }

    /*override function updateHoldCover(beat:Float, cover:NoteHoldCover, pos:Vector3, player:Int) {
        if (cover.curNote != null) {
            var baseScale = FlxPoint.weak(cover.defScale.x, cover.defScale.y);
            var finalScale = getScale(cover, baseScale, cover.curNote.noteData, player);
            
            cover.scale.copyFrom(finalScale);
            finalScale.putWeak();
            baseScale.putWeak();
        }
    }*/
}