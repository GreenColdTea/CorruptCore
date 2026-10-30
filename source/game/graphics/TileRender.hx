package game.graphics;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.math.FlxRect;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

import lime.app.Application;

import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.OpenGLRenderer;
import openfl.display.Sprite;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.Vector;

import game.objects.Note;
import game.objects.Note.Sustain;

#if MODCHART_ALLOWED
import game.modchart.ModManager;
#end

import math.Vector3;

using flixel.util.FlxColorTransformUtil;

@:access(openfl.display.BitmapData)
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.Graphics)
@:access(openfl.display3D.Context3D)
@:access(flixel.FlxCamera)
class TileRender extends FlxSprite 
{
    private static inline final PIXEL_OFFSET_X:Float = 5.0;
    private static inline final MAX_TOTAL_SEGMENTS:Int = 48;
    private static inline final MAX_TEXTURE_SIZE:Int = 4096;
    private static inline final MIN_TEXTURE_ALLOC:Int = 256;

    private static final sharedColorTransform:ColorTransform = new ColorTransform();
    private static final sharedIdentityColor:ColorTransform = new ColorTransform();
    private static final sharedMatrix:Matrix = new Matrix();
    private static final sharedVec3_0:Vector3 = new Vector3(0.0, 0.0, 0.0);

    private static final glProxySprite:Sprite = new Sprite();
    private static final glBakeVertices:Vector<Float> = new Vector<Float>();
    private static final glBakeIndices:Vector<Int> = new Vector<Int>();
    private static final glBakeUvt:Vector<Float> = new Vector<Float>();

    private static var spineX:Vector<Float> = new Vector<Float>(64, false);
    private static var spineY:Vector<Float> = new Vector<Float>(64, false);
    private static var spineNX:Vector<Float> = new Vector<Float>(64, false);
    private static var spineNY:Vector<Float> = new Vector<Float>(64, false);

    private static var _offsetX:Float = 0.0;
    private static var _offsetY:Float = 0.0;

    private var sustainVertices:Vector<Float> = new Vector<Float>(128, false);
    private var sustainUvtData:Vector<Float> = new Vector<Float>(128, false);
    private var sustainIndices:Vector<Int> = new Vector<Int>(192, false);

    private var _vertexCapacity:Int = 128;
    private var _indexCapacity:Int = 192;

    private var __bakedBitmap:Null<BitmapData> = null;
    private var __bakedGraphic:Null<FlxGraphic> = null;
    private var __bakeDirty:Bool = true;
    private var __lastBakedHeight:Int = -1;
    private var __lastBakedFlipY:Bool = false;

    public var tailAnim(default, set):Null<String> = null;
    public var segmentsPerTile:Int = !ClientPrefs.lowQuality ? 6 : 3;
    public var skew:FlxPoint = FlxPoint.get();

    private var tailFrame:Null<FlxFrame> = null;
    private var bodyFrame:Null<FlxFrame> = null;
    private var originalFrame:Null<FlxFrame> = null;

    private var tiles:Float = 0.0;
    private var tileCount:Int = 0;

    #if MODCHART_ALLOWED
    public var parentNote:Null<Note> = null;
    #end

    public function new(?X:Float = 0.0, ?Y:Float = 0.0)
    {
        super(X, Y);
    }

    private function set_tailAnim(value:Null<String>):Null<String>
    {
        if (tailAnim != value) 
        {
            tailAnim = value;
            updateTailFrame();
            __bakeDirty = true;
        }
        return value;
    }

    private inline function adjustFrame(frame:Null<FlxFrame>):Void
    {
        if (frame == null) return;
        frame.sourceSize.y -= 2.0;
        frame.frame.height -= 2.0;
        frame.frame.y += 1.0;
    }

    private function updateTailFrame():Void
    {
        if (frames == null || animation == null || tailAnim == null || !animation.exists(tailAnim)) return;  

        final anim = animation.getByName(tailAnim);
        final curAnim = animation.curAnim;
        if (anim == null || curAnim == null) return;

        final rawTail = frames.frames[anim.frames[curAnim.curFrame]];
        if (rawTail != null)
        {
            tailFrame = rawTail.copyTo(tailFrame);
            adjustFrame(tailFrame);
            __bakeDirty = true;
        }
    }

