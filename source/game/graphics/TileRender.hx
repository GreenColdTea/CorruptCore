package game.graphics;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.math.FlxRect;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

import openfl.geom.ColorTransform;
import openfl.Vector;

import game.objects.Note;
import game.objects.Note.Sustain;

#if MODCHART_ALLOWED
import game.modchart.ModManager;
#end

import math.Vector3;

using flixel.util.FlxColorTransformUtil;

class TileRender extends FlxSprite 
{
    static inline final PIXEL_OFFSET_X:Float = 5.0;
    static inline final MAX_TOTAL_SEGMENTS:Int = 96;

    static inline final MIN_SAMPLES:Int = 48;
    static inline final MAX_SAMPLES:Int = 128;

    static var sharedColorTransform:ColorTransform = new ColorTransform();
    static var sharedVec3_0:Vector3 = new Vector3(0, 0, 0);
    static var sharedVec3_1:Vector3 = new Vector3(0, 0, 0);

    static var sampleCache:Array<Float> = [];
    static var normalCache:Array<Float> = [];

    var sustainVertices:Vector<Float> = new Vector<Float>(256, false);
    var sustainUvtData:Vector<Float> = new Vector<Float>(256, false);
    var sustainIndices:Vector<Int> = new Vector<Int>(256, false);

    var _vertexCapacity:Int = 256;
    var _indexCapacity:Int = 256;

    public var tailAnim(default, set):String = null;
    public var segmentsPerTile:Int = !ClientPrefs.lowQuality ? 12 : 4;
    public var skew:FlxPoint = FlxPoint.get();

    var tailFrame:FlxFrame;
    var bodyFrame:FlxFrame;
    var originalFrame:FlxFrame;

    var tiles:Float;
    var tileCount:Int;

    #if MODCHART_ALLOWED
    public var parentNote:Note = null;
    #end

    public function new(?X:Float = 0, ?Y:Float = 0)
    {
        super(X, Y);
    }

    function set_tailAnim(value:String):String
    {
        tailAnim = value;
        updateTailFrame();
        return value;
    }

    function adjustFrame(frame:FlxFrame):Void
    {
        if (frame == null) return;
        frame.sourceSize.y -= 2;
        frame.frame.height -= 2;
        frame.frame.y += 1;
    }

    function updateTailFrame():Void
    {
        if (frames == null || animation == null || tailAnim == null || !animation.exists(tailAnim)) return;  

        final rawTail = frames.frames[animation.getByName(tailAnim).frames[animation.curAnim.curFrame]];
        tailFrame = rawTail.copyTo(tailFrame);
        adjustFrame(tailFrame);
    }

    override public function draw():Void
    {
        if (alpha == 0 || !visible || frames == null || tiles <= 0) return;

        #if MODCHART_ALLOWED  
        if (tryDrawModchartMesh()) return;
        #end  

        for (camera in cameras)
        {
            if (!camera.visible || !camera.exists) continue;
            drawComplex(camera);
        }
    }

    #if MODCHART_ALLOWED
    private function tryDrawModchartMesh():Bool 
    {
        var pNote:Note = parentNote;
        if (pNote == null && Std.isOfType(this, Sustain))
            pNote = (cast this:Sustain).parent;

        final modMgr:ModManager = PlayState.instance?.modManager;

        if (pNote == null || modMgr == null) return false;

        final playerNum:Int = pNote.mustPress ? 0 : 1;

        if (modMgr.activeModInstances[playerNum] == null || modMgr.activeModInstances[playerNum].length == 0) return false;

        var hasPosMod = false;
        for (mod in modMgr.activeModInstances[playerNum]) {
            if (!mod.ignorePos()) {
                hasPosMod = true;
                break;
            }
        }
        if (!hasPosMod) return false;

        drawBentSustainToCameras(pNote, PlayState.instance, modMgr, playerNum);
        return true;
    }

