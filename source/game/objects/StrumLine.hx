package game.objects;

import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class StrumLine extends FlxTypedGroup<StrumNote> {
    public var player:Int;
    public var keyAmount:Int;
    public var startX:Float;
    public var startY:Float;
    public var isDownscroll:Bool;

    public function new(x:Float, y:Float, player:Int = 0, keyAmount:Int = 4, isDownscroll:Bool = false) {
        super();
        this.startX = x;
        this.startY = y;
        this.player = player;
        this.keyAmount = keyAmount;
        this.isDownscroll = isDownscroll;

        generateStrums();
        attachToModchart();
    }

    public function generateStrums():Void {
        final noteWidth:Float = 112;
        final strumlineOffset:Float = (keyAmount * noteWidth) / 2;

        for (i in 0...keyAmount) {
            var targetAlpha:Float = 1;
            
            if (player < 1) {
                if (!ClientPrefs.opponentStrums) targetAlpha = 0;
                else if (ClientPrefs.middleScroll) targetAlpha = 0.35;
            }

            final babyArrow:StrumNote = new StrumNote(this.startX, this.startY, i, player);
            babyArrow.downScroll = this.isDownscroll;

            babyArrow.postAddedToGroup();

            if (ClientPrefs.middleScroll && player < 1) {
                babyArrow.x += 310;
                if (i > 1)
                    babyArrow.x += FlxG.width / 2 + 25;
            }

            if (!PlayState.isStoryMode && !PlayState.instance.skipArrowStartTween) {
                babyArrow.alpha = 0;
                FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {
                    ease: FlxEase.circOut,
                    startDelay: 0.5 + (0.2 * i)
                });
            } else {
                babyArrow.alpha = targetAlpha;
            }

            add(babyArrow);
            
            PlayState.instance?.strumLineNotes?.add(babyArrow);
        }
    }

    public function attachToModchart():Void {
        #if MODCHART_ALLOWED
        if (PlayState.instance?.modManager != null) {
            final modManager = PlayState.instance.modManager;
            
            while (modManager.receptors.length <= player)
                modManager.receptors.push([]);
            
            modManager.receptors[player] = this.members;
        }
        #end
    }
    
    public function updatePosition(newX:Float, newY:Float):Void {
        this.startX = newX;
        this.startY = newY;

        final noteWidth:Float = 112;
        final strumlineOffset:Float = (keyAmount * noteWidth) / 2;
        
        for (i in 0...this.members.length) {
            final arrow = this.members[i];
            if (arrow != null) {
                arrow.x = this.startX + (i * noteWidth) - strumlineOffset;
                arrow.y = this.startY;
            }
        }
    }
}