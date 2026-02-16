package game.modchart.modifiers;

import math.Vector3;
import game.modchart.NoteModifier;
import game.objects.Note;
import game.objects.StrumNote;
import game.objects.NoteSplash;
import game.objects.NoteHoldCover;

class SkewModifier extends NoteModifier {
    override function getName():String {
        return "skewX";
    }

    override function shouldExecute(player:Int, val:Float):Bool {
        return true;
    }

    override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {
        var data = note.noteData;
        var skewX = (getValue(player) + getSubmodValue('noteSkewX', player) + getSubmodValue('noteSkewX$data', player)) * 100;
        var skewY = (getSubmodValue('skewY', player) + getSubmodValue('noteSkewY', player) + getSubmodValue('noteSkewY$data', player)) * 100;

        note.skew.x = skewX;
        note.skew.y = skewY;
    }

    override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {
        var data = receptor.noteData;
        var skewX = (getValue(player) + getSubmodValue('noteSkewX', player) + getSubmodValue('noteSkewX$data', player)) * 100;
        var skewY = (getSubmodValue('skewY', player) + getSubmodValue('noteSkewY', player) + getSubmodValue('noteSkewY$data', player)) * 100;

        receptor.skew.x = skewX;
        receptor.skew.y = skewY;
    }

    override function updateSplash(beat:Float, splash:NoteSplash, pos:Vector3, player:Int) {
        var data = splash.noteData;
        var skewX = (getValue(player) + getSubmodValue('noteSkewX', player) + getSubmodValue('noteSkewX$data', player)) * 100;
        var skewY = (getSubmodValue('skewY', player) + getSubmodValue('noteSkewY', player) + getSubmodValue('noteSkewY$data', player)) * 100;

        splash.skew.x = skewX;
        splash.skew.y = skewY;
    }

    override function updateHoldCover(beat:Float, cover:NoteHoldCover, pos:Vector3, player:Int) {
        if (cover.curNote != null) {
            var data = cover.curNote.noteData;
            var skewX = (getValue(player) + getSubmodValue('noteSkewX', player) + getSubmodValue('noteSkewX$data', player)) * 100;
            var skewY = (getSubmodValue('skewY', player) + getSubmodValue('noteSkewY', player) + getSubmodValue('noteSkewY$data', player)) * 100;

            cover.skew.x = skewX;
            cover.skew.y = skewY;
        }
    }

    override function getSubmods():Array<String> {
        var subs = ["skewY", "noteSkewX", "noteSkewY"];
        for (i in 0...4) {
            subs.push('noteSkewX$i');
            subs.push('noteSkewY$i');
        }
        return subs;
    }
}