package psych.ui;

import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class PsychUICheckBox extends FlxSpriteGroup
{
	@:unreflective
	public static final CLICK_EVENT = 'checkbox_click';

	public var name:String;
	public var box:FlxSprite;
	public var text:FlxText;
	public var label(get, set):String;

	public var checked(default, set):Bool = false;
	public var onClick:Void->Void = null;

	private var _isHovered:Bool = false;

	public function new(x:Float, y:Float, label:String, ?textWid:Int = 100, ?callback:Void->Void)
	{
		super(x, y);

		box = new FlxSprite();
		boxGraphic();
		add(box);

		text = new FlxText(box.width + 4, 0, textWid, label);
		text.y += box.height/2 - text.height/2;
		add(text);

		this.onClick = callback;
	}

	public function boxGraphic()
	{
		box.loadGraphic(Paths.image('checkbox', 'psych-ui').bitmap, true, 16, 16);
		box.animation.add('false', [0]);
		box.animation.add('true', [1]);
		box.animation.play('false');
	}

	public var broadcastCheckBoxEvent:Bool = true;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var screenPos:FlxPoint = getScreenPosition(null, camera);
		var mousePos:FlxPoint = #if (flixel < "5.9.0") FlxG.mouse.getPositionInCameraView(camera) #else FlxG.mouse.getViewPosition(camera) #end;
		var isOver = (mousePos.x >= screenPos.x && mousePos.x < screenPos.x + width) &&
					(mousePos.y >= screenPos.y && mousePos.y < screenPos.y + height);

		if (isOver && !_isHovered)
		{
			if (flixel.FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.BUTTON;
			_isHovered = true;
		}
		else if (!isOver && _isHovered)
		{
			if (flixel.FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.AUTO;
			_isHovered = false;
		}

		if(FlxG.mouse.justPressed && isOver)
		{
			checked = !checked;
			if(onClick != null) onClick();
			if(broadcastCheckBoxEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
		}
	}

	override public function destroy()
	{
		if (_isHovered && flixel.FlxG.mouse.useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		super.destroy();
	}

	function set_checked(v:Any)
	{
		var v:Bool = (v != null && v != false);
		box.animation.play(Std.string(v));
		return (checked = v);
	}

	function get_label():String {
		return text.text;
	}
	function set_label(v:String):String {
		return (text.text = v);
	}
}