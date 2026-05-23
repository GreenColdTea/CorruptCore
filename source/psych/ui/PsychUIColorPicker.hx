package psych.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;

import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import openfl.display.BlendMode;
import openfl.display.BitmapData;
import openfl.display.GradientType;
import openfl.display.Shape;
import openfl.geom.Matrix;

enum ColorMode
{
	RGB;
	HSB;
	HEX;
}

class PsychUIColorPicker extends PsychUIGroup
{
	@:unreflective public static final CHANGE_EVENT = "colorpicker_change";
	
	private var _selectedColor:FlxColor;
	public var selectedColor(get, set):FlxColor;
	
	public var onColorChange:FlxColor->Void;
	public var broadcastPickerEvent:Bool = true;
	
	private var _mode:ColorMode = RGB;
	
	// RGB Components
	private var redSlider:PsychUISlider;
	private var greenSlider:PsychUISlider;
	private var blueSlider:PsychUISlider;
	private var alphaSlider:PsychUISlider;
	
	// HSB Components
	private var hueSlider:PsychUISlider;
	private var saturationSlider:PsychUISlider;
	private var brightnessSlider:PsychUISlider;
	
	private var hexInput:PsychUIInputText;
	private var rgbInputs:Array<PsychUIInputText> = [];
	private var hsbInputs:Array<PsychUIInputText> = [];
	
	// Preview and mode selector
	private var currentPreview:FlxSprite;
	private var previousPreview:FlxSprite;
	private var modeSelector:PsychUIDropDownMenu;
	
	// Color wheel for HEX mode
	private var colorWheel:FlxSprite;
	private var colorWheelSelector:FlxSprite;
	private var colorWheelBrightnessSlider:PsychUISlider;
	private var colorWheelOverlay:FlxSprite;
	
	private var isDraggingColorWheel:Bool = false;
	
	private var hexLabel:FlxText;
	private var previewLabel:FlxText;
	private var brightnessLabel:FlxText;
	
	// Layout
	private var currentY:Float = 0;
	private var sliderWidth:Float = 200;
	private var inputWidth:Float = 45;
	private var colorWheelSize:Float = 100;
	
	private var _updating:Bool = false;
	private var _previousColor:FlxColor;
	private var _uiCreated:Bool = false;

	public var customLabel:String = "";

	public function new(x:Float = 0, y:Float = 0, defaultColor:FlxColor = FlxColor.WHITE, ?onColorChange:FlxColor->Void, showAlpha:Bool = false, customLabel:String = "")
	{
		super(x, y);
		
		this.customLabel = customLabel;
		this.onColorChange = onColorChange;

		_selectedColor = defaultColor;
		_previousColor = defaultColor;
		
		createUI(showAlpha);
		_uiCreated = true;
		
		updateFromColor(_selectedColor);
		previousPreview.color = _previousColor;
	}
	
