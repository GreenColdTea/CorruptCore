package game.graphics;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;
import flixel.math.FlxMath;
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

    static var sharedColorTransform:ColorTransform = new ColorTransform();
    static var sharedVec3_0:Vector3 = new Vector3(0, 0, 0);
    static var sharedVec3_1:Vector3 = new Vector3(0, 0, 0);
    
    var sustainVertices:Vector<Float> = new Vector<Float>(256, false);
    var sustainUvtData:Vector<Float> = new Vector<Float>(256, false);
    var sustainIndices:Vector<Int> = new Vector<Int>(256, false);

    public var tailAnim(default, set):String = null;
    public var segmentsPerTile:Int = !ClientPrefs.lowQuality ? 12 : 4;

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
        if (sustainVertices.length < neededVertices) 
        {
            final allocSize = neededVertices + 256;
            final allocIdx = neededIndices + 256;

            sustainVertices = new Vector<Float>(allocSize, false);
            sustainUvtData = new Vector<Float>(allocSize, false);
            sustainIndices = new Vector<Int>(allocIdx, false);
        }
        
        sustainVertices.length = neededVertices;
        sustainUvtData.length = neededVertices;
        sustainIndices.length = neededIndices;
    }

    @:access(game.PlayState)
    private function drawBentSustainToCameras(pNote:Note, state:PlayState, modMgr:ModManager, pN:Int):Void  
    {  
        final isPixel:Bool = PlayState.isPixelStage;
        final zoom:Float = PlayState.daPixelZoom;
          
        var currentSegments = isPixel ? Math.floor(segmentsPerTile / zoom) : segmentsPerTile;  
        if (currentSegments < 1) currentSegments = 1;

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

        var currentLocalY:Float = 0.0;
        var vIdx:Int = 0;
        var iIdx:Int = 0;
        var cx0:Float = 0, cy0:Float = 0, normX0:Float = 1.0, normY0:Float = 0.0;
        var isFirstPoint = true;

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
                final pStart = seg / currentSegments;
                final pEnd = (seg + 1) / currentSegments;
                final y0 = currentLocalY + (tileHeight * pStart);
                final y1 = currentLocalY + (tileHeight * pEnd);

                if (isFirstPoint) {
                    final timeProg0 = FlxMath.bound(flipY ? (1.0 - y0 * invTotalHeight) : (y0 * invTotalHeight), 0.0, 1.0);
                    final t0 = pointTimeBase + (currentLengthMs * timeProg0);
                    final td0 = songPos - t0;
                    final td0_next = td0 - 1.0;

                    final bent0 = modMgr.getPos(t0, td0 * speedMult, td0, cBeat, hNoteData, pN, headNote, null, sharedVec3_0);
                    final bent0_next = modMgr.getPos(t0 + 1.0, td0_next * speedMult, td0_next, cBeat, hNoteData, pN, headNote, null, sharedVec3_1);

                    cx0 = bent0.x + offsets.x;
                    cy0 = bent0.y + offsets.y;

                    final dirX0 = bent0_next.x - bent0.x;
                    final dirY0 = bent0_next.y - bent0.y;
                    final dist0Sq = dirX0 * dirX0 + dirY0 * dirY0;
                    
                    if (dist0Sq > 0.000001) {
                        final invDist0 = 1.0 / Math.sqrt(dist0Sq);
                        normX0 = (-dirY0 * invDist0) * sign;
                        normY0 = (dirX0 * invDist0) * sign;
                    }
                    isFirstPoint = false;
                }

                final timeProg1 = FlxMath.bound(flipY ? (1.0 - y1 * invTotalHeight) : (y1 * invTotalHeight), 0.0, 1.0);
                final t1 = pointTimeBase + (currentLengthMs * timeProg1);
                final td1 = songPos - t1;
                final td1_next = td1 - 1.0;
                
                final bent1 = modMgr.getPos(t1, td1 * speedMult, td1, cBeat, hNoteData, pN, headNote, null, sharedVec3_0);
                final bent1_next = modMgr.getPos(t1 + 1.0, td1_next * speedMult, td1_next, cBeat, hNoteData, pN, headNote, null, sharedVec3_1); 

                final cx1 = bent1.x + offsets.x;
                final cy1 = bent1.y + offsets.y;

                final dirX1 = bent1_next.x - bent1.x;
                final dirY1 = bent1_next.y - bent1.y;
                final dist1Sq = dirX1 * dirX1 + dirY1 * dirY1;

                var normX1 = 1.0, normY1 = 0.0;
                if (dist1Sq > 0.000001) {
                    final invDist1 = 1.0 / Math.sqrt(dist1Sq);
                    normX1 = (-dirY1 * invDist1) * sign;
                    normY1 = (dirX1 * invDist1) * sign;
                }

                final bVertex = Std.int(vIdx / 2);
                final v0 = vTop + (vBot - vTop) * pStart;
                final v1 = vTop + (vBot - vTop) * pEnd;

                sustainVertices[vIdx] = cx0 - normX0 * halfWidth; sustainUvtData[vIdx++] = u0;
                sustainVertices[vIdx] = cy0 - normY0 * halfWidth; sustainUvtData[vIdx++] = v0;
                sustainVertices[vIdx] = cx0 + normX0 * halfWidth; sustainUvtData[vIdx++] = u1;
                sustainVertices[vIdx] = cy0 + normY0 * halfWidth; sustainUvtData[vIdx++] = v0;
                sustainVertices[vIdx] = cx1 - normX1 * halfWidth; sustainUvtData[vIdx++] = u0;
                sustainVertices[vIdx] = cy1 - normY1 * halfWidth; sustainUvtData[vIdx++] = v1;
                sustainVertices[vIdx] = cx1 + normX1 * halfWidth; sustainUvtData[vIdx++] = u1;
                sustainVertices[vIdx] = cy1 + normY1 * halfWidth; sustainUvtData[vIdx++] = v1;

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
                frameToDraw.frame.height -= clipReduction;
                frameToDraw.frame.y += clipReduction;

                if (flipY)
                {
                    final clipOffset = clipReduction * absScaleY;
                    _matrix.translate(clipOffset * _sinAngle, -clipOffset * _cosAngle);
                }

                batch.addQuad(frameToDraw, _matrix, sharedColorTransform);
                offsetAmount = frameToDraw.frame.height * absScaleY;
                frameToDraw.frame.height += clipReduction;
                frameToDraw.frame.y -= clipReduction;
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