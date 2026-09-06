package psych.ui;

import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class PsychUISlider extends FlxSpriteGroup
{
	@:unreflective public static final CHANGE_EVENT = "slider_change";
	
	public var bar:FlxSprite;
	public var minText:FlxText;
	public var maxText:FlxText;
	public var valueText:FlxText;
	public var handle:FlxSprite;
	public var label(get, set):String;
	public var labelText:FlxText;
	
	public var leftColor(default, set):FlxColor = FlxColor.TRANSPARENT;
	public var rightColor(default, set):FlxColor = FlxColor.TRANSPARENT;
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var mainColor:FlxColor;

	public var value(default, set):Float = 0;
	public var onChange:Float->Void;
	public var min(default, set):Float = -999;
	public var max(default, set):Float = 999;
	public var decimals(default, set):Int = 2;
	
	private var _isHovered:Bool = false;
	private var _isHandleHovered:Bool = false;

	public function new(x:Float = 0, y:Float = 0, callback:Float->Void, def:Float = 0, min:Float = -999, max:Float = 999, wid:Float = 200, mainColor:FlxColor = FlxColor.WHITE, handleColor:FlxColor = 0xFFAAAAAA)
	{
		super(x, y);
		this.onChange = callback;
		this.mainColor = mainColor;

		leftBar = new FlxSprite().makeGraphic(1, 1, mainColor);
		leftBar.scale.set(0, 5);
		leftBar.updateHitbox();
		add(leftBar);

		rightBar = new FlxSprite().makeGraphic(1, 1, mainColor);
		rightBar.scale.set(wid, 5);
		rightBar.updateHitbox();
		add(rightBar);

		bar = new FlxSprite().makeGraphic(Std.int(wid), 5, FlxColor.TRANSPARENT);
		bar.alpha = 0;
		add(bar);

		minText = new FlxText(0, 0, 80, '', 8);
		minText.alignment = CENTER;
		minText.color = mainColor;
		add(minText);
		
		maxText = new FlxText(0, 0, 80, '', 8);
		maxText.alignment = CENTER;
		maxText.color = mainColor;
		add(maxText);
		
		valueText = new FlxText(0, 0, 80, '', 8);
		valueText.alignment = CENTER;
		valueText.color = handleColor;
		add(valueText);
		
		labelText = new FlxText(0, 0, wid, '', 8);
		labelText.alignment = CENTER;
		add(labelText);

		handle = new FlxSprite().makeGraphic(16, 16, FlxColor.TRANSPARENT);
		flixel.util.FlxSpriteUtil.drawCircle(handle, -1, -1, -1, FlxColor.WHITE);
		handle.color = handleColor;
		add(handle);

		this.min = min;
		this.max = max;
		this.value = def;
		_updatePositions();
		forceNextUpdate = true;
	}

	public var movingHandle:Bool = false;
	public var forceNextUpdate:Bool = false;
	public var broadcastSliderEvent:Bool = true;
	public var handleTargetX:Float = 0;
	public var handleLerpSpeed:Float = 0.2;
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var isOverBar = FlxG.mouse.overlaps(bar, camera);
		var isOverHandle = FlxG.mouse.overlaps(handle, camera);
		var isOverSlider = isOverBar || isOverHandle;
		
		if (isOverSlider && !_isHovered)
		{
			if (flixel.FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.BUTTON;
			_isHovered = true;
		}
		else if (!isOverSlider && _isHovered)
		{
			if (flixel.FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.AUTO;
			_isHovered = false;
		}
		
		_isHandleHovered = isOverHandle;

		if(FlxG.mouse.justMoved || FlxG.mouse.justPressed || forceNextUpdate)
		{
			forceNextUpdate = false;
			if(FlxG.mouse.justPressed && isOverSlider)
				movingHandle = true;
			
			if(movingHandle)
			{
				var lastValue:Float = FlxMath.roundDecimal(value, decimals);
				#if (flixel < "5.9.0")
				var mouseX = FlxG.mouse.getPositionInCameraView(camera).x;
				#else
				var mouseX = FlxG.mouse.getViewPosition(camera).x;
				#end
				value = Math.max(min, Math.min(max, FlxMath.remapToRange(mouseX, bar.x, bar.x + bar.width, min, max)));
				_updateHandleX();
				handle.x = handleTargetX;
				if(this.onChange != null && lastValue != value)
				{
					this.onChange(FlxMath.roundDecimal(value, decimals));
					if(broadcastSliderEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
				}
				
				_updateBarSizes();
			}
		}

		if(!movingHandle)
		{
			_updateHandleX();
			if(Math.abs(handle.x - handleTargetX) > 0.5)
			{
				handle.x += (handleTargetX - handle.x) * handleLerpSpeed;
				_updateBarSizes();
			}
			else if(handle.x != handleTargetX)
			{
				handle.x = handleTargetX;
				_updateBarSizes();
			}
		}

		if (!FlxG.mouse.pressed) movingHandle = false;
	}

	override public function destroy()
	{
		if (_isHovered && flixel.FlxG.mouse.useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		super.destroy();
	}

	inline private function _updatePositions():Void
	{
		bar.x = x;
		bar.y = y;
		leftBar.x = bar.x;
		leftBar.y = bar.y;
		rightBar.x = bar.x;
		rightBar.y = bar.y;

		minText.x = bar.x - minText.width/2;
		maxText.x = bar.x + bar.width - maxText.width/2;
		valueText.x = bar.x + bar.width/2 - valueText.width/2;

		labelText.x = bar.x + bar.width/2 - labelText.width/2;
		if(label.length > 0) bar.y = labelText.y + 24;
		
		minText.y = maxText.y = valueText.y = bar.y + 12;

		_updateHandleX();
		handle.y = bar.y + bar.height/2 - handle.height/2;

		_updateBarSizes();
		_updateColors();
	}

	inline private function _updateBarSizes():Void
	{
		leftBar.x = bar.x;
		leftBar.y = bar.y;
		rightBar.x = bar.x;
		rightBar.y = bar.y;
		
		var handlePos:Float = handle.x - (bar.x - handle.width/2);
		handlePos = Math.max(0, Math.min(bar.width, handlePos));
		leftBar.scale.x = handlePos;
		rightBar.scale.x = bar.width - handlePos;
		leftBar.updateHitbox();
		rightBar.updateHitbox();
		rightBar.x = bar.x + handlePos;
	}

	inline private function _updateColors():Void
	{
		var leftAlpha:Int = (Std.int(leftColor) >> 24) & 0xFF;
		var rightAlpha:Int = (Std.int(rightColor) >> 24) & 0xFF;
		leftBar.color = (leftAlpha == 0) ? mainColor : leftColor;
		rightBar.color = (rightAlpha == 0) ? mainColor : rightColor;
	}

	inline private function _updateHandleX():Void
	{
		handleTargetX = bar.x - handle.width/2 + FlxMath.remapToRange(FlxMath.roundDecimal(value, decimals), min, max, 0, bar.width);
		handle.y = bar.y + bar.height/2 - handle.height/2;
	}

	public function set_decimals(v:Int):Int
	{
		decimals = v;
		minText.text = Std.string(FlxMath.roundDecimal(min, decimals));
		maxText.text = Std.string(FlxMath.roundDecimal(max, decimals));
		valueText.text = Std.string(FlxMath.roundDecimal(value, decimals));
		if(this.onChange != null) this.onChange(FlxMath.roundDecimal(value, decimals));
		_updatePositions();
		return decimals;
	}

	public function set_min(v:Float):Float
	{
		if(v > max) max = v;
		min = v;
		minText.text = Std.string(FlxMath.roundDecimal(min, decimals));
		_updateHandleX();
		_updatePositions();
		return min;
	}

	public function set_max(v:Float):Float
	{
		if(v < min) min = v;
		max = v;
		maxText.text = Std.string(FlxMath.roundDecimal(max, decimals));
		_updateHandleX();
		_updatePositions();
		return max;
	}

	public function set_value(v:Float):Float
	{
		value = Math.max(min, Math.min(max, v));
		valueText.text = Std.string(FlxMath.roundDecimal(value, decimals));
		_updateHandleX();
		_updatePositions();
		return value;
	}

	public function set_label(v:String):String
	{
		labelText.text = v;
		_updatePositions();
		return labelText.text;
	}
	
	public function get_label():String
	{
		return labelText.text;
	}
		
	public function set_leftColor(color:FlxColor):FlxColor
	{
		leftColor = color;
		_updateColors();
		return color;
	}
	
	public function set_rightColor(color:FlxColor):FlxColor
	{
		rightColor = color;
		_updateColors();
		return color;
	}
}