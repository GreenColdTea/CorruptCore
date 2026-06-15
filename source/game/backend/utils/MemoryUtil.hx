package game.backend.utils;

typedef MemoryStats = {
    var usage:Int;
    var current:Int;
    var reserved:Int;
    var large:Int;
	@:optional var hlTotalAllocated:Int;
    @:optional var hlAllocationCount:Int;
}

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
		#if cpp
		return NativeMemory.getProcessMemoryUsage();
		#else
		return openfl.system.System.totalMemoryNumber;
		#end
	}

	public static function getPeakRamUsage():Float {
		#if cpp
		return NativeMemory.getPeakMemoryUsage();
		#else
		return getAccurateRamUsage();
		#end
	}

	public static function getAvailableSystemMemory():Float {
		#if cpp
		return NativeMemory.getAvailableSystemMemory();
		#else
		return -1;
		#end
	}

    public static function getVRAMUsage():Float {
		#if cpp
		return NativeMemory.getVRAMUsage();
		#else
		return -1;
		#end
	}
}

//С++ MY BELOVED <3
#if cpp
#if windows
@:buildXml("
<target id='haxe'>
    <lib name='psapi.lib' if='windows'/>
    <lib name='kernel32.lib' if='windows'/>
    <lib name='dxgi.lib' if='windows'/> 
</target>
")
@:headerCode('
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#include <dxgi1_4.h>

#undef NO_ERROR
#undef IGNORE
#undef TRANSPARENT
#undef OPAQUE
#undef NEAR
#undef FAR
')
#elseif linux
@:headerCode('
#include <unistd.h>
#include <sys/sysinfo.h>
#include <fstream>
#include <string>
')
#elseif mac
@:headerCode('
#include <mach/mach.h>
#include <sys/sysctl.h>
')
#end
final class NativeMemory {
	public static function getProcessMemoryUsage():Float {
		#if windows
		var result:Float = -1.0;
		untyped __cpp__('
			PROCESS_MEMORY_COUNTERS_EX pmc;
			if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
				result = (double)pmc.WorkingSetSize;
			}
		');
		return result;
		#elseif linux
		var result:Float = -1.0;
		untyped __cpp__('
			long rss = 0;
			std::ifstream stat_stream("/proc/self/statm", std::ios_base::in);
			if (stat_stream.is_open()) {
				long size, resident;
				stat_stream >> size >> resident;
				stat_stream.close();
				rss = resident * sysconf(_SC_PAGE_SIZE);
				result = (double)rss;
			}
		');
		return result;
		#elseif mac
		var result:Float = -1.0;
		untyped __cpp__('
			struct mach_task_basic_info info;
			mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
			if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &infoCount) == KERN_SUCCESS) {
				result = (double)info.resident_size;
			}
		');
		return result;
		#else
		return openfl.system.System.totalMemoryNumber;
		#end
	}

	public static function getPeakMemoryUsage():Float {
		#if windows
		var result:Float = -1.0;
		untyped __cpp__('
			PROCESS_MEMORY_COUNTERS_EX pmc;
			if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
				result = (double)pmc.PeakWorkingSetSize;
			}
		');
		return result;
		#elseif linux
		var result:Float = -1.0;
		untyped __cpp__('
			std::ifstream status_stream("/proc/self/status");
			std::string line;
			if (status_stream.is_open()) {
				while (std::getline(status_stream, line)) {
					if (line.compare(0, 6, "VmHWM:") == 0) {
						size_t hwm = std::stoull(line.substr(6));
						result = (double)(hwm * 1024);
						break;
					}
				}
			}
		');
		return result;
		#elseif mac
		var result:Float = -1.0;
		untyped __cpp__('
			struct mach_task_basic_info info;
			mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
			if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &infoCount) == KERN_SUCCESS) {
				result = (double)info.resident_size_max;
			}
		');
		return result;
		#else
		return -1;
		#end
	}

	public static function getAvailableSystemMemory():Float {
		#if windows
		var result:Float = -1.0;
		untyped __cpp__('
			MEMORYSTATUSEX statex;
			statex.dwLength = sizeof(statex);
			if (GlobalMemoryStatusEx(&statex)) {
				result = (double)statex.ullAvailPhys;
			}
		');
		return result;
		#elseif linux
		var result:Float = -1.0;
		untyped __cpp__('
			struct sysinfo memInfo;
			if (sysinfo(&memInfo) != -1) {
				long long totalAvailable = memInfo.freeram + memInfo.bufferram;
				result = (double)(totalAvailable * memInfo.mem_unit);
			}
		');
		return result;
		#elseif mac
		var result:Float = -1.0;
		untyped __cpp__('
			vm_statistics64_data_t vm_stat;
			unsigned int count = HOST_VM_INFO64_COUNT;
			if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vm_stat, &count) == KERN_SUCCESS) {
				long long free_memory = (int64_t)vm_stat.free_count * sysconf(_SC_PAGESIZE);
				result = (double)free_memory;
			}
		');
		return result;
		#else
		return -1;
		#end
	}

	public static function getVRAMUsage():Float {
		#if windows
		var result:Float = -1.0;
		untyped __cpp__('
			IDXGIFactory4* pFactory = nullptr;
			if (SUCCEEDED(CreateDXGIFactory1(__uuidof(IDXGIFactory4), (void**)&pFactory))) {
				IDXGIAdapter3* pAdapter = nullptr;
				if (SUCCEEDED(pFactory->EnumAdapters(0, reinterpret_cast<IDXGIAdapter**>(&pAdapter)))) {
					DXGI_QUERY_VIDEO_MEMORY_INFO info;
					if (SUCCEEDED(pAdapter->QueryVideoMemoryInfo(0, DXGI_MEMORY_SEGMENT_GROUP_LOCAL, &info))) {
						result = (double)info.CurrentUsage;
					}
					pAdapter->Release();
				}
				pFactory->Release();
			}
		');
		return result;
		
		#elseif linux
		var result:Float = -1.0;
		untyped __cpp__('
			std::ifstream amd_vram("/sys/class/drm/card0/device/mem_info_vram_used");
			if (amd_vram.is_open()) {
				long long vram_used = 0;
				if (amd_vram >> vram_used) {
					result = (double)vram_used;
				}
				amd_vram.close();
			}
		');
		return result;
		
		#else
		return -1;
		#end
	}
}
#end