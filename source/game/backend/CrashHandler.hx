package game.backend;

import openfl.events.UncaughtErrorEvent;
import openfl.events.ErrorEvent;
import openfl.errors.Error;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Exception;
import flixel.FlxG;
import lime.system.System;
import openfl.system.System as OpenFlSystem;
import game.backend.utils.CoolUtil;
import game.states.MainMenuState;

using StringTools;

enum AudioStatus {
    PAUSE;
    RESUME;
    STOP;
}

class CrashHandler
{
    @:unreflective
    static final LOGS_DIR = "logs/";
    
    public static function init():Void
    {
        try {
            openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
            #if cpp
            untyped __global__.__hxcpp_set_critical_error_handler(onError);
            #elseif hl
            hl.Api.setErrorHandler(onError);
            #end
        } catch (e:Exception) {
            trace("Failed to initialize crash handler: " + e.message);
        }
    }

    private static function onUncaughtError(e:UncaughtErrorEvent):Void
    {
        e.preventDefault();
        e.stopPropagation();
        e.stopImmediatePropagation();

        var message = parseErrorMessage(e.error);
        var stack = formatExceptionStack(haxe.CallStack.exceptionStack());
        
        handleCrash(message, stack);
    }

    #if (cpp || hl)
    private static function onError(message:Dynamic):Void
    {
        var log = [];
        if (message != null && Std.string(message).length > 0)
            log.push(Std.string(message));
            
        log.push(formatExceptionStack(haxe.CallStack.exceptionStack(true)));
        handleCrash(log.join('\n'), "");
    }
    #end

    private static function parseErrorMessage(error:Dynamic):String
    {
        return if (Std.isOfType(error, Error)) {
            cast(error, Error).message;
        } else if (Std.isOfType(error, ErrorEvent)) {
            cast(error, ErrorEvent).text;
        } else {
            Std.string(error);
        }
    }

    private static function formatExceptionStack(stack:Array<haxe.CallStack.StackItem>):String {
        var result = "";
        for (item in stack) {
            switch(item) {
                case FilePos(item, file, line):
                    result += 'at ${formatStackItem(item)} ($file: $line line)\n';
                    
                case Method(classname, method):
                    result += 'in ${classname}.$method\n';
                    
                case Module(module):
                    result += 'in module $module\n';
                    
                case CFunction:
                    result += "in C function\n";
                    
                case _:
                    result += 'in ${Std.string(item)}\n';
            }
        }
        return result;
    }

    private static function formatStackItem(item:haxe.CallStack.StackItem):String {
        return switch(item) {
            case Method(classname, method): '$classname.$method';
            case Module(module): 'module $module';
            case CFunction: "C function";
            case FilePos(_, file, line): '$file:$line';
            case _: Std.string(item);
        };
    }

    private static function handleCrash(message:String, stack:String):Void
    {
        var fullError = 'CRASH DETAILS:\n$message\n\nSTACK TRACE:\n$stack';
        
        #if sys
        saveCrashLog(fullError);
        #end
        
        switchAudioStatus(PAUSE);
        showErrorPopup(fullError);
        
        try {
            switchAudioStatus(RESUME);

            FlxG.sound.playMusic(Paths.music('freakyMenu'));

            FlxTransitionableState.skipNextTransIn = true;
            FlxTransitionableState.skipNextTransOut = true;
            FlxG.switchState(MainMenuState.new);
        } catch (e:Dynamic) {
            switchAudioStatus(STOP);
            trace("Failed to switch to MainMenuState: " + e);
            #if sys
            System.exit(1);
            #elseif js
            js.Browser.window.location.reload();
            #end
        }
    }

    private static function switchAudioStatus(status:AudioStatus):Void
    {
        switch(status)
        {
            case PAUSE:
                FlxG.sound?.music?.pause();
                if (FlxG.sound != null && FlxG.sound.list != null) {
                    for (sound in FlxG.sound.list) {
                        if (sound != null && sound.playing) {
                            sound.pause();
                        }
                    }
                }
            case RESUME:
                FlxG.sound?.music?.resume();
                if (FlxG.sound != null && FlxG.sound.list != null) {
                    for (sound in FlxG.sound.list) {
                        if (sound != null && sound.playing) {
                            sound.resume();
                        }
                    }
                }
            case STOP:
                FlxG.sound?.music?.stop();
                if (FlxG.sound != null && FlxG.sound.list != null) {
                    for (sound in FlxG.sound.list) {
                        if (sound != null && sound.playing) {
                            sound.stop();
                        }
                    }
                }
        }
    }

    private static function showErrorPopup(message:String):Void
    {
        try {
            CoolUtil.showPopUp(message, "Error!", #if sl_windows_api MSG_ERROR #end);
        } catch (e:Dynamic) {
            trace("Failed to show error popup: " + e);
        }
    }

    #if sys
    private static function saveCrashLog(content:String):Void
    {
        try {
            if (!FileSystem.exists(LOGS_DIR)) {
                FileSystem.createDirectory(LOGS_DIR);
            }
            
            var now = Date.now();
            var timestamp = '${now.getFullYear()}-${lpad(Std.string(now.getMonth() + 1), "0", 2)}'
                + '-${lpad(Std.string(now.getDate()), "0", 2)}_${lpad(Std.string(now.getHours()), "0", 2)}'
                + '-${lpad(Std.string(now.getMinutes()), "0", 2)}-${lpad(Std.string(now.getSeconds()), "0", 2)}';
            
            var fileName = LOGS_DIR + 'crash_$timestamp.txt';
            
            var logContent = new StringBuf();
            logContent.add('======================= CRASH LOG =======================\n\n');
            logContent.add('CRASH TIME: ${now.toString()}\n');
            logContent.add('\n${content}\n');
            logContent.add('==================== SYSTEM INFORMATION ==================\n\n');

            var osInfo = '${System.platformLabel} ${System.platformVersion}';
            
            var arch = "Unknown";
            try {
                arch = Sys.getEnv("PROCESSOR_ARCHITECTURE");
            } catch(e:Dynamic) {}
            logContent.add('Architecture: ${arch.toString().replace("AMD", "ARM")}\n');
            
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
            logContent.add('Memory Usage: ${Math.round(#if (openfl >= "9.4.0") OpenFlSystem.totalMemoryNumber #else OpenFlSystem.totalMemory #end / 1024 / 1024 * 100)/100} MB\n');
            
            File.saveContent(fileName, logContent.toString());
        } catch (e:Exception) {
            trace('Failed to save crash log: ${e.message}');
        }
    }
    
    private static function lpad(value:String, pad:String, length:Int):String 
    {
        while (value.length < length) value = pad + value;
        return value;
    }
    
    private static function getCpuInfo():String 
    {
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
        return "Unknown CPU";
    }
    
    private static function getGpuInfo():String 
    {
        try {
            var gpuName:String = "N/A";
            @:privateAccess {
                if (FlxG.stage?.context3D?.gl != null) {
                    var renderer = FlxG.stage.context3D.gl.getParameter(FlxG.stage.context3D.gl.RENDERER);
                    if (renderer != null) {
                        gpuName = Std.string(renderer).split("/")[0].trim();
                        if (gpuName != "N/A" && gpuName != "") {
                            return gpuName;
                        }
                    }
                }
            }
        } catch (e:Dynamic) {}

        return "Unknown GPU";
    }
    
    private static function getRamInfo():String 
    {
        try {
            #if sl_windows_api
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
                    total = Std.parseFloat(tokens[1]) * 1024;
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
        return "Unknown RAM";
    }
    #end
}