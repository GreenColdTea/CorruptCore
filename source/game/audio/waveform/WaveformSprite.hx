package game.audio.waveform;

import game.objects.MeshRender;

import flixel.util.FlxColor;

class WaveformSprite extends MeshRender
{
	static final DEFAULT_COLOR:FlxColor = FlxColor.WHITE;
	static final DEFAULT_DURATION:Float = 5.0;
	static final DEFAULT_ORIENTATION:WaveformOrientation = HORIZONTAL;
	static final DEFAULT_X:Float = 0.0;
	static final DEFAULT_Y:Float = 0.0;
	static final DEFAULT_WIDTH:Float = 100.0;
	static final DEFAULT_HEIGHT:Float = 100.0;
	
	/**
	 * Set this to true to tell the waveform to rebuild itself.
	 * Do this any time the data or drawable area of the waveform changes.
	 * This often (but not always) needs to be done every frame.
	 */
	var isWaveformDirty:Bool = true;
	
	/**
	 * If true, force the waveform to redraw every frame.
	 * Useful if the waveform's clipRect is constantly changing.
	 */
	public var forceUpdate:Bool = false;
	
	public var waveformData(default, set):Null<WaveformData>;
	
	function set_waveformData(value:Null<WaveformData>):Null<WaveformData>
	{
		if (waveformData == value) return value;
		
		waveformData = value;
		isWaveformDirty = true;
		return waveformData;
	}
	
	/**
	 * The color to render the waveform with.
	 */
	public var waveformColor(default, set):FlxColor;
	
	function set_waveformColor(value:FlxColor):FlxColor
	{
		if (waveformColor == value) return value;
		
		waveformColor = value;
		// We don't need to dirty the waveform geometry, just rebuild the texture.
		rebuildGraphic();
		return waveformColor;
	}
	
	public var orientation(default, set):WaveformOrientation;
	
	function set_orientation(value:WaveformOrientation):WaveformOrientation
	{
		if (orientation == value) return value;
		
		orientation = value;
		isWaveformDirty = true;
		return orientation;
	}
	
	/**
	 * Time, in seconds, at which the waveform starts.
	 */
	public var time(default, set):Float;
	
	function set_time(value:Float)
	{
		if (time == value) return value;
		
		time = value;
		isWaveformDirty = true;
		return time;
	}
	
	/**
	 * The duration, in seconds, that the waveform represents.
	 * The section of waveform from `time` to `time + duration` and `width` are used to determine how many samples each pixel represents.
	 */
	public var duration(default, set):Float;
	
	function set_duration(value:Float)
	{
		if (duration == value) return value;
		
		duration = value;
		isWaveformDirty = true;
		return duration;
	}
	
	/**
	 * Set the physical size of the waveform with `this.height = value`.
	 */
	override function set_height(value:Float):Float
	{
		if (height == value) return super.set_height(value);
		
		isWaveformDirty = true;
		return super.set_height(value);
	}
	
	/**
	 * Set the physical size of the waveform with `this.width = value`.
	 */
	override function set_width(value:Float):Float
	{
		if (width == value) return super.set_width(value);
		
		isWaveformDirty = true;
		return super.set_width(value);
	}
	
	/**
	 * The minimum size, in pixels, that a waveform will display with.
	 * Useful for preventing the waveform from becoming too small to see.
	 *
	 * NOTE: This is technically doubled since it's applied above and below the center of the waveform.
	 */
	public var minWaveformSize:Int = 1;
	
	/**
	 * A multiplier on the size of the waveform.
	 * Still capped at the width and height set for the sprite.
	 */
	public var amplitude:Float = 1.0;
	
	public function new(?waveformData:WaveformData, ?orientation:WaveformOrientation, ?color:FlxColor, ?duration:Float)
	{
		super(DEFAULT_X, DEFAULT_Y, DEFAULT_COLOR);
		this.waveformColor = color ?? DEFAULT_COLOR;
		this.width = DEFAULT_WIDTH;
		this.height = DEFAULT_HEIGHT;
		
		this.waveformData = waveformData;
		this.orientation = orientation ?? DEFAULT_ORIENTATION;
		this.time = 0.0;
		this.duration = duration ?? DEFAULT_DURATION;
		
		this.forceUpdate = false;
	}
	
