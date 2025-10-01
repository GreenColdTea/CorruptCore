package game.backend.plugins;

import haxe.Timer;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.system.System;
import openfl.utils.Assets;
import flixel.FlxG;
import sys.FileSystem;
import sys.io.File;

#if gl_stats
import openfl.display._internal.stats.Context3DStats;
import openfl.display._internal.stats.DrawCallContext;
#end

@:allow(Init)
class FPSCounterPlugin extends Bitmap
{
	public var currentFPS(default, null):Int;
	public var currentMemory(get, never):Float;
	public var showDebugInfo:Bool = false;

	private var cacheCount:Int = 0;
	private var currentTime:Float = 0;
	private var times:Array<Float> = [];
	private var lastFrameTime:Float = 0;
	
	#if (openfl >= "9.4.0")
	private var peakMemory:Float = 0;
	#else
	private var peakMemory:UInt = 0;
	#end

	private var graphWidth:Int = 180;
	private var graphHeight:Int = 50;
	private var graphHistory:Array<Float> = [];
	private var maxGraphPoints:Int = 180;
	private var frameTimes:Array<Float> = [];
	private var maxFrameTimeHistory:Int = 60;

	private var strokeSize:Int = 1;
	private var strokeColor:Int = 0xFF000000;
	private var fillColor:Int = 0xFFFFFFFF;
	private var fontSize:Int = 12;
	private var fontCustom = "_sans";
	private var dataTexts = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

	private var minFPS:Int = 9999;
	private var maxFPS:Int = 0;
	private var avgFPS:Float = 0;
	private var fpsSamples:Int = 0;
	private var totalFPS:Float = 0;
	private var lastStatReset:Float = 0;

	private var logEnabled:Bool = false;
	private var logFile:String = "fps_log.txt";
	private var logTimer:Float = 0;
	private var logInterval:Float = 1.0;

	private var counterVisible:Bool = true;
	private var keyCooldown:Float = 0;
	private var keyCooldownTime:Float = 0.2;

	public function new(x:Float = 10, y:Float = 10, ?fillColor:Int = 0xFFFFFFFF)
	{
		super();
		this.x = x;
		this.y = y;
		this.fillColor = fillColor;
		lastFrameTime = Timer.stamp();
		lastStatReset = lastFrameTime;
		
		if (logEnabled) {
			initLogFile();
		}
		
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		if (keyCooldown > 0) return;
		
		switch (event.keyCode) {
			/*case Keyboard.F1:
				toggleCounterVisibility();
				keyCooldown = keyCooldownTime;*/
			case Keyboard.F2:
				resetStats();
				keyCooldown = keyCooldownTime;
			case Keyboard.F3:
				toggleDebugInfo();
				keyCooldown = keyCooldownTime;
		}
	}

	/*private function toggleCounterVisibility():Void
	{
		counterVisible = !counterVisible;
		this.visible = counterVisible;
	}*/

	inline function get_currentMemory():Float
	{
		return MemoryUtil.memoryUsage();
	}

	private function onEnterFrame(event:Event):Void
	{
		if (keyCooldown > 0) {
			keyCooldown -= Timer.stamp() - lastFrameTime;
		}

		var currentTime = Timer.stamp() * 1000;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
			times.shift();

		var currentCount = times.length;
		currentFPS = Math.round(currentCount);

		if (currentFPS > ClientPrefs.framerate && !ClientPrefs.vsync) 
			currentFPS = ClientPrefs.framerate;

		updateStatistics();
		updateGraphs();
		updateFrameTiming();
		
		if (logEnabled) {
			updateLogging();
		}

		if (currentCount != cacheCount && counterVisible)
		{
			var output = buildOutputString();
			updateText(output);
		}

		cacheCount = currentCount;
	}

	private function updateStatistics():Void
	{
		if (currentFPS < minFPS && currentFPS > 0) minFPS = currentFPS;
		if (currentFPS > maxFPS) maxFPS = currentFPS;
		
		fpsSamples++;
		totalFPS += currentFPS;
		avgFPS = totalFPS / fpsSamples;
		
		var currentTime = Timer.stamp();
		if (currentTime - lastStatReset > 30) {
			resetStatistics();
		}
	}

	private function resetStatistics():Void
	{
		minFPS = 9999;
		maxFPS = 0;
		avgFPS = 0;
		fpsSamples = 0;
		totalFPS = 0;
		lastStatReset = Timer.stamp();
	}

	private function updateGraphs():Void
	{
		graphHistory.push(currentFPS);
		if (graphHistory.length > maxGraphPoints) {
			graphHistory.shift();
		}
	}

	private function updateFrameTiming():Void
	{
		var currentTime = Timer.stamp();
		if (lastFrameTime > 0) {
			var frameTime = (currentTime - lastFrameTime) * 1000;
			frameTimes.push(frameTime);
			if (frameTimes.length > maxFrameTimeHistory) {
				frameTimes.shift();
			}
		}
		lastFrameTime = currentTime;
	}

	private function updateLogging():Void
	{
		var currentTime = Timer.stamp();
		if (currentTime - logTimer > logInterval) {
			logData();
			logTimer = currentTime;
		}
	}

