#if LUA_ALLOWED
import hxluajit.Lua;
import hxluajit.LuaL;
import hxluajit.Types;
import hxluajit.wrapper.LuaConverter;
import hxluajit.wrapper.LuaUtils;
import hxluajit.wrapper.LuaError;

#if flixel_animate
import game.scripting.FunkinLua.ModchartAnimateSprite;
#end
import game.scripting.FunkinLua.ModchartSprite;
import game.scripting.FunkinLua.ModchartText;
import game.scripting.FunkinLua.ModchartBackdrop;
#end