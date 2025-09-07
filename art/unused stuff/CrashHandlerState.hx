package game.states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.Lib;
import openfl.system.System;
import haxe.io.Bytes;
import lime.system.System as LimeSystem;

#if windows
import game.backend.utils.WindowsRegistry;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class CrashHandlerState extends MusicBeatState
{	
	final warningMessage:String;
	
	final continueCallback:Void->Void;
	
	public function new(warningMessage:String, continueCallback:Void->Void)
	{
		this.continueCallback = continueCallback;
		this.warningMessage = warningMessage;
		super();
	}
	
	override function create()
	{
		@:nullSafety(Off)
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		FlxTransitionableState.skipNextTransOut = true;
		FlxTransitionableState.skipNextTransIn = true;

		FlxG.sound.playMusic(Paths.music("NO-WAY!"));
		
		#if sys
		try {
			if (!FileSystem.exists("logs")) {
				FileSystem.createDirectory("logs");
			}
			
			var now = Date.now();
			var timestamp = '${now.getFullYear()}-${lpad(Std.string(now.getMonth() + 1), "0", 2)}'
				+ '-${lpad(Std.string(now.getDate()), "0", 2)}_${lpad(Std.string(now.getHours()), "0", 2)}'
				+ '-${lpad(Std.string(now.getMinutes()), "0", 2)}-${lpad(Std.string(now.getSeconds()), "0", 2)}';
			
			var logPath = 'logs/crash_$timestamp.txt';
			var logContent = new StringBuf();
			
			logContent.add('======================= CRASH LOG =======================\n\n');
			
			logContent.add('CRASH TIME: ${now.toString()}\n');
			logContent.add('\n${warningMessage}\n');
			
			logContent.add('==================== SYSTEM INFORMATION ==================\n\n');

			var osInfo = "Unknown";
			#if windows
			try {
				var windowsCurrentVersionPath = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion";
				var buildStr = WindowsRegistry.getKey(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, "CurrentBuildNumber");
				var buildNumber:Int = 0;
				if (buildStr != null) {
					var parsed = Std.parseInt(buildStr);
					if (parsed != null) buildNumber = parsed;
				}
				var edition = WindowsRegistry.getKey(HKEY_LOCAL_MACHINE, windowsCurrentVersionPath, "ProductName");
				if (edition == null) edition = "Windows";
				
				if (buildNumber >= 22000) { // win 11
					edition = edition.replace("Windows 10", "Windows 11");
				}
				osInfo = edition;
			} catch (e:Dynamic) {
				osInfo = 'Windows ${LimeSystem.platformVersion}';
			}
			#else
			osInfo = '${LimeSystem.platformLabel} ${LimeSystem.platformVersion}';
			#end
			
			// arch
			var arch = "Unknown";
			try {
				arch = Sys.getEnv("PROCESSOR_ARCHITECTURE");
			} catch(e:Dynamic) {}
			logContent.add('Architecture: ${arch.toString().replace("AMD", "ARM")}\n'); // tf is amd lol
			
			logContent.add('Screen: ${FlxG.stage.window.width}x${FlxG.stage.window.height}\n');
			
			logContent.add('\n------ HARDWARE INFORMATION ------\n');
			logContent.add('CPU: ${getCpuInfo()}\n');
			logContent.add('GPU: ${getGpuInfo()}\n');
			logContent.add('RAM: ${getRamInfo()}\n');
			
			logContent.add('\n------ LIBRARY VERSIONS ------\n');
			logContent.add('Haxe: ${haxe.macro.Compiler.getDefine("haxe")}\n');

			var flxVer = FlxG.VERSION.toString();
			logContent.add('Flixel: ${flxVer.replace("HaxeFlixel ", "")}\n');
			
			logContent.add('\n------ SYSTEM RESOURCES ------\n');
			logContent.add('Memory Usage: ${Math.round(System.totalMemory / 1024 / 1024 * 100)/100} MB\n');
			
			File.saveContent(logPath, logContent.toString());
		} catch (e:Dynamic) {
			trace('Failed to save crash log: $e');
		}
		#end
		
		var error = new FlxText(0, 0, 0, 'CRASH HAS OCCURED!', 46);
		error.setFormat(Paths.font('vcr.ttf'), 46, FlxColor.RED, LEFT, OUTLINE, FlxColor.BLACK);
		error.screenCenter(X);
		error.y = 25;
		add(error);
		
		var text = new FlxText(25, 0, FlxG.width - 50, warningMessage, 32);
		text.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(text);
		text.screenCenter(Y);
		
		var text = new FlxText(0, FlxG.height - 25 - 32, FlxG.width, 'Press ACCEPT to go to main menu', 32);
		text.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(text);

		FlxTween.tween(error, {y: error.y + 45}, 2, {ease: FlxEase.sineInOut, type: PINGPONG});
		
		super.create();
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (controls.ACCEPT)
		{
			persistentUpdate = false;
			FlxG.sound.playMusic(Paths.music("freakyMenu"));
			continueCallback();
		}
	}
	
	static function lpad(value:String, pad:String, length:Int):String 
	{
		while (value.length < length) value = pad + value;
		return value;
	}
	
	static function getCpuInfo():String 
	{
		#if sys
		try {
			#if windows
			try {
				return WindowsRegistry.getKey(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "ProcessorNameString");
			} catch(e:Dynamic) {}
			
			//fallback to WMIC
			var process = new Process("wmic", ["cpu", "get", "name"]);
			var result = process.stdout.readAll().toString();
			process.close();
			
			var lines = result.split("\n");
			for (line in lines) {
				if (line.trim() != "" && line.indexOf("Name") == -1) {
					return line.trim();
				}
			}
			#elseif linux
			var process = new Process("cat", ["/proc/cpuinfo"]);
			var result = process.stdout.readAll().toString();
			process.close();
			
			var lines = result.split("\n");
			for (line in lines) {
				if (line.indexOf("model name") == 0) {
					return line.substring(line.indexOf(":") + 2);
				}
			}
			#elseif mac
			var process = new Process("sysctl", ["-n", "machdep.cpu.brand_string"]);
			var result = process.stdout.readAll().toString().trim();
			process.close();
			return result;
			#end
		} catch (e:Dynamic) {}
		#end
		return "Unknown CPU";
	}
	
	static function getGpuInfo():String 
	{
		#if sys
		try {
			#if windows
			try {
				return WindowsRegistry.getKey(HKEY_LOCAL_MACHINE, "SYSTEM\\CurrentControlSet\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}\\0000", "DriverDesc");
			} catch(e:Dynamic) {}
			
			//fallback to WMIC
			var process = new Process("wmic", ["path", "win32_VideoController", "get", "name"]);
			var result = process.stdout.readAll().toString();
			process.close();
			
			var lines = result.split("\n");
			for (line in lines) {
				if (line.trim() != "" && line.indexOf("Name") == -1) {
					return line.trim();
				}
			}
			#elseif linux
			var process = new Process("lspci", []);
			var result = process.stdout.readAll().toString();
			process.close();
			
			var lines = result.split("\n");
			for (line in lines) {
				if (line.indexOf("VGA") != -1 || line.indexOf("3D") != -1) {
					var parts = line.split(":");
					if (parts.length > 1) return parts[parts.length-1].trim();
				}
			}
			#elseif mac
			var process = new Process("system_profiler", ["SPDisplaysDataType"]);
			var result = process.stdout.readAll().toString();
			process.close();
			
			var lines = result.split("\n");
			for (line in lines) {
				if (line.indexOf("Chipset Model") != -1) {
					var parts = line.split(":");
					if (parts.length > 1) return parts[1].trim();
				}
			}
			#end
		} catch (e:Dynamic) {}
		#end
		return "Unknown GPU";
	}
	
	static function getRamInfo():String 
	{
		#if sys
		try {
			#if windows
			var totalMemBytes:Float = winapi.WindowsAPI.obtainRAM();
			if (!Math.isNaN(totalMemBytes)) {
				var gb = Math.round(totalMemBytes / 1024 * 100) / 100;
				return '${gb} GB';
			}
			#else
			//fallback to system commands
			var total = 0.0;
			
			if (Sys.systemName() == "Windows") {
				var process = new Process("wmic", ["computersystem", "get", "totalphysicalmemory"]);
				var result = process.stdout.readAll().toString();
				process.close();
				
				var lines = result.split("\n");
				for (line in lines) {
					if (line.trim() != "" && line.indexOf("TotalPhysicalMemory") == -1) {
						total = Std.parseFloat(line.trim());
						break;
					}
				}
			}
			else if (Sys.systemName() == "Linux") {
				var process = new Process("grep", ["MemTotal", "/proc/meminfo"]);
				var result = process.stdout.readAll().toString();
				process.close();
				
				var tokens = result.split(" ").filter(function(token) return token.trim() != "");
				if (tokens.length > 1) {
					total = Std.parseFloat(tokens[1]) * 1024;  // convert kB to bytes
				}
			}
			else if (Sys.systemName() == "Mac") {
				var process = new Process("sysctl", ["-n", "hw.memsize"]);
				total = Std.parseFloat(process.stdout.readAll().toString().trim());
				process.close();
			}
			
			if (!Math.isNaN(total) && total > 0) {
				var gb = Math.round(total / 1024 / 1024 / 1024 * 100) / 100;
				return '${gb} GB';
			}
			#end
		} catch (e:Dynamic) {}
		#end
		return "Unknown RAM";
	}
}