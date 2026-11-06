package psych.ui;

import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;

class PsychUINumericStepper extends PsychUIInputText
{
	@:unreflective public static final CHANGE_EVENT = "numericstepper_change";

	public var step:Float = 0;
	public var min(default, set):Float = 0;
	public var max(default, set):Float = 0;
	public var decimals(default, set):Int = 0;
	public var isPercent(default, set):Bool = false;
	
	public var buttonPlus:FlxSprite;
	public var buttonMinus:FlxSprite;

	public var onValueChange:Void->Void;
	public var value(default, set):Float;
	
	private var _isPlusHovered:Bool = false;
	private var _isMinusHovered:Bool = false;
	
	public var broadcastStepperEvent:Bool = true;

	public function new(x:Float = 0, y:Float = 0, step:Float = 1, defValue:Float = 0, min:Float = null, max:Float = null, decimals:Int = 0, ?wid:Int = 60, ?isPercent:Bool = false)
	{
		super(x, y, wid, '');
		fieldWidth = Std.int(behindText.width + 2);
		@:bypassAccessor {
			this.decimals = decimals;
			this.isPercent = isPercent;
			this.min = min ?? Math.NEGATIVE_INFINITY;
			this.max = max ?? Math.POSITIVE_INFINITY;
		}
		this.step = step;
		_updateFilter();

		buttonPlus = new FlxSprite(fieldWidth).loadGraphic(Paths.image('stepper_plus', 'psych-ui').bitmap, true, 16, 16);
		buttonPlus.animation.add('normal', [0], false);
		buttonPlus.animation.add('pressed', [1], false);
		buttonPlus.animation.play('normal');
		buttonPlus.antialiasing = false;
		add(buttonPlus);
		
		buttonMinus = new FlxSprite(fieldWidth + buttonPlus.width).loadGraphic(Paths.image('stepper_minus', 'psych-ui').bitmap, true, 16, 16);
		buttonMinus.animation.add('normal', [0], false);
		buttonMinus.animation.add('pressed', [1], false);
		buttonMinus.animation.play('normal');
		buttonMinus.antialiasing = false;
		add(buttonMinus);

		this.unfocus = function()
		{
			_updateValueFromText();
			_internalOnChange();
		}
		
		setValueSilent(defValue);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		final isOverPlus = FlxG.mouse.overlaps(buttonPlus, camera);
		final isOverMinus = FlxG.mouse.overlaps(buttonMinus, camera);
		final isOverStepper = isOverPlus || isOverMinus;
		
		if (isOverStepper && (!_isPlusHovered && !_isMinusHovered))
		{
			if (FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.BUTTON;
		}
		else if (!isOverStepper && (_isPlusHovered || _isMinusHovered))
		{
			if (FlxG.mouse.useSystemCursor && PsychUIInputText.focusOn != this) 
				Mouse.cursor = MouseCursor.AUTO;
		}
		
		_isPlusHovered = isOverPlus;
		_isMinusHovered = isOverMinus;

		if (FlxG.mouse.justPressed)
		{
			if (buttonPlus?.exists && isOverPlus)
			{
				buttonPlus.animation.play('pressed');
				this.value += step;
			}
			else if (buttonMinus?.exists && isOverMinus)
			{
				buttonMinus.animation.play('pressed');
				this.value -= step;
			}
		}
		else if (FlxG.mouse.released)
		{
			if (buttonPlus?.exists && buttonPlus.animation.curAnim?.name != 'normal')
				buttonPlus.animation.play('normal');
			if (buttonMinus?.exists && buttonMinus.animation.curAnim?.name != 'normal')
				buttonMinus.animation.play('normal');
		}
	}

	override public function destroy()
	{
		if ((_isPlusHovered || _isMinusHovered) && FlxG.mouse.useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		super.destroy();
	}

	function set_value(v:Float):Float
	{
		v = Math.max(min, Math.min(max, v));
		v = FlxMath.roundDecimal(v, decimals);
		
		if (value == v) return value;
		
		@:bypassAccessor value = v;
		
		_updateTextFromValue();
		_internalOnChange();
		
		return value;
	}

	public function setValueSilent(v:Float):Void
	{
		v = Math.max(min, Math.min(max, v));
		v = FlxMath.roundDecimal(v, decimals);
		
		if (value == v) return;
		
		@:bypassAccessor value = v;
		_updateTextFromValue();
	}

	function set_min(v:Float):Float
	{
		min = v;
		if (min > max) @:bypassAccessor max = min;
		
		_updateFilter();
		setValueSilent(value);
		return min;
	}

	function set_max(v:Float):Float
	{
		max = v;
		if (max < min) @:bypassAccessor min = max;
		
		_updateFilter();
		setValueSilent(value);
		return max;
	}

	function set_decimals(v:Int):Int
	{
		decimals = v;
		_updateFilter();
		setValueSilent(value);
		return decimals;
	}
	
	function set_isPercent(v:Bool):Bool
	{
		if (isPercent == v) return isPercent;
		
		isPercent = v;
		_updateFilter();
		_updateTextFromValue();
		
		return isPercent;
	}

	private function _updateValueFromText():Void
	{
		var txt = this.text;
		
		if (isPercent) txt = StringTools.replace(txt, '%', '');
		
		while (txt.indexOf('.') > -1 && txt.indexOf('.') != txt.lastIndexOf('.'))
		{
			var lastId = txt.lastIndexOf('.');
			txt = txt.substring(0, lastId) + txt.substring(lastId + 1);
		}

		var val:Float = Std.parseFloat(txt);
		if (Math.isNaN(val)) val = 0;

		if (isPercent) val /= 100;

		setValueSilent(val);
	}

	private function _updateTextFromValue():Void
	{
		var displayVal = isPercent ? (value * 100) : value;
		var strValue = Std.string(displayVal);
		if (isPercent) strValue += "%";
		
		final oldBroadcast = this.broadcastInputTextEvent;
		this.broadcastInputTextEvent = false;
		
		this.text = strValue; 
		
		this.broadcastInputTextEvent = oldBroadcast;

		if (caretIndex > this.text.length) caretIndex = this.text.length;
		if (selectIndex > this.text.length) selectIndex = this.text.length;
		updateCaret();
	}
	
	inline function _updateFilter():Void
	{
		if (min < 0)
		{
			if (decimals > 0)
				customFilterPattern = isPercent ? ~/[^0-9.%\-]*/g : ~/[^0-9.\-]*/g;
			else
				customFilterPattern = isPercent ? ~/[^0-9%\-]*/g : ~/[^0-9\-]*/g;
		}
		else
		{
			if (decimals > 0)
				customFilterPattern = isPercent ? ~/[^0-9.%]*/g : ~/[^0-9.]*/g;
			else
				customFilterPattern = isPercent ? ~/[^0-9%]*/g : ~/[^0-9]*/g;
		}
	}

	inline function _internalOnChange():Void
	{
		if (onValueChange != null) onValueChange();
		if (broadcastStepperEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}

	override function setGraphicSize(width:Float = 0, height:Float = 0)
	{
		super.setGraphicSize(width, height);
		if (behindText != null)
			behindText.setGraphicSize(width - 32, height - 2);
	}
}