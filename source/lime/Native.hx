package lime;

import lime.app.Application;
import lime.system.Display;
import lime.system.System;

import flixel.util.FlxColor;

#if (cpp && windows)
@:buildXml('
<target id="haxe">
	<lib name="dwmapi.lib" if="windows"/>
	<lib name="gdi32.lib" if="windows"/>
</target>
')
@:cppFileCode('
#include <windows.h>
#include <dwmapi.h>
#include <winuser.h>
#include <wingdi.h>
#include <shobjidl.h>

#define attributeDarkMode 20
#define attributeDarkModeFallback 19

#define attributeCaptionColor 34
#define attributeTextColor 35
#define attributeBorderColor 36

typedef HRESULT (WINAPI *SetGameDVRRecordableWindow_t)(HWND hwnd);

struct HandleData {
	DWORD pid = 0;
	HWND handle = 0;
};

BOOL CALLBACK findByPID(HWND handle, LPARAM lParam) {
	DWORD targetPID = ((HandleData*)lParam)->pid;
	DWORD curPID = 0;

	GetWindowThreadProcessId(handle, &curPID);
	if (targetPID != curPID || GetWindow(handle, GW_OWNER) != (HWND)0 || !IsWindowVisible(handle)) {
		return TRUE;
	}

	((HandleData*)lParam)->handle = handle;
	return FALSE;
}

HWND curHandle = 0;
void getHandle() {
	if (curHandle == (HWND)0) {
		HandleData data;
		data.pid = GetCurrentProcessId();
		EnumWindows(findByPID, (LPARAM)&data);
		curHandle = data.handle;
	}
}

void markAsGame(HWND hwnd) {
    if (hwnd != (HWND)0) {
        HMODULE hDVR = LoadLibraryA("GameBarPresenceWriter.dll");
        if (hDVR) {
            auto fn = (SetGameDVRRecordableWindow_t)GetProcAddress(hDVR, "SetGameDVRRecordableWindow");
            if (fn) {
                fn(hwnd);
            }
            FreeLibrary(hDVR);
        }
    }
}
')
#end
#if cpp
@:headerCode('
	#include <iostream>
	#include <thread>
')
#end
class Native
{
	#if (cpp && windows)
	@:functionCode('
		getHandle();
		if (curHandle != (HWND)0) {
			markAsGame(curHandle);
		}
	')
	#end
	public static function registerAsGame():Void {}

	#if cpp
	@:functionCode('
		return std::thread::hardware_concurrency();
    ')
	#end
    public static function getCPUThreadsCount():Int return 1;
}