    private function calculateOffsets(swagWidth:Float, zoom:Float, isPixel:Bool, dScroll:Bool):{x:Float, y:Float} 
    {
        var outX = swagWidth * 0.5 - this.x;
        if (isPixel) outX -= PIXEL_OFFSET_X;

        final yAdjustment = isPixel ? (dScroll ? -4.5 : -0.75) * zoom : (dScroll ? -3.5 : -4.0);

        return {
            x: outX,
            y: (swagWidth * 0.5) + yAdjustment - this.y
        };
    }

    private function allocateBuffers(neededVertices:Int, neededIndices:Int):Void 
    {
        if (_vertexCapacity < neededVertices || _indexCapacity < neededIndices) 
        {
            _vertexCapacity = neededVertices + 256;
            _indexCapacity = neededIndices + 256;

            sustainVertices = new Vector<Float>(_vertexCapacity, false);
            sustainUvtData = new Vector<Float>(_vertexCapacity, false);
            sustainIndices = new Vector<Int>(_indexCapacity, false);
        }

        sustainVertices.length = neededVertices;
        sustainUvtData.length = neededVertices;
        sustainIndices.length = neededIndices;
    }

    private function buildModifierSamples(
        pNote:Note, state:PlayState, modMgr:ModManager, pN:Int,
        songPos:Float, currentLengthMs:Float, pointTimeBase:Float, cBeat:Float,
        speedMult:Float, hNoteData:Int, headNote:Note,
        offsets:{x:Float, y:Float},
        count:Int
    ):Void {
        final neededFloats = count * 2;

        while (sampleCache.length < neededFloats) sampleCache.push(0.0);
        while (normalCache.length < neededFloats) normalCache.push(0.0);

        final invCount = count > 1 ? 1.0 / (count - 1) : 0.0;
        for (i in 0...count) {
            final t = i * invCount;
            final time = pointTimeBase + currentLengthMs * t;
            final td = songPos - time;
            final bent = modMgr.getPos(time, td * speedMult, td, cBeat, hNoteData, pN, headNote, null, sharedVec3_0);
            sampleCache[i * 2]     = bent.x + offsets.x;
            sampleCache[i * 2 + 1] = bent.y + offsets.y;
        }

        for (i in 0...count) {
            final i0 = i > 0 ? i - 1 : 0;
            final i1 = i;
            final i2 = i + 1 < count ? i + 1 : count - 1;
            final i3 = i2 < count - 1 ? i2 + 1 : count - 1;

            final dx = MathUtil.catmullRomDeriv(0.0,
                sampleCache[i0*2],   sampleCache[i1*2],   sampleCache[i2*2],   sampleCache[i3*2]);
            final dy = MathUtil.catmullRomDeriv(0.0,
                sampleCache[i0*2+1], sampleCache[i1*2+1], sampleCache[i2*2+1], sampleCache[i3*2+1]);

            final lenSq = dx*dx + dy*dy;
            if (lenSq > 0.000001) {
                final invLen = 1.0 / Math.sqrt(lenSq);
                normalCache[i*2]     = -dy * invLen;
                normalCache[i*2 + 1] =  dx * invLen;
            } else {
                normalCache[i*2]     = 1.0;
                normalCache[i*2 + 1] = 0.0;
            }
        }
    }

