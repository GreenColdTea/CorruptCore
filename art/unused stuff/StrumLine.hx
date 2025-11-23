package game.objects;

import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxTween;

#if MODCHART_ALLOWED
import game.modchart.ModManager;
#end

class StrumLine extends FlxSpriteGroup
{
    public var characters:Array<Character> = [];
    public var strumNotes:FlxTypedGroup<StrumNote>;
    public var downScroll:Bool = false;
    public var isPlayer:Bool = false;
    
    #if MODCHART_ALLOWED
    public var modManager:ModManager;
    public var noteData:Int = 0;
    #end
    
    public function new(x:Float, y:Float, isPlayer:Bool = false, downScroll:Bool = false, noteData:Int = 0)
    {
        super();
        this.isPlayer = isPlayer;
        this.downScroll = downScroll;
        
        #if MODCHART_ALLOWED
        this.noteData = noteData;
        #end
        
        strumNotes = new FlxTypedGroup<StrumNote>();
        
        generateStrums(x, y);
        
        for (strum in strumNotes) add(strum);
    }
    
    #if MODCHART_ALLOWED
    public function setModManager(modManager:ModManager):Void
    {
        this.modManager = modManager;
        for (strum in strumNotes) {
            if (strum != null) {
                strum.modManager = modManager;
            }
        }
    }
    
    public function updateModcharts(curDecBeat:Float):Void
    {
        if (modManager == null) return;
        
        for (i in 0...strumNotes.length)
        {
            var strum = strumNotes.members[i];
            if (strum?.exists)
            {
                var player = isPlayer ? 0 : 1;
                var pos = modManager.getPos(0, 0, 0, curDecBeat, i, player, strum, [], strum.vec3Cache);
                modManager.updateObject(curDecBeat, strum, pos, player);
                strum.x = pos.x;
                strum.y = pos.y;
                if (ClientPrefs.middleScroll && !isPlayer)
                    strum.visible = (strum.alpha > 0) && ClientPrefs.opponentStrums;
            }
        }
    }
    #end
    
    private function generateStrums(x:Float, y:Float):Void
    {
        for (i in 0...4)
        {
            var targetAlpha:Float = 1;
            if (!isPlayer)
            {
                if(!ClientPrefs.opponentStrums) targetAlpha = 0;
                else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
            }

            var strumLineX:Float = ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : x;
            var babyArrow = new StrumNote(strumLineX, y, i, isPlayer ? 1 : 0);
            babyArrow.downScroll = downScroll;
            
            #if MODCHART_ALLOWED
            if (modManager != null) {
                babyArrow.modManager = modManager;
            }
            #end
            
            if (PlayState.instance != null && !PlayState.instance.startedCountdown && !PlayState.instance.skipArrowStartTween) {
                babyArrow.alpha = 0;
                FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {
                    ease: FlxEase.circOut, 
                    startDelay: 0.5 + (0.2 * i)
                });
            } else {
                babyArrow.alpha = targetAlpha;
            }

            if (!isPlayer && ClientPrefs.middleScroll)
            {
                babyArrow.x += 310;
                if(i > 1) { //Up and Right
                    babyArrow.x += FlxG.width / 2 + 25;
                }
            }

            strumNotes.add(babyArrow);
            babyArrow.postAddedToGroup();
        }
    }
    
    public function playAnim(anim:String, index:Int, time:Float):Void
    {
        if (strumNotes.members[index] != null)
        {
            strumNotes.members[index].playAnim(anim, true);
            strumNotes.members[index].resetAnim = time;
        }
    }
    
    public function resetStrums():Void
    {
        for (strum in strumNotes)
        {
            strum.playAnim('static');
            strum.resetAnim = 0;
        }
    }
    
    public function getStrumX():Float
    {
        return ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
    }
    
    public function getStrumY():Float
    {
        return ClientPrefs.downScroll ? (FlxG.height - 150) : 50;
    }
    
    public function addCharacter(character:Character):Void
    {
        if (!characters.contains(character)) characters.push(character);
    }
    
    public function removeCharacter(character:Character):Void
    {
        characters.remove(character);
    }
    
    public function getStrum(noteData:Int):StrumNote
    {
        return strumNotes.members[noteData];
    }
}