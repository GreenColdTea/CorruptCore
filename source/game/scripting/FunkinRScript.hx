package game.scripting;

#if sys
import sys.io.File;
#end

import haxe.ds.StringMap;
import haxe.io.Path;

import rulescript.*;
import rulescript.parsers.*;
import rulescript.RuleScript;

import rulescript.interps.RuleScriptInterp;

import game.scripting.HScriptClassManager.ScriptClassRef;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;

using StringTools;
using Lambda;

class FunkinRScript {
    static final PRESET_VARS:Map<String, Dynamic> = [
        // Flixel Classes
        "FlxG" => flixel.FlxG,
        "FlxSprite" => flixel.FlxSprite,
        "FlxSpriteUtil" => flixel.util.FlxSpriteUtil,
        "FlxTimer" => flixel.util.FlxTimer,
        "FlxTween" => flixel.tweens.FlxTween,
        "FlxEase" => flixel.tweens.FlxEase,
        "FlxText" => flixel.text.FlxText,

        #if VIDEOS_ALLOWED
        "FunkinVideoSprite" => game.objects.FunkinVideoSprite,
        #end

        #if flxsoundfilters
        "FlxFilteredSound" => FlxFilteredSound,
        #end

        #if flxgif
        "FlxGifSprite" => FlxGifSprite,
        "FlxGifBackdrop" => FlxGifBackdrop,
        #end

        "Paths" => game.Paths,
        "Character" => game.objects.Character,
        "CoolUtil" => game.backend.utils.CoolUtil,
        "MusicBeatState" => MusicBeatState,
        "Conductor" => game.backend.Conductor,
        "ClientPrefs" => game.backend.ClientPrefs,
        "PlayState" => game.PlayState,
        "BGSprite" => game.objects.BGSprite,
        "FunkinRScript" => FunkinRScript,
        "FunkinLua" => FunkinLua,

        'StringMap' => haxe.ds.StringMap,
		'IntMap' => haxe.ds.IntMap,
		'ObjectMap' => haxe.ds.ObjectMap,
    ];

    static final ABSTRACT_IMPORTS:Array<String> = [
        "flixel.util.FlxColor",
        "flixel.input.keyboard.FlxKey",
        "haxe.ds.Map",
        #if flxgif
        "flxgif.FlxGifAsset",
        #end
        "openfl.display.BlendMode"
    ];

    public var scriptType:String = "N/A"; //yeah
    public var scriptName:String;
    public var active(default, null):Bool = true;
    
    private var rule:RuleScript;
    private var parentInstance:Dynamic;
    private var callbacks:Map<String, Array<Dynamic>> = new Map();
    private var importedPackages:Map<String, Bool> = new Map();

    public static function fromFile(file:String, ?instance:Dynamic, skipCreate:Bool = false):Null<FunkinRScript> {
        return switch Path.extension(file).toLowerCase() {
            case "hx": new FunkinRScript(file, instance, skipCreate);
            case _: null;
        }
    }

    public function new(path:String, parentInstance:Dynamic = null, skipCreate:Bool = false) {
        this.parentInstance = parentInstance;
        scriptName = path;

        rule = new RuleScript(new RuleScriptInterpEx(this));
        rule.scriptName = path;
        rule.errorHandler = onError;

        try {
            var content = loadScriptContent(path);
            execute(content, skipCreate);
        } catch (e:haxe.Exception) {
            trace('Failed to load script $path: ${e.message}');
            active = false;
        }
    }

    private function loadScriptContent(path:String):String {
        #if sys
        return File.getContent(path);
        #else
        var resourceName = path.replace("/", "_").replace(".", "_").replace(":", "_");
        var content = haxe.Resource.getString(resourceName);
        if (content == null) {
            throw 'HScript not found in resources: $path (resource name: $resourceName)';
        }
        return content;
        #end
    }

    function execute(code:String, skipCreate:Bool) {
        presetVariables();
        rule.tryExecute(code);
        if (!skipCreate) call("onCreate");
    }

    function presetVariables() {
        for (key => value in PRESET_VARS)
            set(key, value);

        for (get in ABSTRACT_IMPORTS)
            rulescript.types.Abstracts.resolveAbstract(get);
                
        if (parentInstance != null)
            set("parent", parentInstance);

        var isPlayState = FlxG.state is PlayState;
        if (isPlayState) {
            set("game", PlayState.instance);
            
            set("add", function(basic:flixel.FlxBasic, ?frontOfChars:Bool = false) {
                if (frontOfChars) {
                    PlayState.instance.add(basic);
                    return;
                }

                var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
                if(PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position) 
                    position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
                else if(PlayState.instance.members.indexOf(PlayState.instance.dadGroup) < position) 
                    position = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
                
                PlayState.instance.insert(position, basic);
            });
            
            set("insert", PlayState.instance.insert);
            set("remove", PlayState.instance.remove);
            set("addBehindGF", PlayState.instance.addBehindGF);
            set("addBehindDad", PlayState.instance.addBehindDad);
            set("addBehindBF", PlayState.instance.addBehindBF);
            
            set("setVar", (name:String, value:Dynamic) -> {
                PlayState.instance.variables.set(name, value);
                return value;
            });
            set("getVar", (name:String) -> {
                var result:Dynamic = null;
                if(PlayState.instance.variables.exists(name)) 
                    result = PlayState.instance.variables.get(name);
                return result;
            });
            set("removeVar", (name:String) -> {
                if(PlayState.instance.variables.exists(name)) {
                    PlayState.instance.variables.remove(name);
                    return true;
                }
                return false;
            });
            
        } else {
            var scriptObject = FlxG.state ?? FlxG.state.subState;
            set("game", scriptObject);
            
            set("add", scriptObject.add);
            set("insert", scriptObject.insert);
            set("remove", scriptObject.remove);
            
            set("setVar", (name:String, value:Dynamic) -> {
                rule.variables.set(name, value);
                return value;
            });
            set("getVar", (name:String) -> {
                var result:Dynamic = rule.variables.get(name);
                return result;
            });
            set("removeVar", (name:String) -> {
                if(rule.variables.exists(name)) {
                    rule.variables.remove(name);
                    return true;
                }
                return false;
            });
        }
        
        set("getObject", getObject);
        set("getAll", getAllObjects);
    }

