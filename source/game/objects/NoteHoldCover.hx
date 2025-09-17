package game.objects;

import flixel.FlxSprite;
import flixel.util.FlxTimer;
import flixel.math.FlxRect;

import game.PlayState;
import game.objects.Note;
import game.objects.StrumNote;

class NoteHoldCover extends FlxSprite {
    public var colorSwap:ColorSwap = null;
    public var startCrochet:Float;
    public var frameRate:Int;
    public var strumNote:StrumNote;
    public var curNote:Note;
    
    static final OFFSET_X = 106.25;
    static final OFFSET_Y = 100;
    static final PIXEL_OFFSET_X = 112.5;
    static final PIXEL_OFFSET_Y = -210;

    var isEnding:Bool = false;
    var endingTimer:FlxTimer = null;

    public static var activeCovers:Map<StrumNote, NoteHoldCover> = new Map();

    public function new() {
        super();

        animation = new PsychAnimationController(this);
        antialiasing = ClientPrefs.globalAntialiasing;

        var skin:String = 'holdCovers';
        if(PlayState.SONG.holdCoverSkin != null && PlayState.SONG.holdCoverSkin.length > 1) skin = PlayState.SONG.holdCoverSkin;

        colorSwap = new ColorSwap();
        shader = colorSwap.shader;
    }

    override function update(elapsed:Float) {
        if (strumNote != null) {
            alpha = strumNote.alpha;
            if (!isEnding) {
                var strumAnimName = strumNote.animation.curAnim != null ? strumNote.animation.curAnim.name : "";
                var isStrumStaticOrPressed = strumAnimName == "static" || strumAnimName == "pressed";
                var isCoverAnimActive = animation.curAnim != null && 
                                       animation.curAnim.name.startsWith("holdCover");
                
                visible = !(isCoverAnimActive && isStrumStaticOrPressed && curNote != null && !curNote.isSustainNote);
            }
        }

        super.update(elapsed);
    }
    
    public function setupHoldCover(strum:StrumNote, daNote:Note, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0):Void {
        if (strum == null || daNote == null) {
            kill();
            return;
        }

        if (activeCovers.exists(strum)) {
            var existingCover = activeCovers.get(strum);
            if (existingCover != this) existingCover.finishCover();
        }
        
        activeCovers.set(strum, this);

        final parentNote = daNote.isSustainNote ? daNote.parent : daNote;
        if (parentNote == null || parentNote.tail == null) {
            kill();
            return;
        }

        final tail = parentNote.tail;
        final strumTime = parentNote.strumTime;
        final lengthToGet = tail.length;
        
        final timeThingy = (startCrochet * lengthToGet + (strumTime - Conductor.songPosition + ClientPrefs.ratingOffset)) / 1000;

        if(texture == null) {
            texture = 'holdCovers';
            if(PlayState.SONG.holdCoverSkin != null && PlayState.SONG.holdCoverSkin.length > 1) texture = PlayState.SONG.holdCoverSkin;
        }

        colorSwap.hue = hueColor;
        colorSwap.saturation = satColor;
        colorSwap.brightness = brtColor;

        strumNote = strum;
        curNote = daNote;
        setPosition(strum.x, strum.y);
        offset.set(PlayState.isPixelStage ? PIXEL_OFFSET_X : OFFSET_X, OFFSET_Y);
        visible = true;
        isEnding = false;
        
        @:privateAccess
        var colorSuffix = getColorSuffixFromNoteData(strumNote.noteData);
        
        frames = Paths.getSparrowAtlas(texture);
        
        if (animation.getByName('holdCover') == null)
            animation.addByPrefix('holdCover', 'holdCover$colorSuffix', 20, true);

        if (animation.getByName('holdCoverStart') == null)
            animation.addByPrefix('holdCoverStart', 'holdCoverStart$colorSuffix', 24, false);

        if (animation.getByName('holdCoverEnd') == null)
            animation.addByPrefix('holdCoverEnd', 'holdCoverEnd$colorSuffix', 24, false);
        
        animation.onFinish.removeAll();
        
        if(strumNote.alpha > 0)
            animation.play('holdCoverStart', true);
        
        animation.onFinish.add((name:String) -> {
            if (name == 'holdCoverStart' && exists && visible) {
                animation.play('holdCover', true);
            }
        });
        
        clipRect = new FlxRect(0, PlayState.isPixelStage ? PIXEL_OFFSET_Y : 0, frameWidth, frameHeight);

        endingTimer?.cancel();
        endingTimer = null;

        endingTimer = new FlxTimer().start(timeThingy, (timer:FlxTimer) -> {
            if (!exists) return;

            isEnding = true;
            final shouldAnimateEnd = strumNote != null && strumNote.alpha > 0 && daNote.mustPress;

            if (shouldAnimateEnd) {
                animation.onFinish.removeAll();
                
                animation.play('holdCoverEnd', true);
                animation.curAnim.frameRate = frameRate;
                clipRect = null;
                
                animation.onFinish.add((name:String) -> {
                    if (name == 'holdCoverEnd') {
                        finishCover();
                    }
                });
            } else {
                finishCover();
            }
        });
    }
    
    public function finishCover():Void {
        visible = false;
        isEnding = false;
        
        if (strumNote != null && activeCovers.get(strumNote) == this)
            activeCovers.remove(strumNote);
        
        kill();
    }
    
    private function getColorSuffixFromNoteData(noteData:Int):String {
        return switch(noteData % 4) {
            case 0: 'Purple';
            case 1: 'Blue';
            case 2: 'Green';
            case 3: 'Red';
            case _: 'Blue';
        }
    }

    override function destroy() {
        endingTimer?.cancel();
        endingTimer = null;
        
        if (strumNote != null && activeCovers.get(strumNote) == this)
            activeCovers.remove(strumNote);
        
        super.destroy();
    }
}