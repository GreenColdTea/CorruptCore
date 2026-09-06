#if HSCRIPT_ALLOWED
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
import rulescript.scriptedClass.RuleScriptedClassUtil.*;
import rulescript.scriptedClass.RuleScriptedClassUtil;
import rulescript.scriptedClass.RuleScriptedClass.*;
import rulescript.scriptedClass.RuleScriptedClass;
import rulescript.types.ScriptedTypeUtil;
import rulescript.types.ScriptedAbstract;
import rulescript.types.ScriptedModule;
import rulescript.types.Abstracts;

import hscript.Expr;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;

import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;

using StringTools;
using Lambda;

using rulescript.Tools;

class FunkinRuleScript {

    @:unreflective
    static final PRESET_VARS:haxe.ds.Map<String, Dynamic> = [
        // Flixel Classes
        "FlxG" => flixel.FlxG,
        "FlxSprite" => flixel.FlxSprite,
        "FlxSpriteUtil" => flixel.util.FlxSpriteUtil,
        "FlxTimer" => flixel.util.FlxTimer,
        "FlxTween" => flixel.tweens.FlxTween,
        "FlxEase" => flixel.tweens.FlxEase,
        "FlxText" => flixel.text.FlxText,
        "FlxSound" => flixel.sound.FlxSound,
        "FlxTextBorderStyle" => flixel.text.FlxText.FlxTextBorderStyle,
        "FlxCamera" => flixel.FlxCamera,
        "FlxTextFormat" => flixel.text.FlxText.FlxTextFormat,
        "FlxTextFormatMarkerPair" => flixel.text.FlxText.FlxTextFormatMarkerPair,

        "BaseScaleMode" => flixel.system.scaleModes.BaseScaleMode,
        "FillScaleMode" => flixel.system.scaleModes.FillScaleMode,
        "FixedScaleAdjustSizeScaleMode" => flixel.system.scaleModes.FixedScaleAdjustSizeScaleMode,
        "FixedScaleMode" => flixel.system.scaleModes.FixedScaleMode,
        "PixelPerfectScaleMode" => flixel.system.scaleModes.PixelPerfectScaleMode,
        "RatioScaleMode" => flixel.system.scaleModes.RatioScaleMode,
        "RelativeScaleMode" => flixel.system.scaleModes.RelativeScaleMode,
        "StageSizeScaleMode" => flixel.system.scaleModes.StageSizeScaleMode,

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

        #if MODCHART_ALLOWED
        "ModManager" => game.modchart.ModManager,
        #end

        "FlxShader" => flixel.system.FlxAssets.FlxShader,

        "Paths" => game.Paths,
        "Character" => game.objects.Character,
        "PlayerSettings" => game.backend.PlayerSettings,
        "CoolUtil" => game.backend.utils.CoolUtil,
        "MusicBeatState" => MusicBeatState,
        "MusicBeatSubstate" => MusicBeatSubstate,
        "Conductor" => game.backend.Conductor,
        "ClientPrefs" => game.backend.ClientPrefs,
        "PlayState" => game.PlayState,
        "BGSprite" => game.objects.BGSprite,
        "FunkinRuleScript" => FunkinRuleScript,

        #if LUA_ALLOWED
        "FunkinLua" => FunkinLua,
        #end

        #if MODS_ALLOWED
        "Mods" => game.backend.system.Mods,
        #end

        #if SCRIPTABLE_STATES
        "TitleState" => game.states.TitleState,
        "MainMenuState" => game.states.MainMenuState,
        "OptionsState" => game.states.options.OptionsState,
        "CreditsState" => game.states.CreditsState,
        "StoryMenuState" => game.states.StoryMenuState,
        "FreeplayState" => game.states.FreeplayState,
        "LoadingState" => game.states.LoadingState,
        "HScriptState" => game.scripting.HScriptState,
        "HScriptSubstate" => game.scripting.HScriptSubstate,
        #end

        'StringMap' => haxe.ds.StringMap,
		'IntMap' => haxe.ds.IntMap,
		'ObjectMap' => haxe.ds.ObjectMap,

        'ScriptedClasses' => game.scripting.haxe.ScriptedClasses
    ];

