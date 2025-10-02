package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

import game.modchart.*;
import math.*;

/**
 * Swaps note positions between player and opponent sides
 * Moves notes horizontally between the player's side and the opponent's side
 * Creates a gameplay mechanic where players must hit notes from the opposite side
 */
class OpponentModifier extends NoteModifier {
    override function getName():String {
        return 'opponentSwap';
    }

    /**
     * Applies opponent swap transformation to note positions
     * Moves notes between player and opponent sides based on modifier intensity
     * 
     * @param time Note strum time
     * @param diff Visual position difference
     * @param tDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision  
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = BF, 1 = Dad, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with opponent swap applied
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
        // Early return if opponent swap is disabled for this player
        if (getValue(player) == 0) {
            return pos;
        }

        var swapOffset = calculateOpponentSwapOffset(data, player);
        pos.x += swapOffset;
        
        return pos;
    }

    /**
     * Calculates the horizontal offset needed to swap note positions between sides
     * Determines the distance between player and opponent sides and applies swap
     */
    private function calculateOpponentSwapOffset(noteData:Int, player:Int):Float {
        var opponentPlayer = getOpponentPlayerIndex(player);
        
        var opponentBaseX = modMgr.getBaseX(noteData, opponentPlayer);
        var playerBaseX = modMgr.getBaseX(noteData, player);
        
        var horizontalDistance = opponentBaseX - playerBaseX;
        var swapOffset = horizontalDistance * getValue(player);
        
        return swapOffset;
    }

    /**
     * Returns the opponent player index for the given player
     * Swaps 0 between 1 (Player 1 between Player 2)
     */
    private function getOpponentPlayerIndex(player:Int):Int {
        return Std.int(MathUtil.scale(player, 0, 1, 1, 0));
    }
}