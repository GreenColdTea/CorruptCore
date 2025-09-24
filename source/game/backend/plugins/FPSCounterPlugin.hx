package game.backend.plugins;

import haxe.Timer;

import openfl.Lib;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.system.System;
import openfl.utils.Assets;
import flixel.FlxG;

#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

class FPSCounterPlugin extends Bitmap
{
	public var currentFPS(default, null):Int;

	/**
	 * The current memory usage in bytes (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	 */
	public var memoryMegas(get, never):Float;

	private var cacheCount:Int = 0;
	private var currentTime:Float = 0;
	private var times:Array<Float> = [];
	#if (openfl >= "9.4.0")
	private var peakMemory:Float = 0;
	#else
	private var peakMemory:UInt = 0;
	#end

	private var strokeSize:Int = 1; //set ur border size here
	private var strokeColor:Int = 0xFF000000;
	private var fillColor:Int = 0xFFFFFFFF;
	private var fontSize:Int = 12;
	//private var fontCustom = Assets.getFont(Paths.font("NiseSegaSonic.TTF")); for custom font, set it here
	private var fontCustom = "_sans";
	private var dataTexts = ["B", "KB", "MB", "GB", "TB", "PB"];

	public function new(x:Float = 10, y:Float = 10, ?fillColor:Int = 0xFFFFFFFF)
	{
		super();
		this.x = x;
		this.y = y;
		this.fillColor = fillColor;
		addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	inline function get_memoryMegas():Float
	{
		return MemoryUtil.memoryUsage();
	}

	private function onEnterFrame(event:Event):Void
	{
		var currentTime = Timer.stamp() * 1000;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
			times.shift();

		var currentCount = times.length;
		currentFPS = currentCount;

		if (currentFPS > ClientPrefs.framerate && ClientPrefs.vsync != 'On') currentFPS = ClientPrefs.framerate;

		if (currentCount != cacheCount)
        {
            var output = "FPS: " + currentFPS;
            #if (openfl >= "9.4.0")
            var memoryUsage:Float = System.totalMemoryNumber;
            #else
            var memoryUsage:UInt = System.totalMemory;
            #end
            if (memoryUsage > peakMemory) peakMemory = memoryUsage;

            output += "\nRAM: " + getSizeLabel(memoryUsage);
            output += "\nRAM Peak: " + getSizeLabel(peakMemory);
            #if debug output += "\nGC Memory: " + getSizeLabel(Std.int(memoryMegas)) + " (" + memoryMegas + " bytes)"; #end

            var vsyncEnabled = (ClientPrefs.vsync != 'Off');
            var targetFPS = vsyncEnabled ? getDisplayRefreshRate() : ClientPrefs.framerate;
            
            // performance checker
            var isLowFPS = currentFPS < targetFPS * 0.7; // less than 70%
            var isVeryLowFPS = currentFPS < targetFPS * 0.5; // less than 50%
            var isHighMemory = memoryUsage > 2000000000; // more than 2gb
            
            if (isVeryLowFPS || isHighMemory)
            {
                fillColor = 0xFFFF0000; //bad
            }
            else if (isLowFPS)
            {
                fillColor = 0xFFFFFF00; //mid
            }
            else
            {
                fillColor = 0xFFFFFFFF; //good
            }

            #if (gl_stats && !disable_cffi && (!html5 || !canvas))
            output += "\ntotalDC: " + Context3DStats.totalDrawCalls();
            output += "\nstageDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE);
            output += "\nstage3DDC: " + Context3DStats.contextDrawCalls(DrawCallContext.STAGE3D);
            #end

            updateText(output);
        }

		cacheCount = currentCount;
	}

	private function getDisplayRefreshRate():Int
	{
		var window = Lib.application.window;
		if (window != null && window.display != null && window.display.currentMode != null)
		{
			return window.display.currentMode.refreshRate;
		}
		
		return 60;
	}

	private function getSizeLabel(#if (openfl >= "9.4.0") num:Float #else num:UInt #end):String
	{
		var size:Float = num;
		var data = 0;
		while (size > 1024 && data < dataTexts.length - 1)
		{
			data++;
			size /= 1024;
		}

		size = Math.round(size * 100) / 100;
		if (data <= 2)
			size = Math.round(size);

		return size + " " + dataTexts[data];
	}

	private function updateText(content:String):Void
	{
		var tf = new TextField();
		tf.defaultTextFormat = new TextFormat(fontCustom/*.fontName*/, fontSize, fillColor);
		tf.text = content;
		tf.autoSize = LEFT;
		tf.multiline = true;
		tf.selectable = false;
		tf.antiAliasType = NORMAL;
		tf.sharpness = 100;
		//tf.gridFitType = PIXEL;

		var w = tf.width + strokeSize * 2;
		var h = tf.height + strokeSize * 2;
		var bmd = new BitmapData(Math.ceil(w), Math.ceil(h), true, 0x00000000);

		// Draw border (8 directions)
		for (dx in -strokeSize...strokeSize + 1) {
			for (dy in -strokeSize...strokeSize + 1) {
				if (dx != 0 || dy != 0) {
					tf.textColor = strokeColor;
					bmd.draw(tf, new Matrix(1, 0, 0, 1, strokeSize + dx, strokeSize + dy));
				}
			}
		}

		// Draw main text
		tf.textColor = fillColor;
		bmd.draw(tf, new Matrix(1, 0, 0, 1, strokeSize, strokeSize));

		this.bitmapData = bmd;
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}
}