    private function bakeSustainStrip():Bool
    {
        final context3D = FlxG.stage?.context3D;
        final parentGraphic = _frame?.parent;
        if (context3D == null || _frame == null || parentGraphic == null || tileCount <= 0)
            return false;

        final texW = Std.int(Math.max(1.0, _frame.frame.width));
        final absScaleY = Math.abs(scale.y);
        final unscaledH = Std.int(Math.max(1.0, Math.ceil(height / (absScaleY > 0.0001 ? absScaleY : 1.0))));

        if (unscaledH > MAX_TEXTURE_SIZE) return false;

        if (__bakedBitmap == null || __bakedBitmap.width < texW || __bakedBitmap.height < unscaledH)
        {
            final allocH = Std.int(Math.min(MAX_TEXTURE_SIZE, Math.max(unscaledH, MIN_TEXTURE_ALLOC)));
            if (__bakedGraphic != null) 
            {
                __bakedGraphic = FlxDestroyUtil.destroy(__bakedGraphic);
                __bakedBitmap = null;
            }

            __bakedBitmap = new BitmapData(texW, allocH, true, 0);
            __bakedBitmap.disposeImage();
            __bakedGraphic = FlxGraphic.fromBitmapData(__bakedBitmap, false, null, false);
            __bakeDirty = true;
        }

        if (!__bakeDirty && __lastBakedHeight == unscaledH && __lastBakedFlipY == flipY)
            return true;

        __lastBakedHeight = unscaledH;
        __lastBakedFlipY = flipY;
        __bakeDirty = false;

        __bakedBitmap.getTexture(context3D);
        __bakedBitmap.__fillRect(__bakedBitmap.rect, 0x00000000, true);

        glBakeVertices.length = tileCount * 8;
        glBakeUvt.length = tileCount * 8;
        glBakeIndices.length = tileCount * 6;

        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;
        final invParentW = 1.0 / parentGraphic.width;
        final invParentH = 1.0 / parentGraphic.height;

        var curY = 0.0;
        var vIdx = 0;
        var iIdx = 0;

        for (i in 0...tileCount)
        {
            final isTail = (i == tailIndex);
            final isClip = (i == bodyIndex && tiles < tileCount);
            final frameToDraw = isTail ? (tailFrame ?? _frame) : _frame;

            var fH = frameToDraw.frame.height;
            var uvYOffset = 0.0;

            if (isClip) 
            {
                final clipReduction = fH * (tileCount - tiles);
                fH -= clipReduction;
                uvYOffset = clipReduction;
            }

            final u0 = frameToDraw.frame.x * invParentW;
            final u1 = (frameToDraw.frame.x + frameToDraw.frame.width) * invParentW;
            var v0 = (frameToDraw.frame.y + uvYOffset) * invParentH;
            var v1 = (frameToDraw.frame.y + frameToDraw.frame.height) * invParentH;

            if (flipY) 
            {
                final tmp = v0;
                v0 = v1;
                v1 = tmp;
            }

            final nextY = curY + fH;
            final bV = i << 2;

            glBakeVertices[vIdx] = 0.0;  glBakeUvt[vIdx++] = u0;
            glBakeVertices[vIdx] = curY; glBakeUvt[vIdx++] = v0;

            glBakeVertices[vIdx] = texW; glBakeUvt[vIdx++] = u1;
            glBakeVertices[vIdx] = curY; glBakeUvt[vIdx++] = v0;

            glBakeVertices[vIdx] = 0.0;   glBakeUvt[vIdx++] = u0;
            glBakeVertices[vIdx] = nextY; glBakeUvt[vIdx++] = v1;

            glBakeVertices[vIdx] = texW;  glBakeUvt[vIdx++] = u1;
            glBakeVertices[vIdx] = nextY; glBakeUvt[vIdx++] = v1;

            glBakeIndices[iIdx++] = bV;
            glBakeIndices[iIdx++] = bV + 1;
            glBakeIndices[iIdx++] = bV + 2;
            glBakeIndices[iIdx++] = bV + 1;
            glBakeIndices[iIdx++] = bV + 3;
            glBakeIndices[iIdx++] = bV + 2;

            curY = nextY;
        }

        final gfx = glProxySprite.graphics;
        gfx.clear();
        gfx.beginBitmapFill(parentGraphic.bitmap, null, false, antialiasing);
        gfx.drawTriangles(glBakeVertices, glBakeIndices, glBakeUvt);
        gfx.endFill();

        @:privateAccess
        glProxySprite.__update(false, true);

        __bakedBitmap.__textureContext ??= Application.current?.window?.context;

        if (__bakedBitmap.__renderer == null) 
        {
            __bakedBitmap.__renderer = new OpenGLRenderer(context3D, __bakedBitmap);
        } 
        else 
        {
            __bakedBitmap.__renderer.__cleanup();
            __bakedBitmap.__renderer.setShader(__bakedBitmap.__renderer.__defaultShader);
        }

        final renderer = __bakedBitmap.__renderer;
        renderer.__allowSmoothing = antialiasing;
        renderer.__pixelRatio = 1.0;
        renderer.__overrideBlendMode = NORMAL;
        sharedMatrix.identity();
        renderer.__worldTransform = sharedMatrix;
        renderer.__worldAlpha = 1.0;
        renderer.__worldColorTransform = sharedIdentityColor;
        renderer.__resize(__bakedBitmap.width, __bakedBitmap.height);

        __bakedBitmap.__drawGL(glProxySprite, renderer, false);

        return true;
    }

