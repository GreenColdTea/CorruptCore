package game.backend.plugins;

import haxe.Timer;

import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.system.System;
import openfl.text.AntiAliasType;
import openfl.text.GridFitType;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

import game.backend.utils.MemoryUtil;

#if sys
import sys.io.File;
#end

@:allow(Init)
class FPSCounterPlugin extends Sprite
{
	public var currentFPS(default, null):Int = 0;
	public var currentMemory(get, never):Float;
	public var showDebugInfo:Bool = false;
	public var strokeSize:Int = 1;
	public var strokeColor:Int = 0xFF000000;
	public var fillColor:Int = 0xFFFFFFFF;
	public var fontSize:Int = 11;
	public var fontCustom:String = "_sans";

	private var frameCount:Int = 0;
	private var lastFPSTime:Float = 0;
	
	private var lastFrameTime:Float = 0;
	private var lastUpdateTime:Float = 0;
	private var lastMemoryUpdate:Float = 0;
	private var lastWarningUpdate:Float = 0;
	private var lastGraphUpdate:Float = 0;
	private var lastStatReset:Float = 0;

	private var updateInterval:Float = 0.1;
	private var memoryUpdateInterval:Float = 1.0;
	private var warningUpdateInterval:Float = 2.0;
	private var graphUpdateInterval:Float = 0.12;

	private var memoryReadings:Array<Float> = [];
	private var vramReadings:Array<Float> = [];
	private var maxMemoryReadings:Int = 10;
	private var smoothMemory:Float = 0;
	private var smoothVRAM:Float = 0;
	private var availableSystemMemory:Float = 0;

	#if (openfl >= "9.4.0")
	private var peakMemory:Float = 0;
	private var peakVRAM:Float = 0;
	#else
	private var peakMemory:UInt = 0;
	private var peakVRAM:UInt = 0;
	#end

	private var graphWidth:Int = 135;
	private var graphHeight:Int = 40;
	private var graphHistory:Array<Float> = [];
	private var maxGraphPoints:Int = 135;
	private var frameTimes:Array<Float> = [];
	private var maxFrameTimeHistory:Int = 20;

	@:unreflective
	private final dataTexts = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

	private var minFPS:Int = 9999;
	private var maxFPS:Int = 0;
	private var avgFPS:Float = 0;
	private var fpsSamples:Int = 0;
	private var totalFPS:Float = 0;

	private var logEnabled:Bool = false;
	private var logFile:String = "fps_log.txt";
	private var logTimer:Float = 0;
	private var logInterval:Float = 1.0;

	private var counterVisible:Bool = true;
	private var keyCooldown:Float = 0;
	private var keyCooldownTime:Float = 0.2;

	private var graphDirty:Bool = true;
	private var lowFPSFrames:Int = 0;
	private var totalFrames:Int = 0;
	private var performanceScore:Float = 0;
	private var stabilityIssues:Int = 0;

	private var textFormat:TextFormat;
	private var shadowFormat:TextFormat;
	private var textField:TextField;
	private var shadowField:TextField;
	private var graphBitmap:Bitmap;
	private var graphBMD:BitmapData;

	private var lastOutput:String = "";
	private var lastFPS:Int = -1;
	private var lastMemBucket:Int = -1;
	private var lastShowDebugInfo:Bool = false;

