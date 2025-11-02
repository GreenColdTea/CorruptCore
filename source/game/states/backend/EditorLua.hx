package game.states.backend;

#if LUA_ALLOWED
import hxluajit.Lua;
import hxluajit.LuaL;
import hxluajit.Types;
import hxluajit.wrapper.LuaConverter;
import hxluajit.wrapper.LuaUtils;
import hxluajit.wrapper.LuaError;
#end

import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.FlxBasic;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import Type.ValueType;

import game.backend.Controls;
import game.objects.DialogueBoxPsych;

import game.states.editors.EditorPlayState;

#if DISCORD_ALLOWED
import api.Discord;
#end

using StringTools;

class EditorLua {
	@:unreflective
	public static final Function_Stop = 1;

	@:unreflective
	public static final Function_Continue = 0;

	#if LUA_ALLOWED
	public var lua:cpp.RawPointer<Lua_State> = null;
	#end

	public function new(script:String) {
		#if LUA_ALLOWED
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());

		var result:Int = LuaL.dofile(lua, script);
		var resultStr:String = Lua.tostring(lua, result);
		if(resultStr != null && result != 0) {
			CoolUtil.showPopUp(resultStr, 'Error on .LUA script!' #if sl_windows_api , MSG_INFORMATION #end);
			trace('Error on .LUA script! ' + resultStr);
			lua = null;
			return;
		}
		trace('Lua file loaded succesfully:' + script);

		// Lua variables
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('inChartEditor', true);

		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songName', PlayState.SONG.song);

		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		for (i in 0...4) {
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}

		set('downscroll', ClientPrefs.downScroll);
		set('middlescroll', ClientPrefs.middleScroll);

		//stuff 4 noobz like you B)
		LuaUtils.addFunction(lua, "getProperty", function(variable:String):Dynamic {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(EditorPlayState.instance, killMe[0]);

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
			return Reflect.getProperty(EditorPlayState.instance, variable);
		});
		
		LuaUtils.addFunction(lua, "setProperty", function(variable:String, value:Dynamic):Void {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(EditorPlayState.instance, killMe[0]);

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			} else {
				Reflect.setProperty(EditorPlayState.instance, variable, value);
			}
		});
		
		LuaUtils.addFunction(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic):Dynamic {
			if(Std.isOfType(Reflect.getProperty(EditorPlayState.instance, obj), FlxTypedGroup)) {
				return Reflect.getProperty(Reflect.getProperty(EditorPlayState.instance, obj).members[index], variable);
			}

			var leArray:Dynamic = Reflect.getProperty(EditorPlayState.instance, obj)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					return leArray[variable];
				}
				return Reflect.getProperty(leArray, variable);
			}
			return null;
		});
		
		LuaUtils.addFunction(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic):Void {
			if(Std.isOfType(Reflect.getProperty(EditorPlayState.instance, obj), FlxTypedGroup)) {
				Reflect.setProperty(Reflect.getProperty(EditorPlayState.instance, obj).members[index], variable, value);
				return;
			}

			var leArray:Dynamic = Reflect.getProperty(EditorPlayState.instance, obj)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					leArray[variable] = value;
				} else {
					Reflect.setProperty(leArray, variable, value);
				}
			}
		});
		
		LuaUtils.addFunction(lua, "removeFromGroup", function(obj:String, index:Int, dontDestroy:Bool = false):Void {
			if(Std.isOfType(Reflect.getProperty(EditorPlayState.instance, obj), FlxTypedGroup)) {
				var sex = Reflect.getProperty(EditorPlayState.instance, obj).members[index];
				if(!dontDestroy)
					sex.kill();
				Reflect.getProperty(EditorPlayState.instance, obj).remove(sex, true);
				if(!dontDestroy)
					sex.destroy();
				return;
			}
			Reflect.getProperty(EditorPlayState.instance, obj).remove(Reflect.getProperty(EditorPlayState.instance, obj)[index]);
		});

		LuaUtils.addFunction(lua, "getColorFromHex", function(color:String):Int {
			if(!color.startsWith('0x')) color = '0xff' + color;
			return Std.parseInt(color);
		});

		LuaUtils.addFunction(lua, "setGraphicSize", function(obj:String, x:Int, y:Int = 0):Void {
			var poop:FlxSprite = Reflect.getProperty(EditorPlayState.instance, obj);
			poop?.setGraphicSize(x, y);
			poop?.updateHitbox();
		});
		
		LuaUtils.addFunction(lua, "scaleObject", function(obj:String, x:Float, y:Float):Void {
			var poop:FlxSprite = Reflect.getProperty(EditorPlayState.instance, obj);
			poop?.scale.set(x, y);
			poop?.updateHitbox();
		});
		
		LuaUtils.addFunction(lua, "updateHitbox", function(obj:String):Void {
			var poop:FlxSprite = Reflect.getProperty(EditorPlayState.instance, obj);
			poop?.updateHitbox();
		});

		api.Discord.DiscordClient.addLuaCallbacks(lua);

		call('onCreate', []);
		#end
	}
	
	public function call(event:String, args:Array<Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if(lua == null) {
			return Function_Continue;
		}

		try {
			Lua.getglobal(lua, event);
			var type:Int = Lua.type(lua, -1);
			
			if (type != 6) { // 6 = LUA_TFUNCTION
				Lua.pop(lua, 1);
				
				if (event != 'onCreate' && event != 'onUpdate') {
					trace('Lua function "$event" not found');
				}
				return Function_Continue;
			}

			for (arg in args) {
				LuaConverter.toLua(lua, arg);
			}

			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			if (status != Lua.OK) {
				var error:String = Lua.tostring(lua, -1);
				if (error != 'attempt to call a nil value' && !error.contains('onCreate')) {
					trace('Lua error calling $event: $error');
				}
				Lua.pop(lua, 1);
				return Function_Continue;
			}

			var result:Dynamic = LuaConverter.fromLua(lua, -1);
			Lua.pop(lua, 1);

			if (result == null) result = Function_Continue;
			return result;
		} catch(e:Dynamic) {
			trace('Error calling Lua function $event: $e');
		}
		#end
		return Function_Continue;
	}

	#if LUA_ALLOWED
	function resultIsAllowed(leLua:cpp.RawPointer<Lua_State>, leResult:Null<Int>):Bool {
		var type:Int = Lua.type(leLua, leResult);
		if (type == 0 || type == 1 || type == 3 || type == 4 || type == 5) {
			return true;
		}
		return false;
	}
	#end

	public function set(variable:String, data:Dynamic) {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		LuaUtils.setVariable(lua, variable, data);
		#end
	}

	#if LUA_ALLOWED
	public function getBool(variable:String) {
		var result:Dynamic = LuaUtils.getVariable(lua, variable);
		return (result == true || result == 'true');
	}
	#end

	public function stop() {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		LuaUtils.cleanupStateFunctions(lua);
		Lua.close(lua);
		lua = null;
		#end
	}
}