	private function buildOutputString():String
	{
		var output = 'FPS: $currentFPS / ${!ClientPrefs.vsync ? ClientPrefs.framerate : getDisplayRefreshRate()}';
		
		#if (openfl >= "9.4.0")
		var memoryUsage:Float = System.totalMemoryNumber;
		#else
		var memoryUsage:UInt = System.totalMemory;
		#end
		
		if (memoryUsage > peakMemory) peakMemory = memoryUsage;

		output += "\nRAM: " + getSizeLabel(memoryUsage);
		output += "\nRAM Peak: " + getSizeLabel(peakMemory);
		
		if (showDebugInfo) {
			output += "\nGC: " + getSizeLabel(Std.int(currentMemory));
			output += "\nMin/Max/Avg: " + minFPS + "/" + maxFPS + "/" + Math.round(avgFPS);
			output += "\nVSync: " + (ClientPrefs.vsync ? "ON" : "OFF");
			output += "\nTarget: " + (ClientPrefs.vsync ? getDisplayRefreshRate() + "Hz" : ClientPrefs.framerate + "FPS");
			
			output += "\n\nSystem:";
			output += "\nOS: " + CoolUtil.getBuildTarget();
			output += "\nDisplay: " + Lib.current.stage.stageWidth + "x" + Lib.current.stage.stageHeight;
			output += "\nRefresh: " + getDisplayRefreshRate() + "Hz";
			
			if (frameTimes.length > 0) {
				var frameStats = getFrameTimingStats();
				output += "\nFrame: " + frameStats.avg + "ms (min: " + frameStats.min + "ms, max: " + frameStats.max + "ms)";
			}
			
			var warnings = getPerformanceWarnings(memoryUsage);
			if (warnings != "") {
				output += "\n\nWARNINGS:\n" + warnings;
			}
		}

		var vsyncEnabled = ClientPrefs.vsync;
		var targetFPS = vsyncEnabled ? getDisplayRefreshRate() : ClientPrefs.framerate;
		
		var isLowFPS = currentFPS < targetFPS * 0.7;
		var isVeryLowFPS = currentFPS < targetFPS * 0.5;
		var isHighMemory = memoryUsage > 2000000000;
		
		if (isVeryLowFPS || isHighMemory) {
			fillColor = 0xFFFF0000;
		} else if (isLowFPS) {
			fillColor = 0xFFFFFF00;
		} else {
			fillColor = 0xFFFFFFFF;
		}

		return output;
	}

	private function getFrameTimingStats():{avg:Float, min:Float, max:Float}
	{
		var avg:Float = 0;
		var min:Float = 1000;
		var max:Float = 0;
		
		for (time in frameTimes) {
			avg += time;
			if (time < min) min = time;
			if (time > max) max = time;
		}
		avg /= frameTimes.length;
		
		return {
			avg: Math.round(avg * 100) / 100,
			min: Math.round(min * 100) / 100,
			max: Math.round(max * 100) / 100
		};
	}

	private function getPerformanceWarnings(#if (openfl >= "9.4.0") memUsage:Float #else memUsage:UInt #end):String
	{
		var warnings = "";
		var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
		
		if (currentFPS < targetFPS * 0.3)
			warnings += "• EXTREMELY LOW FPS (" + currentFPS + "/" + targetFPS + ")\n";
		else if (currentFPS < targetFPS * 0.5)
			warnings += "• Very low FPS (" + currentFPS + "/" + targetFPS + ")\n";
		else if (currentFPS < targetFPS * 0.7)
			warnings += "• Low FPS (" + currentFPS + "/" + targetFPS + ")\n";
		
		if (memUsage > 3000000000)
			warnings += "• High memory usage (" + getSizeLabel(memUsage) + ")\n";
		
		if (frameTimes.length > 10) {
			var stats = getFrameTimingStats();
			if (stats.avg > 33.33) {
				warnings += "• Slow frame rendering (" + stats.avg + "ms avg)\n";
			}
			
			if (stats.max > 100) {
				warnings += "• Frame spikes detected (" + stats.max + "ms max)\n";
			}
		}
		
		return warnings;
	}

	private static function getDisplayRefreshRate():Int
	{
		var window = Lib.application.window;
		if (window?.display?.currentMode != null)
		{
			return window.display.currentMode.refreshRate;
		}

		return 60;
	}

	private function getSizeLabel(num:Float):String
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
		tf.defaultTextFormat = new TextFormat(fontCustom, fontSize, fillColor);
		tf.text = content;
		tf.autoSize = LEFT;
		tf.multiline = true;
		tf.selectable = false;
		tf.antiAliasType = NORMAL;
		tf.sharpness = 100;

		var textWidth = tf.textWidth + strokeSize * 2;
		var textHeight = tf.textHeight + strokeSize * 2;
		
		var totalWidth = Math.max(textWidth, graphWidth + strokeSize * 2);
		var totalHeight = textHeight + (showDebugInfo ? graphHeight + 10 : 0);
		
		var bmd = new BitmapData(Math.ceil(totalWidth), Math.ceil(totalHeight), true, 0x00000000);

		for (dx in -strokeSize...strokeSize + 1) {
			for (dy in -strokeSize...strokeSize + 1) {
				if (dx != 0 || dy != 0) {
					tf.textColor = strokeColor;
					bmd.draw(tf, new Matrix(1, 0, 0, 1, strokeSize + dx, strokeSize + dy));
				}
			}
		}

		tf.textColor = fillColor;
		bmd.draw(tf, new Matrix(1, 0, 0, 1, strokeSize, strokeSize));

		if (showDebugInfo && graphHistory.length > 1) {
			drawGraph(bmd, strokeSize, Std.int(textHeight + 5));
		}
		
		this.bitmapData = bmd;
	}

