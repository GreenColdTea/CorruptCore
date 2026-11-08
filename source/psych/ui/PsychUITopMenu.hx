package psych.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import psych.ui.PsychUIBox.UIStyleData;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class PsychUITopMenu extends PsychUIGroup
{
	public var bg:FlxSprite;
	public var menuItems:Array<PsychUITopMenuCategory> = [];

	public function new(height:Int = 25)
	{
		super(0, 0);

		bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, height, FlxColor.BLACK);
		bg.alpha = 0.85;
		bg.scrollFactor.set();
		add(bg);
	}

	public function addCategory(name:String, options:Array<String>, callbacks:Array<String->Void>, ?shortcuts:Array<String>, ?textColors:Array<FlxColor>):Void
	{
		var startX:Float = 10;
		if (menuItems.length > 0) 
		{
			final lastItem = menuItems[menuItems.length - 1];
			startX = lastItem.x + lastItem.bg.width;
		}

		final category = new PsychUITopMenuCategory(startX, 0, name, options, callbacks, shortcuts, textColors, Std.int(bg.height));
		menuItems.push(category);
		add(category);
	}

	override function set_cameras(v:Array<flixel.FlxCamera>)
	{
		bg.cameras = v;
		for (item in menuItems) item.cameras = v;
		return super.set_cameras(v);
	}
}

class PsychUITopMenuCategory extends PsychUIGroup
{
	public var bg:FlxSprite;
	public var text:FlxText;
	
	public var dropDownItems:Array<PsychUITopMenuOption> = [];

	public var isExpanded:Bool = false;

	private var _isHovered:Bool = false;
	
	public var hoverStyle:UIStyleData = {
		bgColor: FlxColor.GRAY,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: FlxColor.TRANSPARENT,
		textColor: FlxColor.WHITE,
		bgAlpha: 0
	};
	public var expandedStyle:UIStyleData = {
		bgColor: 0xFF333333,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};

	public function new(x:Float, y:Float, label:String, options:Array<String>, callbacks:Array<String->Void>, shortcuts:Array<String>, textColors:Array<FlxColor>, height:Int)
	{
		super(x, y);

		text = new FlxText(10, 0, 0, label, 16);
		text.setFormat(null, 13, FlxColor.WHITE, LEFT);
		text.y = (height / 2) - (text.height / 2);
		
		bg = new FlxSprite(0, 0).makeGraphic(Std.int(text.width + 20), height, FlxColor.WHITE);
		bg.alpha = normalStyle.bgAlpha;
		bg.color = normalStyle.bgColor;
		
		add(bg);
		add(text);

		var dropY = height;
		var maxDropWidth:Float = bg.width;

		for (i in 0...options.length) {
			final shortcutTxt = (shortcuts?.length > i && shortcuts[i] != null) ? "  " + shortcuts[i] : "";
			final tempText = new FlxText(0, 0, 0, options[i] + shortcutTxt, 16);
			tempText.setFormat(null, 13, FlxColor.WHITE, LEFT);
			
			if (tempText.width + 30 > maxDropWidth)
				maxDropWidth = tempText.width + 30;

			tempText.destroy();
		}

		final optionHeight:Int = 25;
		for (i in 0...options.length) 
		{
			final shortcut = (shortcuts != null && i < shortcuts.length) ? shortcuts[i] : "";
			final specificColor:FlxColor = (textColors != null && i < textColors.length) ? textColors[i] : FlxColor.WHITE;
			
			final opt = new PsychUITopMenuOption(0, dropY, maxDropWidth, optionHeight, options[i], shortcut, specificColor, callbacks[i]);
			dropY += optionHeight;
			dropDownItems.push(opt);
			add(opt);
		}

		setExpanded(false);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		var isOverMain = FlxG.mouse.overlaps(bg, camera);
		var isOverAnyDrop = false;
		
		if (isExpanded) {
			for (drop in dropDownItems) 
			{
				if (FlxG.mouse.overlaps(drop.bg, camera)) 
				{
					isOverAnyDrop = true;
					break;
				}
			}
		}

		if ((isOverMain || isOverAnyDrop) && !_isHovered)
		{
			if (FlxG.mouse.useSystemCursor) Mouse.cursor = MouseCursor.BUTTON;
			_isHovered = true;
		}
		else if (!isOverMain && !isOverAnyDrop && _isHovered)
		{
			if (FlxG.mouse.useSystemCursor) Mouse.cursor = MouseCursor.AUTO;
			_isHovered = false;
		}

		if (isOverMain) {
			if (!isExpanded) 
			{
				bg.alpha = hoverStyle.bgAlpha;
				bg.color = hoverStyle.bgColor;
			}

			if (FlxG.mouse.justPressed)
				setExpanded(!isExpanded);
		} else {
			if (!isExpanded) 
			{
				bg.alpha = normalStyle.bgAlpha;
				bg.color = normalStyle.bgColor;
			}
		}
		
		if (FlxG.mouse.justPressed && !isOverMain && !isOverAnyDrop && isExpanded)
			setExpanded(false);
	}

	public function setExpanded(v:Bool)
	{
		isExpanded = v;
		if (isExpanded) {
			bg.alpha = expandedStyle.bgAlpha;
			bg.color = expandedStyle.bgColor;
		} else {
			bg.alpha = normalStyle.bgAlpha;
			bg.color = normalStyle.bgColor;
		}

		for (drop in dropDownItems) {
			drop.visible = isExpanded;
			drop.active = isExpanded;
		}
	}
}

class PsychUITopMenuOption extends PsychUIGroup
{
	public var bg:FlxSprite;
	public var text:FlxText;
	public var shortcutText:FlxText;
	public var line:FlxSprite;
	public var callback:String->Void;

	private var labelName:String;
	private var _isHovered:Bool = false;
	
	private var baseTextColor:FlxColor;

	public var hoverStyle:UIStyleData = {
		bgColor: 0xFF0066FF,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: 0xFF222222,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};

	public function new(x:Float, y:Float, w:Float, h:Float, label:String, shortcut:String, customTextColor:FlxColor, cb:String->Void)
	{
		super(x, y);
		this.labelName = label;
		this.callback = cb;
		this.baseTextColor = customTextColor;

		bg = new FlxSprite(0, 0).makeGraphic(Std.int(w), Std.int(h), normalStyle.bgColor);
		add(bg);

		text = new FlxText(10, 0, w - 20, label, 16);
		text.setFormat(null, 13, baseTextColor, LEFT);
		text.y = (h / 2) - (text.height / 2);
		add(text);

		if (shortcut != null && shortcut != "") 
		{
			shortcutText = new FlxText(10, 0, w - 20, shortcut, 16);
			shortcutText.setFormat(null, 11, FlxColor.GRAY, RIGHT);
			shortcutText.y = (h / 2) - (shortcutText.height / 2);
			add(shortcutText);
		}

		line = new FlxSprite(0, h - 1).makeGraphic(Std.int(w), 1, 0xFF444444);
		add(line);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!visible) return;

		var isOver = FlxG.mouse.overlaps(bg, camera);

		if (isOver) {
			bg.color = hoverStyle.bgColor;
			text.color = FlxColor.WHITE; 
			if (shortcutText != null) shortcutText.color = FlxColor.WHITE;
			
			if (FlxG.mouse.justPressed && callback != null)
				callback(labelName);
		} else {
			bg.color = normalStyle.bgColor;
			text.color = baseTextColor; 
			if (shortcutText != null) shortcutText.color = FlxColor.GRAY;
		}
	}
}