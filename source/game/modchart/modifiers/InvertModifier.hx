package game.modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;

/**
 * Swaps the positions of left and right note columns
 * Creates a mirror effect by exchanging note positions across the center axis
 */
class InvertModifier extends NoteModifier {
    override function getName():String {
        return 'invert';
    }

    /**
     * Applies horizontal inversion transformation to note positions
     * Swaps left and right columns while maintaining middle columns
     * 
     * @param time Note strum time
     * @param diff Visual position difference
     * @param tDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision  
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with inversion applied
     */
    override function getPos(
        time:Float, 
        diff:Float, 
        tDiff:Float, 
        beat:Float, 
        pos:Vector3, 
        data:Int, 
        player:Int, 
        obj:FlxSprite
    ):Vector3 {
        // Early return if inversion is disabled for this player
        if (getValue(player) == 0) {
            return pos;
        }

        var invertOffset = calculateInvertOffset(data, player);
        pos.x += invertOffset;
        
        return pos;
    }

    /**
     * Calculates the horizontal offset needed to invert note positions
     * Swaps columns based on even/odd indexing:
     * - Even columns (0, 2) move right by one note width
     * - Odd columns (1, 3) move left by one note width
     * This effectively swaps left and right sides
     */
    private function calculateInvertOffset(noteData:Int, player:Int):Float {
        var isEvenColumn = (noteData % 2 == 0);
        var direction = isEvenColumn ? 1 : -1;
        var invertDistance = Note.swagWidth * direction * getValue(player);
        
        return invertDistance;
    }
}