    override public function draw():Void
    {
        if (alpha <= 0.0 || !visible || frames == null || tiles <= 0.0) return;

        #if MODCHART_ALLOWED  
        if (tryDrawModchartMesh()) return;
        #end  

        for (camera in cameras)
        {
            if (camera == null || !camera.visible || !camera.exists) continue;
            drawComplex(camera);
        }
    }

    #if MODCHART_ALLOWED
    private function tryDrawModchartMesh():Bool 
    {
        final pNote:Null<Note> = parentNote ?? ((this is Sustain) ? (cast this : Sustain).parent : null);
        final state = PlayState.instance;
        final modMgr = state?.modManager;

        if (pNote == null || state == null || modMgr == null) return false;

        final playerNum = pNote.mustPress ? 0 : 1;
        final activeMods = modMgr.activeModInstances[playerNum];

        if (activeMods == null || activeMods.length == 0) return false;

        var hasPosMod = false;
        for (mod in activeMods) 
        {
            if (!mod.ignorePos()) 
            {
                hasPosMod = true;
                break;
            }
        }
        if (!hasPosMod) return false;

        drawBentSustain(pNote, state, modMgr, playerNum);
        return true;
    }

    private inline function updateOffsets(swagWidth:Float, zoom:Float, isPixel:Bool, dScroll:Bool):Void 
    {
        final outX = (swagWidth * 0.5 - this.x) - (isPixel ? PIXEL_OFFSET_X : 0.0);
        final yAdjustment = isPixel ? (dScroll ? -4.5 : -0.75) * zoom : (dScroll ? -3.5 : -4.0);

        _offsetX = outX;
        _offsetY = (swagWidth * 0.5) + yAdjustment - this.y;
    }

    private inline function allocateStripBuffers(rings:Int, segs:Int):Void 
    {
        final neededVertices = rings << 2; // rings * 4
        final neededIndices = segs * 6;

        if (_vertexCapacity < neededVertices) 
        {
            _vertexCapacity = neededVertices + 64;
            sustainVertices = new Vector<Float>(_vertexCapacity, false);
            sustainUvtData = new Vector<Float>(_vertexCapacity, false);
        }
        if (_indexCapacity < neededIndices) 
        {
            _indexCapacity = neededIndices + 96;
            sustainIndices = new Vector<Int>(_indexCapacity, false);
        }
        if (spineX.length < rings) 
        {
            final cap = rings + 16;
            spineX = new Vector<Float>(cap, false);
            spineY = new Vector<Float>(cap, false);
            spineNX = new Vector<Float>(cap, false);
            spineNY = new Vector<Float>(cap, false);
        }

        sustainVertices.length = neededVertices;
        sustainUvtData.length = neededVertices;
        sustainIndices.length = neededIndices;
    }