	private function createUI(showAlpha:Bool):Void
	{
		currentY = 0;
		if (customLabel != null && customLabel != "") {
			var label = new FlxText(0, currentY, 0, customLabel, 8);
			add(label);
			currentY += 15;
		}
		
		modeSelector = new PsychUIDropDownMenu(0, currentY, ["RGB", "HSB", "Hex"], function(index:Int, mode:String) {
			switch(index) {
				case 0: setMode(RGB);
				case 1: setMode(HSB);
				case 2: setMode(HEX);
			}
		});
		modeSelector.selectedLabel = "RGB";
		
		currentY += modeSelector.height + 10;
		var sliderBaseY = currentY;
		
		redSlider = createSlider("R:", 0, 255, FlxColor.RED, sliderBaseY);
		redSlider.onChange = (v) -> updateFromRGB();
		
		greenSlider = createSlider("G:", 0, 255, FlxColor.GREEN, sliderBaseY + 50);
		greenSlider.onChange = (v) -> updateFromRGB();
		
		blueSlider = createSlider("B:", 0, 255, FlxColor.BLUE, sliderBaseY + 100);
		blueSlider.onChange = (v) -> updateFromRGB();
		
		if (showAlpha) {
			alphaSlider = createSlider("A:", 0, 255, FlxColor.GRAY, sliderBaseY + 150);
			alphaSlider.onChange = (v) -> updateFromRGB();
		}
		
		var rgbInputX = sliderWidth + 10;
		for (i in 0...3) {
			var input = new PsychUIInputText(rgbInputX, sliderBaseY + 20 + (i * 50), Std.int(inputWidth), "0", 8);
			input.filterMode = ONLY_NUMERIC;
			input.maxLength = 3;
			input.onChange = (old, val) -> {
				var v = Std.parseInt(val);
				if (v != null && !_updating) {
					v = Std.int(Math.max(0, Math.min(255, v)));
					switch(i) {
						case 0: redSlider.value = v;
						case 1: greenSlider.value = v;
						case 2: blueSlider.value = v;
					}
					updateFromRGB();
				}
			};
			rgbInputs.push(input);
			add(input);
		}
		
		if (showAlpha) {
			var alphaInput = new PsychUIInputText(rgbInputX, sliderBaseY + 90, Std.int(inputWidth), "255", 8);
			alphaInput.filterMode = ONLY_NUMERIC;
			alphaInput.maxLength = 3;
			alphaInput.onChange = (old, val) -> {
				var v = Std.parseInt(val);
				if (v != null && alphaSlider != null && !_updating) {
					alphaSlider.value = Std.int(Math.max(0, Math.min(255, v)));
					updateFromRGB();
				}
			};
			rgbInputs.push(alphaInput);
			add(alphaInput);
		}
		
		hueSlider = createSlider("H:", 0, 360, FlxColor.WHITE, sliderBaseY);
		hueSlider.onChange = (v) -> updateFromHSB();
		hueSlider.visible = hueSlider.active = false;
		
		saturationSlider = createSlider("S:", 0, 100, FlxColor.WHITE, sliderBaseY + 50);
		saturationSlider.onChange = (v) -> updateFromHSB();
		saturationSlider.visible = saturationSlider.active = false;
		
		brightnessSlider = createSlider("B:", 0, 100, FlxColor.WHITE, sliderBaseY + 100);
		brightnessSlider.onChange = (v) -> updateFromHSB();
		brightnessSlider.visible = brightnessSlider.active = false;
		
		for (i in 0...3) {
			var input = new PsychUIInputText(rgbInputX, sliderBaseY + 20 + (i * 50), Std.int(inputWidth), "0", 8);
			input.filterMode = ONLY_NUMERIC;
			input.maxLength = 3;
			input.visible = input.active = false;
			input.onChange = (old, val) -> {
				var v = Std.parseFloat(val);
				if (!Math.isNaN(v) && !_updating) {
					switch(i) {
						case 0: hueSlider.value = Math.max(0, Math.min(360, v));
						case 1: saturationSlider.value = Math.max(0, Math.min(100, v));
						case 2: brightnessSlider.value = Math.max(0, Math.min(100, v));
					}
					updateFromHSB();
				}
			};
			hsbInputs.push(input);
			add(input);
		}
		
		var wheelY = showAlpha ? sliderBaseY + 75 : sliderBaseY + 25;
		colorWheel = createColorWheel(0, wheelY, Std.int(colorWheelSize));
		colorWheel.visible = colorWheel.active = false;
		add(colorWheel);
		
		colorWheelOverlay = createCircleOverlay(Std.int(colorWheelSize), FlxColor.WHITE);
		colorWheelOverlay.x = 0;
		colorWheelOverlay.y = wheelY;
		colorWheelOverlay.visible = false;
		add(colorWheelOverlay);
		
		colorWheelSelector = createSelectorSprite();
		colorWheelSelector.x = 0;
		colorWheelSelector.y = 0;
		colorWheelSelector.visible = false;
		add(colorWheelSelector);
		
		brightnessLabel = new FlxText(colorWheelSize + 10, wheelY, 0, "Brightness:", 8);
		brightnessLabel.visible = brightnessLabel.active = false;
		add(brightnessLabel);
		
		colorWheelBrightnessSlider = new PsychUISlider(colorWheelSize + 10, wheelY + 15, null, 100, 0, 100, 100, FlxColor.WHITE);
		colorWheelBrightnessSlider.label = "";
		colorWheelBrightnessSlider.decimals = 0;
		colorWheelBrightnessSlider.visible = colorWheelBrightnessSlider.active = false;
		colorWheelBrightnessSlider.onChange = (v) -> {
			updateColorWheelBrightness();
			updateFromColorWheel();
		};
		add(colorWheelBrightnessSlider);
		
		var hexY = wheelY + colorWheelSize + 10;
		hexLabel = new FlxText(0, hexY, 0, "Hex:", 8);
		hexLabel.visible = hexLabel.active = false;
		add(hexLabel);
		
		hexInput = new PsychUIInputText(35, hexY, 80, "FFFFFF", 8);
		hexInput.filterMode = ONLY_HEXADECIMAL;
		hexInput.forceCase = UPPER_CASE;
		hexInput.maxLength = 6;
		hexInput.visible = hexInput.active = false;
		hexInput.onChange = (old, val) -> {
			if (val.length == 6 && !_updating) {
				var newColor = FlxColor.fromString("#" + val);
				if (newColor != null) {
					newColor.alpha = alphaSlider != null ? Std.int(alphaSlider.value) : _selectedColor.alpha;
					setColor(newColor);
				}
			}
		};
		add(hexInput);
		
		var previewY = hexY + 30;
		previewLabel = new FlxText(0, previewY, 0, "Preview:", 8);
		add(previewLabel);
		
		currentPreview = new FlxSprite(50, previewY).makeGraphic(40, 40, FlxColor.WHITE);
		add(currentPreview);
		
		previousPreview = new FlxSprite(100, previewY).makeGraphic(40, 40, FlxColor.WHITE);
		add(previousPreview);
		
		currentY = previewY + 50;
		
		add(redSlider);
		add(greenSlider);
		add(blueSlider);
		if (alphaSlider != null) add(alphaSlider);
		add(hueSlider);
		add(saturationSlider);
		add(brightnessSlider);
		add(modeSelector);
	}
	
