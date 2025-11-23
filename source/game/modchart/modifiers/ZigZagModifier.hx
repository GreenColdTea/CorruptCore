package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.FlxG;

import game.modchart.*;
import math.Vector3;
import math.*;

/**
 * Creates zigzag wave pattern on notes
 * Based on cosine wave transformation that creates back-and-forth movement
 * Creates oscillating horizontal movement based on note distance
 */
class ZigZagModifier extends NoteModifier {
    private var prefix:String;
    
    public function new(modMgr:ModManager, ?prefix:String = '', ?parent:Modifier) {
        this.prefix = prefix;
        super(modMgr, parent);
    }

    override function getName():String {
        return '${prefix}zigZag';
    }

    override function getOrder():Int {
        return Modifier.ModifierOrder.DEFAULT;
    }

    override function getSubmods():Array<String> {
        return [];
    }

    /**
     * Applies zigzag wave transformation to note positions
     * Creates oscillating horizontal movement based on distance
     * 
     * @param time Note strum time
     * @param visualDiff Visual position difference from receptor
     * @param timeDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = BF, 1 = Dad)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with zigzag effect applied
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
        var zigzag = getValue(player);

        if (zigzag == 0)
            return pos;

        var arrowSize = Note.swagWidth;
        var arrowSizeHalf = arrowSize / 2;

        // Calculate theta based on visual distance (absolute value for consistent effect)
        var distance = Math.abs(visualDiff);
        var theta = -distance / arrowSize * Math.PI;

        // Calculate wave offset using cosine function
        var outRelative = Math.acos(Math.cos(theta + Math.PI / 2)) / Math.PI * 2 - 1;

        // Apply zigzag effect
        pos.x += outRelative * arrowSizeHalf * zigzag;

        return pos;
    }

    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        super.updateNote(beat, note, pos, player);
    }

    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        super.updateReceptor(beat, receptor, pos, player);
    }
}