    private inline function interpAt(t:Float, count:Int, outPos:Array<Float>, outNormal:Array<Float>):Void {
        final fIdx = t * (count - 1);
        var i1 = Std.int(fIdx);
        if (i1 < 0) i1 = 0;
        if (i1 >= count - 1) i1 = count - 2;

        final a = fIdx - i1;
        final i0 = i1 > 0 ? i1 - 1 : 0;
        final i2 = i1 + 1;
        final i3 = i2 < count - 1 ? i2 + 1 : count - 1;

        outPos[0] = MathUtil.catmullRom(a, sampleCache[i0*2],   sampleCache[i1*2],   sampleCache[i2*2],   sampleCache[i3*2]);
        outPos[1] = MathUtil.catmullRom(a, sampleCache[i0*2+1], sampleCache[i1*2+1], sampleCache[i2*2+1], sampleCache[i3*2+1]);

        final dx = MathUtil.catmullRomDeriv(a, sampleCache[i0*2],   sampleCache[i1*2],   sampleCache[i2*2],   sampleCache[i3*2]);
        final dy = MathUtil.catmullRomDeriv(a, sampleCache[i0*2+1], sampleCache[i1*2+1], sampleCache[i2*2+1], sampleCache[i3*2+1]);

        final lenSq = dx*dx + dy*dy;
        if (lenSq > 0.000001) {
            final invLen = 1.0 / Math.sqrt(lenSq);
            outNormal[0] = -dy * invLen;
            outNormal[1] =  dx * invLen;
        } else {
            outNormal[0] = 1.0;
            outNormal[1] = 0.0;
        }
    }

