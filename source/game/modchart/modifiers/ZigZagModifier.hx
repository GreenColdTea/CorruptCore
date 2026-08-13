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
    
    private static final HALF_PI:Float = Math.PI * 0.5;
    private static final INV_PI:Float = 1.0 / Math.PI;
    
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
        final zigzag = getValue(player);

        if (zigzag == 0)
            return pos;

        final arrowSize = Note.swagWidth;
        final distance = Math.abs(visualDiff);
        
        final theta = -(distance / arrowSize) * Math.PI;

        final outRelative = Math.acos(Math.cos(theta + HALF_PI)) * INV_PI * 2 - 1;

        pos.x += outRelative * (arrowSize * 0.5) * zigzag;

        return pos;
    }
}