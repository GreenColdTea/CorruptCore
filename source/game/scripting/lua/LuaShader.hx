package game.scripting.lua;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end

class LuaShader
{
    public static function init(script:FunkinLua)
    {
        var lua:cpp.RawPointer<Lua_State> = script.lua;
        
        LuaUtils.addFunction(lua, "initLuaShader", function(name:String, glslVersion:Int = 120) {
			if(!ClientPrefs.shaders) return false;

			#if (!flash && sys)
			return initLuaShader(name, glslVersion);
			#else
			FunkinLua.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});
		
		LuaUtils.addFunction(lua, "setSpriteShader", function(obj:String, shader:String) {
			if(!ClientPrefs.shaders) return false;

			#if (!flash && sys)
			if(!PlayState.instance.runtimeShaders.exists(shader) && !initLuaShader(shader))
			{
				FunkinLua.luaTrace('setSpriteShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}

			var killMe:Array<String> = obj.split('.');
			var leObj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				leObj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(leObj != null) {
				var arr:Array<String> = PlayState.instance.runtimeShaders.get(shader);
				leObj.shader = new FlxRuntimeShader(arr[0], arr[1]);
				return true;
			}
			#else
			FunkinLua.luaTrace("setSpriteShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});
		LuaUtils.addFunction(lua, "removeSpriteShader", function(obj:String) {
			var killMe:Array<String> = obj.split('.');
			var leObj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				leObj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(leObj != null) {
				leObj.shader = null;
				return true;
			}
			return false;
		});

		LuaUtils.addFunction(lua, "setShaderCamera", function(camera:String, shader:String) {
			if(!ClientPrefs.shaders) {
				FunkinLua.luaTrace('setShaderCamera: Shaders are disabled!', false, false, FlxColor.RED);
				return;
			}

			#if (!flash && sys)
			var cam:FlxCamera = FunkinLua.cameraFromString(camera);
			if(cam == null) {
				FunkinLua.luaTrace('setShaderCamera: Camera not found: $camera', false, false, FlxColor.RED);
				return;
			}

			if(shader == null || shader.trim() == '') {
				cam.filters = [];
				if(PlayState.instance.cameraShaders.exists(camera))
					PlayState.instance.cameraShaders.remove(camera);
				return;
			}

			if(!PlayState.instance.runtimeShaders.exists(shader)) {
				FunkinLua.luaTrace('setShaderCamera: Shader not found: $shader', false, false, FlxColor.RED);
				return;
			}

			var arr:Array<String> = PlayState.instance.runtimeShaders.get(shader);
			var runtimeShader:FlxRuntimeShader = new FlxRuntimeShader(arr[0], arr[1]);
			cam.filters = [new ShaderFilter(runtimeShader)];
			PlayState.instance.cameraShaders.set(camera, runtimeShader);
			#else
			FunkinLua.luaTrace("setShaderCamera: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});


		LuaUtils.addFunction(lua, "getShaderBool", function(obj:String, prop:String) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				Lua.pushnil(lua);
				return null;
			}
			return shader.getBool(prop);
			#else
			FunkinLua.luaTrace("getShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			Lua.pushnil(lua);
			return null;
			#end
		});
		LuaUtils.addFunction(lua, "getShaderBoolArray", function(obj:String, prop:String) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				Lua.pushnil(lua);
				return null;
			}
			return shader.getBoolArray(prop);
			#else
			FunkinLua.luaTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			Lua.pushnil(lua);
			return null;
			#end
		});
		LuaUtils.addFunction(lua, "getShaderInt", function(obj:String, prop:String) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				Lua.pushnil(lua);
				return null;
			}
			return shader.getInt(prop);
			#else
			FunkinLua.luaTrace("getShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			Lua.pushnil(lua);
			return null;
			#end
		});
		LuaUtils.addFunction(lua, "getShaderIntArray", function(obj:String, prop:String) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				Lua.pushnil(lua);
				return null;
			}
			return shader.getIntArray(prop);
			#else
			FunkinLua.luaTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			Lua.pushnil(lua);
			return null;
			#end
		});
		LuaUtils.addFunction(lua, "getShaderFloat", function(obj:String, prop:String) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				Lua.pushnil(lua);
				return null;
			}
			return shader.getFloat(prop);
			#else
			FunkinLua.luaTrace("getShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			Lua.pushnil(lua);
			return null;
			#end
		});
		LuaUtils.addFunction(lua, "getShaderFloatArray", function(obj:String, prop:String) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				Lua.pushnil(lua);
				return null;
			}
			return shader.getFloatArray(prop);
			#else
			FunkinLua.luaTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			Lua.pushnil(lua);
			return null;
			#end
		});


		LuaUtils.addFunction(lua, "setShaderBool", function(obj:String, prop:String, value:Bool) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) return;

			shader.setBool(prop, value);
			#else
			FunkinLua.luaTrace("setShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});
		LuaUtils.addFunction(lua, "setShaderBoolArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) return;

			shader.setBoolArray(prop, values);
			#else
			FunkinLua.luaTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});
		LuaUtils.addFunction(lua, "setShaderInt", function(obj:String, prop:String, value:Int) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) return;

			shader.setInt(prop, value);
			#else
			FunkinLua.luaTrace("setShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});
		LuaUtils.addFunction(lua, "setShaderIntArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) return;

			shader.setIntArray(prop, values);
			#else
			FunkinLua.luaTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});
		LuaUtils.addFunction(lua, "setShaderFloat", function(obj:String, prop:String, value:Float) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) return;

			shader.setFloat(prop, value);
			#else
			FunkinLua.luaTrace("setShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});
		LuaUtils.addFunction(lua, "setShaderFloatArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) return;

			shader.setFloatArray(prop, values);
			#else
			FunkinLua.luaTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
		});
    }

    static function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.shaders) return false;

		#if (!flash && sys)
		if(PlayState.instance.runtimeShaders.exists(name))
		{
			FunkinLua.luaTrace('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.getPreloadPath('shaders/') #if MODS_ALLOWED , Mods.getModPath('shaders/') #end];

		#if MODS_ALLOWED
		if(Mods.currentModDirectory?.length > 0)
			foldersToCheck.insert(0, Mods.getModPath(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Mods.getModPath(mod + '/shaders/'));
		#end
		
		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if(FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					PlayState.instance.runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		FunkinLua.luaTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		#else
		FunkinLua.luaTrace('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end
		return false;
	}

	#if (!flash && sys)
	static function getShader(obj:String):FlxRuntimeShader
	{
		var killMe:Array<String> = obj.split('.');
		var leObj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
		if(killMe.length > 1) {
			leObj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
		}

		if(leObj != null) {
			var shader:Dynamic = leObj.shader;
			var shader:FlxRuntimeShader = shader;
			return shader;
		}
		return null;
	}
	#end
}