    @:access(game.PlayState)
    private function drawBentSustainToCameras(pNote:Note, state:PlayState, modMgr:ModManager, pN:Int):Void  
    {  
        final isPixel:Bool = PlayState.isPixelStage;
        final zoom:Float = PlayState.daPixelZoom;

        var currentSegments = isPixel ? Math.floor(segmentsPerTile / zoom) : segmentsPerTile;  
        if (currentSegments < 1) currentSegments = 1;

        if (tileCount * currentSegments > MAX_TOTAL_SEGMENTS)
            currentSegments = Std.int(Math.max(1, Math.floor(MAX_TOTAL_SEGMENTS / tileCount)));

        final totalSegs = tileCount * currentSegments;
        final sampleCount = Std.int(Math.min(MAX_SAMPLES, Math.max(MIN_SAMPLES, totalSegs + 1)));

        allocateBuffers(tileCount * currentSegments * 8, tileCount * currentSegments * 6);

        final absScaleY = Math.abs(scale.y);
        final absScaleX = Math.abs(scale.x);
        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;

        var tStuffVal:Float = 0.0;

        if (Std.isOfType(this, Sustain)) 
        {
            final sus:Sustain = cast this;
            tStuffVal = sus.timeStuff; 
        }

        final songPos:Float = Conductor.songPosition;
        final currentLengthMs:Float = Math.max(0, pNote.sustainLength - tStuffVal);
        final pointTimeBase:Float = pNote.strumTime + tStuffVal;
        final cBeat:Float = state.curDecBeat ?? 0.0;

        final speedMult:Float = -0.45 * (state.songSpeed ?? 1.0) * pNote.multSpeed;
        final headNote:Note = pNote.parent ?? pNote;
        final hNoteData:Int = pNote.noteData;
        final invTotalHeight = height > 0 ? 1.0 / height : 0;

        final swagWidth:Float = Note.swagWidth;
        final dScroll:Bool = ClientPrefs.downScroll;
        final offsets = calculateOffsets(swagWidth, zoom, isPixel, dScroll);

        buildModifierSamples(pNote, state, modMgr, pN, songPos, currentLengthMs, pointTimeBase,
                     cBeat, speedMult, hNoteData, headNote, offsets, sampleCount);

        final oldActive:Bool = headNote.active;
        headNote.active = true;

        final tanX = Math.tan(skew.x * FlxAngle.TO_RAD);
        final tanY = Math.tan(skew.y * FlxAngle.TO_RAD);
        final ox = 0.0;
        final oy = 0.0;

        final tmpPos:Array<Float> = [0.0, 0.0];
        final tmpNormal:Array<Float> = [0.0, 0.0];

        var currentLocalY:Float = 0.0;
        var vIdx:Int = 0;
        var iIdx:Int = 0;

        var cx0:Float = 0, cy0:Float = 0, normX0:Float = 1.0, normY0:Float = 0.0;
        var isFirstPoint = true;

        final totalSegments = tileCount * currentSegments;
        final totalSegmentsInv = totalSegments > 0 ? 1.0 / totalSegments : 0.0;

        for (i in 0...tileCount)
        {
            final isTail = (i == tailIndex);
            final isClip = (i == bodyIndex && tiles < tileCount);
            final frameToDraw = isTail ? (tailFrame ?? _frame) : _frame;

            var tileHeight = frameToDraw.frame.height * absScaleY;
            var uvYOffset = 0.0;

            if (isClip) 
            {
                final clipReduction = frameToDraw.frame.height * (tileCount - tiles);
                tileHeight -= clipReduction * absScaleY;
                uvYOffset = clipReduction;
            }

            final invParentW = 1.0 / frameToDraw.parent.width;
            final invParentH = 1.0 / frameToDraw.parent.height;

            var u0 = frameToDraw.frame.x * invParentW;
            var u1 = (frameToDraw.frame.x + frameToDraw.frame.width) * invParentW;
            if (flipX) { final tempU = u0; u0 = u1; u1 = tempU; }

            var vTop = (frameToDraw.frame.y + uvYOffset) * invParentH;
            var vBot = (frameToDraw.frame.y + frameToDraw.frame.height) * invParentH;
            if (flipY) { final temp = vTop; vTop = vBot; vBot = temp; }

            final halfWidth = (frameToDraw.frame.width * absScaleX) * 0.5;
            final sign = flipY ? 1.0 : -1.0;

            for (seg in 0...currentSegments) {
                final y0 = currentLocalY + (tileHeight * (seg / currentSegments));
                final y1 = currentLocalY + (tileHeight * ((seg + 1) / currentSegments));

                if (isFirstPoint) {
                    final timeProg0 = FlxMath.bound(flipY ? (1.0 - y0 * invTotalHeight) : (y0 * invTotalHeight), 0.0, 1.0);
                    interpAt(timeProg0, sampleCount, tmpPos, tmpNormal);

                    cx0 = tmpPos[0];
                    cy0 = tmpPos[1];
                    normX0 = tmpNormal[0] * sign;
                    normY0 = tmpNormal[1] * sign;

                    isFirstPoint = false;
                }

                final timeProg1 = FlxMath.bound(flipY ? (1.0 - y1 * invTotalHeight) : (y1 * invTotalHeight), 0.0, 1.0);
                interpAt(timeProg1, sampleCount, tmpPos, tmpNormal);

                final cx1 = tmpPos[0];
                final cy1 = tmpPos[1];
                final normX1 = tmpNormal[0] * sign;
                final normY1 = tmpNormal[1] * sign;

                final bVertex = Std.int(vIdx / 2);
                final v0 = vTop + (vBot - vTop) * (seg / currentSegments);
                final v1 = vTop + (vBot - vTop) * ((seg + 1) / currentSegments);

                var px:Float, py:Float;

                px = cx0 - normX0 * halfWidth; py = cy0 - normY0 * halfWidth;
                sustainVertices[vIdx] = px + (py - oy) * tanX; sustainUvtData[vIdx++] = u0;
                sustainVertices[vIdx] = py + (px - ox) * tanY; sustainUvtData[vIdx++] = v0;

                px = cx0 + normX0 * halfWidth; py = cy0 + normY0 * halfWidth;
                sustainVertices[vIdx] = px + (py - oy) * tanX; sustainUvtData[vIdx++] = u1;
                sustainVertices[vIdx] = py + (px - ox) * tanY; sustainUvtData[vIdx++] = v0;

                px = cx1 - normX1 * halfWidth; py = cy1 - normY1 * halfWidth;
                sustainVertices[vIdx] = px + (py - oy) * tanX; sustainUvtData[vIdx++] = u0;
                sustainVertices[vIdx] = py + (px - ox) * tanY; sustainUvtData[vIdx++] = v1;

                px = cx1 + normX1 * halfWidth; py = cy1 + normY1 * halfWidth;
                sustainVertices[vIdx] = px + (py - oy) * tanX; sustainUvtData[vIdx++] = u1;
                sustainVertices[vIdx] = py + (px - ox) * tanY; sustainUvtData[vIdx++] = v1;

                sustainIndices[iIdx++] = bVertex;
                sustainIndices[iIdx++] = bVertex + 1;
                sustainIndices[iIdx++] = bVertex + 2;
                sustainIndices[iIdx++] = bVertex + 1;
                sustainIndices[iIdx++] = bVertex + 3;
                sustainIndices[iIdx++] = bVertex + 2;

                cx0 = cx1; cy0 = cy1;
                normX0 = normX1; normY0 = normY1;
            }
            currentLocalY += tileHeight;
        }

        headNote.active = oldActive;

        sharedColorTransform.redMultiplier = colorTransform?.redMultiplier ?? 1.0;
        sharedColorTransform.greenMultiplier = colorTransform?.greenMultiplier ?? 1.0;
        sharedColorTransform.blueMultiplier = colorTransform?.blueMultiplier ?? 1.0;
        sharedColorTransform.redOffset = colorTransform?.redOffset ?? 0;
        sharedColorTransform.greenOffset = colorTransform?.greenOffset ?? 0;
        sharedColorTransform.blueOffset = colorTransform?.blueOffset ?? 0;
        sharedColorTransform.alphaOffset = colorTransform?.alphaOffset ?? 0;

        for (camera in cameras) 
        {
            if (!camera.visible || !camera.exists) continue;

            sharedColorTransform.alphaMultiplier = (colorTransform?.alphaMultiplier ?? 1.0) * camera.alpha;
            getScreenPosition(_point, camera);

            camera.drawTriangles(_frame.parent, sustainVertices, sustainIndices, sustainUvtData, null, _point, blend, false, antialiasing, sharedColorTransform, shader);
        }
    }
    #end

