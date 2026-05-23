package psych.ui;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import flixel.FlxG;
import flixel.FlxCamera;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class PsychUITab extends FlxSprite
{
	public var name(default, set):String;
	public var text:FlxText;
	public var menu:PsychUIGroup = new PsychUIGroup();

	public var scrollY:Float = 0;
	public var scrollable:Bool = false;

	public var scrollBarBG:FlxSprite;
	public var scrollBarHandle:FlxSprite;
	public var scrollBarWidth:Int = 10;

	private var _isHovered:Bool = false;
	private var _isDraggingScroll:Bool = false;
	private var _dragOffsetY:Float = 0;

	public function new(name:String)
	{
		super();
		makeGraphic(1, 1, FlxColor.WHITE);
		color = FlxColor.BLACK;
		alpha = 0.6;
		@:bypassAccessor this.name = name;
		text = new FlxText(0, 0, 100, name);
		text.alignment = CENTER;

		scrollBarBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		scrollBarBG.alpha = 0.5;
		scrollBarHandle = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var isOver = FlxG.mouse.overlaps(this, camera);
		
		if (isOver && !_isHovered)
		{
			if (FlxG.mouse.useSystemCursor) 
				Mouse.cursor = MouseCursor.BUTTON;
			_isHovered = true;
		}
		else if (!isOver && _isHovered)
		{
			if (FlxG.mouse.useSystemCursor) 
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
		if (_isHovered && FlxG.mouse.useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		text = FlxDestroyUtil.destroy(text);
		menu = FlxDestroyUtil.destroy(menu);
		scrollBarBG = FlxDestroyUtil.destroy(scrollBarBG);
		scrollBarHandle = FlxDestroyUtil.destroy(scrollBarHandle);
		
		super.destroy();
	}
	
	inline public function updateMenu(parent:PsychUIBox, elapsed:Float)
	{
		if(menu != null && menu.exists && menu.active)
		{
			var visibleHeight:Float = parent.bg.height - parent.tabHeight;
			var maxContentHeight:Float = 0.01;
			
			for (member in menu.members) {
				if (member != null && Std.isOfType(member, FlxSprite)) {
					var spr:FlxSprite = cast member;
					var relY = (spr.y - menu.y) + spr.height;
					if (relY > maxContentHeight) maxContentHeight = relY;
				}
			}

			var canScroll = scrollable && maxContentHeight > visibleHeight;
			var minScrollY = canScroll ? visibleHeight - maxContentHeight : 0; 

			if (canScroll) {
				var boxTop = parent.y + parent.tabHeight;
				
				scrollBarBG.setGraphicSize(scrollBarWidth, Std.int(visibleHeight));
				scrollBarBG.updateHitbox();
				scrollBarBG.x = parent.x + parent.bg.width - scrollBarWidth;
				scrollBarBG.y = boxTop;
				
				var handleHeight = Math.max(20, (visibleHeight / maxContentHeight) * visibleHeight);
				scrollBarHandle.setGraphicSize(scrollBarWidth, Std.int(handleHeight));
				scrollBarHandle.updateHitbox();
				scrollBarHandle.x = scrollBarBG.x;
				
				var handleMinY = scrollBarBG.y;
				var handleMaxY = scrollBarBG.y + scrollBarBG.height - scrollBarHandle.height;

				var currentScrollRatio = (minScrollY < 0) ? (scrollY / minScrollY) : 0;
				if (currentScrollRatio > 1) currentScrollRatio = 1;
				scrollBarHandle.y = handleMinY + currentScrollRatio * (handleMaxY - handleMinY);

				var mousePos = FlxG.mouse.getScreenPosition(camera);

				if (FlxG.mouse.justReleased) {
					_isDraggingScroll = false;
				}
				
				if (FlxG.mouse.justPressed) {
					if (FlxG.mouse.overlaps(scrollBarHandle, camera)) {
						_isDraggingScroll = true;
						_dragOffsetY = mousePos.y - scrollBarHandle.y;
					} else if (FlxG.mouse.overlaps(scrollBarBG, camera)) {
						_isDraggingScroll = true;
						_dragOffsetY = scrollBarHandle.height / 2;
					}
				}

				if (_isDraggingScroll) {
					var targetHandleY = mousePos.y - _dragOffsetY;
					targetHandleY = Math.max(handleMinY, Math.min(handleMaxY, targetHandleY));
					var dragRatio = (handleMaxY > handleMinY) ? (targetHandleY - handleMinY) / (handleMaxY - handleMinY) : 0;
					
					scrollY = dragRatio * minScrollY;
				} else {
					if (FlxG.mouse.overlaps(parent.bg, camera) && FlxG.mouse.deltaWheel.y != 0) {
						scrollY += FlxG.mouse.deltaWheel.y * 30;
					}
				}
			} else {
				scrollY = 0;
			}

			if (scrollY < minScrollY) scrollY = minScrollY;
			if (scrollY > 0) scrollY = 0;

			menu.scrollFactor.set(parent.scrollFactor.x, parent.scrollFactor.y);
			menu.update(elapsed);
		}
	}

	public function drawMenu(parent:PsychUIBox)
	{
		if(menu != null && menu.exists && menu.visible)
		{
			menu.x = parent.x;
			menu.y = parent.y + parent.tabHeight + scrollY;
			
			var boxTop = parent.y + parent.tabHeight;
			var boxBottom = parent.y + parent.bg.height;
			var maxContentHeight:Float = 0.01;

			for (member in menu.members) {
				if (member != null && Std.isOfType(member, FlxSprite)) {
					final spr:FlxSprite = cast member;
					spr.visible = spr.y + spr.height >= boxTop && spr.y <= boxBottom;
					spr.active = spr.visible;
					
					var relY = (spr.y - menu.y) + spr.height;
					if (relY > maxContentHeight) maxContentHeight = relY;
				}
			}

			menu.draw();
			
			var visibleHeight = parent.bg.height - parent.tabHeight;
			if (scrollable && maxContentHeight > visibleHeight) {
				scrollBarBG.draw();
				
				var handleMinY = scrollBarBG.y;
				var handleMaxY = scrollBarBG.y + scrollBarBG.height - scrollBarHandle.height;
				var minScrollY = visibleHeight - maxContentHeight;
				var currentScrollRatio = (minScrollY < 0) ? (scrollY / minScrollY) : 0;
				if (currentScrollRatio > 1) currentScrollRatio = 1;
				
				scrollBarHandle.y = handleMinY + currentScrollRatio * (handleMaxY - handleMinY);
				scrollBarHandle.draw();
			}
		}
	}

	inline public function resize(width:Int, height:Int)
	{
		setGraphicSize(width, height);
		updateHitbox();
		if (text != null) text.fieldWidth = width;
	}

	function set_name(v:String)
	{
		if (text != null) text.text = v;
		return (name = v);
	}

	override function set_cameras(v:Array<FlxCamera>)
	{
		if (text != null) text.cameras = v;
		if (menu != null) menu.cameras = v;
		if (scrollBarBG != null) scrollBarBG.cameras = v;
		if (scrollBarHandle != null) scrollBarHandle.cameras = v;
		return super.set_cameras(v);
	}

	override function set_camera(v:FlxCamera)
	{
		if (text != null) text.camera = v;
		if (menu != null) menu.camera = v;
		if (scrollBarBG != null) scrollBarBG.camera = v;
		if (scrollBarHandle != null) scrollBarHandle.camera = v;
		return super.set_camera(v);
	}
}