package game.modchart.modifiers;

import flixel.math.FlxPoint;
import flixel.math.FlxMath;

import game.modchart.*;
import math.*;

/**
 * Applies rotation effects to notes and receptors
 * Creates visual disorientation by rotating gameplay elements at various angles
 */
class ConfusionModifier extends NoteModifier {
    override function getName():String {
        return 'confusion';
    }

    /**
     * Always execute this modifier to handle submodifiers even when base value is 0
     */
    override function shouldExecute(player:Int, val:Float):Bool {
        return true;
    }

    /**
     * Returns all submodifiers supported by this modifier
     * Includes per-noteData variants for column-specific effects
     */
    override function getSubmods():Array<String> {
        var subMods:Array<String> = [
            "noteAngle",      // Global note angle offset
            "receptorAngle"   // Global receptor angle offset
        ];

        // Add per-column submodifiers for fine-tuned control
        for (i in 0...4) {
            subMods.push('note${i}Angle');     // Note angle for specific column
            subMods.push('receptor${i}Angle'); // Receptor angle for specific column  
            subMods.push('confusion${i}');     // Confusion intensity for specific column
        }

        return subMods;
    }

    /**
     * Updates note rotation based on confusion values
     * Regular notes use dynamic angles, sustain notes preserve their original angle
     * 
     * @param beat Current beat with decimal precision
     * @param note The note to update
     * @param pos Current position vector
     * @param player Player index (0 = BF, 1 = Dad, -1 = Both)
     */
    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        if (!note.isSustainNote) {
            // Calculate total rotation angle for regular notes
            var totalAngle = calculateNoteAngle(note, player);
            note.angle = totalAngle;
        } else {
            // Sustain notes keep their original angle to maintain visual consistency
            note.angle = note.mAngle;
        }
    }

    /**
     * Calculates the total rotation angle for a note
     * Combines global, per-column, and note-specific angle modifiers
     */
    private function calculateNoteAngle(note:Note, player:Int):Float {
        var baseConfusion = getValue(player);                           // Global confusion intensity
        var columnConfusion = getSubmodValue('confusion${note.noteData}', player); // Column-specific confusion
        var noteAngle = getSubmodValue('note${note.noteData}Angle', player);       // Note-specific angle offset
        
        return baseConfusion + columnConfusion + noteAngle;
    }

    /**
     * Updates receptor rotation based on confusion values
     * Receptors rotate independently of notes for visual variety
     * 
     * @param beat Current beat with decimal precision
     * @param receptor The strum note receptor to update
     * @param pos Current position vector
     * @param player Player index (0 = BF, 1 = Dad, -1 = Both)
     */
    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        var totalAngle = calculateReceptorAngle(receptor, player);
        receptor.angle = totalAngle;
    }

    /**
     * Calculates the total rotation angle for a receptor
     * Combines global, per-column, and receptor-specific angle modifiers
     */
    private function calculateReceptorAngle(receptor:StrumNote, player:Int):Float {
        var baseConfusion = getValue(player);                                    // Global confusion intensity
        var columnConfusion = getSubmodValue('confusion${receptor.noteData}', player); // Column-specific confusion
        var receptorAngle = getSubmodValue('receptor${receptor.noteData}Angle', player); // Receptor-specific angle offset
        
        return baseConfusion + columnConfusion + receptorAngle;
    }
}