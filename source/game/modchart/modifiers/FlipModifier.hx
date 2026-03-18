package game.modchart.modifiers;

import flixel.FlxSprite;
import math.Vector3;

/**
 * Horizontally flips note positions across the center axis
 * Reverses the left-to-right order of notes while maintaining spacing
 */
class FlipModifier extends NoteModifier {
    override function getName():String {
        return 'flip';
    }

    /**
     * Applies horizontal flip transformation to note positions
     * Mirrors note positions across the center axis of the playfield
     * 
     * @param time Note strum time
     * @param diff Visual position difference
     * @param tDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision  
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with flip applied
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
        // Early return if flip is disabled for this player
        if (getValue(player) == 0) {
            return pos;
        }

        var flipOffset = calculateFlipOffset(data, player);
        pos.x += flipOffset;
        
        return pos;
    }

    /**
     * Calculates the horizontal offset needed to flip a note position
     * Moves notes from left side to right side and vice versa
     */
    private function calculateFlipOffset(noteData:Int, player:Int):Float {
        var receptors = modMgr.receptors[player];
        var receptorCount = receptors.length;
        
        // Calculate the mirror distance from center
        // For 4 columns: 
        // - data=0 (leftmost) moves 1.5 spaces right  
        // - data=1 moves 0.5 spaces right
        // - data=2 moves 0.5 spaces left
        // - data=3 (rightmost) moves 1.5 spaces left
        var mirrorDistanceMultiplier = (receptorCount / 2) - 0.5 - noteData;
        var flipDistance = Note.swagWidth * mirrorDistanceMultiplier * 2 * getValue(player);
        
        return flipDistance;
    }
}