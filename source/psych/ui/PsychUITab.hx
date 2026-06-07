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
	public var scrollX:Float = 0;
	public var scrollable:Bool = false;

	public var scrollBarBG:FlxSprite;
	public var scrollBarHandle:FlxSprite;
	public var scrollBarWidth:Int = 10;

	public var hScrollBarBG:FlxSprite;
	public var hScrollBarHandle:FlxSprite;
	public var hScrollBarHeight:Int = 10;

	private var _isHovered:Bool = false;
	private var _isDraggingScroll:Bool = false;
	private var _dragOffsetY:Float = 0;
	
	private var _isDraggingHScroll:Bool = false;
	private var _dragOffsetX:Float = 0;

	public function new(name:String)
	{
		super();
		makeGraphic(1, 1, FlxColor.WHITE);
		color = FlxColor.BLACK;
		alpha = 0.6;
		@:bypassAccessor this.name = name;

		text = new FlxText(0, 0, 100, name);
		text.alignment = CENTER;
		text.antialiasing = false;

		scrollBarBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		scrollBarBG.alpha = 0.5;
		scrollBarHandle = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);

		hScrollBarBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		hScrollBarBG.alpha = 0.5;
		hScrollBarHandle = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var isOver = FlxG.mouse.overlaps(this, camera);
		
		if (isOver && !_isHovered)
		{
			if (FlxG.mouse.useSystemCursor) Mouse.cursor = MouseCursor.BUTTON;
			_isHovered = true;
		}
		else if (!isOver && _isHovered)
		{
			if (FlxG.mouse.useSystemCursor) Mouse.cursor = MouseCursor.AUTO;
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
		if (_isHovered && FlxG.mouse.useSystemCursor) Mouse.cursor = MouseCursor.AUTO;
		
		text = FlxDestroyUtil.destroy(text);
		menu = FlxDestroyUtil.destroy(menu);
		scrollBarBG = FlxDestroyUtil.destroy(scrollBarBG);
		scrollBarHandle = FlxDestroyUtil.destroy(scrollBarHandle);
		hScrollBarBG = FlxDestroyUtil.destroy(hScrollBarBG);
		hScrollBarHandle = FlxDestroyUtil.destroy(hScrollBarHandle);
		
		super.destroy();
	}
	
	inline public function updateMenu(parent:PsychUIBox, elapsed:Float)
	{
		if(menu != null && menu.exists && menu.active)
		{
			var visibleHeight:Float = parent.bg.height - parent.tabHeight;
			var visibleWidth:Float = parent.bg.width;
			var maxContentHeight:Float = 0.01;
			var maxContentWidth:Float = 0.01;
			
			for (member in menu.members) {
				if (member != null && Std.isOfType(member, FlxSprite)) {
					var spr:FlxSprite = cast member;
					
					var relY = (spr.y - menu.y) + spr.height;
					if (relY > maxContentHeight) maxContentHeight = relY;

					var relX = (spr.x - menu.x) + spr.width;
					if (relX > maxContentWidth) maxContentWidth = relX;
				}
			}

			var canScrollY = scrollable && maxContentHeight > visibleHeight;
			var minScrollY = canScrollY ? visibleHeight - maxContentHeight : 0; 

			var canScrollX = scrollable && maxContentWidth > visibleWidth;
			var minScrollX = canScrollX ? visibleWidth - maxContentWidth : 0;

			var boxTop = parent.y + parent.tabHeight;

			if (canScrollY) {
				scrollBarBG.setGraphicSize(scrollBarWidth, Std.int(visibleHeight));
				scrollBarBG.updateHitbox();
				scrollBarBG.x = parent.x + parent.bg.width - scrollBarWidth;
				scrollBarBG.y = boxTop;
				
				final handleHeight = Math.max(20, (visibleHeight / maxContentHeight) * visibleHeight);
				scrollBarHandle.setGraphicSize(scrollBarWidth, Std.int(handleHeight));
				scrollBarHandle.updateHitbox();
				scrollBarHandle.x = scrollBarBG.x;
				
				final handleMinY = scrollBarBG.y;
				final handleMaxY = scrollBarBG.y + scrollBarBG.height - scrollBarHandle.height;

				var currentScrollRatio = (minScrollY < 0) ? (scrollY / minScrollY) : 0;
				if (currentScrollRatio > 1) currentScrollRatio = 1;
				scrollBarHandle.y = handleMinY + currentScrollRatio * (handleMaxY - handleMinY);
			}

			if (canScrollX) {
				final hBarWidth = parent.bg.width - (canScrollY ? scrollBarWidth : 0);
				hScrollBarBG.setGraphicSize(Std.int(hBarWidth), hScrollBarHeight);
				hScrollBarBG.updateHitbox();
				hScrollBarBG.x = parent.x;
				hScrollBarBG.y = parent.y + parent.bg.height - hScrollBarHeight;
				
				final handleWidth = Math.max(20, (visibleWidth / maxContentWidth) * hBarWidth);
				hScrollBarHandle.setGraphicSize(Std.int(handleWidth), hScrollBarHeight);
				hScrollBarHandle.updateHitbox();
				hScrollBarHandle.y = hScrollBarBG.y;
				
				final handleMinX = hScrollBarBG.x;
				final handleMaxX = hScrollBarBG.x + hScrollBarBG.width - hScrollBarHandle.width;

				var currentHScrollRatio = (minScrollX < 0) ? (scrollX / minScrollX) : 0;
				if (currentHScrollRatio > 1) currentHScrollRatio = 1;
				hScrollBarHandle.x = handleMinX + currentHScrollRatio * (handleMaxX - handleMinX);
			}

			final mousePos = FlxG.mouse.getViewPosition(camera);

			if (FlxG.mouse.justReleased) {
				_isDraggingScroll = false;
				_isDraggingHScroll = false;
			}
			
			if (FlxG.mouse.justPressed) {
				if (canScrollY && FlxG.mouse.overlaps(scrollBarHandle, camera)) {
					_isDraggingScroll = true;
					_dragOffsetY = mousePos.y - scrollBarHandle.y;
				} else if (canScrollY && FlxG.mouse.overlaps(scrollBarBG, camera)) {
					_isDraggingScroll = true;
					_dragOffsetY = scrollBarHandle.height / 2;
				} else if (canScrollX && FlxG.mouse.overlaps(hScrollBarHandle, camera)) {
					_isDraggingHScroll = true;
					_dragOffsetX = mousePos.x - hScrollBarHandle.x;
				} else if (canScrollX && FlxG.mouse.overlaps(hScrollBarBG, camera)) {
					_isDraggingHScroll = true;
					_dragOffsetX = hScrollBarHandle.width / 2;
				}
			}

			if (_isDraggingScroll && canScrollY) {
				final handleMinY = scrollBarBG.y;
				final handleMaxY = scrollBarBG.y + scrollBarBG.height - scrollBarHandle.height;

				var targetHandleY = mousePos.y - _dragOffsetY;
				targetHandleY = Math.max(handleMinY, Math.min(handleMaxY, targetHandleY));
				
				final dragRatio = (handleMaxY > handleMinY) ? (targetHandleY - handleMinY) / (handleMaxY - handleMinY) : 0;
				scrollY = dragRatio * minScrollY;
			} else if (_isDraggingHScroll && canScrollX) {
				final handleMinX = hScrollBarBG.x;
				final handleMaxX = hScrollBarBG.x + hScrollBarBG.width - hScrollBarHandle.width;

				var targetHandleX = mousePos.x - _dragOffsetX;
				targetHandleX = Math.max(handleMinX, Math.min(handleMaxX, targetHandleX));

				final dragRatio = (handleMaxX > handleMinX) ? (targetHandleX - handleMinX) / (handleMaxX - handleMinX) : 0;
				scrollX = dragRatio * minScrollX;
			} else {
				if (FlxG.mouse.overlaps(parent.bg, camera)) {
					if (FlxG.mouse.deltaWheel.y != 0) {
						if (FlxG.keys.pressed.SHIFT)
							scrollX += FlxG.mouse.deltaWheel.y * 30;
						else
							scrollY += FlxG.mouse.deltaWheel.y * 30;
					}

					if (FlxG.mouse.deltaWheel.x != 0)
						scrollX -= FlxG.mouse.deltaWheel.x * 30; 
				}
			}

			if (!canScrollY) scrollY = 0;
			if (scrollY < minScrollY) scrollY = minScrollY;
			if (scrollY > 0) scrollY = 0;

			if (!canScrollX) scrollX = 0;
			if (scrollX < minScrollX) scrollX = minScrollX;
			if (scrollX > 0) scrollX = 0;

			menu.scrollFactor.set(parent.scrollFactor.x, parent.scrollFactor.y);
			menu.update(elapsed);
		}
	}

	public function drawMenu(parent:PsychUIBox)
	{
		if(menu != null && menu.exists && menu.visible)
		{
			menu.x = parent.x + scrollX;
			menu.y = parent.y + parent.tabHeight + scrollY;
			
			var boxTop = parent.y + parent.tabHeight;
			var boxBottom = parent.y + parent.bg.height;
			var boxLeft = parent.x;
			var boxRight = parent.x + parent.bg.width;
			
			var maxContentHeight:Float = 0.01;
			var maxContentWidth:Float = 0.01;

			for (member in menu.members) {
				if (member != null && Std.isOfType(member, FlxSprite)) {
					final spr:FlxSprite = cast member;
					
					spr.visible = spr.y + spr.height >= boxTop && spr.y <= boxBottom && spr.x + spr.width >= boxLeft && spr.x <= boxRight;
					spr.active = spr.visible;

					if (Std.isOfType(spr, FlxText)) {
						if (spr.visible) {
							var cY:Float = 0;
							var cH:Float = spr.frameHeight;
							var cX:Float = 0;
							var cW:Float = spr.frameWidth;
							
							if (spr.y < boxTop) {
								cY = boxTop - spr.y;
								cH -= cY;
							}

							if (spr.y + spr.frameHeight > boxBottom) {
								cH -= (spr.y + spr.frameHeight) - boxBottom;
							}

							if (spr.x < boxLeft) {
								cX = boxLeft - spr.x;
								cW -= cX;
							}
							if (spr.x + spr.frameWidth > boxRight) {
								cW -= (spr.x + spr.frameWidth) - boxRight;
							}
							
							if (cH > 0 && cW > 0) {
								spr.clipRect ??= flixel.math.FlxRect.get();
								spr.clipRect.set(cX, cY, cW, cH);
								spr.clipRect = spr.clipRect;
							} else {
								spr.visible = false;
							}
						}
						
						if (!spr.visible && spr.clipRect != null) {
							spr.clipRect.put();
							spr.clipRect = null;
						}
					}

					final relY = (spr.y - menu.y) + spr.height;
					if (relY > maxContentHeight) maxContentHeight = relY;
					
					final relX = (spr.x - menu.x) + spr.width;
					if (relX > maxContentWidth) maxContentWidth = relX;
				}
			}

			menu.draw();
			
			final visibleHeight = parent.bg.height - parent.tabHeight;
			final visibleWidth = parent.bg.width;
			
			if (scrollable && maxContentHeight > visibleHeight) {
				scrollBarBG.draw();
				scrollBarHandle.draw();
			}
			
			if (scrollable && maxContentWidth > visibleWidth) {
				hScrollBarBG.draw();
				hScrollBarHandle.draw();
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
		
		if (hScrollBarBG != null) hScrollBarBG.cameras = v;
		if (hScrollBarHandle != null) hScrollBarHandle.cameras = v;
		
		return super.set_cameras(v);
	}

	override function set_camera(v:FlxCamera)
	{
		if (text != null) text.camera = v;
		if (menu != null) menu.camera = v;
		if (scrollBarBG != null) scrollBarBG.camera = v;
		if (scrollBarHandle != null) scrollBarHandle.camera = v;
		
		if (hScrollBarBG != null) hScrollBarBG.camera = v;
		if (hScrollBarHandle != null) hScrollBarHandle.camera = v;
		
		return super.set_camera(v);
	}
}