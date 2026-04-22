package game.backend.utils;

final class MemoryUtil {
    public static function enableGC(enable:Bool = true):Void {
        #if cpp
        cpp.NativeGc.enable(enable);
        cpp.vm.Gc.enable(enable);
        #elseif hl
        hl.Gc.enable(enable);
        #elseif java
        java.vm.Gc.run(enable);
        #end
    }

    public static function forceGC(enable:Bool = true):Void {
        #if cpp
        cpp.NativeGc.run(enable);
        cpp.vm.Gc.run(enable);
        #elseif hl
        if(enable) hl.Gc.major();
        #elseif java
        if(enable) java.lang.System.gc();
        #elseif neko
        neko.vm.Gc.run(enable);
        #else
        openfl.system.System.gc();
        #end
    }

    public static function memoryUsage():Int {
        #if cpp
        return cast cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
        #elseif java
        var runtime = java.lang.Runtime.getRuntime();
        return cast (runtime.totalMemory() - runtime.freeMemory());
        #else
        return -1;
        #end
    }

    public static function currentMemory():Int {
        #if cpp
        return cast cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_CURRENT);
        #else
        return -1;
        #end
    }

    public static function reservedMemory():Int {
        #if cpp
        return cast cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_RESERVED);
        #else
        return -1;
        #end
    }

    public static function largeMemory():Int {
        #if cpp
        return cast cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_LARGE);
        #else
        return -1;
        #end
    }

    public static function compact():Void {
        #if cpp
        cpp.NativeGc.compact();
        cpp.vm.Gc.compact();
        #elseif eval
        eval.Gc.compact();
        #end
    }

    public static function getMemoryStats():MemoryStats {
        var stats:MemoryStats = {
            usage: memoryUsage(),
            current: currentMemory(),
            reserved: reservedMemory(),
            large: largeMemory()
        };

        #if hl
        var hlStats = hl.Gc.stats();
        stats.hlTotalAllocated = Std.int(hlStats.totalAllocated);
        stats.hlAllocationCount = Std.int(hlStats.allocationCount);
        #end

        return stats;
    }

    public static function getAccurateRamUsage():Float {
        #if windows
        return WindowsMemoryAPI.getProcessMemoryUsage();
        #else
        return openfl.system.System.totalMemoryNumber;
        #end
    }

    public static function getPeakRamUsage():Float {
        #if windows
        return WindowsMemoryAPI.getPeakMemoryUsage();
        #else
        return getAccurateRamUsage();
        #end
    }

    public static function getAvailableSystemMemory():Float {
        #if windows
        return WindowsMemoryAPI.getAvailableSystemMemory();
        #else
        return -1;
        #end
    }
}

//С++ MY BELOVED <3
#if windows
@:buildXml("
<target id='haxe'>
    <lib name='psapi.lib' if='windows'/>
    <lib name='kernel32.lib' if='windows'/>
</target>
")
@:headerCode('
#include <windows.h>
#include <psapi.h>
')
final class WindowsMemoryAPI {
    public static function getProcessMemoryUsage(moreAccurate:Bool = true):Float {
        #if cpp
        var result:Float = -1.0;
        untyped __cpp__('
            PROCESS_MEMORY_COUNTERS_EX pmc;
            if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
                result = moreAccurate ? (double)pmc.WorkingSetSize : (double)pmc.PrivateUsage;
            }
        ');
        return result;
        #else
        return -1;
        #end
    }

    public static function getPeakMemoryUsage():Float {
        #if cpp
        var result:Float = -1.0;
        untyped __cpp__('
            PROCESS_MEMORY_COUNTERS_EX pmc;
            if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
                result = (double)pmc.PeakPagefileUsage;
            }
        ');
        return result;
        #else
        return -1;
        #end
    }

    public static function getAvailableSystemMemory():Float {
        #if cpp
        var result:Float = -1.0;
        untyped __cpp__('
            MEMORYSTATUSEX statex;
            statex.dwLength = sizeof(statex);
            if (GlobalMemoryStatusEx(&statex)) {
                result = (double)statex.ullAvailPhys;
            }
        ');
        return result;
        #else
        return -1;
        #end
    }
}
#end

typedef MemoryStats = {
    var usage:Int;
    var current:Int;
    var reserved:Int;
    var large:Int;

    @:optional var hlTotalAllocated:Int;
    @:optional var hlAllocationCount:Int;
}