	public function new(x:Float = 10, y:Float = 10, ?fillColor:Int = 0xFFFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;
		this.fillColor = fillColor;

		lastFrameTime = Timer.stamp();
		lastFPSTime = lastFrameTime;
		lastUpdateTime = lastFrameTime;
		lastMemoryUpdate = lastFrameTime;
		lastWarningUpdate = lastFrameTime;
		lastGraphUpdate = lastFrameTime;
		lastStatReset = lastFrameTime;

		for (i in 0...maxMemoryReadings)
		{
			memoryReadings.push(0);
			vramReadings.push(0);
		}

		textFormat = new TextFormat(fontCustom, fontSize, fillColor);
		shadowFormat = new TextFormat(fontCustom, fontSize, strokeColor);

		shadowField = createTextField();
		shadowField.defaultTextFormat = shadowFormat;
		shadowField.x = strokeSize;
		shadowField.y = strokeSize;
		addChild(shadowField);

		textField = createTextField();
		textField.defaultTextFormat = textFormat;
		addChild(textField);

		graphBMD = new BitmapData(graphWidth, graphHeight, true, 0x00000000);
		graphBitmap = new Bitmap(graphBMD);
		graphBitmap.visible = false;
		addChild(graphBitmap);

		if (logEnabled)
			initLogFile();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	private function createTextField():TextField
	{
		var tf = new TextField();
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.multiline = true;
		tf.wordWrap = false;
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.antiAliasType = AntiAliasType.ADVANCED;
		tf.gridFitType = GridFitType.PIXEL;
		tf.sharpness = 0;
		return tf;
	}

	inline function get_currentMemory():Float
	{
		return smoothMemory;
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		if (keyCooldown > 0) return;

		switch (event.keyCode)
		{
			case Keyboard.F2:
				resetDebugInfo();
				keyCooldown = keyCooldownTime;
			case Keyboard.F3:
				toggleDebugInfo();
				keyCooldown = keyCooldownTime;
		}
	}

	private function onEnterFrame(event:Event):Void
	{
		final now = Timer.stamp();
		final deltaTime = now - lastFrameTime;

		if (keyCooldown > 0)
			keyCooldown -= deltaTime;

		frameCount++;
		if (now - lastFPSTime >= 0.25)
		{
			var calculatedFPS = Math.round(frameCount / (now - lastFPSTime));
			var currentCount = calculatedFPS < FlxG.updateFramerate ? calculatedFPS : FlxG.updateFramerate;
			currentFPS = ClientPrefs.unlimitedFPS ? calculatedFPS : Math.round(currentCount);
			frameCount = 0;
			lastFPSTime = now;
		}

		updateFrameTiming(deltaTime);

		if (now - lastMemoryUpdate >= memoryUpdateInterval)
			updateMemoryStats(now);

		if (now - lastGraphUpdate >= graphUpdateInterval)
		{
			updateGraphs();
			lastGraphUpdate = now;
		}

		if (now - lastUpdateTime >= updateInterval)
		{
			updateStats();

			if (counterVisible)
			{
				final output = buildOutputString();
				final memBucket = Std.int(smoothMemory / (16 * 1024 * 1024));

				final needsVisualRefresh = output != lastOutput
					|| currentFPS != lastFPS
					|| memBucket != lastMemBucket
					|| showDebugInfo != lastShowDebugInfo;

				if (needsVisualRefresh)
				{
					updateText(output);
					lastOutput = output;
					lastFPS = currentFPS;
					lastMemBucket = memBucket;
					lastShowDebugInfo = showDebugInfo;
				}
			}

			lastUpdateTime = now;
		}

		if (logEnabled)
			updateLogging(now);

		lastFrameTime = now;
	}

	private function calculateFPSStability():Float
	{
		if (graphHistory.length < 10) return 1.0;

		var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
		var averageFPS = 0.0;
		var variance = 0.0;

		for (fps in graphHistory)
			averageFPS += fps;

		averageFPS /= graphHistory.length;

		for (fps in graphHistory)
			variance += (fps - averageFPS) * (fps - averageFPS);

		variance /= graphHistory.length;

		var stability = 1.0 - (variance / (targetFPS * targetFPS));
		return Math.max(0, Math.min(1.0, stability));
	}

	private function updateMemoryStats(currentTime:Float):Void
	{
		var currentMem = MemoryUtil.getAccurateRamUsage();
		var currentVRAMUsage = MemoryUtil.getVRAMUsage();

		if (currentMem < 0)
		{
			#if (openfl >= "9.4.0")
			currentMem = System.totalMemoryNumber;
			#else
			currentMem = System.totalMemory;
			#end
		}

		memoryReadings.push(currentMem);
		if (memoryReadings.length > maxMemoryReadings)
			memoryReadings.shift();

		var total:Float = 0;
		for (reading in memoryReadings)
			total += reading;

		smoothMemory = total / memoryReadings.length;

		vramReadings.push(currentVRAMUsage);
		if (vramReadings.length > maxMemoryReadings)
			vramReadings.shift();

		var totalVRAM:Float = 0;
		for (reading in vramReadings)
			totalVRAM += reading;
			
		smoothVRAM = totalVRAM / vramReadings.length;

		availableSystemMemory = MemoryUtil.getAvailableSystemMemory();
		lastMemoryUpdate = currentTime;

		if (currentMem > peakMemory)
			peakMemory = currentMem;
			
		if (currentVRAMUsage > peakVRAM)
			peakVRAM = currentVRAMUsage;
	}

	private function updateStats():Void
	{
		if (currentFPS < minFPS && currentFPS > 0) minFPS = currentFPS;
		if (currentFPS > maxFPS) maxFPS = currentFPS;

		fpsSamples++;
		totalFPS += currentFPS;
		avgFPS = totalFPS / fpsSamples;

		if (!ClientPrefs.unlimitedFPS)
		{
			var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
			if (currentFPS < targetFPS * 0.8)
				lowFPSFrames++;
		}

		totalFrames++;

		var fpsScore:Float;

		if (ClientPrefs.unlimitedFPS)
		{
			fpsScore = Math.min(currentFPS / 120.0 * 60.0, 60.0);
		}
		else
		{
			var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
			fpsScore = (currentFPS / targetFPS) * 60;
			fpsScore = Math.min(fpsScore, 60);
		}

		final memoryRatio = Math.min(smoothMemory / 2e9, 1.0);
		final memoryScore = 40 * (1 - memoryRatio);

		var stabilityFactor = 0;

		if (!ClientPrefs.unlimitedFPS && stabilityIssues > 10)
			stabilityFactor = -20;
		else if (!ClientPrefs.unlimitedFPS && stabilityIssues > 5)
			stabilityFactor = -10;
		else if (!ClientPrefs.unlimitedFPS && stabilityIssues > 2)
			stabilityFactor = -5;

		performanceScore = fpsScore + memoryScore + stabilityFactor;
		performanceScore = Math.max(0, Math.min(100, performanceScore));

		final now = Timer.stamp();

		if (now - lastStatReset > 30)
			resetStats();
	}

	private function resetStats():Void
	{
		minFPS = 9999;
		maxFPS = 0;
		avgFPS = 0;
		fpsSamples = 0;
		totalFPS = 0;
		lowFPSFrames = 0;
		totalFrames = 0;
		performanceScore = 100;
		stabilityIssues = 0;
		lastStatReset = Timer.stamp();
	}

	private function updateGraphs():Void
	{
		graphHistory.push(currentFPS);
		if (graphHistory.length > maxGraphPoints)
			graphHistory.shift();

		graphDirty = true;
	}

	private function updateFrameTiming(deltaTime:Float):Void
	{
		final frameTime = deltaTime * 1000;
		frameTimes.push(frameTime);

		if (frameTimes.length > maxFrameTimeHistory)
			frameTimes.shift();

		if (frameTimes.length >= 3)
		{
			final lastFrame = frameTimes[frameTimes.length - 1];
			final prevFrame = frameTimes[frameTimes.length - 2];

			if (lastFrame > prevFrame * 2.0 && lastFrame > 33.0)
				stabilityIssues++;
		}
	}

	private function updateLogging(currentTime:Float):Void
	{
		if (currentTime - logTimer > logInterval)
		{
			logData();
			logTimer = currentTime;
		}
	}

	private function buildOutputString():String
	{
		var fpsText:String = null;

		if (ClientPrefs.unlimitedFPS)
		{
			fpsText = 'FPS: $currentFPS (Unlimited)';
		}
		else
		{
			var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
			fpsText = 'FPS: $currentFPS / $targetFPS';
		}

		var output = fpsText;

		var memoryText = "RAM: " + getSizeLabel(smoothMemory);
		if (availableSystemMemory > 0)
			memoryText += " / " + getSizeLabel(availableSystemMemory);

		output += "\n" + memoryText;
		
		if (smoothVRAM > 0) {
			output += "\nVRAM: " + getSizeLabel(smoothVRAM);
			output += '\nRAM Peak: ${getSizeLabel(peakMemory)} | VRAM Peak: ${getSizeLabel(peakVRAM)}';
		} else {
			output += '\nRAM Peak: ${getSizeLabel(peakMemory)}';
		}

		var performanceGrade = getPerformanceGrade();
		output += '\nPerformance: ${Math.round(performanceScore)}% (${performanceGrade})';

		if (showDebugInfo)
		{
			output += "\n\n--- DETAILS ---";
			output += "\nMin/Max/Avg: " + minFPS + "/" + maxFPS + "/" + Math.round(avgFPS);
			output += "\nVSync: " + (ClientPrefs.vsync ? "ON" : "OFF");
			output += "\nUnlimited FPS: " + (ClientPrefs.unlimitedFPS ? "ON" : "OFF");

			#if (openfl >= "9.4.0")
			output += "\nGC RAM: " + flixel.util.FlxStringUtil.formatBytes(System.totalMemoryNumber);
			#else
			output += "\nGC RAM: " + flixel.util.FlxStringUtil.formatBytes(System.totalMemory);
			#end

			if (frameTimes.length > 0)
			{
				var frameStats = getFrameTimingStats();
				output += "\nFrame: " + frameStats.avg + "ms (min: " + frameStats.min + "ms, max: " + frameStats.max + "ms)";
			}

			if (!ClientPrefs.unlimitedFPS)
				output += "\nStability: " + Math.round(calculateFPSStability() * 100) + "%";

			output += "\nProblem frames: " + stabilityIssues;
		}

		fillColor = 0xFFFFFFFF;

		return output;
	}

	private function getPerformanceGrade():String
	{
		if (performanceScore >= 90) return "Excellent";
		if (performanceScore >= 75) return "Good";
		if (performanceScore >= 60) return "Normal";
		if (performanceScore >= 40) return "Poor";
		return "Very poor";
	}

	private function getFrameTimingStats():{avg:Float, min:Float, max:Float}
	{
		var avg:Float = 0;
		var min:Float = 1000;
		var max:Float = 0;

		for (time in frameTimes)
		{
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

	private static function getDisplayRefreshRate():Int
	{
		final window = Lib.application.window;
		if (window?.display?.currentMode != null)
			return window.display.currentMode.refreshRate;
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
		textFormat.font = fontCustom;
		textFormat.size = fontSize;
		textFormat.color = fillColor;

		shadowFormat.font = fontCustom;
		shadowFormat.size = fontSize;
		shadowFormat.color = strokeColor;

		textField.defaultTextFormat = textFormat;
		shadowField.defaultTextFormat = shadowFormat;

		textField.text = content;
		shadowField.text = content;

		textField.textColor = fillColor;
		shadowField.textColor = strokeColor;

		shadowField.x = strokeSize;
		shadowField.y = strokeSize;
		textField.x = 0;
		textField.y = 0;

		if (showDebugInfo)
		{
			graphBitmap.visible = true;

			if (graphDirty)
			{
				graphBMD.fillRect(graphBMD.rect, 0x00000000);
				drawGraph(graphBMD, 0, 0);
				graphBitmap.bitmapData = graphBMD;
				graphDirty = false;
			}

			var textBottom = Math.ceil(Math.max(textField.height, shadowField.height));
			graphBitmap.x = 0;
			graphBitmap.y = textBottom + 5;
		}
		else
		{
			graphBitmap.visible = false;
		}
	}

	private function drawGraph(bmd:BitmapData, x:Int, y:Int):Void
	{
		if (graphHistory.length < 2) return;

		final graphX = x;
		final graphY = y;

		bmd.fillRect(new Rectangle(graphX, graphY, graphWidth, graphHeight), 0x88000000);

		for (i in 0...5)
		{
			var lineY = graphY + Std.int(graphHeight * i / 4);
			bmd.fillRect(new Rectangle(graphX, lineY, graphWidth, 1), 0x33FFFFFF);
		}

		for (i in 0...6)
		{
			var lineX = graphX + Std.int(graphWidth * i / 5);
			bmd.fillRect(new Rectangle(lineX, graphY, 1, graphHeight), 0x33FFFFFF);
		}

		var maxValue = Math.max(ClientPrefs.framerate, Math.max(currentFPS, getArrayMax(graphHistory)));
		if (maxValue < 1) maxValue = 1;

		if (!ClientPrefs.unlimitedFPS)
		{
			var targetY = graphY + graphHeight - Std.int((ClientPrefs.framerate / maxValue) * graphHeight);
			bmd.fillRect(new Rectangle(graphX, targetY - 1, graphWidth, 3), 0xAA00FF00);
		}

		var points:Array<{x:Int, y:Int}> = [];
		var segmentCount = Std.int(Math.min(graphHistory.length, graphWidth));

		for (i in 0...segmentCount)
		{
			var historyIndex = graphHistory.length - segmentCount + i;
			if (historyIndex < 0) continue;

			var xPos = graphX + Std.int((i / segmentCount) * graphWidth);
			var yPos = graphY + graphHeight - Std.int((graphHistory[historyIndex] / maxValue) * graphHeight);
			
			yPos = Std.int(Math.max(graphY + 1, Math.min(graphY + graphHeight - 2, yPos)));
			xPos = Std.int(Math.max(graphX + 1, Math.min(graphX + graphWidth - 2, xPos)));

			points.push({x: xPos, y: yPos});
		}

		if (points.length >= 2)
		{
			for (i in 1...points.length)
			{
				var prev = points[i - 1];
				var curr = points[i];
				drawSmoothLine(bmd, prev.x, prev.y, curr.x, curr.y, fillColor, 2);
			}

			var lastPoint = points[points.length - 1];
			bmd.fillRect(new Rectangle(lastPoint.x - 2, lastPoint.y - 2, 5, 5), 0xFFFFFF00);
		}

		bmd.fillRect(new Rectangle(graphX, graphY, graphWidth, 1), 0x99FFFFFF);
		bmd.fillRect(new Rectangle(graphX, graphY + graphHeight - 1, graphWidth, 1), 0x99FFFFFF);
		bmd.fillRect(new Rectangle(graphX, graphY, 1, graphHeight), 0x99FFFFFF);
		bmd.fillRect(new Rectangle(graphX + graphWidth - 1, graphY, 1, graphHeight), 0x99FFFFFF);
	}

	private function drawSmoothLine(bmd:BitmapData, x1:Int, y1:Int, x2:Int, y2:Int, color:Int, thickness:Int = 1):Void
	{
		final dx = Math.abs(x2 - x1);
		final dy = Math.abs(y2 - y1);
		final sx = (x1 < x2) ? 1 : -1;
		final sy = (y1 < y2) ? 1 : -1;

		var err = dx - dy;
		var x = x1;
		var y = y1;

		final maxPoints = Math.max(dx, dy);
		var pointsDrawn = 0;

		while (pointsDrawn < maxPoints && pointsDrawn < 100)
		{
			bmd.fillRect(new Rectangle(x - thickness, y - thickness, thickness * 2, thickness * 2), color);

			if (x == x2 && y == y2) break;

			final e2 = 2 * err;
			
			if (e2 > -dy)
			{
				err -= dy;
				x += sx;
			}
			if (e2 < dx)
			{
				err += dx;
				y += sy;
			}

			pointsDrawn++;
		}
	}

	private function getArrayMax(arr:Array<Float>):Float
	{
		var max = arr[0];
		for (i in 1...arr.length)
			if (arr[i] > max) max = arr[i];
		return max;
	}

	private function initLogFile():Void
	{
		#if sys
		try
		{
			var header = "Timestamp,FPS,Memory,PeakMemory,AvailableMemory,VSync,TargetFPS,PerformanceScore,Warnings\n";
			File.saveContent(logFile, header);
		}
		catch (e:Dynamic)
		{
			trace("Failed to create log file: " + e);
		}
		#end
	}

	private function logData():Void
	{
		#if sys
		try
		{
			final timestamp = Date.now().toString();
			
			final logLine = timestamp + "," + currentFPS + "," + smoothMemory + "," + peakMemory + "," +
				availableSystemMemory + "," + (ClientPrefs.vsync ? "ON" : "OFF") + "," +
				(ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate) + "," +
				performanceScore + "\n";
				
			File.saveContent(logFile, File.getContent(logFile) + logLine);
		}
		catch (e:Dynamic)
		{
			trace("Failed to write log: " + e);
		}
		#end
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1):Void
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	public function toggleDebugInfo():Void
	{
		showDebugInfo = !showDebugInfo;
		graphDirty = true;
		lastOutput = "";
	}

	public function resetDebugInfo():Void
	{
		resetStats();
		graphHistory = [];
		frameTimes = [];
		memoryReadings = [];
		vramReadings = [];
		
		for (i in 0...maxMemoryReadings)
		{
			memoryReadings.push(0);
			vramReadings.push(0);
		}
		
		peakMemory = 0;
		peakVRAM = 0;
		graphDirty = true;
		lastOutput = "";
		lastFPS = -1;
		lastMemBucket = -1;
	}

	public function setLogging(enabled:Bool):Void
	{
		logEnabled = enabled;
		if (logEnabled)
			initLogFile();
	}

	public function destroy():Void
	{
		removeEventListener(Event.ENTER_FRAME, onEnterFrame);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);

		if (graphBitmap != null)
		{
			if (contains(graphBitmap))
				removeChild(graphBitmap);

			graphBitmap.bitmapData = null;
			graphBitmap = null;
		}

		if (graphBMD != null)
		{
			graphBMD.dispose();
			graphBMD = null;
		}

		if (textField != null)
		{
			if (contains(textField))
				removeChild(textField);

			textField = null;
		}

		if (shadowField != null)
		{
			if (contains(shadowField))
				removeChild(shadowField);
			
			shadowField = null;
		}
	}
}