	private function createColorWheel(x:Float, y:Float, size:Int):FlxSprite
	{
		final wheel = new FlxSprite(x, y);
		wheel.makeGraphic(size, size, FlxColor.TRANSPARENT, false);
		
		final shape = new Shape();
		final g = shape.graphics;
		final radius = size / 2;
		
		final segments:Int = 360;
		for (i in 0...segments)
		{
			var startAngle = (i / segments) * Math.PI * 2;
			var endAngle = ((i + 1.5) / segments) * Math.PI * 2;
			
			var hue = i * (360 / segments);
			g.beginFill(FlxColor.fromHSB(hue, 1.0, 1.0), 1.0);
			g.moveTo(radius, radius);
			g.lineTo(radius + Math.cos(startAngle) * radius, radius + Math.sin(startAngle) * radius);
			g.lineTo(radius + Math.cos(endAngle) * radius, radius + Math.sin(endAngle) * radius);
			g.lineTo(radius, radius);
			g.endFill();
		}
		
		final bitmap = new BitmapData(size, size, true, 0x00000000);
		bitmap.draw(shape);
		
		final saturationMask = new Shape();
		final colors = [0xFFFFFFFF, 0x00FFFFFF];
		final alphas:Array<Float> = [1, 1];
		final ratios = [0, 255];
		final matrix = new Matrix();
		matrix.createGradientBox(size, size, 0, 0, 0);
		
		saturationMask.graphics.beginGradientFill(GradientType.RADIAL, colors, alphas, ratios, matrix);
		saturationMask.graphics.drawCircle(radius, radius, radius);
		saturationMask.graphics.endFill();
		
		bitmap.draw(saturationMask, null, null, BlendMode.MULTIPLY);
		
		wheel.pixels = bitmap;
		return wheel;
	}
	
