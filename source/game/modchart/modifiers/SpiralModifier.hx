package game.modchart.modifiers;

import flixel.math.FlxMath;
import math.Vector3;
import game.modchart.NoteModifier;

class SpiralModifier extends NoteModifier {
    override function getName():String {
        return "spiralX";
    }

    override function getSubmods():Array<String> {
        return [
            "spiralY", "spiralZ",
            "spiralXOffset", "spiralXPeriod",
            "spiralYOffset", "spiralYPeriod",
            "spiralZOffset", "spiralZPeriod",
            "schmovinSpiralX", "schmovinSpiralY", "schmovinSpiralZ",
            "schmovinSpiralXSpeed", "schmovinSpiralYSpeed", "schmovinSpiralZSpeed",
            "schmovinSpiralXOffset", "schmovinSpiralYOffset", "schmovinSpiralZOffset",
            "schmovinSpiralXSpacing", "schmovinSpiralYSpacing", "schmovinSpiralZSpacing"
        ];
    }

    override function getPos(time:Float, diff:Float, tDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:flixel.FlxSprite):Vector3 {
        final spiralX = getValue(player);
        final spiralY = getSubmodValue("spiralY", player);
        final spiralZ = getSubmodValue("spiralZ", player);

        if (spiralX != 0) {
            final offset = getSubmodValue("spiralXOffset", player);
            final period = getSubmodValue("spiralXPeriod", player);
            pos.x += tDiff * spiralX * FlxMath.fastCos((period + 1) * tDiff + offset);
        }

        if (spiralY != 0) {
            final offset = getSubmodValue("spiralYOffset", player);
            final period = getSubmodValue("spiralYPeriod", player);
            pos.y += tDiff * spiralY * FlxMath.fastSin((period + 1) * tDiff + offset);
        }

        if (spiralZ != 0) {
            final offset = getSubmodValue("spiralZOffset", player);
            final period = getSubmodValue("spiralZPeriod", player);
            pos.z += tDiff * spiralZ * FlxMath.fastSin((period + 1) * tDiff + offset);
        }

        final schmovinSpiralX = getSubmodValue("schmovinSpiralX", player);
        final schmovinSpiralY = getSubmodValue("schmovinSpiralY", player);
        final schmovinSpiralZ = getSubmodValue("schmovinSpiralZ", player);

        if (schmovinSpiralX != 0) {
            final dist = getSubmodValue("schmovinSpiralXSpacing", player) * 33.5;
            final angleBeat = ((getSubmodValue("schmovinSpiralXSpeed", player) * beat) + getSubmodValue("schmovinSpiralXOffset", player)) * Math.PI / 4;
            final radiusOffset = -diff / 4;
            final radius = radiusOffset + dist * (data % 4);
            pos.x += FlxMath.fastCos(-tDiff / Conductor.crochet * Math.PI + angleBeat) * radius * schmovinSpiralX;
        }

        if (schmovinSpiralY != 0) {
            final dist = getSubmodValue("schmovinSpiralYSpacing", player) * 33.5;
            final angleBeat = ((getSubmodValue("schmovinSpiralYSpeed", player) * beat) + getSubmodValue("schmovinSpiralYOffset", player)) * Math.PI / 4;
            final radiusOffset = -diff / 4;
            final radius = radiusOffset + dist * (data % 4);
            pos.y += FlxMath.fastSin(-tDiff / Conductor.crochet * Math.PI + angleBeat) * radius * schmovinSpiralY;
        }

        if (schmovinSpiralZ != 0) {
            final dist = getSubmodValue("schmovinSpiralZSpacing", player) * 33.5;
            final angleBeat = ((getSubmodValue("schmovinSpiralZSpeed", player) * beat) + getSubmodValue("schmovinSpiralZOffset", player)) * Math.PI / 4;
            final radiusOffset = -diff / 4;
            final radius = radiusOffset + dist * (data % 4);
            pos.z += FlxMath.fastSin(-tDiff / Conductor.crochet * Math.PI + angleBeat) * radius * schmovinSpiralZ;
        }

        return pos;
    }
}