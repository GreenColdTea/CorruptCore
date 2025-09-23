package psych.ui;

import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class PsychUINumericStepper extends PsychUIInputText
{
	public static final CHANGE_EVENT = "numericstepper_change";

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

	public function new(x:Float = 0, y:Float = 0, step:Float = 1, defValue:Float = 0, min:Float = -999, max:Float = 999, decimals:Int = 0, ?wid:Int = 60, ?isPercent:Bool = false)
	{
		super(x, y, wid, '');
		fieldWidth = Std.int(behindText.width + 2);
		@:bypassAccessor {
			this.decimals = decimals;
			this.isPercent = isPercent;
			this.min = min;
			this.max = max;
		}
		this.step = step;
		_updateFilter();

		buttonPlus = new FlxSprite(fieldWidth).loadGraphic(Paths.image('stepper_plus', 'psych-ui'), true, 16, 16);
		buttonPlus.animation.add('normal', [0], false);
		buttonPlus.animation.add('pressed', [1], false);
		buttonPlus.animation.play('normal');
		add(buttonPlus);
		
		buttonMinus = new FlxSprite(fieldWidth + buttonPlus.width).loadGraphic(Paths.image('stepper_minus', 'psych-ui'), true, 16, 16);
		buttonMinus.animation.add('normal', [0], false);
		buttonMinus.animation.add('pressed', [1], false);
		buttonMinus.animation.play('normal');
		add(buttonMinus);

		unfocus = function()
		{
			_updateValue();
			_internalOnChange();
		}
		value = defValue;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var isOverPlus = FlxG.mouse.overlaps(buttonPlus, camera);
		var isOverMinus = FlxG.mouse.overlaps(buttonMinus, camera);
		var isOverStepper = isOverPlus || isOverMinus;
		
		if (isOverStepper && (!_isPlusHovered && !_isMinusHovered))
		{
			if (flixel.FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.BUTTON;
		}
		else if (!isOverStepper && (_isPlusHovered || _isMinusHovered))
		{
			if (flixel.FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.AUTO;
		}
		
		_isPlusHovered = isOverPlus;
		_isMinusHovered = isOverMinus;

		if(FlxG.mouse.justPressed)
		{
			if(buttonPlus != null && buttonPlus.exists && isOverPlus)
			{
				buttonPlus.animation.play('pressed');
				value += step;
				_internalOnChange();
			}
			else if(buttonMinus != null && buttonMinus.exists && isOverMinus)
			{
				buttonMinus.animation.play('pressed');
				value -= step;
				_internalOnChange();
			}
		}
		else if(FlxG.mouse.released)
		{
			if(buttonPlus != null && buttonPlus.exists && buttonPlus.animation.curAnim != null && buttonPlus.animation.curAnim.name != 'normal')
				buttonPlus.animation.play('normal');
			if(buttonMinus != null && buttonMinus.exists && buttonMinus.animation.curAnim != null && buttonMinus.animation.curAnim.name != 'normal')
				buttonMinus.animation.play('normal');
		}
	}

	override public function destroy()
	{
		if ((_isPlusHovered || _isMinusHovered) && flixel.FlxG.mouse.useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		super.destroy();
	}

	function set_value(v:Float)
	{
		value = Math.max(min, Math.min(max, v));
		text = Std.string(isPercent ? (value * 100) : value);
		_updateValue();
		return value;
	}

	function set_min(v:Float)
	{
		min = v;
		@:bypassAccessor if(min > max) max = min;
		_updateFilter();
		_updateValue();
		return min;
	}

	function set_max(v:Float)
	{
		max = v;
		@:bypassAccessor if(max < min) min = max;
		_updateFilter();
		_updateValue();
		return max;
	}

	function set_decimals(v:Int)
	{
		decimals = v;
		_updateFilter();
		return decimals;
	}
	function set_isPercent(v:Bool)
	{
		var changed:Bool = (isPercent != v);
		isPercent = v;
		_updateFilter();

		if(changed)
		{
			text = Std.string(value * 100);
			_updateValue();
		}
		return isPercent;
	}

	inline function _updateValue()
	{
		var txt:String = text.replace('%', '');
		if(txt.indexOf('-') > 0)
			txt.replace('-', '');

		while(txt.indexOf('.') > -1 && txt.indexOf('.') != txt.lastIndexOf('.'))
		{
			var lastId = txt.lastIndexOf('.');
			txt = txt.substr(0, lastId) + txt.substring(lastId+1);
		}

		var val:Float = Std.parseFloat(txt);
		if(Math.isNaN(val))
			val = 0;

		if(isPercent) val /= 100;

		if(val < min) val = min;
		else if(val > max) val = max;
		val = FlxMath.roundDecimal(val, decimals);
		@:bypassAccessor value = val;

		if(isPercent)
		{
			text = Std.string(val * 100);
			text += '%';
		}
		else text = Std.string(val);

		if(caretIndex > text.length) caretIndex = text.length;
		if(selectIndex > text.length) selectIndex = text.length;
	}
	
	inline function _updateFilter()
	{
		if(min < 0)
		{
			if(decimals > 0)
			{
				if(isPercent)
					customFilterPattern = ~/[^0-9.%\-]*/g;
				else
					customFilterPattern = ~/[^0-9.\-]*/g;
			}
			else
			{
				if(isPercent)
					customFilterPattern = ~/[^0-9%\-]*/g;
				else
					customFilterPattern = ~/[^0-9\-]*/g;
			}
		}
		else
		{
			if(decimals > 0)
			{
				if(isPercent)
					customFilterPattern = ~/[^0-9.%]*/g;
				else
					customFilterPattern = ~/[^0-9.]*/g;
			}
			else
			{
				if(isPercent)
					customFilterPattern = ~/[^0-9%]*/g;
				else
					customFilterPattern = ~/[^0-9]*/g;
			}
		}
	}

	public var broadcastStepperEvent:Bool = true;
	inline function _internalOnChange()
	{
		if(onValueChange != null) onValueChange();
		if(broadcastStepperEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}

	override function setGraphicSize(width:Float = 0, height:Float = 0)
	{
		super.setGraphicSize(width, height);
		behindText.setGraphicSize(width - 32, height - 2);
	}
}