	private function createCircleOverlay(size:Int, color:FlxColor):FlxSprite
	{
		final overlay = new FlxSprite().makeGraphic(size, size, FlxColor.TRANSPARENT, false);
		final bitmap = new BitmapData(size, size, true, 0x00000000);
		final radius = size / 2.0;
		
		for (px in 0...size) {
			for (py in 0...size) {
				var dx = px - radius;
				var dy = py - radius;
				if (Math.abs(Math.sqrt(dx * dx + dy * dy) - radius) <= 1.5) {
					bitmap.setPixel32(px, py, color);
				}
			}
		}
		
		overlay.pixels = bitmap;
		return overlay;
	}
	
	private function createSelectorSprite():FlxSprite
	{
		final size = 12;
		final selector = new FlxSprite().makeGraphic(size, size, FlxColor.TRANSPARENT, false);
		final bitmap = new BitmapData(size, size, true, 0x00000000);
		final center = Std.int(size / 2);
		
		for (y in 0...size) {
			bitmap.setPixel32(center, y, FlxColor.BLACK);
			if (y > 0 && y < size - 1) bitmap.setPixel32(center, y, FlxColor.WHITE);
		}
		for (x in 0...size) {
			bitmap.setPixel32(x, center, FlxColor.BLACK);
			if (x > 0 && x < size - 1) bitmap.setPixel32(x, center, FlxColor.WHITE);
		}
		
		selector.pixels = bitmap;
		selector.offset.set(size / 2, size / 2);
		return selector;
	}
	
	private function updateColorWheelBrightness():Void
	{
		if (colorWheel == null || !colorWheel.visible) return;
		final b = colorWheelBrightnessSlider.value / 100.0;
		colorWheel.color = FlxColor.fromRGBFloat(b, b, b);
	}
	
	private function updateColorWheelSelectorFromColor(color:FlxColor):Void
	{
		if (colorWheel == null || !colorWheel.visible) return;
		
		final hue = color.hue;
		final saturation = color.saturation;
		final brightness = color.brightness;
		
		_updating = true;
		colorWheelBrightnessSlider.value = brightness * 100;
		_updating = false;
		
		final angle = hue * Math.PI / 180;
		final radius = saturation * (colorWheelSize / 2);
		
		final centerX = colorWheel.x + colorWheelSize / 2;
		final centerY = colorWheel.y + colorWheelSize / 2;
		
		colorWheelSelector.x = centerX + Math.cos(angle) * radius;
		colorWheelSelector.y = centerY + Math.sin(angle) * radius;
		colorWheelSelector.visible = true;
	}
	
	private function createSlider(label:String, min:Float, max:Float, color:FlxColor, y:Float):PsychUISlider
	{
		var slider = new PsychUISlider(0, y, null, 0, min, max, sliderWidth, color);
		slider.label = label;
		slider.decimals = 0;
		return slider;
	}
	
	private function setMode(mode:ColorMode):Void
	{
		_mode = mode;
		final showRGB = mode == RGB;
		final showHSB = mode == HSB;
		final showHEX = mode == HEX;
		
		redSlider.visible = redSlider.active = showRGB;
		greenSlider.visible = greenSlider.active = showRGB;
		blueSlider.visible = blueSlider.active = showRGB;
		if (alphaSlider != null) alphaSlider.visible = alphaSlider.active = showRGB;
		
		for (i in 0...rgbInputs.length) rgbInputs[i].visible = rgbInputs[i].active = showRGB;
		
		hueSlider.visible = hueSlider.active = showHSB;
		saturationSlider.visible = saturationSlider.active = showHSB;
		brightnessSlider.visible = brightnessSlider.active = showHSB;
		
		for (i in 0...hsbInputs.length) hsbInputs[i].visible = hsbInputs[i].active = showHSB;
		
		hexInput.visible = hexInput.active = showHEX;
		hexLabel.visible = hexLabel.active = showHEX;
		colorWheel.visible = colorWheel.active = showHEX;
		colorWheelOverlay.visible = showHEX;
		colorWheelBrightnessSlider.visible = colorWheelBrightnessSlider.active = showHEX;
		brightnessLabel.visible = brightnessLabel.active = showHEX;
		
		if (showHEX) {
			updateColorWheelBrightness();
			updateColorWheelSelectorFromColor(_selectedColor);
		} else {
			colorWheelSelector.visible = false;
			isDraggingColorWheel = false;
		}
		
		updateUIFromColor();
	}
	
