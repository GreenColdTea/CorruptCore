package game.backend.utils;

enum abstract RegistryHive(Int) {
	var HKEY_CLASSES_ROOT = 0x80000000;
	var HKEY_CURRENT_USER = 0x80000001;
	var HKEY_LOCAL_MACHINE = 0x80000002;
	var HKEY_USERS = 0x80000003;
	var HKEY_CURRENT_CONFIG = 0x80000005;
}
#if windows
@:cppFileCode('
#include <windows.h>
#include <tchar.h>
#include <string>
#include <vector>
')
#end
final class WindowsRegistry {
	#if windows
	@:functionCode('
		HKEY hKey;
		LONG result;
		DWORD dataSize = 0;
		DWORD dataType = 0;

		std::wstring subkey = std::wstring(key.wchar_str());
		std::wstring valname = std::wstring(string.wchar_str());

		result = RegOpenKeyExW((HKEY)reinterpret_cast<HKEY>(static_cast<uintptr_t>(hive)), subkey.c_str(), 0, KEY_READ, &hKey);
		if (result != ERROR_SUCCESS) return null();

		result = RegQueryValueExW(hKey, valname.c_str(), NULL, &dataType, NULL, &dataSize);
		if (result != ERROR_SUCCESS || dataSize == 0) {
			RegCloseKey(hKey);
			return null();
		}

		std::vector<wchar_t> buffer(dataSize / sizeof(wchar_t));
		result = RegQueryValueExW(hKey, valname.c_str(), NULL, NULL, (LPBYTE)buffer.data(), &dataSize);
		RegCloseKey(hKey);

		if (result == ERROR_SUCCESS) {
			return ::String(buffer.data());
		}
		return null();
	')
	#end
	public static function getKey(hive:RegistryHive, key:String, string:String):Null<String>
	{
		return null;
	}
}