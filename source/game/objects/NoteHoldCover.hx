package game.objects;

import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

import game.objects.Note;
import game.objects.StrumNote;

import math.Vector3;

class NoteHoldCover extends flixel.addons.effects.FlxSkewedSprite {
    public var vec3Cache:Vector3 = new Vector3();
    public var defScale:FlxPoint = FlxPoint.get(1, 1);

    public var pixelShader:PixelShader;
    public var allowPixel:Bool = false;
    
    public var colorSwap:ColorSwap = null;
    public var startCrochet:Float;
    public var frameRate:Int = 24;
    public var strumNote:StrumNote;
    public var curNote:Note;
    
    static final OFFSET_X = 106.25;
    static final OFFSET_Y = 100;
    static final PIXEL_OFFSET_X = 112.5;
    static final PIXEL_OFFSET_Y = -210;

    var isEnding:Bool = false;
    var endTime:Float = 0;
    var hasStartedEnd:Bool = false;

    var startAnimName:String = null;
    var loopAnimName:String = null;
    var endAnimName:String = null;

    public static var activeCovers:Map<StrumNote, NoteHoldCover> = new Map();

    public var texture(default, set):String = null;
    private function set_texture(value:String):String {
        if (texture == value) return value;
        texture = value;
        reloadCover();
        return value;
    }

    public function new() {
        super();

        animation = new PsychAnimationController(this);
        antialiasing = !PlayState.isPixelStage ? ClientPrefs.globalAntialiasing : false;

        var skin:String = !PlayState.isPixelStage ? 'holdCovers' : 'pixelUI/holdCoversPixel';
        if(PlayState.SONG.holdCoverSkin?.length > 1) skin = PlayState.SONG.holdCoverSkin;
        texture = skin;

        colorSwap = new ColorSwap();
        pixelShader = new PixelShader();
        
        shader = colorSwap.shader;
    }

    override function revive() {
        super.revive();

        isEnding = false;
        hasStartedEnd = false;
        endTime = 0;
        startAnimName = null;
        loopAnimName = null;
        endAnimName = null;
        strumNote = null;
        curNote = null;
        clipRect = null;
        animation.onFinish.removeAll();
    }
    
    public function setupHoldCover(strum:StrumNote, daNote:Note, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0):Void {
        cleanup();

        if (strum == null || daNote == null) {
            kill();
            return;
        }

        visible = true;

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

        endTime = parentNote.strumTime + parentNote.sustainLength;

        colorSwap.hue = hueColor;
        colorSwap.saturation = satColor;
        colorSwap.brightness = brtColor;

        if (allowPixel) {
            pixelShader.copyFromColorSwap(colorSwap);
            pixelShader.pixelAmount = PlayState.daPixelZoom;
            shader = pixelShader.shader;
        } else {
            shader = colorSwap.shader;
        }

        strumNote = strum;
        curNote = daNote;
        setPosition(strumNote.x, strumNote.y);
        offset.set(PlayState.isPixelStage ? PIXEL_OFFSET_X : OFFSET_X, OFFSET_Y);

        reloadCover();
    }
    
    override function update(elapsed:Float) {
        super.update(elapsed);

        if (!isEnding && !hasStartedEnd && endTime > 0 && Conductor.songPosition >= endTime)
            startEndAnimation();
    }

    function startEndAnimation():Void {
        if (!exists) return;

        hasStartedEnd = true;
        isEnding = true;

        final shouldAnimateEnd = strumNote != null && curNote.mustPress;
        final endAnimFullName = endAnimName != null ? '$endAnimName-end' : null;
        
        if (shouldAnimateEnd && endAnimFullName != null && animation.getByName(endAnimFullName) != null) {
            animation.play(endAnimFullName, true);
            if (animation.curAnim != null) {
                animation.curAnim.frameRate = frameRate;
            }
            clipRect = null;

            animation.onFinish.removeAll();
            animation.onFinish.add((animName:String) -> {
                if (animName == endAnimFullName)
                    finishCover();
            });
        } else {
            finishCover();
        }
    }
    
    public function finishCover():Void {
        cleanup();
        visible = false;

        if (strumNote != null && activeCovers.get(strumNote) == this)
            activeCovers.remove(strumNote);

        animation.onFinish.removeAll();

        kill();
    }

    inline function cleanup():Void {
        isEnding = false;
        hasStartedEnd = false;
        endTime = 0;
        animation.onFinish.removeAll();
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

    public function reloadCover():Void {
        if (strumNote == null || curNote == null) return;

        var skin:String = texture;
        if (skin == null || skin.length < 1) {
            skin = PlayState.SONG.holdCoverSkin;
            if (skin == null || skin.length < 1) skin = PlayState.isPixelStage ? 'pixelUI/holdCoversPixel' : 'holdCovers';
        }

        var hue = colorSwap.hue;
        var sat = colorSwap.saturation;
        var brt = colorSwap.brightness;

        @:privateAccess
        animation.clearAnimations();

        frames = Paths.getSparrowAtlas(skin);

        var colorSuffix = getColorSuffixFromNoteData(strumNote.noteData);
        var startAnim = startAnimName ?? (PlayState.isPixelStage ? 'loop' : 'holdCoverStart$colorSuffix');
        var loopAnim = loopAnimName ?? (PlayState.isPixelStage ? 'loop' : 'holdCover$colorSuffix');
        var endAnim = endAnimName ?? (PlayState.isPixelStage ? 'explode' : 'holdCoverEnd$colorSuffix');

        startAnimName = startAnim;
        loopAnimName = loopAnim;
        endAnimName = endAnim;

        animation.addByPrefix('$startAnim-start', startAnim, 24, false);
        animation.addByPrefix('$loopAnim-loop', loopAnim, 20, true);
        animation.addByPrefix('$endAnim-end', endAnim, 24, false);

        var hasStartAnim = animation.getByName('$startAnim-start') != null;
        var hasLoopAnim = animation.getByName('$loopAnim-loop') != null;
        var hasEndAnim = animation.getByName('$endAnim-end') != null;

        if (!hasStartAnim || !hasLoopAnim || !hasEndAnim) {
            finishCover();
            return;
        }

        if (!isEnding) {
            animation.play('$startAnim-start', true);
            animation.onFinish.removeAll();
            animation.onFinish.add((animName:String) -> {
                if (animName == '$startAnim-start' && !isEnding) {
                    animation.play('$loopAnim-loop', true);
                    animation.onFinish.removeAll();
                }
            });
        }

        if (PlayState.isPixelStage) {
            clipRect = null;
            setGraphicSize(Std.int(width * PlayState.daPixelZoom));
            updateHitbox();
            offset.x /= scale.x - 1.5;
            offset.y /= scale.y;
        } else {
            clipRect = new FlxRect(0, 0, frameWidth, frameHeight);
        }

        defScale.copyFrom(scale);
        colorSwap.hue = hue;
        colorSwap.saturation = sat;
        colorSwap.brightness = brt;
    }

    override function destroy() {
        cleanup();
        
        if (strumNote != null && activeCovers.get(strumNote) == this)
            activeCovers.remove(strumNote);
        
        if (defScale != null) {
            defScale.put();
            defScale = null;
        }
        
        super.destroy();
    }
}