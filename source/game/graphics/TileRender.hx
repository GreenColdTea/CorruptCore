package game.graphics;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;

import openfl.Vector;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

class TileRender extends flixel.FlxStrip
{
    public var tailAnim(default, set):String = null;
    public var segmentsPerTile:Int = 12;

    var tailFrame:FlxFrame;
    var tiles:Float;
    var tileCount:Int;

    #if MODCHART_ALLOWED
    public var parentNote:Dynamic = null;
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
        if (frames == null || animation == null || tailAnim == null || animation.getByName(tailAnim) == null) return;
        tailFrame = frames.frames[animation.getByName(tailAnim).frames[animation.curAnim.curFrame]].copyTo(tailFrame);
        adjustFrame(tailFrame);
    }

    override public function draw():Void
    {
        if (alpha == 0 || !visible || frames == null || tiles <= 0) return;

        #if MODCHART_ALLOWED
        final pNote:Dynamic = parentNote ?? Reflect.getProperty(this, "parent");
        if (pNote != null && PlayState.instance?.modManager != null) {
            final modMgr:Dynamic = PlayState.instance.modManager;
            final pN:Int = pNote.mustPress ? 0 : 1;
            
            if (modMgr.activeMods[pN].length > 0) {
                buildMesh(pNote, PlayState.instance, modMgr, pN);
                
                final oldAngle = this.angle;
                final oldScaleX = this.scale.x;
                final oldScaleY = this.scale.y;
                final oldOffsetX = this.offset.x;
                final oldOffsetY = this.offset.y;
                final oldOriginX = this.origin.x;
                final oldOriginY = this.origin.y;

                this.angle = 0;
                this.scale.set(1, 1);
                this.offset.set(0, 0);
                this.origin.set(0, 0);

                for (camera in cameras) {
                    if (!camera.visible || !camera.exists) continue;
                    
                    final origCT = this.colorTransform;
                    @:privateAccess
                    final ct:ColorTransform = origCT?.__clone() ?? new ColorTransform();
                    ct.alphaMultiplier *= camera.alpha;

                    this.colorTransform = ct;
                    super.draw();
                    this.colorTransform = origCT;
                }
                
                this.angle = oldAngle;
                this.scale.set(oldScaleX, oldScaleY);
                this.offset.set(oldOffsetX, oldOffsetY);
                this.origin.set(oldOriginX, oldOriginY);
                return; 
            }
        }
        #end

        for (camera in cameras)
        {
            if (!camera.visible || !camera.exists) continue;
            drawComplex(camera);
        }
    }

    #if MODCHART_ALLOWED
    private function buildMesh(pNote:Dynamic, state:Dynamic, modMgr:Dynamic, pN:Int):Void
    {
        final isPixel:Bool = state.isPixelStage;
        final zoom:Float = state.daPixelZoom;
        
        var currentSegments = isPixel ? Math.floor(segmentsPerTile / zoom) : segmentsPerTile;
        if (currentSegments < 1) currentSegments = 1;

        final neededVertices = tileCount * currentSegments * 8; 
        final neededIndices = tileCount * currentSegments * 6;

        if (vertices == null) {
            vertices = new Vector<Float>(neededVertices, false);
            uvtData = new Vector<Float>(neededVertices, false);
            indices = new Vector<Int>(neededIndices, false);
        } else {
            vertices.length = neededVertices;
            uvtData.length = neededVertices;
            indices.length = neededIndices;
        }

        final absScaleY = Math.abs(scale.y);
        final absScaleX = Math.abs(scale.x);
        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;

        var tStuffDyn:Dynamic = Reflect.field(this, "timeStuff");
        if (tStuffDyn == null && pNote != null) {
            final hNote = Reflect.field(pNote, "holdNote");
            if (hNote != null) tStuffDyn = Reflect.field(hNote, "timeStuff");
        }

        final songPos = Conductor.songPosition;
        var tStuffVal:Float = tStuffDyn != null ? cast(tStuffDyn, Float) : 0;

        final isHit:Bool = Reflect.hasField(this, "hit") ? Reflect.field(this, "hit") : false;
        if (isHit)
            tStuffVal = songPos - pNote.strumTime;

        var currentLengthMs:Float = pNote.sustainLength - tStuffVal;
        if (currentLengthMs < 0) currentLengthMs = 0;

        final pointTimeBase:Float = pNote.strumTime + tStuffVal;
        final cBeat:Float = state.curDecBeat;
        final sSpeed:Float = state.songSpeed;
        
        final speedMult:Float = -0.45 * sSpeed * pNote.multSpeed;
        final headNote:Dynamic = Reflect.hasField(pNote, "parent") ? Reflect.field(pNote, "parent") : pNote;
        final hNoteData = pNote.noteData;
        final totalHeight = this.height;
        final invTotalHeight = totalHeight > 0 ? 1.0 / totalHeight : 0;
        
        final swagWidth:Float = Reflect.hasField(pNote, "swagWidth") ? Reflect.field(pNote, "swagWidth") : 112;
        final dScroll:Bool = ClientPrefs.downScroll;
        
        final offsetX = swagWidth * 0.5 - (!isPixel ? 0 : 5) - this.x;
        final offsetY = swagWidth * 0.5 + (!isPixel ? (dScroll ? 3.5 : -4) : (dScroll ? -3.5 * zoom : -1 * zoom)) - this.y;

        var currentLocalY:Float = 0.0;
        var vIdx:Int = 0;
        var iIdx:Int = 0;

        var cx0:Float = 0, cy0:Float = 0, normX0:Float = 1.0, normY0:Float = 0;
        var isFirstPoint = true;

        for (i in 0...tileCount)
        {
            final isTail = (i == tailIndex);
            final isClip = (i == bodyIndex && tiles < tileCount);
            final frameToDraw = isTail ? (tailFrame ?? _frame) : _frame;
            
            var tileHeight = frameToDraw.frame.height * absScaleY;
            var clipReduction = 0.0;
            var uvYOffset = 0.0;
            
            if (isClip) {
                clipReduction = frameToDraw.frame.height * (tileCount - tiles);
                tileHeight -= clipReduction * absScaleY;
                uvYOffset = clipReduction;
            }

            final parentW = frameToDraw.parent.width;
            final parentH = frameToDraw.parent.height;

            var u0 = frameToDraw.frame.x / parentW;
            var u1 = (frameToDraw.frame.x + frameToDraw.frame.width) / parentW;
            if (flipX) { final tempU = u0; u0 = u1; u1 = tempU; }
            
            var vTop = (frameToDraw.frame.y + uvYOffset) / parentH;
            var vBot = (frameToDraw.frame.y + frameToDraw.frame.height) / parentH;
            if (flipY) { final temp = vTop; vTop = vBot; vBot = temp; }

            final widthLocal = frameToDraw.frame.width * absScaleX;
            final halfWidth = widthLocal * 0.5;
            final sign = flipY ? 1.0 : -1.0;

            for (seg in 0...currentSegments) {
                final pStart = seg / currentSegments;
                final pEnd = (seg + 1) / currentSegments;

                final y0 = currentLocalY + (tileHeight * pStart);
                final y1 = currentLocalY + (tileHeight * pEnd);

                final v0 = vTop + (vBot - vTop) * pStart;
                final v1 = vTop + (vBot - vTop) * pEnd;

                if (isFirstPoint) {
                    var timeProg0 = y0 * invTotalHeight;
                    if (flipY) timeProg0 = 1.0 - timeProg0;

                    final t0 = pointTimeBase + (currentLengthMs * timeProg0);
                    final td0 = songPos - t0;
                    final bent0 = modMgr.getPos(t0, td0 * speedMult, td0, cBeat, hNoteData, pN, headNote);
                    
                    final td0_next = td0 - 1.0;
                    final bent0_next = modMgr.getPos(t0 + 1.0, td0_next * speedMult, td0_next, cBeat, hNoteData, pN, headNote);

                    cx0 = bent0.x + offsetX;
                    cy0 = bent0.y + offsetY;

                    final dirX0 = bent0_next.x - bent0.x;
                    final dirY0 = bent0_next.y - bent0.y;
                    final dist0 = Math.sqrt(dirX0 * dirX0 + dirY0 * dirY0);
                    
                    if (dist0 > 0.001) {
                        normX0 = (-dirY0 / dist0) * sign;
                        normY0 = (dirX0 / dist0) * sign;
                    }
                    isFirstPoint = false;
                }

                var timeProg1 = y1 * invTotalHeight;
                if (flipY) timeProg1 = 1.0 - timeProg1;

                final t1 = pointTimeBase + (currentLengthMs * timeProg1);
                final td1 = songPos - t1;
                
                final bent1 = modMgr.getPos(t1, td1 * speedMult, td1, cBeat, hNoteData, pN, headNote);
                final td1_next = td1 - 1.0;
                final bent1_next = modMgr.getPos(t1 + 1.0, td1_next * speedMult, td1_next, cBeat, hNoteData, pN, headNote);

                final cx1 = bent1.x + offsetX;
                final cy1 = bent1.y + offsetY;

                final dirX1 = bent1_next.x - bent1.x;
                final dirY1 = bent1_next.y - bent1.y;
                final dist1 = Math.sqrt(dirX1 * dirX1 + dirY1 * dirY1);

                var normX1 = 1.0; var normY1 = 0.0;
                if (dist1 > 0.001) {
                    normX1 = (-dirY1 / dist1) * sign;
                    normY1 = (dirX1 / dist1) * sign;
                }

                final bVertex = Std.int(vIdx / 2);

                vertices[vIdx] = cx0 - normX0 * halfWidth; uvtData[vIdx++] = u0;
                vertices[vIdx] = cy0 - normY0 * halfWidth; uvtData[vIdx++] = v0;

                vertices[vIdx] = cx0 + normX0 * halfWidth; uvtData[vIdx++] = u1;
                vertices[vIdx] = cy0 + normY0 * halfWidth; uvtData[vIdx++] = v0;

                vertices[vIdx] = cx1 - normX1 * halfWidth; uvtData[vIdx++] = u0;
                vertices[vIdx] = cy1 - normY1 * halfWidth; uvtData[vIdx++] = v1;

                vertices[vIdx] = cx1 + normX1 * halfWidth; uvtData[vIdx++] = u1;
                vertices[vIdx] = cy1 + normY1 * halfWidth; uvtData[vIdx++] = v1;

                indices[iIdx++] = bVertex;
                indices[iIdx++] = bVertex + 1;
                indices[iIdx++] = bVertex + 2;

                indices[iIdx++] = bVertex + 1;
                indices[iIdx++] = bVertex + 3;
                indices[iIdx++] = bVertex + 2;

                cx0 = cx1;
                cy0 = cy1;
                normX0 = normX1;
                normY0 = normY1;
            }
            currentLocalY += tileHeight;
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
        
        @:privateAccess
        final ct:ColorTransform = colorTransform?.__clone() ?? new ColorTransform();
        ct.alphaMultiplier *= camera.alpha;
        
        if (isPixelPerfectRender(camera))
        {
            _matrix.tx = Math.floor(_matrix.tx);
            _matrix.ty = Math.floor(_matrix.ty);
        }

        final hasRGB = ct.redMultiplier != 1 || ct.greenMultiplier != 1 || ct.blueMultiplier != 1;
        final hasOffsets = ct.alphaMultiplier != 1 || ct.redOffset != 0 || ct.greenOffset != 0 || ct.blueOffset != 0 || ct.alphaOffset != 0;
        final batch = camera.startQuadBatch(_frame.parent, hasRGB, hasOffsets, blend, antialiasing, shader);
        
        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;
        final absScaleY = Math.abs(scale.y);

        if (flipY)
        {
            var tailOffset = (_frame.frame.height - (tailFrame ?? _frame).frame.height) * absScaleY;
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

                batch.addQuad(frameToDraw, _matrix, ct);
                offsetAmount = frameToDraw.frame.height * absScaleY;
                frameToDraw.frame.height += clipReduction;
                frameToDraw.frame.y -= clipReduction;
            }
            else
            {
                batch.addQuad(frameToDraw, _matrix, ct);
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
        super.set_frame(value);
        adjustFrame(_frame);
        updateTailFrame();
        return value;
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
        super.destroy();
    }
}