package psych.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;

import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.GradientType;
import openfl.display.Shape;
import openfl.geom.Matrix;

class PsychUIColorPicker extends PsychUIGroup
{
	@:unreflective public static final CHANGE_EVENT = "colorpicker_change";

	private var _selectedColor:FlxColor;
	public var selectedColor(get, set):FlxColor;

	public var onColorChange:FlxColor->Void;
	public var broadcastPickerEvent:Bool = true;

	final boxWidth:Int = 280;
	final boxHeight:Int = 170;
	final hueHeight:Int = 18;

	var svBox:FlxSprite;
	var svCursor:FlxSprite;

	var hueBar:FlxSprite;
	var hueCursor:FlxSprite;

	var previewBox:FlxSprite;
	var hexText:PsychUIInputText;

	var rSliderBg:FlxSprite;
	var gSliderBg:FlxSprite;
	var bSliderBg:FlxSprite;
	var rHandle:FlxSprite;
	var gHandle:FlxSprite;
	var bHandle:FlxSprite;
	var rValText:FlxText;
	var gValText:FlxText;
	var bValText:FlxText;

	var curHue:Float = 195;
	var curSat:Float = 0.8;
	var curVal:Float = 0.8;

	var isDraggingSV:Bool = false;
	var isDraggingHue:Bool = false;
	var activeDraggingSlider:Int = -1; // 0 = R, 1 = G, 2 = B

	var _updating:Bool = false;
	var _uiCreated:Bool = false;

	public function new(x:Float = 0, y:Float = 0, defaultColor:FlxColor = 0xFF31B0D1, ?onColorChange:FlxColor->Void, showAlpha:Bool = false, customLabel:String = "")
	{
		super(x, y);

		this.onColorChange = onColorChange;
		_selectedColor = defaultColor;

		curHue = defaultColor.hue;
		curSat = defaultColor.saturation;
		curVal = defaultColor.brightness;

		createUI();
		_uiCreated = true;

		setColor(defaultColor);
	}