    @:access(game.PlayState)
    private function drawBentSustain(pNote:Note, state:PlayState, modMgr:ModManager, pN:Int):Void  
    {  
        if (!bakeSustainStrip() || __bakedBitmap == null || __bakedGraphic == null) return;

        final isPixel = PlayState.isPixelStage;
        final zoom = PlayState.daPixelZoom;

        final rawSegs = isPixel ? Math.floor(segmentsPerTile / zoom) : segmentsPerTile;  
        final segsPerTile = rawSegs < 1 ? 1 : rawSegs;

        final totalSegs = FlxMath.minInt(MAX_TOTAL_SEGMENTS, FlxMath.maxInt(2, tileCount * segsPerTile));
        final totalRings = totalSegs + 1;

        allocateStripBuffers(totalRings, totalSegs);

        final tStuffVal = (this is Sustain) ? (cast this : Sustain).timeStuff : 0.0;
        final songPos = Conductor.songPosition;
        final currentLengthMs = Math.max(0.0, pNote.sustainLength - tStuffVal);
        final pointTimeBase = pNote.strumTime + tStuffVal;
        final cBeat = state.curDecBeat ?? 0.0;

        final speedMult = -0.45 * (state.songSpeed ?? 1.0) * pNote.multSpeed;
        final headNote = pNote.parent ?? pNote;
        final hNoteData = pNote.noteData;

        updateOffsets(Note.swagWidth, zoom, isPixel, ClientPrefs.downScroll);
        final offX = _offsetX;
        final offY = _offsetY;

        final oldActive = headNote.active;
        headNote.active = true;

        final invSegs = 1.0 / totalSegs;
        final sign = flipY ? 1.0 : -1.0;

        for (r in 0...totalRings)
        {
            final frac = r * invSegs;
            final t = flipY ? (1.0 - frac) : frac;
            final time = pointTimeBase + currentLengthMs * t;
            final td = songPos - time;

            final bent = modMgr.getPos(time, td * speedMult, td, cBeat, hNoteData, pN, headNote, null, sharedVec3_0);
            spineX[r] = bent.x + offX;
            spineY[r] = bent.y + offY;
        }

        headNote.active = oldActive;

        for (r in 0...totalRings)
        {
            final prev = r > 0 ? r - 1 : 0;
            final next = r < totalSegs ? r + 1 : totalSegs;

            final dx = spineX[next] - spineX[prev];
            final dy = spineY[next] - spineY[prev];
            final lenSq = dx * dx + dy * dy;

            if (lenSq > 0.000001) 
            {
                final invLen = sign / Math.sqrt(lenSq);
                spineNX[r] = -dy * invLen;
                spineNY[r] =  dx * invLen;
            } 
            else 
            {
                spineNX[r] = sign;
                spineNY[r] = 0.0;
            }
        }

        final halfWidth = (_frame.frame.width * Math.abs(scale.x)) * 0.5;
        final maxV = __lastBakedHeight / __bakedBitmap.height;
        final u0 = flipX ? 1.0 : 0.0;
        final u1 = flipX ? 0.0 : 1.0;

        final hasSkew = (skew.x != 0.0 || skew.y != 0.0);
        final tanX = hasSkew ? Math.tan(skew.x * FlxAngle.TO_RAD) : 0.0;
        final tanY = hasSkew ? Math.tan(skew.y * FlxAngle.TO_RAD) : 0.0;

        var vIdx = 0;
        for (r in 0...totalRings)
        {
            final cx = spineX[r];
            final cy = spineY[r];
            final nx = spineNX[r] * halfWidth;
            final ny = spineNY[r] * halfWidth;
            final vCoord = (r * invSegs) * maxV;

            var lx = cx - nx;
            var ly = cy - ny;
            var rx = cx + nx;
            var ry = cy + ny;

            if (hasSkew) 
            {
                final slx = lx + ly * tanX;
                final sly = ly + lx * tanY;
                final srx = rx + ry * tanX;
                final sry = ry + rx * tanY;
                lx = slx; ly = sly;
                rx = srx; ry = sry;
            }

            sustainVertices[vIdx] = lx; sustainUvtData[vIdx++] = u0;
            sustainVertices[vIdx] = ly; sustainUvtData[vIdx++] = vCoord;

            sustainVertices[vIdx] = rx; sustainUvtData[vIdx++] = u1;
            sustainVertices[vIdx] = ry; sustainUvtData[vIdx++] = vCoord;
        }

        var iIdx = 0;
        for (s in 0...totalSegs)
        {
            final bV = s << 1;
            sustainIndices[iIdx++] = bV;
            sustainIndices[iIdx++] = bV + 1;
            sustainIndices[iIdx++] = bV + 2;
            sustainIndices[iIdx++] = bV + 1;
            sustainIndices[iIdx++] = bV + 3;
            sustainIndices[iIdx++] = bV + 2;
        }

        sharedColorTransform.redMultiplier = colorTransform?.redMultiplier ?? 1.0;
        sharedColorTransform.greenMultiplier = colorTransform?.greenMultiplier ?? 1.0;
        sharedColorTransform.blueMultiplier = colorTransform?.blueMultiplier ?? 1.0;
        sharedColorTransform.redOffset = colorTransform?.redOffset ?? 0.0;
        sharedColorTransform.greenOffset = colorTransform?.greenOffset ?? 0.0;
        sharedColorTransform.blueOffset = colorTransform?.blueOffset ?? 0.0;
        sharedColorTransform.alphaOffset = colorTransform?.alphaOffset ?? 0.0;

        final baseAlpha = colorTransform?.alphaMultiplier ?? 1.0;

        for (camera in cameras) 
        {
            if (camera == null || !camera.visible || !camera.exists) continue;

            sharedColorTransform.alphaMultiplier = baseAlpha * camera.alpha;
            getScreenPosition(_point, camera);

            camera.drawTriangles(
                __bakedGraphic,
                sustainVertices,
                sustainIndices,
                sustainUvtData,
                null,
                _point,
                blend,
                false,
                antialiasing,
                sharedColorTransform,
                shader
            );
        }
    }
    #end