    public function getObject(index:Int, group:String):Dynamic {
        if (parentInstance == null) return null;
        
        try {
            if (Reflect.hasField(parentInstance, group)) {
                var targetGroup = Reflect.field(parentInstance, group);
                if (Std.isOfType(targetGroup, FlxTypedGroup)) {
                    return targetGroup.members[index];
                }
            }
        } catch (e:Dynamic) {
            trace('Error getting object: ${e.message}');
        }
        return null;
    }

    public function getAllObjects(group:String):Array<Dynamic> {
        if (parentInstance == null) return [];
        
        try {
            if (Reflect.hasField(parentInstance, group)) {
                var targetGroup = Reflect.field(parentInstance, group);
                if (Std.isOfType(targetGroup, FlxTypedGroup)) {
                    return targetGroup.members;
                }
            }
        } catch (e:Dynamic) {
            trace('Error getting objects: ${e.message}');
        }
        return [];
    }

    public function resolveType(typeName:String):Dynamic {
        var cl = Type.resolveClass(typeName);
        if (cl != null) return cl;
        
        for (pkg in importedPackages.keys()) {
            cl = Type.resolveClass(pkg + "." + typeName);
            if (cl != null) return cl;
        }
        
        return null;
    }

    public function call(event:String, ?args:Array<Dynamic>):Dynamic {
        if (!active) return null;
        
        if (callbacks.exists(event)) {
            for (cb in callbacks.get(event)) {
                try {
                    Reflect.callMethod(null, cb, args != null ? args : []);
                } catch (e:Dynamic) {
                    @:privateAccess
                    onError(haxe.Exception.caught(e));
                }
            }
        }
        
        if (!exists(event)) return null;
        
        try {
            return Reflect.callMethod(null, get(event), args != null ? args : []);
        } catch (e:Dynamic) {
            @:privateAccess
            onError(haxe.Exception.caught(e));
            return null;
        }
    }

    public function exists(variable:String):Bool {
        return active && rule.variables.exists(variable);
    }

    public function get(variable:String):Dynamic {
        return exists(variable) ? rule.variables.get(variable) : null;
    }

    public function set(variable:String, value:Dynamic):Void {
        if (active) rule.variables.set(variable, value);
    }

    public function addCallback(event:String, callback:Dynamic):Void {
        if (!callbacks.exists(event))
            callbacks.set(event, []);
        callbacks.get(event).push(callback);
    }

    public function removeCallback(event:String, callback:Dynamic):Bool {
        return if (callbacks.exists(event)) {
            var arr = callbacks.get(event);
            var result = arr.remove(callback);
            if (arr.length == 0) callbacks.remove(event);
            result;
        } else false;
    }

    function onError(e:haxe.Exception):Void {
        final text = 'Error in $scriptName: ${e.details()}';
        trace(text);
        CoolUtil.hxTrace(text, FlxColor.RED);
    }

    public function stop():Void {
        if (!active) return;
        
        active = false;
        rule.variables.clear();
        callbacks.clear();
        importedPackages.clear();
        rule = null;
        parentInstance = null;
    }
}

class RuleScriptInterpEx extends RuleScriptInterp {
    public static var resolveScriptState:ResolveScriptState;
    public var ref:ScriptClassRef;
    public var funkScript:FunkinRScript;
    
    public function new(?funkScript:FunkinRScript) {
        this.funkScript = funkScript;
        super();
    }
    
    override function resolveType(path:String):Dynamic {
        var resolved = funkScript.resolveType(path);
        if (resolved != null) {
            resolveScriptState = {owner: this, mode: "resolve"};
            return resolved;
        }
        
        resolveScriptState = {owner: this, mode: "resolve"};
        return super.resolveType(path);
    }
    
    override function cnew(cl:String, args:Array<Dynamic>):Dynamic {
        resolveScriptState = {owner: this, mode: "cnew", args: args};
        return super.cnew(cl, args);
    }

    override function get(o:Dynamic, f:String):Dynamic {
        if (o == this) {
            if (this.ref != null && this.ref.staticFields.exists(f))
                return this.ref.staticFields.get(f);
        }

        if (Std.isOfType(o, ScriptClassRef)) {
            var cls:ScriptClassRef = cast o;
            if (cls.staticFields.exists(f))
                return cls.staticFields.get(f);
        }

        return super.get(o, f);
    }

    override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
        if (o == this) {
            if (this.ref != null && this.ref.staticFields.exists(f)) {
                this.ref.staticFields.set(f, v);
                return v;
            }
        }

        if (Std.isOfType(o, ScriptClassRef)) {
            var cls:ScriptClassRef = cast o;
            if (cls.staticFields.exists(f)) {
                cls.staticFields.set(f, v);
                return v;
            }
        }

        return super.set(o, f, v);
    }
}

typedef ResolveScriptState = {
    var owner:RuleScriptInterpEx;
    var mode:String; // resolve or cnew
    var ?args:Array<Dynamic>;
}