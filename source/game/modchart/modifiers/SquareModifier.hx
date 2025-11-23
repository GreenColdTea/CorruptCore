package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.FlxG;

import game.modchart.*;
import math.Vector3;
import math.*;

/**
 * Creates square wave pattern on notes
 * Based on square wave transformation that creates sharp back-and-forth movement
 * Creates digital/blocky horizontal movement based on note distance
 */
class SquareModifier extends NoteModifier {
    private var prefix:String;
    
    public function new(modMgr:ModManager, ?prefix:String = '', ?parent:Modifier) {
        this.prefix = prefix;
        super(modMgr, parent);
    }

    override function getName():String {
        return '${prefix}square';
    }

    override function getOrder():Int {
        return Modifier.ModifierOrder.DEFAULT;
    }

    override function getSubmods():Array<String> {
        return [
            '${prefix}squareOffset', // Offset for the square wave
            '${prefix}squarePeriod'  // Period/wavelength control
        ];
    }

    /**
     * Applies square wave transformation to note positions
     * Creates digital/blocky horizontal movement based on distance
     * 
     * @param time Note strum time
     * @param visualDiff Visual position difference from receptor
     * @param timeDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = BF, 1 = Dad)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with square effect applied
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
        var squarep = getValue(player);

        if (squarep == 0)
            return pos;

        var offset = getSubmodValue('${prefix}squareOffset', player);
        var period = getSubmodValue('${prefix}squarePeriod', player);

        var arrowSize = Note.swagWidth;
        var distance = Math.abs(visualDiff);
        
        // Calculate amplitude using distance, offset and period
        var amp = (Math.PI * (distance + offset) / (arrowSize + (period * arrowSize)));

        pos.x += squarep * MathUtil.square(amp) * arrowSize;

        return pos;
    }

    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        super.updateNote(beat, note, pos, player);
    }

    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        super.updateReceptor(beat, receptor, pos, player);
    }
}