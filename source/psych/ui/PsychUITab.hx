package psych.ui;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class PsychUITab extends FlxSprite
{
	public var name(default, set):String;
	public var text:FlxText;
	public var menu:PsychUIGroup = new PsychUIGroup();
	
	private var _isHovered:Bool = false;

	public function new(name:String)
	{
		super();
		makeGraphic(1, 1, FlxColor.WHITE);
		color = FlxColor.BLACK;
		alpha = 0.6;

		@:bypassAccessor this.name = name;
		text = new FlxText(0, 0, 100, name);
		text.alignment = CENTER;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		var isOver = FlxG.mouse.overlaps(this, camera);
		
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
	}

	override function draw()
	{
		super.draw();

		if(visible && text != null && text.exists && text.visible)
		{
			text.x = x;
			text.y = y + height/2 - text.height/2;
			text.draw();
		}
	}

	override function destroy()
	{
		if (_isHovered && flixel.FlxG.mouse.useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		text = FlxDestroyUtil.destroy(text);
		menu = FlxDestroyUtil.destroy(menu);
		super.destroy();
	}
	
	inline public function updateMenu(parent:PsychUIBox, elapsed:Float)
	{
		if(menu != null && menu.exists && menu.active)
		{
			menu.scrollFactor.set(parent.scrollFactor.x, parent.scrollFactor.y);
			menu.update(elapsed);
		}
	}

	inline public function drawMenu(parent:PsychUIBox)
	{
		if(menu != null && menu.exists && menu.visible)
		{
			menu.x = parent.x;
			menu.y = parent.y + parent.tabHeight;
			menu.draw();
		}
	}

	inline public function resize(width:Int, height:Int)
	{
		setGraphicSize(width, height);
		updateHitbox();
		text.fieldWidth = width;
	}

	function set_name(v:String)
	{
		text.text = v;
		return (name = v);
	}

	override function set_cameras(v:Array<FlxCamera>)
	{
		text.cameras = v;
		menu.cameras = v;
		return super.set_cameras(v);
	}

	override function set_camera(v:FlxCamera)
	{
		text.camera = v;
		menu.camera = v;
		return super.set_camera(v);
	}
}