	private function updateFromColor(color:FlxColor):Void
	{
		if (_updating || !_uiCreated) return;

		_updating = true;
		
		redSlider.value = color.red;
		greenSlider.value = color.green;
		blueSlider.value = color.blue;
		if (alphaSlider != null) alphaSlider.value = color.alpha;
		
		rgbInputs[0].text = Std.string(color.red);
		rgbInputs[1].text = Std.string(color.green);
		rgbInputs[2].text = Std.string(color.blue);
		if (alphaSlider != null && rgbInputs.length > 3) {
			rgbInputs[3].text = Std.string(color.alpha);
		}
		
		hueSlider.value = color.hue;
		saturationSlider.value = color.saturation * 100;
		brightnessSlider.value = color.brightness * 100;
		
		hsbInputs[0].text = Std.string(Math.round(color.hue));
		hsbInputs[1].text = Std.string(Math.round(color.saturation * 100));
		hsbInputs[2].text = Std.string(Math.round(color.brightness * 100));
		
		hexInput.text = color.toHexString(false, false);
		currentPreview.color = color;
		
		if (_mode == HEX) {
			updateColorWheelSelectorFromColor(color);
		}
		
		_updating = false;
	}
	
	private function updateFromRGB():Void
	{
		if (_updating) return;

		final r = Std.int(redSlider.value);
		final g = Std.int(greenSlider.value);
		final b = Std.int(blueSlider.value);
		final a = alphaSlider != null ? Std.int(alphaSlider.value) : _selectedColor.alpha;
		
		setColor(FlxColor.fromRGB(r, g, b, a));
	}
	
	private function updateFromHSB():Void
	{
		if (_updating) return;

		final h = hueSlider.value;
		final s = saturationSlider.value / 100;
		final b = brightnessSlider.value / 100;
		final a = alphaSlider != null ? alphaSlider.value / 255 : _selectedColor.alphaFloat;
		
		setColor(FlxColor.fromHSB(h, s, b, a));
	}
	
	private function updateFromColorWheel():Void
	{
		if (_updating || !colorWheelSelector.visible) return;
		
		final brightness = colorWheelBrightnessSlider.value / 100;
		final centerX = colorWheel.x + colorWheelSize / 2;
		final centerY = colorWheel.y + colorWheelSize / 2;
		
		final dx = colorWheelSelector.x - centerX;
		final dy = colorWheelSelector.y - centerY;
		
		final distance = Math.sqrt(dx * dx + dy * dy);
		
		var angle = Math.atan2(dy, dx);
		if (angle < 0) angle += Math.PI * 2;
		
		final hue = angle * 180 / Math.PI;
		final saturation = Math.min(1.0, distance / (colorWheelSize / 2));
		final alpha = alphaSlider != null ? alphaSlider.value / 255 : _selectedColor.alphaFloat;
		
		setColor(FlxColor.fromHSB(hue, saturation, brightness, alpha));
	}
	
	private function updateUIFromColor():Void
	{
		updateFromColor(_selectedColor);
	}
	