    override function drawComplex(camera:FlxCamera):Void
    {
        if (frames == null || tiles <= 0 || !dirty) return;

        _frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
        _matrix.translate(-origin.x, -origin.y);
        _matrix.scale(scale.x, scale.y);

        if (skew.x != 0 || skew.y != 0)
        {
            final skMat = new openfl.geom.Matrix();
            skMat.b = Math.tan(skew.y * FlxAngle.TO_RAD);
            skMat.c = Math.tan(skew.x * FlxAngle.TO_RAD);
            _matrix.concat(skMat);
        }

        if (bakedRotationAngle <= 0)
        {
            updateTrig();
            if (angle != 0) _matrix.rotateWithTrig(_cosAngle, _sinAngle);
        }

        getScreenPosition(_point, camera).subtract(offset.x, offset.y).add(origin.x, origin.y);
        _matrix.translate(_point.x, _point.y);
        
        sharedColorTransform.redMultiplier = colorTransform?.redMultiplier ?? 1.0;
        sharedColorTransform.greenMultiplier = colorTransform?.greenMultiplier ?? 1.0;
        sharedColorTransform.blueMultiplier = colorTransform?.blueMultiplier ?? 1.0;
        sharedColorTransform.alphaMultiplier = (colorTransform?.alphaMultiplier ?? 1.0) * camera.alpha;
        sharedColorTransform.redOffset = colorTransform?.redOffset ?? 0;
        sharedColorTransform.greenOffset = colorTransform?.greenOffset ?? 0;
        sharedColorTransform.blueOffset = colorTransform?.blueOffset ?? 0;
        sharedColorTransform.alphaOffset = colorTransform?.alphaOffset ?? 0;
        
        if (isPixelPerfectRender(camera))
        {
            _matrix.tx = Math.floor(_matrix.tx);
            _matrix.ty = Math.floor(_matrix.ty);
        }

        final hasRGB = sharedColorTransform.redMultiplier != 1 || sharedColorTransform.greenMultiplier != 1 || sharedColorTransform.blueMultiplier != 1;
        final hasOffsets = sharedColorTransform.alphaMultiplier != 1 || sharedColorTransform.redOffset != 0 || sharedColorTransform.greenOffset != 0 
                || sharedColorTransform.blueOffset != 0 || sharedColorTransform.alphaOffset != 0;
        
        final batch = camera.startQuadBatch(_frame.parent, hasRGB, hasOffsets, blend, antialiasing, shader);
          
        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;
        final absScaleY = Math.abs(scale.y);

        if (flipY)
        {
            final tailOffset = (_frame.frame.height - (tailFrame ?? _frame).frame.height) * absScaleY;
            _matrix.translate(tailOffset * _sinAngle, -tailOffset * _cosAngle);
        }

        for (i in 0...tileCount)
        {
            final frameToDraw = (i == tailIndex) ? (tailFrame ?? _frame) : _frame;

            var offsetAmount = (flipY ? _frame.frame.height : frameToDraw.frame.height) * absScaleY;
            if (i == bodyIndex && tiles < tileCount)  
            {
                final clipReduction = frameToDraw.frame.height * (tileCount - tiles);
                
                final oldHeight = frameToDraw.frame.height;
                final oldY = frameToDraw.frame.y;

                frameToDraw.frame.height = oldHeight - clipReduction;
                frameToDraw.frame.y = oldY + clipReduction;

                if (flipY)
                {
                    final clipOffset = clipReduction * absScaleY;
                    _matrix.translate(clipOffset * _sinAngle, -clipOffset * _cosAngle);
                }

                batch.addQuad(frameToDraw, _matrix, sharedColorTransform);
                offsetAmount = frameToDraw.frame.height * absScaleY;
                
                frameToDraw.frame.height = oldHeight;
                frameToDraw.frame.y = oldY;
            }
            else
            {
                batch.addQuad(frameToDraw, _matrix, sharedColorTransform);
            }

            _matrix.translate(-offsetAmount * _sinAngle, offsetAmount * _cosAngle);
        }
    }