    @:unreflective
    static final ABSTRACT_IMPORTS:Array<String> = [
        "flixel.util.FlxColor",
        "flixel.input.keyboard.FlxKey",
        "flixel.tweens.FlxTween.FlxTweenType",
        "flixel.text.FlxText.FlxTextAlign",
        "flixel.util.FlxAxes",
        #if flxgif
        "flxgif.FlxGifAsset",
        #end
        "openfl.display.BlendMode"
    ];

    public var scriptName:String;
    public var active(default, null):Bool = true;
    
    private var rule:RuleScript;
    private var parentInstance:Dynamic;
    private var callbacks:Map<String, Array<Dynamic>> = new Map();
    private var importedPackages:Map<String, Bool> = new Map();

    public function new(path:String, parentInstance:Dynamic = null, skipCreate:Bool = false, runScript:Bool = true) {
        this.parentInstance = parentInstance;
        scriptName = path;

        initScriptedClasses();

        rule = new RuleScript(new RuleScriptInterp());
        rule.scriptName = path;
        rule.errorHandler = onError;

        if (runScript) {
            try {
                var content = loadScriptContent(path);
                execute(content, skipCreate);
            } catch (e:haxe.Exception) {
                if (shouldTraceErrors())
                    trace('Failed to load script $path: ${e.message}');
                active = false;
            }
        }
    }

    private function initScriptedClasses() {
        ScriptedTypeUtil.resolveModule = function(name:String):Array<ModuleDecl> {
            final filePath = 'scripts/classes/${name.replace('.', '/')}.hxc';
            if (!Paths.fileExists(filePath, TEXT))
                return null;

            final content = Paths.getTextFromFile(filePath);
            if (content == null) {
                if (shouldTraceErrors()) trace('Failed to load module content: $filePath');
                return null;
            }

            final parser = new HxParser();
            parser.allowAll();
            parser.mode = MODULE;
            try {
                return parser.parseModule(content);
            } catch (e:Dynamic) {
                if (shouldTraceErrors()) trace('Failed to parse module $filePath: $e');
                return null;
            }
        };

        ScriptedTypeUtil.resolveScript = function(name:String):Dynamic {
            final path = Tools.parseTypePath(name);
            if (path.name == null || path.name.length == 0) {
                if (shouldTraceErrors()) trace('Invalid script path: $name');
                return null;
            }

            final moduleName = path.modulePath();
            final module = ScriptedTypeUtil.resolveModule(moduleName);
            if (module == null) return null;

            try {
                @:privateAccess
                final scriptedModule = new ScriptedModule(moduleName, module, ScriptedTypeUtil._currentContext);
                final type = scriptedModule.types[path.typeName];
                if (type != null)
                    RuleScriptedClassUtil.registerRuleScriptedClass(name, cast type);
                
                return type;
            } catch (e:Dynamic) {
                if (shouldTraceErrors()) trace('Failed to create scripted module for $name: $e');
                return null;
            }
        };

        RuleScriptedClassUtil.buildBridge = function(typePath:String, superInstance:Dynamic):RuleScript {
            final type:ScriptedClassType = ScriptedTypeUtil.resolveScript(typePath);
            if (type == null) {
                if (shouldTraceErrors()) trace('Failed to resolve script type: $typePath');
                return null;
            }

            final script = new RuleScript(new RuleScriptInterp());
            script.scriptName = typePath;
            script.superInstance = superInstance;
            script.getParser(HxParser).allowAll();
            script.getInterp(RuleScriptInterp).skipNextRestore = true;
            if (type.isExpr) {
                script.execute(cast type);
                return script;
            } else {
                var cl:ScriptedClass = cast type;
                RuleScriptedClassUtil.buildScriptedClass(cl, script);
            }
            return script;
        };
    }