	public function setColor(newColor:FlxColor):Void
	{
		if (_selectedColor == newColor) return;
		
		_selectedColor = newColor;
		updateFromColor(newColor);
		
		if (onColorChange != null) onColorChange(newColor);
		if (broadcastPickerEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		if (_mode == HSB && hueSlider != null)
			updateHueSliderColors();
			
		if (_mode == HEX && colorWheel.visible)
		{
            final cam = this.camera ?? FlxG.camera;
            final mousePos = FlxG.mouse.getWorldPosition(cam);
            
            final mouseX = mousePos.x;
            final mouseY = mousePos.y;
            mousePos.put();
			
			final wheelWorldX = colorWheel.x + colorWheelSize / 2;
			final wheelWorldY = colorWheel.y + colorWheelSize / 2;

			final dx = mouseX - wheelWorldX;
			final dy = mouseY - wheelWorldY;
			final distanceToCenter = Math.sqrt(dx * dx + dy * dy);
			final wheelRadius = colorWheelSize / 2;

			final selectorWorldX = colorWheelSelector.x;
			final selectorWorldY = colorWheelSelector.y;
			final dxSelector = mouseX - selectorWorldX;
			final dySelector = mouseY - selectorWorldY;
			final distanceToSelector = Math.sqrt(dxSelector * dxSelector + dySelector * dySelector);
			
			final isInsideWheel = distanceToCenter <= wheelRadius;
			final isOnSelector = distanceToSelector <= 15;
			
			Mouse.cursor = (isInsideWheel || isOnSelector || isDraggingColorWheel) ? MouseCursor.HAND : MouseCursor.AUTO;
			
			if (FlxG.mouse.justPressed && (isInsideWheel || isOnSelector)) {
				isDraggingColorWheel = true;
				updateSelectorFromMouse(mouseX, mouseY);
			}
			
			if (FlxG.mouse.justReleased) {
				isDraggingColorWheel = false;
			}
			
			if (isDraggingColorWheel && FlxG.mouse.pressed) {
				updateSelectorFromMouse(mouseX, mouseY);
			}
		}
		else
		{
			isDraggingColorWheel = false;
		}
	}
	
	private function updateSelectorFromMouse(mouseX:Float, mouseY:Float):Void
	{
		final wheelWorldX = colorWheel.x + colorWheelSize / 2;
		final wheelWorldY = colorWheel.y + colorWheelSize / 2;
		
		var dx = mouseX - wheelWorldX;
		var dy = mouseY - wheelWorldY;
		var distance = Math.sqrt(dx * dx + dy * dy);
		
		var maxRadius = colorWheelSize / 2;
		if (distance > maxRadius)
		{
			dx = dx * maxRadius / distance;
			dy = dy * maxRadius / distance;
		}
		
		colorWheelSelector.x = colorWheel.x + colorWheelSize / 2 + dx;
		colorWheelSelector.y = colorWheel.y + colorWheelSize / 2 + dy;
		colorWheelSelector.visible = true;
		
		updateFromColorWheel();
	}
	
	private function updateHueSliderColors():Void
	{
		hueSlider.leftColor = FlxColor.RED;
		hueSlider.rightColor = FlxColor.RED;
		
		final currentColor = FlxColor.fromHSB(hueSlider.value, 1, 1);
		saturationSlider.mainColor = currentColor;
		brightnessSlider.mainColor = currentColor;
	}
	
	private function get_selectedColor():FlxColor
	{
		return _selectedColor;
	}
	
	private function set_selectedColor(value:FlxColor):FlxColor
	{
		if (_uiCreated) {
			setColor(value);
		} else {
			_selectedColor = value;
		}
		return _selectedColor;
	}
	
	override public function destroy():Void
	{
		if (colorWheel?.pixels != null)
			FlxDestroyUtil.dispose(colorWheel.pixels);

		if (colorWheelOverlay?.pixels != null)
			FlxDestroyUtil.dispose(colorWheelOverlay.pixels);

		if (colorWheelSelector?.pixels != null)
			FlxDestroyUtil.dispose(colorWheelSelector.pixels);
		super.destroy();
	}
}