    override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
    {
        newRect ??= FlxRect.get();
        camera ??= FlxG.camera;

        newRect.setPosition(x, y);

        if (pixelPerfectPosition) newRect.floor();
        
        _scaledOrigin.set(origin.x * scale.x, origin.y * scale.y);
        newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x + origin.x - _scaledOrigin.x;
        newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y + origin.y - _scaledOrigin.y;

        if (isPixelPerfectRender(camera)) newRect.floor();
        
        newRect.setSize(frameWidth * Math.abs(scale.x), height);
        
        return newRect.getRotatedBounds(angle, _scaledOrigin, newRect);
    }

    override function set_frame(value:FlxFrame):FlxFrame
    {
        if (value == null || value == bodyFrame)
            return super.set_frame(value);

        originalFrame = value;
        
        bodyFrame = originalFrame.copyTo(bodyFrame);
        adjustFrame(bodyFrame);

        super.set_frame(bodyFrame);

        updateTailFrame();  

        return bodyFrame;
    }

    override function set_height(value:Float):Float  
    {  
        if (height == value || frames == null) return value;  

        final absScaleY = Math.abs(scale.y);
        final tailHeight = (tailFrame?.frame.height ?? _frame.frame.height) * absScaleY;
        tiles = value <= tailHeight ? value / tailHeight : (value - tailHeight) / (_frame.frame.height * absScaleY) + 1;
        tileCount = Math.ceil(tiles);
        
        return super.set_height(value);  
    }  

    override function destroy()
    {
        tailFrame = FlxDestroyUtil.destroy(tailFrame);
        bodyFrame = FlxDestroyUtil.destroy(bodyFrame);
        originalFrame = null;

        sustainVertices = null;
        sustainUvtData = null;
        sustainIndices = null;

        super.destroy();
    }
}