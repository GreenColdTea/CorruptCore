package game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;

import math.*;
import game.modchart.*;
import game.modchart.Modifier.ModifierOrder;

using StringTools;

class ReverseModifier extends NoteModifier {
	override function getOrder() return REVERSE;
    override function getName() return 'reverse';

    public function getReverseValue(dir:Int, player:Int, ?scrolling=false){
        var suffix = scrolling ? 'Scroll' : '';
        
        var receptors = modMgr.receptors[player];
        var kNum = receptors.length;
        var val:Float = 0;
        if(dir >= kNum/2)
            val += getSubmodValue("split" + suffix, player);

        if((dir % 2) == 1)
            val += getSubmodValue("alternate" + suffix, player);

        var first = kNum / 4;
        var last = kNum - 1 - first;

        if(dir >= first && dir <= last)
            val += getSubmodValue("cross" + suffix, player);
        

        if(suffix == '')
            val += getValue(player) + getSubmodValue("reverse" + Std.string(dir), player);
        else
            val += getSubmodValue("reverse" + suffix, player);
        

        if(getSubmodValue("unboundedReverse", player) == 0){
            val %= 2;
            if(val > 1)val = 2 - val;
        }

        if(ClientPrefs.downScroll)
            val = 1 - val;

        return val;
    }

    public function getScrollReversePerc(dir:Int, player:Int)
        return getReverseValue(dir,player) * 100;

	override function shouldExecute(player:Int,val:Float)
        return true;

	override function ignoreUpdateNote()
		return false;
    
	override function updateNote(beat:Float, daNote:Note, pos:Vector3, player:Int)
	{
		if (daNote.isSustainNote)
		{
			var y = pos.y;
            var revPerc = getReverseValue(daNote.noteData, player);
			var strumLine = modMgr.receptors[player][daNote.noteData];
			
			var shitGotHit = (strumLine.sustainReduce
				&& daNote.isSustainNote
				&& (daNote.mustPress || !daNote.ignoreNote)
				&& (!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))));
				
			if (shitGotHit)
			{
				var center:Float = strumLine.y + Note.swagWidth / 2;
				
                var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
				if (revPerc >= 0.5) // Downscroll behavior'
				{
					if (y - daNote.offset.y * daNote.scale.y + daNote.height >= center)
					{
						swagRect.height = (center - y) / daNote.scale.y;
						swagRect.y = daNote.frameHeight - swagRect.height;
					}
				}
				else // Upscroll behavior
				{
					if (y + daNote.offset.y * daNote.scale.y <= center)
					{
						swagRect.y = (center - y) / daNote.scale.y;
						swagRect.height -= swagRect.y;
					}
				}

                daNote.clipRect = swagRect;
			}
		}
    }
	
	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
	{
        var perc = getReverseValue(data, player);
		var shift = MathUtil.scale(perc, 0, 1, 50, FlxG.height - 150);
		var mult = MathUtil.scale(perc, 0, 1, 1, -1);
		shift = MathUtil.scale(getSubmodValue("centered", player), 0, 1, shift, (FlxG.height/2) - 56);

		pos.y = shift + (visualDiff * mult);

		// Sus note positioning adjustments 
        // Using in-game logic
        if(obj is Note)
		{
            var note:Note = cast obj;
            if (note.isSustainNote)
            {
                if (perc >= 0.5) // Downscroll behavior
                {
                    if (PlayState.isPixelStage)
                    {
                        pos.y -= PlayState.daPixelZoom * 9.5;
                    }
                    pos.y -= (note.frameHeight * note.scale.y) - (Note.swagWidth / 2);
                }
            }
        }

		return pos;
	}

    override function getSubmods(){
        var subMods:Array<String> = ["cross", "split", "alternate", "reverseScroll", "crossScroll", "splitScroll", "alternateScroll", "centered", "unboundedReverse"];

        var receptors = modMgr.receptors[0];
		for (i in 0...4)
		{
            subMods.push('reverse${i}');
        }
        return subMods;
    }
}