	function createUI():Void
	{
		final startX = 10;
		final startY = 20;

		svBox = new FlxSprite(startX, startY);
		svBox.makeGraphic(boxWidth, boxHeight, FlxColor.WHITE, true);
		add(svBox);

		svCursor = createFilledCircleCursor(10);
		add(svCursor);

		final hueY = startY + boxHeight + 8;
		hueBar = createHueGradient(startX, hueY, boxWidth, hueHeight);
		add(hueBar);

		hueCursor = new FlxSprite(startX, hueY - 2).makeGraphic(6, hueHeight + 4, FlxColor.WHITE);
		add(hueCursor);

		final bottomY = hueY + hueHeight + 10;
		final sliderTrackW = 100;
		final sliderX = startX + 25;

		final rLabel = new FlxText(startX, bottomY - 2, 0, "R:", 12);
		rLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(rLabel);

		final gLabel = new FlxText(startX, bottomY + 18, 0, "G:", 12);
		gLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(gLabel);

		final bLabel = new FlxText(startX, bottomY + 38, 0, "B:", 12);
		bLabel.setFormat(null, 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(bLabel);

		rSliderBg = new FlxSprite(sliderX, bottomY + 4).makeGraphic(sliderTrackW, 6, 0xFF333333);
		gSliderBg = new FlxSprite(sliderX, bottomY + 24).makeGraphic(sliderTrackW, 6, 0xFF333333);
		bSliderBg = new FlxSprite(sliderX, bottomY + 44).makeGraphic(sliderTrackW, 6, 0xFF333333);
		add(rSliderBg);
		add(gSliderBg);
		add(bSliderBg);

		rHandle = new FlxSprite(sliderX, bottomY).makeGraphic(8, 14, 0xFFAAAAAA);
		gHandle = new FlxSprite(sliderX, bottomY + 20).makeGraphic(8, 14, 0xFFAAAAAA);
		bHandle = new FlxSprite(sliderX, bottomY + 40).makeGraphic(8, 14, 0xFFAAAAAA);
		add(rHandle);
		add(gHandle);
		add(bHandle);

		rValText = new FlxText(sliderX + sliderTrackW + 8, bottomY - 1, 35, "0", 12);
		gValText = new FlxText(sliderX + sliderTrackW + 8, bottomY + 19, 35, "0", 12);
		bValText = new FlxText(sliderX + sliderTrackW + 8, bottomY + 39, 35, "0", 12);
		for (txt in [rValText, gValText, bValText])
		{
			txt.setFormat(null, 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(txt);
		}

		final previewW = 60;
		final previewH = 38;
		final previewX = startX + boxWidth - previewW;
		final previewY = bottomY - 2;

		previewBox = new FlxSprite(previewX, previewY).makeGraphic(previewW, previewH, _selectedColor);
		add(previewBox);

		hexText = new PsychUIInputText(previewX - 6, previewY + previewH + 4, previewW + 12, _selectedColor.toHexString(false, false), 12);
		hexText.filterMode = ONLY_HEXADECIMAL;
		hexText.forceCase = UPPER_CASE;
		hexText.maxLength = 6;
		hexText.onChange = (old, val) -> {
			if (val.length == 6 && !_updating)
			{
				final parsed = FlxColor.fromString("#" + val);
				if (parsed != null) setColor(parsed);
			}
		};
		add(hexText);

		renderSVBox();
	}

	function createFilledCircleCursor(size:Int):FlxSprite
	{
		final circle = new FlxSprite().makeGraphic(size, size, FlxColor.TRANSPARENT, true);
		final shape = new Shape();
		
		shape.graphics.lineStyle(1.5, 0xFF000000);
		shape.graphics.beginFill(0xFFFFFFFF);
		shape.graphics.drawCircle(size / 2, size / 2, (size / 2) - 1.5);
		shape.graphics.endFill();

		final bmp = new BitmapData(size, size, true, 0x00000000);
		bmp.draw(shape);
		circle.pixels = bmp;
		circle.offset.set(size / 2, size / 2);
		return circle;
	}

	function createHueGradient(x:Float, y:Float, w:Int, h:Int):FlxSprite
	{
		final bar = new FlxSprite(x, y);
		final shape = new Shape();
		final matrix = new Matrix();
		matrix.createGradientBox(w, h, 0, 0, 0);

		final colors:Array<UInt> = [0xFFFF0000, 0xFFFFFF00, 0xFF00FF00, 0xFF00FFFF, 0xFF0000FF, 0xFFFF00FF, 0xFFFF0000];
		final alphas = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
		final ratios = [0, 42, 85, 127, 170, 213, 255];

		shape.graphics.beginGradientFill(GradientType.LINEAR, colors, alphas, ratios, matrix);
		shape.graphics.drawRect(0, 0, w, h);
		shape.graphics.endFill();

		final bmp = new BitmapData(w, h, false);
		bmp.draw(shape);
		bar.pixels = bmp;
		return bar;
	}

	function renderSVBox():Void
	{
		if (svBox == null) return;

		final pureColor = FlxColor.fromHSB(curHue, 1.0, 1.0);
		final w = boxWidth;
		final h = boxHeight;

		final bmp = new BitmapData(w, h, false);

		final shapeH = new Shape();
		final matrixH = new Matrix();
		matrixH.createGradientBox(w, h, 0, 0, 0);
		shapeH.graphics.beginGradientFill(GradientType.LINEAR, [0xFFFFFFFF, pureColor], [1.0, 1.0], [0, 255], matrixH);
		shapeH.graphics.drawRect(0, 0, w, h);
		shapeH.graphics.endFill();
		bmp.draw(shapeH);

		final shapeV = new Shape();
		final matrixV = new Matrix();
		matrixV.createGradientBox(w, h, Math.PI / 2, 0, 0);
		shapeV.graphics.beginGradientFill(GradientType.LINEAR, [0x00000000, 0xFF000000], [0.0, 1.0], [0, 255], matrixV);
		shapeV.graphics.drawRect(0, 0, w, h);
		shapeV.graphics.endFill();
		bmp.draw(shapeV, null, null, BlendMode.NORMAL);

		svBox.pixels = bmp;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		final cam = this.camera ?? FlxG.camera;
		final mousePos = FlxG.mouse.getWorldPosition(cam);
		final mx = mousePos.x;
		final my = mousePos.y;
		mousePos.put();

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(svBox, cam))
			{
				isDraggingSV = true;
				updateSVFromPoint(mx, my);
			}
			else if (FlxG.mouse.overlaps(hueBar, cam))
			{
				isDraggingHue = true;
				updateHueFromPoint(mx);
			}
			else if (FlxG.mouse.overlaps(rSliderBg, cam) || FlxG.mouse.overlaps(rHandle, cam))
			{
				activeDraggingSlider = 0;
				updateRGBSliderFromPoint(0, mx);
			}
			else if (FlxG.mouse.overlaps(gSliderBg, cam) || FlxG.mouse.overlaps(gHandle, cam))
			{
				activeDraggingSlider = 1;
				updateRGBSliderFromPoint(1, mx);
			}
			else if (FlxG.mouse.overlaps(bSliderBg, cam) || FlxG.mouse.overlaps(bHandle, cam))
			{
				activeDraggingSlider = 2;
				updateRGBSliderFromPoint(2, mx);
			}
		}

		if (FlxG.mouse.justReleased)
		{
			isDraggingSV = false;
			isDraggingHue = false;
			activeDraggingSlider = -1;
		}

		if (FlxG.mouse.pressed)
		{
			if (isDraggingSV) updateSVFromPoint(mx, my);
			if (isDraggingHue) updateHueFromPoint(mx);
			if (activeDraggingSlider >= 0) updateRGBSliderFromPoint(activeDraggingSlider, mx);
		}
	}