	private function drawGraph(bmd:BitmapData, x:Int, y:Int):Void
	{
		if (graphHistory.length < 2) return;
		
		var graphX = x;
		var graphY = y;
		
		bmd.fillRect(new Rectangle(graphX, graphY, graphWidth, graphHeight), 0x55000000);
		
		for (i in 0...5) {
			var lineY = graphY + Std.int(graphHeight * i / 4);
			bmd.fillRect(new Rectangle(graphX, lineY, graphWidth, 1), 0x33FFFFFF);
		}
		
		var maxValue = Math.max(ClientPrefs.framerate, Math.max(currentFPS, getArrayMax(graphHistory)));
		if (maxValue < 1) maxValue = 1;
		
		var targetY = graphY + graphHeight - Std.int((ClientPrefs.framerate / maxValue) * graphHeight);
		bmd.fillRect(new Rectangle(graphX, targetY, graphWidth, 1), 0x6600FF00);
		
		var prevX = graphX;
		var prevY = graphY + graphHeight - Std.int((graphHistory[0] / maxValue) * graphHeight);
		
		for (i in 1...graphHistory.length) {
			var xPos = graphX + Std.int((i / graphHistory.length) * graphWidth);
			var yPos = graphY + graphHeight - Std.int((graphHistory[i] / maxValue) * graphHeight);
			
			yPos = Std.int(Math.max(graphY, Math.min(graphY + graphHeight - 1, yPos)));
			xPos = Std.int(Math.max(graphX, Math.min(graphX + graphWidth - 1, xPos)));
			
			drawLine(bmd, prevX, prevY, xPos, yPos, fillColor);
			
			bmd.fillRect(new Rectangle(xPos - 1, yPos - 1, 3, 3), 0xFFFFFF00);
			
			prevX = xPos;
			prevY = yPos;
		}
	}

	private function drawLine(bmd:BitmapData, x1:Int, y1:Int, x2:Int, y2:Int, color:Int):Void
	{
		var dx = Math.abs(x2 - x1);
		var dy = Math.abs(y2 - y1);
		var sx = (x1 < x2) ? 1 : -1;
		var sy = (y1 < y2) ? 1 : -1;
		var err = dx - dy;
		
		var x = x1;
		var y = y1;
		
		while (true) {
			if (x >= 0 && x < bmd.width && y >= 0 && y < bmd.height) {
				bmd.setPixel32(x, y, color);
			}
			
			if (x == x2 && y == y2) break;
			
			var e2 = 2 * err;
			if (e2 > -dy) {
				err -= dy;
				x += sx;
			}
			if (e2 < dx) {
				err += dx;
				y += sy;
			}
		}
	}

	private function getArrayMax(arr:Array<Float>):Float
	{
		var max = arr[0];
		for (i in 1...arr.length) {
			if (arr[i] > max) max = arr[i];
		}
		return max;
	}

	private function initLogFile():Void
	{
		try {
			var header = "Timestamp,FPS,Memory,PeakMemory,VSync,TargetFPS\n";
			File.saveContent(logFile, header);
		} catch (e:Dynamic) {
			trace("Failed to create log file: " + e);
		}
	}

	private function logData():Void
	{
		try {
			var timestamp = Date.now().toString();
			#if (openfl >= "9.4.0")
			var memory = System.totalMemoryNumber;
			#else
			var memory = System.totalMemory;
			#end
			
			var logLine = timestamp + "," + currentFPS + "," + memory + "," + peakMemory + "," + 
						 (ClientPrefs.vsync ? "ON" : "OFF") + "," + 
						 (ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate) + "\n";
			
			File.saveContent(logFile, File.getContent(logFile) + logLine);
		} catch (e:Dynamic) {
			trace("Failed to write log: " + e);
		}
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	public function toggleDebugInfo():Void
	{
		showDebugInfo = !showDebugInfo;
	}

	public function resetStats():Void
	{
		resetStatistics();
		graphHistory = [];
		frameTimes = [];
		#if (openfl >= "9.4.0")
		peakMemory = System.totalMemoryNumber;
		#else
		peakMemory = System.totalMemory;
		#end
	}

	public function setLogging(enabled:Bool):Void
	{
		logEnabled = enabled;
		if (logEnabled) {
			initLogFile();
		}
	}

	public function destroy():Void
	{
		removeEventListener(Event.ENTER_FRAME, onEnterFrame);
		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
	}
}