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
import game.backend.utils.MemoryUtil;

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

	public var strokeSize:Int = 1;
	public var strokeColor:Int = 0xFF000000;
	public var fillColor:Int = 0xFFFFFFFF;
	public var fontSize:Int = 11;
	public var fontCustom = "_sans";

	// Warning system
	public var performanceWarnings(default, null):Array<String> = [];
	public var warningLevel(default, null):Int = 0; // 0 = normal, 1 = warning, 2 = dangerous, 3 = critical
	private var lastWarningUpdate:Float = 0;
	private var warningUpdateInterval:Float = 2.0;

	// Warning thresholds
	private var warningThresholds = {
		fpsLow: 0.8,        // 80% of target FPS
		fpsVeryLow: 0.6,    // 60% of target FPS
		fpsCritical: 0.4,   // 40% of target FPS
		memoryHigh: 2e9,    // 2 GB
		memoryVeryHigh: 3e9, // 3 GB
		memoryCritical: 4e9, // 4 GB
		frameTimeHigh: 25.0, // 25ms (40 FPS)
		frameTimeVeryHigh: 40.0, // 40ms (25 FPS)
		systemMemoryLow: 0.21e9 // 200 MB free RAM
	};

	private var cacheCount:Int = 0;
	private var currentTime:Float = 0;
	private var times:Array<Float> = [];
	private var lastFrameTime:Float = 0;
	
	#if (openfl >= "9.4.0")
	private var peakMemory:Float = 0;
	#else
	private var peakMemory:UInt = 0;
	#end

	private var graphWidth:Int = 135;
	private var graphHeight:Int = 40;
	private var graphHistory:Array<Float> = [];
	private var maxGraphPoints:Int = 135;
	private var frameTimes:Array<Float> = [];
	private var maxFrameTimeHistory:Int = 20;

	private final dataTexts = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

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

	private var cachedBMD:BitmapData = null;
	private var lastUpdateTime:Float = 0;
	private var updateInterval:Float = 0.033;
	private var memoryReadings:Array<Float> = [];
	private var maxMemoryReadings:Int = 10;
	private var smoothMemory:Float = 0;
	private var availableSystemMemory:Float = 0;
	private var lastMemoryUpdate:Float = 0;
	private var memoryUpdateInterval:Float = 1.0;

	private var graphDirty:Bool = true;
	private var lastGraphUpdate:Float = 0;
	private var graphUpdateInterval:Float = 0.033;

	private var lastOutput:String = "";
	private var lastFPS:Int = -1;
	private var lastMem:Float = -1;

	// Performance analysis statistics
	private var lowFPSFrames:Int = 0;
	private var totalFrames:Int = 0;
	private var performanceScore:Float = 0;
	private var stabilityIssues:Int = 0;

	public function new(x:Float = 10, y:Float = 10, ?fillColor:Int = 0xFFFFFFFF)
	{
		super();
		this.x = x;
		this.y = y;
		this.fillColor = fillColor;
		lastFrameTime = Timer.stamp();
		lastStatReset = lastFrameTime;
		lastUpdateTime = lastFrameTime;
		lastMemoryUpdate = lastFrameTime;
		lastWarningUpdate = lastFrameTime;
		
		for (i in 0...maxMemoryReadings) {
			memoryReadings.push(0);
		}
		
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
			case Keyboard.F2:
				resetStats();
				keyCooldown = keyCooldownTime;
			case Keyboard.F3:
				toggleDebugInfo();
				keyCooldown = keyCooldownTime;
		}
	}

	inline function get_currentMemory():Float
	{
		return smoothMemory;
	}

	private function onEnterFrame(event:Event):Void
	{
		var currentTimeStamp = Timer.stamp();
		var deltaTime = currentTimeStamp - lastFrameTime;
		
		if (keyCooldown > 0) {
			keyCooldown -= deltaTime;
		}

		var currentTime = currentTimeStamp * 1000;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
			times.shift();

		var currentCount = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		currentFPS = Math.round(currentCount);

		if (currentTimeStamp - lastUpdateTime >= updateInterval) {
			updateMemoryStats(currentTimeStamp);
			updateStatistics();
			updateFrameTiming(deltaTime);
			
			if (currentTimeStamp - lastWarningUpdate >= warningUpdateInterval) {
				updatePerformanceWarnings();
				lastWarningUpdate = currentTimeStamp;
			}
			
			if (counterVisible) {
				var output = buildOutputString();
				if (output != lastOutput || currentFPS != lastFPS || smoothMemory != lastMem) {
					updateText(output);
					lastOutput = output;
					lastFPS = currentFPS;
					lastMem = smoothMemory;
				}
			}
			
			lastUpdateTime = currentTimeStamp;
		}

		if (currentTimeStamp - lastGraphUpdate >= graphUpdateInterval) {
			updateGraphs();
			lastGraphUpdate = currentTimeStamp;
		}
		
		if (logEnabled) {
			updateLogging(currentTimeStamp);
		}

		cacheCount = currentCount;
		lastFrameTime = currentTimeStamp;
	}

	private function updatePerformanceWarnings():Void
	{
		performanceWarnings = [];
		warningLevel = 0;
		
		var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
		
		if (currentFPS < targetFPS * warningThresholds.fpsCritical) {
			performanceWarnings.push("CRITICAL: Very low FPS!");
			warningLevel = 3;
		} else if (currentFPS < targetFPS * warningThresholds.fpsVeryLow) {
			performanceWarnings.push("WARNING: Low FPS");
			if (2 > warningLevel) warningLevel = 2;
		} else if (currentFPS < targetFPS * warningThresholds.fpsLow) {
			performanceWarnings.push("Notice: FPS below normal");
			if (1 > warningLevel) warningLevel = 1;
		}
		
		if (smoothMemory > warningThresholds.memoryCritical) {
			performanceWarnings.push("CRITICAL: Critical memory usage!");
			warningLevel = 3;
		} else if (smoothMemory > warningThresholds.memoryVeryHigh) {
			performanceWarnings.push("WARNING: High memory usage");
			if (2 > warningLevel) warningLevel = 2;
		} else if (smoothMemory > warningThresholds.memoryHigh) {
			performanceWarnings.push("Notice: Elevated memory usage");
			if (1 > warningLevel) warningLevel = 1;
		}
		
		if (frameTimes.length > 0) {
			var frameStats = getFrameTimingStats();
			if (frameStats.avg > warningThresholds.frameTimeVeryHigh) {
				performanceWarnings.push("WARNING: High frame time");
				if (2 > warningLevel) warningLevel = 2;
			} else if (frameStats.avg > warningThresholds.frameTimeHigh) {
				performanceWarnings.push("Notice: Elevated frame time");
				if (1 > warningLevel) warningLevel = 1;
			}
		}
		
		if (availableSystemMemory > 0 && availableSystemMemory < warningThresholds.systemMemoryLow) {
			performanceWarnings.push("WARNING: Low free system memory");
			if (2 > warningLevel) warningLevel = 2;
		}
		
		if (graphHistory.length > 10) {
			var stability = calculateFPSStability();
			if (stability < 0.7) {
				performanceWarnings.push("Notice: Unstable FPS");
				if (1 > warningLevel) warningLevel = 1;
			}
		}
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
		
		for (fps in graphHistory) {
			variance += (fps - averageFPS) * (fps - averageFPS);
		}
		variance /= graphHistory.length;
		
		var stability = 1.0 - (variance / (targetFPS * targetFPS));
		return Math.max(0, Math.min(1.0, stability));
	}

	private function updateMemoryStats(currentTime:Float):Void
	{
		var currentMem = MemoryUtil.getAccurateRamUsage();
		
		if (currentMem < 0) {
			#if (openfl >= "9.4.0")
			currentMem = System.totalMemoryNumber;
			#else
			currentMem = System.totalMemory;
			#end
		}
		
		memoryReadings.push(currentMem);
		if (memoryReadings.length > maxMemoryReadings) {
			memoryReadings.shift();
		}
		
		var total:Float = 0;
		for (reading in memoryReadings) {
			total += reading;
		}
		smoothMemory = total / memoryReadings.length;
		
		if (currentTime - lastMemoryUpdate >= memoryUpdateInterval) {
			availableSystemMemory = MemoryUtil.getAvailableSystemMemory();
			lastMemoryUpdate = currentTime;
		}
		
		if (currentMem > peakMemory) {
			peakMemory = currentMem;
		}
	}

	private function updateStatistics():Void
	{
		if (currentFPS < minFPS && currentFPS > 0) minFPS = currentFPS;
		if (currentFPS > maxFPS) maxFPS = currentFPS;
		
		fpsSamples++;
		totalFPS += currentFPS;
		avgFPS = totalFPS / fpsSamples;
		
		var targetFPS = ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate;
		if (currentFPS < targetFPS * 0.8) {
			lowFPSFrames++;
		}
		totalFrames++;
		
		var fpsScore = (currentFPS / targetFPS) * 60;
		fpsScore = Math.min(fpsScore, 60);
		
		var memoryRatio = Math.min(smoothMemory / 2e9, 1.0);
		var memoryScore = 40 * (1 - memoryRatio);
		
		var stabilityFactor = 0;
		if (stabilityIssues > 10) {
			stabilityFactor = -20;
		} else if (stabilityIssues > 5) {
			stabilityFactor = -10;
		} else if (stabilityIssues > 2) {
			stabilityFactor = -5;
		}
		
		performanceScore = fpsScore + memoryScore + stabilityFactor;
		performanceScore = Math.max(0, Math.min(100, performanceScore));
		
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
		lowFPSFrames = 0;
		totalFrames = 0;
		performanceScore = 100;
		stabilityIssues = 0;
		lastStatReset = Timer.stamp();
	}

	private function updateGraphs():Void
	{
		graphHistory.push(currentFPS);
		if (graphHistory.length > maxGraphPoints) {
			graphHistory.shift();
		}
		graphDirty = true;
	}

	private function updateFrameTiming(deltaTime:Float):Void
	{
		var frameTime = deltaTime * 1000;
		frameTimes.push(frameTime);
		if (frameTimes.length > maxFrameTimeHistory) {
			frameTimes.shift();
		}
		
		if (frameTimes.length >= 3) {
			var lastFrame = frameTimes[frameTimes.length - 1];
			var prevFrame = frameTimes[frameTimes.length - 2];
			if (lastFrame > prevFrame * 2.0 && lastFrame > 33.0) {
				stabilityIssues++;
			}
		}
	}

	private function updateLogging(currentTime:Float):Void
	{
		if (currentTime - logTimer > logInterval) {
			logData();
			logTimer = currentTime;
		}
	}

	private function buildOutputString():String
	{
		var output = 'FPS: $currentFPS / ${!ClientPrefs.vsync ? ClientPrefs.framerate : getDisplayRefreshRate()}';
		
		var memoryText = "RAM: " + getSizeLabel(smoothMemory);
		if (availableSystemMemory > 0) {
			memoryText += " / Sys: " + getSizeLabel(availableSystemMemory);
		}
		output += "\n" + memoryText;
		
		output += '\nRAM Peak: ${getSizeLabel(peakMemory)}';
		
		var performanceGrade = getPerformanceGrade();
		output += '\nPerformance: ${Math.round(performanceScore)}% (${performanceGrade})';
		
		if (performanceWarnings.length > 0) {
			output += "\n\n--- WARNINGS ---";
			for (warning in performanceWarnings) {
				output += "\n!" + warning;
			}
		}
		
		if (showDebugInfo) {
			output += "\n\n--- DETAILS ---";
			output += "\nMin/Max/Avg: " + minFPS + "/" + maxFPS + "/" + Math.round(avgFPS);
			output += "\nVSync: " + (ClientPrefs.vsync ? "ON" : "OFF");

			output += "\nGC RAM: " + flixel.util.FlxStringUtil.formatBytes(#if (openfl >= "9.4.0") System.totalMemoryNumber #else currentMem = System.totalMemory #end);
			
			if (frameTimes.length > 0) {
				var frameStats = getFrameTimingStats();
				output += "\nFrame: " + frameStats.avg + "ms (min: " + frameStats.min + "ms, max: " + frameStats.max + "ms)";
			}
			
			output += "\nStability: " + Math.round(calculateFPSStability() * 100) + "%";
			output += "\nProblem frames: " + stabilityIssues;
		}

		switch (warningLevel) {
			case 3: fillColor = 0xFFFF0000; // Red - critical
			case 2: fillColor = 0xFFFFFF00; // Yellow - dangerous
			case 1: fillColor = 0xFFFFA500; // Orange - warning
			default: fillColor = 0xFFFFFFFF; // White - normal
		}

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
		
		tf.antiAliasType = ADVANCED;
		tf.sharpness = 0;
		tf.gridFitType = PIXEL;

		var textWidth = tf.width + strokeSize * 2 + 4;
    	var textHeight = tf.height + strokeSize * 2 + 2;
		
		var totalWidth = textWidth;
		var totalHeight = textHeight;
		
		if (cachedBMD == null || cachedBMD.width != Math.ceil(totalWidth) || cachedBMD.height != Math.ceil(totalHeight)) {
			cachedBMD?.dispose();
			cachedBMD = new BitmapData(Math.ceil(totalWidth), Math.ceil(totalHeight), true, 0x00000000);
		} else {
			cachedBMD.fillRect(cachedBMD.rect, 0x00000000);
		}

		for (dx in -strokeSize...strokeSize + 1) {
			for (dy in -strokeSize...strokeSize + 1) {
				if (dx != 0 || dy != 0) {
					tf.textColor = strokeColor;
					cachedBMD.draw(tf, new Matrix(1, 0, 0, 1, strokeSize + dx, strokeSize + dy));
				}
			}
		}

		tf.textColor = fillColor;
		cachedBMD.draw(tf, new Matrix(1, 0, 0, 1, strokeSize, strokeSize));

		if (showDebugInfo && graphDirty && graphHistory.length > 1) {
			var debugWidth = Math.max(textWidth, graphWidth + strokeSize * 2);
			var debugHeight = textHeight + graphHeight + 5;
			
			if (cachedBMD.width != debugWidth || cachedBMD.height != debugHeight) {
				var newBMD = new BitmapData(Math.ceil(debugWidth), Math.ceil(debugHeight), true, 0x00000000);
				newBMD.copyPixels(cachedBMD, cachedBMD.rect, new openfl.geom.Point(0, 0));
				cachedBMD?.dispose();
				cachedBMD = newBMD;
			}
			
			drawGraph(cachedBMD, strokeSize, Std.int(textHeight + 5));
			graphDirty = false;
		}
		
		this.bitmapData = cachedBMD;
	}

	private function drawGraph(bmd:BitmapData, x:Int, y:Int):Void
	{
		if (graphHistory.length < 2) return;
    
		var graphX = x;
		var graphY = y;
		
		bmd.fillRect(new Rectangle(graphX, graphY, graphWidth, graphHeight), 0x88000000);
		
		for (i in 0...5) {
			var lineY = graphY + Std.int(graphHeight * i / 4);
			bmd.fillRect(new Rectangle(graphX, lineY, graphWidth, 1), 0x33FFFFFF);
		}
		
		for (i in 0...6) {
			var lineX = graphX + Std.int(graphWidth * i / 5);
			bmd.fillRect(new Rectangle(lineX, graphY, 1, graphHeight), 0x33FFFFFF);
		}
		
		var maxValue = Math.max(ClientPrefs.framerate, Math.max(currentFPS, getArrayMax(graphHistory)));
		if (maxValue < 1) maxValue = 1;
		
		var targetY = graphY + graphHeight - Std.int((ClientPrefs.framerate / maxValue) * graphHeight);
		bmd.fillRect(new Rectangle(graphX, targetY - 1, graphWidth, 3), 0xAA00FF00);
		
		var targetLabel = '${ClientPrefs.framerate}';
		var labelX = graphX + graphWidth - 15;
		var labelY = targetY - 8;
		bmd.fillRect(new Rectangle(labelX - 2, labelY - 1, 16, 10), 0xAA000000);
		bmd.fillRect(new Rectangle(labelX - 1, labelY, 14, 8), 0xAA00FF00);
		
		var points:Array<{x:Int, y:Int}> = [];
		var segmentCount = Std.int(Math.min(graphHistory.length, graphWidth));
		
		for (i in 0...segmentCount) {
			var historyIndex = graphHistory.length - segmentCount + i;
			if (historyIndex < 0) continue;
			
			var xPos = graphX + Std.int((i / segmentCount) * graphWidth);
			var yPos = graphY + graphHeight - Std.int((graphHistory[historyIndex] / maxValue) * graphHeight);
			
			yPos = Std.int(Math.max(graphY + 1, Math.min(graphY + graphHeight - 2, yPos)));
			xPos = Std.int(Math.max(graphX + 1, Math.min(graphX + graphWidth - 2, xPos)));
			
			points.push({x: xPos, y: yPos});
		}
		
		if (points.length >= 2) {
			for (i in 1...points.length) {
				var prev = points[i - 1];
				var curr = points[i];
				
				drawSmoothLine(bmd, prev.x, prev.y, curr.x, curr.y, fillColor, 2);
				drawSmoothLine(bmd, prev.x, prev.y + 1, curr.x, curr.y + 1, 0x66FFFFFF, 1);
			}
			
			var pointStep = Math.floor(points.length / 8);
			if (pointStep == 0) pointStep = 1;
			
			for (i in 0...points.length) {
				if (i % pointStep == 0) {
					var point = points[i];
					bmd.fillRect(new Rectangle(point.x - 2, point.y - 2, 5, 5), 0xAA000000);
					bmd.fillRect(new Rectangle(point.x - 1, point.y - 1, 3, 3), fillColor);
				}
			}
			
			var lastPoint = points[points.length - 1];
			bmd.fillRect(new Rectangle(lastPoint.x - 3, lastPoint.y - 3, 7, 7), 0xAA000000);
			bmd.fillRect(new Rectangle(lastPoint.x - 2, lastPoint.y - 2, 5, 5), 0xFFFFFF00);
			
			var lastFPS = graphHistory[graphHistory.length - 1];
			var fpsText = '${Math.round(lastFPS)}';
			var textX = lastPoint.x - 8;
			var textY = lastPoint.y - 12;
			bmd.fillRect(new Rectangle(textX - 1, textY - 1, 18, 10), 0xAA000000);
			bmd.fillRect(new Rectangle(textX, textY, 16, 8), 0xAAFFFFFF);
		}
		
		bmd.fillRect(new Rectangle(graphX, graphY, graphWidth, 1), 0x99FFFFFF);
		bmd.fillRect(new Rectangle(graphX, graphY + graphHeight - 1, graphWidth, 1), 0x99FFFFFF);
		bmd.fillRect(new Rectangle(graphX, graphY, 1, graphHeight), 0x99FFFFFF);
		bmd.fillRect(new Rectangle(graphX + graphWidth - 1, graphY, 1, graphHeight), 0x99FFFFFF);
	}

	private function drawSmoothLine(bmd:BitmapData, x1:Int, y1:Int, x2:Int, y2:Int, color:Int, thickness:Int = 1):Void
	{
		var dx = Math.abs(x2 - x1);
		var dy = Math.abs(y2 - y1);
		var sx = (x1 < x2) ? 1 : -1;
		var sy = (y1 < y2) ? 1 : -1;
		var err = dx - dy;
		
		var x = x1;
		var y = y1;
		
		var maxPoints = Math.max(dx, dy);
		var pointsDrawn = 0;
		
		while (pointsDrawn < maxPoints && pointsDrawn < 100) {
			for (tx in -thickness...thickness + 1) {
				for (ty in -thickness...thickness + 1) {
					var dist = Math.sqrt(tx * tx + ty * ty);
					if (dist <= thickness) {
						var px = x + tx;
						var py = y + ty;
						if (px >= 0 && px < bmd.width && py >= 0 && py < bmd.height) {
							bmd.setPixel32(px, py, color);
						}
					}
				}
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
			
			pointsDrawn++;
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
			var header = "Timestamp,FPS,Memory,PeakMemory,AvailableMemory,VSync,TargetFPS,PerformanceScore,Warnings\n";
			File.saveContent(logFile, header);
		} catch (e:Dynamic) {
			trace("Failed to create log file: " + e);
		}
	}

	private function logData():Void
	{
		try {
			var timestamp = Date.now().toString();
			var warnings = performanceWarnings.join("; ");
			var logLine = timestamp + "," + currentFPS + "," + smoothMemory + "," + peakMemory + "," + 
						 availableSystemMemory + "," + (ClientPrefs.vsync ? "ON" : "OFF") + "," + 
						 (ClientPrefs.vsync ? getDisplayRefreshRate() : ClientPrefs.framerate) + "," +
						 performanceScore + "," + warnings + "\n";
			
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
		graphDirty = true;
	}

	public function resetStats():Void
	{
		resetStatistics();
		graphHistory = [];
		frameTimes = [];
		memoryReadings = [];
		for (i in 0...maxMemoryReadings) {
			memoryReadings.push(0);
		}
		peakMemory = 0;
		performanceWarnings = [];
		warningLevel = 0;
		graphDirty = true;
		lastOutput = "";
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
		
		if (cachedBMD != null) {
			cachedBMD.dispose();
			cachedBMD = null;
		}
		
		if (this.bitmapData != null && this.bitmapData != cachedBMD) {
			this.bitmapData.dispose();
		}
	}
}