	/**
	 * Manually tell the waveform to rebuild itself, even if none of its properties have changed.
	 */
	public function markDirty():Void
	{
		isWaveformDirty = true;
	}
	
	public override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (forceUpdate || isWaveformDirty)
		{
			// Recalculate the waveform vertices.
			drawWaveform();
			isWaveformDirty = false;
		}
	}
	
	function rebuildGraphic():Void
	{
		// The waveform is rendered using a single colored pixel as a texture.
		// If you want something more elaborate, make sure to modify `build_vertex` below to use the UVs you want.
		makeGraphic(1, 1, this.waveformColor);
	}
	
	/**
	 * @param offsetX Horizontal offset to draw the waveform at, in samples.
	 */
	function drawWaveform():Void
	{
		this.clear();
		
		if (waveformData == null) return;
		
		var waveformCenterPos:Int = orientation == HORIZONTAL ? Std.int(this.height / 2) : Std.int(this.width / 2);
		
		var visibleStartTime:Float = time;
		var visibleEndTime:Float = time + duration;
		var totalDuration:Float = waveformData.lenSeconds();
		
		var startIndex:Int = waveformData.secondsToIndex(visibleStartTime);
		var endIndex:Int = waveformData.secondsToIndex(visibleEndTime);
		
		if (startIndex < 0) startIndex = 0;
		if (endIndex > waveformData.length) endIndex = waveformData.length;
		if (startIndex >= endIndex) {
			createEmptyWaveformVisualization();
			return;
		}
		
		var visiblePointCount:Int = endIndex - startIndex;
		
		if (visiblePointCount <= 0) {
			createEmptyWaveformVisualization();
			return;
		}
		
		var pixelsPerPoint:Float = (orientation == HORIZONTAL ? this.width : this.height) / visiblePointCount;
		
		if (pixelsPerPoint > 10) {
			pixelsPerPoint = 10;
			visiblePointCount = Std.int((orientation == HORIZONTAL ? this.width : this.height) / pixelsPerPoint);
			if (visiblePointCount > (endIndex - startIndex)) visiblePointCount = endIndex - startIndex;
		}
		
		var prevVertexTopIndex:Int = -1;
		var prevVertexBottomIndex:Int = -1;
		
		for (i in 0...visiblePointCount)
		{
			var waveformIndex:Int = startIndex + Std.int(i * ((endIndex - startIndex) / visiblePointCount));
			if (waveformIndex >= waveformData.length) waveformIndex = waveformData.length - 1;
			
			var pixelPos:Float = i * pixelsPerPoint;
			
			var sampleMax:Float = Math.min(waveformData.channel(0).maxSampleMapped(waveformIndex) * amplitude, 1.0);
			var sampleMin:Float = Math.max(waveformData.channel(0).minSampleMapped(waveformIndex) * amplitude, -1.0);
			
			var sampleMaxSize:Float = sampleMax * (orientation == HORIZONTAL ? this.height : this.width) / 2;
			var sampleMinSize:Float = sampleMin * (orientation == HORIZONTAL ? this.height : this.width) / 2;
			
			if (sampleMaxSize < minWaveformSize) sampleMaxSize = minWaveformSize;
			if (sampleMinSize > -minWaveformSize) sampleMinSize = -minWaveformSize;
			
			var vertexTopY:Int = Std.int(waveformCenterPos - sampleMaxSize);
			var vertexBottomY:Int = Std.int(waveformCenterPos - sampleMinSize);
			
			if (vertexBottomY - vertexTopY < minWaveformSize) {
				vertexTopY = vertexBottomY - minWaveformSize;
			}
			
			var vertexTopIndex:Int = -1;
			var vertexBottomIndex:Int = -1;
			
			if (clipRect != null)
			{
				if (orientation == HORIZONTAL)
				{
					vertexTopIndex = buildClippedVertex(Std.int(pixelPos), vertexTopY, -1, -1, -1, -1);
					vertexBottomIndex = buildClippedVertex(Std.int(pixelPos), vertexBottomY, -1, -1, -1, -1);
				}
				else
				{
					vertexTopIndex = buildClippedVertex(vertexTopY, Std.int(pixelPos), -1, -1, -1, -1);
					vertexBottomIndex = buildClippedVertex(vertexBottomY, Std.int(pixelPos), -1, -1, -1, -1);
				}
			}
			else
			{
				if (orientation == HORIZONTAL)
				{
					vertexTopIndex = this.build_vertex(Std.int(pixelPos), vertexTopY);
					vertexBottomIndex = this.build_vertex(Std.int(pixelPos), vertexBottomY);
				}
				else
				{
					vertexTopIndex = this.build_vertex(vertexTopY, Std.int(pixelPos));
					vertexBottomIndex = this.build_vertex(vertexBottomY, Std.int(pixelPos));
				}
			}
			
			if (prevVertexTopIndex != -1 && prevVertexBottomIndex != -1)
			{
				switch (orientation)
				{
					case HORIZONTAL:
						this.add_quad(prevVertexTopIndex, vertexTopIndex, vertexBottomIndex, prevVertexBottomIndex);
					case VERTICAL:
						this.add_quad(prevVertexBottomIndex, prevVertexTopIndex, vertexTopIndex, vertexBottomIndex);
				}
			}
			
			prevVertexTopIndex = vertexTopIndex;
			prevVertexBottomIndex = vertexBottomIndex;
		}
	}

	function createEmptyWaveformVisualization():Void
	{
		var centerY = Std.int(this.height / 2);
		var lineHeight = minWaveformSize;
		
		var leftVertex = this.build_vertex(0, centerY - lineHeight);
		var rightVertex = this.build_vertex(Std.int(this.width), centerY - lineHeight);
		var bottomLeftVertex = this.build_vertex(0, centerY + lineHeight);
		var bottomRightVertex = this.build_vertex(Std.int(this.width), centerY + lineHeight);
		
		this.add_quad(leftVertex, rightVertex, bottomRightVertex, bottomLeftVertex);
	}
	
	function buildClippedVertex(x:Int, y:Int, topLeftVertexIndex:Int, topRightVertexIndex:Int, bottomLeftVertexIndex:Int, bottomRightVertexIndex:Int):Int
	{
		var shouldClipXLeft = x < clipRect.x;
		var shouldClipXRight = x > (clipRect.x + clipRect.width);
		var shouldClipYTop = y < clipRect.y;
		var shouldClipYBottom = y > (clipRect.y + clipRect.height);
		
		// If the vertex is fully outside the clipRect, use a pre-existing vertex.
		// Else, if the vertex is outside the clipRect on one axis, create a new vertex constrained on that axis.
		// Else, create a whole new vertex.
		if (shouldClipXLeft && shouldClipYTop)
		{
			return topLeftVertexIndex;
		}
		else if (shouldClipXRight && shouldClipYTop)
		{
			return topRightVertexIndex;
		}
		else if (shouldClipXLeft && shouldClipYBottom)
		{
			return bottomLeftVertexIndex;
		}
		else if (shouldClipXRight && shouldClipYBottom)
		{
			return bottomRightVertexIndex;
		}
		else if (shouldClipXLeft)
		{
			return this.build_vertex(clipRect.x, y);
		}
		else if (shouldClipXRight)
		{
			return this.build_vertex(clipRect.x + clipRect.width, y);
		}
		else if (shouldClipYTop)
		{
			return this.build_vertex(x, clipRect.y);
		}
		else if (shouldClipYBottom)
		{
			return this.build_vertex(x, clipRect.y + clipRect.height);
		}
		else
		{
			return this.build_vertex(x, y);
		}
	}
	
	public static function buildFromWaveformData(data:WaveformData, ?orientation:WaveformOrientation, ?color:FlxColor, ?duration:Float)
	{
		return new WaveformSprite(data, orientation, color, duration);
	}
}

enum WaveformOrientation
{
	HORIZONTAL;
	VERTICAL;
}