	function updateSVFromPoint(mx:Float, my:Float):Void
	{
		var localX = FlxMath.bound(mx - svBox.x, 0, boxWidth);
		var localY = FlxMath.bound(my - svBox.y, 0, boxHeight);

		curSat = localX / boxWidth;
		curVal = 1.0 - (localY / boxHeight);

		svCursor.x = svBox.x + localX;
		svCursor.y = svBox.y + localY;

		applyHSBColor();
	}

	function updateHueFromPoint(mx:Float):Void
	{
		var localX = FlxMath.bound(mx - hueBar.x, 0, boxWidth);
		curHue = (localX / boxWidth) * 360.0;
		if (curHue >= 360) curHue = 359.9;

		hueCursor.x = FlxMath.bound(hueBar.x + localX - (hueCursor.width / 2), hueBar.x, hueBar.x + boxWidth - hueCursor.width);

		renderSVBox();
		applyHSBColor();
	}

	function updateRGBSliderFromPoint(channel:Int, mx:Float):Void
	{
		final trackW = 100;
		final localX = FlxMath.bound(mx - rSliderBg.x, 0, trackW);
		final val = Std.int((localX / trackW) * 255);

		var r = _selectedColor.red;
		var g = _selectedColor.green;
		var b = _selectedColor.blue;

		switch (channel)
		{
			case 0: r = val;
			case 1: g = val;
			case 2: b = val;
		}

		setColor(FlxColor.fromRGB(r, g, b, _selectedColor.alpha));
	}

	function applyHSBColor():Void
	{
		_updating = true;
		_selectedColor = FlxColor.fromHSB(curHue, curSat, curVal, _selectedColor.alphaFloat);

		previewBox.color = _selectedColor;
		hexText.text = _selectedColor.toHexString(false, false);

		updateSliderVisuals();

		if (onColorChange != null) onColorChange(_selectedColor);
		if (broadcastPickerEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
		_updating = false;
	}

	function updateSliderVisuals():Void
	{
		final trackW = 100;

		rHandle.x = rSliderBg.x + ((_selectedColor.red / 255.0) * trackW) - (rHandle.width / 2);
		gHandle.x = gSliderBg.x + ((_selectedColor.green / 255.0) * trackW) - (gHandle.width / 2);
		bHandle.x = bSliderBg.x + ((_selectedColor.blue / 255.0) * trackW) - (bHandle.width / 2);

		rValText.text = Std.string(_selectedColor.red);
		gValText.text = Std.string(_selectedColor.green);
		bValText.text = Std.string(_selectedColor.blue);
	}

	public function setColor(newColor:FlxColor):Void
	{
		_selectedColor = newColor;

		curHue = newColor.hue;
		curSat = newColor.saturation;
		curVal = newColor.brightness;

		if (!_uiCreated) return;

		_updating = true;

		renderSVBox();

		svCursor.x = svBox.x + (curSat * boxWidth);
		svCursor.y = svBox.y + ((1.0 - curVal) * boxHeight);

		hueCursor.x = FlxMath.bound(hueBar.x + ((curHue / 360.0) * boxWidth) - (hueCursor.width / 2), hueBar.x, hueBar.x + boxWidth - hueCursor.width);

		previewBox.color = newColor;
		hexText.text = newColor.toHexString(false, false);

		updateSliderVisuals();

		if (onColorChange != null) onColorChange(newColor);
		if (broadcastPickerEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);

		_updating = false;
	}

	private function get_selectedColor():FlxColor return _selectedColor;

	private function set_selectedColor(value:FlxColor):FlxColor
	{
		setColor(value);
		return _selectedColor;
	}

	override public function destroy():Void
	{
		if (svBox?.pixels != null) FlxDestroyUtil.dispose(svBox.pixels);
		if (hueBar?.pixels != null) FlxDestroyUtil.dispose(hueBar.pixels);
		if (svCursor?.pixels != null) FlxDestroyUtil.dispose(svCursor.pixels);
		super.destroy();
	}
}