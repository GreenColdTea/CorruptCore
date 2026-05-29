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

        if (pNote != null && game.PlayState.instance?.modManager != null) {
            final modMgr:Dynamic = game.PlayState.instance.modManager;
            final pN:Int = pNote.mustPress ? 0 : 1;
            
            if (modMgr.activeMods[pN].length > 0) {
                buildMesh(pNote, game.PlayState.instance, modMgr, pN);
                
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
        if (vertices == null) {
            vertices = new Vector<Float>();
            uvtData = new Vector<Float>();
            indices = new Vector<Int>();
        }

        vertices.splice(0, vertices.length);
        uvtData.splice(0, uvtData.length);
        indices.splice(0, indices.length);

        final absScaleY = Math.abs(scale.y);
        final absScaleX = Math.abs(scale.x);
        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;

        var tStuffDyn:Dynamic = Reflect.getProperty(this, "timeStuff");
        if (tStuffDyn == null && pNote != null) {
            final hNote = Reflect.getProperty(pNote, "holdNote");
            if (hNote != null)
                tStuffDyn = Reflect.getProperty(hNote, "timeStuff");
        }

        var tStuffVal:Float = tStuffDyn != null ? cast(tStuffDyn, Float) : 0;

        final currentLengthMs:Float = pNote.sustainLength - tStuffVal;
        final pointTimeBase:Float = pNote.strumTime + tStuffVal;
        final cBeat:Float = state.curDecBeat;
        final sSpeed:Float = state.songSpeed;

        final headNote:Dynamic = Reflect.hasField(pNote, "parent") ? Reflect.getProperty(pNote, "parent") : pNote;

        final segmentsPerTile = 4; 
        final totalHeight = this.height;

        var currentLocalY:Float = 0.0;

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

            if (flipX) {
                final tempU = u0;
                u0 = u1;
                u1 = tempU;
            }
            
            var vTop = (frameToDraw.frame.y + uvYOffset) / parentH;
            var vBot = (frameToDraw.frame.y + frameToDraw.frame.height) / parentH;

            if (flipY) {
                final temp = vTop;
                vTop = vBot;
                vBot = temp;
            }

            final widthLocal = frameToDraw.frame.width * absScaleX;
            final swagWidth:Float = Reflect.hasField(pNote, "swagWidth") ? Reflect.getProperty(pNote, "swagWidth") : 112;
            
            final offsetX = swagWidth / 2 - (!PlayState.isPixelStage ? 0 : 5);
            final offsetY = swagWidth / 2 + (!PlayState.isPixelStage ? (ClientPrefs.downScroll ? 3.5 : -4) : 
                            (ClientPrefs.downScroll ? -3.5 * PlayState.daPixelZoom : -1 * PlayState.daPixelZoom));

            for (seg in 0...segmentsPerTile) {
                final pStart = seg / segmentsPerTile;
                final pEnd = (seg + 1) / segmentsPerTile;

                final y0 = currentLocalY + (tileHeight * pStart);
                final y1 = currentLocalY + (tileHeight * pEnd);

                final v0 = vTop + (vBot - vTop) * pStart;
                final v1 = vTop + (vBot - vTop) * pEnd;

                var timeProg0 = totalHeight > 0 ? (y0 / totalHeight) : 0;
                var timeProg1 = totalHeight > 0 ? (y1 / totalHeight) : 0;
                
                if (flipY) {
                    timeProg0 = 1.0 - timeProg0;
                    timeProg1 = 1.0 - timeProg1;
                }

                final t0 = pointTimeBase + (currentLengthMs * timeProg0);
                final t1 = pointTimeBase + (currentLengthMs * timeProg1);

                final td0 = Conductor.songPosition - t0;
                final td1 = Conductor.songPosition - t1;

                final vd0 = -(0.45 * td0 * sSpeed * pNote.multSpeed);
                final vd1 = -(0.45 * td1 * sSpeed * pNote.multSpeed);

                final bent0 = modMgr.getPos(t0, vd0, td0, cBeat, headNote.noteData, pN, headNote);
                final bent1 = modMgr.getPos(t1, vd1, td1, cBeat, headNote.noteData, pN, headNote);

                final td0_next = td0 - 1.0;
                final vd0_next = -(0.45 * td0_next * sSpeed * pNote.multSpeed);
                final bent0_next = modMgr.getPos(t0 + 1.0, vd0_next, td0_next, cBeat, headNote.noteData, pN, headNote);
                
                final td1_next = td1 - 1.0;
                final vd1_next = -(0.45 * td1_next * sSpeed * pNote.multSpeed);
                final bent1_next = modMgr.getPos(t1 + 1.0, vd1_next, td1_next, cBeat, headNote.noteData, pN, headNote);

                final cx0 = (bent0.x + offsetX) - this.x;
                final cy0 = (bent0.y + offsetY) - this.y;
                final cx1 = (bent1.x + offsetX) - this.x;
                final cy1 = (bent1.y + offsetY) - this.y;

                final dirX0 = bent0_next.x - bent0.x;
                final dirY0 = bent0_next.y - bent0.y;
                final dist0 = Math.sqrt(dirX0 * dirX0 + dirY0 * dirY0);
                
                final dirX1 = bent1_next.x - bent1.x;
                final dirY1 = bent1_next.y - bent1.y;
                final dist1 = Math.sqrt(dirX1 * dirX1 + dirY1 * dirY1);

                var normX0 = 1.0; var normY0 = 0.0;
                var normX1 = 1.0; var normY1 = 0.0;

                final sign = flipY ? 1.0 : -1.0;

                if (dist0 > 0.001) {
                    normX0 = (-dirY0 / dist0) * sign;
                    normY0 = (dirX0 / dist0) * sign;
                }
                if (dist1 > 0.001) {
                    normX1 = (-dirY1 / dist1) * sign;
                    normY1 = (dirX1 / dist1) * sign;
                }

                final halfWidth = widthLocal / 2;

                final l0x = cx0 - normX0 * halfWidth;
                final l0y = cy0 - normY0 * halfWidth;
                final r0x = cx0 + normX0 * halfWidth;
                final r0y = cy0 + normY0 * halfWidth;

                final l1x = cx1 - normX1 * halfWidth;
                final l1y = cy1 - normY1 * halfWidth;
                final r1x = cx1 + normX1 * halfWidth;
                final r1y = cy1 + normY1 * halfWidth;

                final bVertex = Std.int(vertices.length / 2);

                vertices.push(l0x); vertices.push(l0y);
                uvtData.push(u0); uvtData.push(v0);

                vertices.push(r0x); vertices.push(r0y);
                uvtData.push(u1); uvtData.push(v0);

                vertices.push(l1x); vertices.push(l1y);
                uvtData.push(u0); uvtData.push(v1);

                vertices.push(r1x); vertices.push(r1y);
                uvtData.push(u1); uvtData.push(v1);

                indices.push(bVertex);
                indices.push(bVertex + 1);
                indices.push(bVertex + 2);

                indices.push(bVertex + 1);
                indices.push(bVertex + 3);
                indices.push(bVertex + 2);
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
            if (angle != 0)
                _matrix.rotateWithTrig(_cosAngle, _sinAngle);
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
        tileCount = Math.ceil(tiles = value <= tailHeight ? value / tailHeight : (value - tailHeight) / (_frame.frame.height * absScaleY) + 1);
        return super.set_height(value);
    }

    override function destroy()
    {
        tailFrame = FlxDestroyUtil.destroy(tailFrame);
        super.destroy();
    }
}