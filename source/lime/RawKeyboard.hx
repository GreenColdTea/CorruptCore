package lime;

#if (cpp && windows)
import cpp.Pointer;
import cpp.RawPointer;
import cpp.Star;

@:cppInclude("windows.h")
@:cppFileCode('
    #include <windows.h>
    #include <hxcpp.h>
')
@:buildXml('
    <target id="haxe">
        <lib name="user32.lib" />
        <lib name="kernel32.lib" />
    </target>
')
#end

class RawKeyboard {
    #if (cpp && windows)
    @:functionCode('
        RAWINPUTDEVICE rid;
        rid.usUsagePage = 0x01;
        rid.usUsage = 0x06;
        rid.dwFlags = 0;
        
        if (windowHandle == 0) {
            rid.hwndTarget = 0; // all shindows
        } else {
            rid.hwndTarget = (HWND)(uintptr_t)windowHandle;
        }
        
        RegisterRawInputDevices(&rid, 1, sizeof(rid));
    ')
    private static function _registerRawInputFlexible(windowHandle:Int = 0):Void {}
    #end

    public static function init(?windowHandle:Int):Void {
        #if (cpp && windows)
        _registerRawInputFlexible(windowHandle ?? 0);
        #end
    }
}