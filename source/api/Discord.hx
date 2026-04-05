package api;

#if DISCORD_ALLOWED
import Sys.sleep;
import lime.app.Application;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;

#if LUA_ALLOWED
import hxluajit.Lua;
import hxluajit.Types;
import hxluajit.wrapper.LuaUtils;
#end

#if MODS_ALLOWED
import game.backend.system.Mods;
#end

class DiscordClient
{
    private static final _defaultID:String = "1412032196260401303";
    
    public static var clientID(default, set):String = _defaultID;
    private static var presence:DiscordRichPresence = new DiscordRichPresence();
    
    public static function prepare()
    {
        initialize();
        Application.current.onExit.add((_) -> shutdown());
    }

    public static function shutdown() 
    {
        Discord.Shutdown();
    }
    
    private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void 
    {
        var requestPtr:cpp.Star<DiscordUser> = cpp.ConstPointer.fromRaw(request).ptr;

        if (Std.parseInt(cast(requestPtr.discriminator, String)) != 0)
            trace('(Discord) Connected to User (${cast(requestPtr.username, String)}#${cast(requestPtr.discriminator, String)})');
        else
            trace('(Discord) Connected to User (${cast(requestPtr.username, String)})');

        changePresence();
    }

    private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void 
    {
        trace('Discord: Error ($errorCode: ${cast(message, String)})');
    }

    private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void 
    {
        trace('Discord: Disconnected ($errorCode: ${cast(message, String)})');
    }

    public static function initialize()
    {
        final discordHandlers:DiscordEventHandlers = new DiscordEventHandlers();
        discordHandlers.ready = cpp.Function.fromStaticFunction(onReady);
        discordHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
        discordHandlers.errored = cpp.Function.fromStaticFunction(onError);

        Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), false, null);

        trace("Discord Client initialized");

        sys.thread.Thread.create(() ->
        {
            var localID:String = clientID;
            while (localID == clientID)
            {
                #if DISCORD_DISABLE_IO_THREAD
                Discord.UpdateConnection();
                #end
                Discord.RunCallbacks();
                Sys.sleep(2);
            }
        });
    }

    public static function changePresence(?details:String = 'In the Menus', ?state:Null<String>, ?smallImageKey:String, ?largeImageKey:String = 'logo', ?hasStartTimestamp:Bool, ?endTimestamp:Float)
    {
        var startTimestamp:Float = 0;
        if (hasStartTimestamp) startTimestamp = Date.now().getTime();
        if (endTimestamp > 0) endTimestamp = startTimestamp + endTimestamp;

        presence.details = details;
        presence.state = state;
        presence.largeImageKey = largeImageKey;
        presence.largeImageText = 'Engine Version: (${Application.current.meta.get('version')})';
        presence.smallImageKey = smallImageKey;
        presence.startTimestamp = Std.int(startTimestamp / 1000);
        presence.endTimestamp = Std.int(endTimestamp / 1000);
        
        updatePresence();

        #if GLOBAL_SCRIPTS game.scripting.HScriptGlobal.callGlobalScript("onChangePresence", [presence]); #end
    }

    public static function updatePresence()
        Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
    
    public static function resetClientID()
        clientID = _defaultID;

	#if MODS_ALLOWED
    public static function setClientIDFromMods()
    {
        var newId = Mods.getEffectiveDiscordClientID();
        if (newId != null && newId != clientID) {
            clientID = newId;
        } else if (newId == null && clientID != _defaultID) {
            clientID = _defaultID;
        }
    }
	#end

    private static function set_clientID(newID:String)
    {
        final change:Bool = (clientID != newID);
        clientID = newID;

        if(change)
        {
            shutdown();
            initialize();
            updatePresence();
        }
        return newID;
    }

    #if LUA_ALLOWED
    public static function addLuaCallbacks(lua:cpp.RawPointer<Lua_State>) {
        LuaUtils.addFunction(lua, "changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
            #if DISCORD_ALLOWED
            changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
            #else
            game.scripting.FunkinLua.luaTrace('changePresence: This platform doesn\'t support Discord RPC!', false, false, FlxColor.RED);
            #end
        });
    }
    #end
}
#end