    private function loadScriptContent(path:String):String {
        if (path == null || path.length == 0) return "// Empty script lol";

        #if sys if (FileSystem.exists(path)) {
            return File.getContent(path);
        } else #end if (OpenFlAssets.exists(path)) {
            return Assets.getText(path);
        } else {
            throw 'Script file not found: $path';
        }
    }

    function execute(code:String, skipCreate:Bool) {
        presetVariables();
        
        try {
            final parser = new HxParser();
            parser.allowAll();
            parser.mode = MODULE;
            
            final parsedDecls = parser.parseModule(code);
            final injectedDecls = RuleScriptedClassUtil.injectImportHx(parsedDecls);
            
            final finalExpr = Tools.moduleDeclsToExpr(injectedDecls, {isScriptedClass: false});
            rule.execute(finalExpr);
        } catch (e:haxe.Exception) {
            onError(e);
        }

        if (!skipCreate) call("onCreate");
    }

    function presetVariables() {
        for (key => value in PRESET_VARS)
            set(key, value);

        for (abstractType in ABSTRACT_IMPORTS) {
            final abstractInstance = Abstracts.resolveAbstract(abstractType);
            final typeName = abstractType.split('.').pop();
            set(typeName, abstractInstance);
        }
                
        if (parentInstance != null)
            set("parent", parentInstance);

        if (FlxG.state is PlayState) {
            set("instance", PlayState.instance);
            
            set("add", function(obj:flixel.FlxBasic) {
                var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
                if(PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position) 
                    position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
                else if(PlayState.instance.members.indexOf(PlayState.instance.dadGroup) < position) 
                    position = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
                
                PlayState.instance.insert(position, obj);
            });
            
            set("insert", PlayState.instance.insert);
            set("remove", PlayState.instance.remove);
            set("addBehindGF", PlayState.instance.addBehindGF);
            set("addBehindDad", PlayState.instance.addBehindDad);
            set("addBehindBF", PlayState.instance.addBehindBF);
        } else {
            final scriptObject = FlxG.state?.subState ?? FlxG.state;
            set("instance", scriptObject);

            set("add", scriptObject.add);
            set("insert", scriptObject.insert);
            set("remove", scriptObject.remove);
        }

        set("controls", game.backend.PlayerSettings.player1.controls);
        
        set("getObject", getObject);
        set("getAll", getAllObjects);
        
        set("showErrorTraces", true);
    }

    private final function shouldTraceErrors():Bool {
        return exists("showErrorTraces") && get("showErrorTraces") == true;
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
            if (shouldTraceErrors())
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
            if (shouldTraceErrors())
                trace('Error getting objects: ${e.message}');
        }
        return [];
    }

    public function resolveType(typeName:String):Dynamic {
        var full = typeName;
        var cl = Type.resolveClass(full);
        if (cl != null) return cl;

        var scripted = ScriptedTypeUtil.resolveScript(full);
        if (scripted != null) return scripted;
        
        for (pkg in importedPackages.keys()) {
            var candidate = pkg + "." + typeName;
            cl = Type.resolveClass(candidate);
            if (cl != null) return cl;
            scripted = ScriptedTypeUtil.resolveScript(candidate);
            if (scripted != null) return scripted;
        }
        
        try {
            var scriptedType = ScriptedTypeUtil.resolveScript(typeName);
            if (scriptedType != null) return scriptedType;
        } catch (e:Dynamic) {
            if (shouldTraceErrors())
                trace('Failed to resolve scripted type $typeName: $e');
        }
        
        return null;
    }

    public function call(event:String, ?args:Array<Dynamic>):Dynamic 
    {
        if (!active) return null;
        
        var originalAdd = null;
        if (event == "onCreatePost" && PlayState.instance != null) {
            originalAdd = get("add");
            set("add", function(obj:flixel.FlxBasic) {
                PlayState.instance.add(obj);
            });
        }
        
        if (callbacks.exists(event)) {
            final cbs = callbacks.get(event);

            var i = cbs.length;
            while (--i >= 0) {
                var cb = cbs[i];
                try {
                    Reflect.callMethod(null, cb, args ?? []);
                } catch (e:Dynamic) {
                    @:privateAccess
                    onError(haxe.Exception.caught(e));
                    cbs.remove(cb);
                }
            }
        }
        
        var result:Dynamic = null;
        if (exists(event)) {
            try {
                result = Reflect.callMethod(null, get(event), args ?? []);
            } catch (e:Dynamic) {
                @:privateAccess
                onError(haxe.Exception.caught(e));
                rule.variables.remove(event);
            }
        }
        
        if (event == "onCreatePost" && originalAdd != null) {
            set("add", originalAdd);
        }
        
        return result;
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
        if (!shouldTraceErrors()) return;

        CoolUtil.showPopUp('Error in $scriptName:\n${e.details()}', 'Error on HScript!');
        if(!(FlxG.state is PlayState)) 
            FlxG.resetState();
    }

    public function stop():Void {
        if (!active) return;
        
        active = false;
        rule?.variables?.clear();
        callbacks?.clear();
        importedPackages?.clear();
        rule = null;
        parentInstance = null;
    }
}
#end