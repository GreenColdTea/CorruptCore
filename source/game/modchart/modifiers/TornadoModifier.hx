package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.FlxG;

import game.modchart.*;
import math.Vector3;
import math.*;

/**
 * Creates swirling vortex effect on notes
 * Based on OpenITG tornado implementation with sine-wave transformation
 * Creates vortex-like movement pattern based on note distance and lane position
 */
class TornadoModifier extends NoteModifier {
    private var prefix:String;
    
    public function new(modMgr:ModManager, ?prefix:String = '', ?parent:Modifier) {
        this.prefix = prefix;
        super(modMgr, parent);
    }

    override function getName():String {
        return '${prefix}tornado';
    }

    override function getOrder():Int {
        return Modifier.ModifierOrder.DEFAULT;
    }

    override function getSubmods():Array<String> {
        return [];
    }

    /**
     * Applies tornado vortex transformation to note positions
     * Creates swirling effect based on note distance and lane position
     * 
     * @param time Note strum time
     * @param visualDiff Visual position difference from receptor
     * @param timeDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = BF, 1 = Dad)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with tornado effect applied
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
        var tornado = getValue(player);

        if (tornado == 0)
            return pos;

        // Get key count from receptors array
        var keyCount = modMgr.receptors[player].length;
        var bWideField = keyCount > 4;
        var iTornadoWidth = bWideField ? 4 : 3;

        var iColNum = data;
        var iStartCol = iColNum - iTornadoWidth;
        var iEndCol = iColNum + iTornadoWidth;
        iStartCol = Math.round(MathUtil.clamp(iStartCol, 0, keyCount));
        iEndCol = Math.round(MathUtil.clamp(iEndCol, 0, keyCount));

        // Calculate base X offset based on note position
        var arrowSize = Note.swagWidth;
        var fXOffset = ((arrowSize * 1.5) - (arrowSize * iColNum));

        var fMinX = -fXOffset;
        var fMaxX = fXOffset;

        final fRealPixelOffset = fXOffset;
        var fPositionBetween = MathUtil.scale(fRealPixelOffset, fMinX, fMaxX, -1, 1);

        // Calculate rotation angle based on visual distance
        var fRads = Math.acos(fPositionBetween);
        fRads += (Math.abs(visualDiff) * 0.8) * 6 / FlxG.height;

        // Apply trigonometric transformation for vortex effect
        final fAdjustedPixelOffset = MathUtil.scale(Math.cos(fRads), -1, 1, fMinX, fMaxX);

        // Apply tornado effect with intensity
        pos.x -= (fAdjustedPixelOffset - fRealPixelOffset) * tornado;

        return pos;
    }

    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        super.updateNote(beat, note, pos, player);
    }

    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        super.updateReceptor(beat, receptor, pos, player);
    }
}