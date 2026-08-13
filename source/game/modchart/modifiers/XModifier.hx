package game.modchart.modifiers;

import game.objects.Note;
import math.Vector3;

class XModifier extends NoteModifier {
    private static final XMOD_KEYS:Array<String> = ['xmod0', 'xmod1', 'xmod2', 'xmod3'];

    override function getName()
        return 'xmod';

    override function shouldExecute(player:Int, val:Float)
        return true;
    
    override function updateNote(beat:Float, daNote:Note, pos:Vector3, player:Int)
    {
        daNote.multSpeed = getValue(player) * getSubmodValue(XMOD_KEYS[daNote.noteData], player);
    }

    override function getSubmods()
    {
        return XMOD_KEYS.copy();
    }
}