    override private function drawComplex(camera:FlxCamera):Void
    {
        if (frames == null || _frame == null || tiles <= 0.0) return;

        _frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
        _matrix.translate(-origin.x, -origin.y);
        _matrix.scale(scale.x, scale.y);

        if (skew.x != 0.0 || skew.y != 0.0)
        {
            sharedMatrix.identity();
            sharedMatrix.b = Math.tan(skew.y * FlxAngle.TO_RAD);
            sharedMatrix.c = Math.tan(skew.x * FlxAngle.TO_RAD);
            _matrix.concat(sharedMatrix);
        }

        if (bakedRotationAngle <= 0.0)
        {
            updateTrig();
            if (angle != 0.0) _matrix.rotateWithTrig(_cosAngle, _sinAngle);
        }

        getScreenPosition(_point, camera).subtract(offset.x, offset.y).add(origin.x, origin.y);
        _matrix.translate(_point.x, _point.y);
        
        sharedColorTransform.redMultiplier = colorTransform?.redMultiplier ?? 1.0;
        sharedColorTransform.greenMultiplier = colorTransform?.greenMultiplier ?? 1.0;
        sharedColorTransform.blueMultiplier = colorTransform?.blueMultiplier ?? 1.0;
        sharedColorTransform.alphaMultiplier = (colorTransform?.alphaMultiplier ?? 1.0) * camera.alpha;
        sharedColorTransform.redOffset = colorTransform?.redOffset ?? 0.0;
        sharedColorTransform.greenOffset = colorTransform?.greenOffset ?? 0.0;
        sharedColorTransform.blueOffset = colorTransform?.blueOffset ?? 0.0;
        sharedColorTransform.alphaOffset = colorTransform?.alphaOffset ?? 0.0;
        
        if (isPixelPerfectRender(camera))
        {
            _matrix.tx = Math.floor(_matrix.tx);
            _matrix.ty = Math.floor(_matrix.ty);
        }

        final hasRGB = sharedColorTransform.redMultiplier != 1.0 || sharedColorTransform.greenMultiplier != 1.0 || sharedColorTransform.blueMultiplier != 1.0;
        final hasOffsets = sharedColorTransform.alphaMultiplier != 1.0 || sharedColorTransform.redOffset != 0.0 || sharedColorTransform.greenOffset != 0.0 
                || sharedColorTransform.blueOffset != 0.0 || sharedColorTransform.alphaOffset != 0.0;
        
        final batch = camera.startQuadBatch(_frame.parent, hasRGB, hasOffsets, blend, antialiasing, shader);
          
        final bodyIndex = flipY ? tileCount - 1 : 0;
        final tailIndex = flipY ? 0 : tileCount - 1;
        final absScaleY = Math.abs(scale.y);

        if (flipY)
        {
            final tailOffset = (_frame.frame.height - (tailFrame?.frame.height ?? _frame.frame.height)) * absScaleY;
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

    override private function set_frame(value:FlxFrame):FlxFrame
    {
        if (value == null || value == bodyFrame)
            return super.set_frame(value);

        originalFrame = value;
        
        bodyFrame = originalFrame.copyTo(bodyFrame);
        adjustFrame(bodyFrame);

        super.set_frame(bodyFrame);

        updateTailFrame();
        __bakeDirty = true;

        return bodyFrame;
    }

    override private function set_height(value:Float):Float  
    {  
        if (height == value || frames == null || _frame == null) return value;  

        final absScaleY = Math.abs(scale.y);
        final tailHeight = (tailFrame?.frame.height ?? _frame.frame.height) * absScaleY;
        tiles = value <= tailHeight ? value / tailHeight : (value - tailHeight) / (_frame.frame.height * absScaleY) + 1.0;
        tileCount = Math.ceil(tiles);
        __bakeDirty = true;
        
        return super.set_height(value);  
    }  

    override public function destroy():Void
    {
        tailFrame = FlxDestroyUtil.destroy(tailFrame);
        bodyFrame = FlxDestroyUtil.destroy(bodyFrame);
        originalFrame = null;

        if (__bakedGraphic != null) 
        {
            __bakedGraphic = FlxDestroyUtil.destroy(__bakedGraphic);
            __bakedBitmap = null;
        }

        skew = FlxDestroyUtil.put(skew);

        sustainVertices = null;
        sustainUvtData = null;
        sustainIndices = null;

        super.destroy();
    }
}