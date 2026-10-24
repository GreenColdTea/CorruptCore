#if HSCRIPT_ALLOWED
package game.scripting;

#if sys
import sys.io.File;
import sys.FileSystem;
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
    static final PRESET_VARS:Map<String, Dynamic> = [
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
        "SongUtil" => game.backend.utils.SongUtil,
        "FileUtil" => game.backend.utils.FileUtil,
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

    public var resetStaticsOnStop:Bool = false;

    private var rule:RuleScript;
    private var parentInstance:Dynamic;
    private var callbacks:Map<String, Array<Dynamic>> = new Map();
    private var importedPackages:Map<String, Bool> = new Map();

    public function new(path:String, parentInstance:Dynamic = null, skipCreate:Bool = false, runScript:Bool = true) {
        this.parentInstance = parentInstance;
        scriptName = path;

        if (!RuleScriptInterp.globalVariables.keys().hasNext()) {
            for (key => value in PRESET_VARS)
                RuleScriptInterp.globalVariables.set(key, value);

            for (abstractType in ABSTRACT_IMPORTS) {
                final abstractInstance = Abstracts.resolveAbstract(abstractType);
                final typeName = abstractType.split('.').pop();
                RuleScriptInterp.globalVariables.set(typeName, abstractInstance);
            }
        }

        initScriptedClasses();

        rule = new RuleScript(new RuleScriptInterp());
        rule.getInterp(RuleScriptInterp).strictMode = true;
        rule.scriptName = path;

        if (runScript) {
            try {
                final content = loadScriptContent(path);
                execute(content, skipCreate);
            } catch (e:haxe.Exception) {
                if (shouldTraceErrors())
                    trace('Failed to load script $path: ${e.message}');
                active = false;
            }
        }
    }

    private function attachInterpErrorHandler(interp:Dynamic, name:String):Void {
        if (Std.isOfType(interp, RuleScriptInterp)) {
            final rsInterp:RuleScriptInterp = cast interp;
            rsInterp.errorHandler = (e:haxe.Exception) -> onError(e, rsInterp.scriptName ?? name);
        }
    }

    private function initScriptedClasses() {
        RuleScriptedClassUtil.fileExists = (p:String) -> return Paths.fileExists(p, TEXT);
        RuleScriptedClassUtil.getFileContent = (p:String) -> return Paths.getTextFromFile(p);

        ScriptedTypeUtil.resolveModule = function(name:String):Array<ModuleDecl> {
            final filePath = 'scripts/classes/${name.replace('.', '/')}.hxc';
            if (!Paths.fileExists(filePath, TEXT))
                return null;

            final content = Paths.getTextFromFile(filePath);
            if (content == null) {
                if (shouldTraceErrors()) trace('Failed to load module content: $filePath');
                return null;
            }

            RuleScriptedClassUtil.importHxCache.clear();

            final parser = new HxParser();
            parser.allowAll();
            parser.mode = MODULE;
            try {
                final moduleDecls = parser.parseModule(content);
                final importDecls = RuleScriptedClassUtil.getImportDecls(filePath);
                return importDecls.concat(moduleDecls);
            } catch (e:haxe.Exception) {
                onError(e, filePath);
                return null;
            }
        };

        ScriptedTypeUtil.resolveScript = function(name:String):Dynamic {
            if (name == null || name.length == 0) return null;

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

                if (type != null) {
                    final simple = path.typeName;
                    final fullName = Std.string(type);

                    final oldClass:ScriptedClass = cast (
                        RuleScriptedClassUtil.types.get(fullName) 
                        ?? RuleScriptedClassUtil.types.get(name) 
                        ?? (simple != null ? RuleScriptedClassUtil.types.get(simple) : null)
                    );

                    if (Std.isOfType(type, ScriptedClass)) {
                        final newClass:ScriptedClass = cast type;

                        @:privateAccess attachInterpErrorHandler(newClass.interp, fullName);
                        @:privateAccess newClass.init();

                        if (oldClass != null && @:privateAccess oldClass.initialized) {
                            @:privateAccess {
                                final oldVars = oldClass.interp.access.getVariables();
                                final newVars = newClass.interp.access.getVariables();

                                for (k => v in oldVars) {
                                    if (k == newClass.className || newClass.module.types.exists(k) || Reflect.isFunction(v))
                                        continue;

                                    if (newVars.exists(k))
                                        newClass.interp.access.setVariable(k, v);
                                }

                                if (oldClass.module.context != null && newClass.module.context != null) {
                                    for (k => v in oldClass.module.context.staticVariables) {
                                        if (!Reflect.isFunction(v))
                                            newClass.module.context.staticVariables.set(k, v);
                                    }
                                    for (k => v in oldClass.module.context.publicVariables) {
                                        if (!Reflect.isFunction(v))
                                            newClass.module.context.publicVariables.set(k, v);
                                    }
                                }
                            }
                        }
                    }

                    RuleScriptedClassUtil.registerRuleScriptedClass(fullName, cast type);
                    RuleScriptedClassUtil.registerRuleScriptedClass(name, cast type);

                    if (simple != null && simple != name)
                        RuleScriptedClassUtil.registerRuleScriptedClass(simple, cast type);
                }
                return type;
            } catch (e:haxe.Exception) {
                onError(e, name);
                return null;
            }
        };

        RuleScriptedClassUtil.buildBridge = function(typePath:String, superInstance:Dynamic):RuleScript {
            if (typePath == null || typePath.length == 0) return null;
            
            final type:ScriptedClassType = ScriptedTypeUtil.resolveScript(typePath);
            if (type == null) {
                if (shouldTraceErrors()) trace('Failed to resolve script type: $typePath');
                return null;
            }

            final script = new RuleScript(new RuleScriptInterp());
            final fullName = Std.string(type);
            script.scriptName = fullName;
            script.superInstance = superInstance;
            script.getParser(HxParser).allowAll();

            final interp = script.getInterp(RuleScriptInterp);
            interp.skipNextRestore = true;
            interp.strictMode = true;

            attachInterpErrorHandler(interp, fullName);
            interp.hasErrorHandler = false;

            try {
                if (type.isExpr) {
                    script.execute(cast type);
                } else {
                    final cl:ScriptedClass = cast type;
                    RuleScriptedClassUtil.buildScriptedClass(cl, script);
                }
            } catch (e:haxe.Exception) {
                onError(e, fullName);
            }
            return script;
        };
    }

    private function loadScriptContent(path:String):String {
        if (path == null || path.length == 0) return "";

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
            rule.tryExecute(code);
            if (!skipCreate) call("onCreate");
        } catch (e:haxe.Exception) {
            onError(e);
        }
    }

    function presetVariables() {
        if (scriptName != null) {
            final importDecls = RuleScriptedClassUtil.getImportDecls(scriptName);
            if (importDecls?.length > 0) {
                final expr = Tools.moduleDeclsToExpr(importDecls, {isScriptedClass: false});
                rule.execute(expr);
            }
        }

        if (parentInstance != null)
            set("parent", parentInstance);

        if (FlxG.state is PlayState) {
            set("this", PlayState.instance);

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
            set("this", scriptObject);

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
        return !exists("showErrorTraces") || get("showErrorTraces") == true;
    }

    public function getObject(index:Int, group:String):Dynamic {
        if (parentInstance == null) return null;

        try {
            if (Reflect.hasField(parentInstance, group)) {
                final targetGroup = Reflect.field(parentInstance, group);
                if (Std.isOfType(targetGroup, FlxTypedGroup))
                    return targetGroup.members[index];
            }
        } catch (e:haxe.Exception) {
            if (shouldTraceErrors())
                trace('Error getting object: ${e.message}');
        }
        return null;
    }

    public function getAllObjects(group:String):Array<Dynamic> {
        if (parentInstance == null) return [];

        try {
            if (Reflect.hasField(parentInstance, group)) {
                final targetGroup = Reflect.field(parentInstance, group);
                if (Std.isOfType(targetGroup, FlxTypedGroup))
                    return targetGroup.members;
            }
        } catch (e:haxe.Exception) {
            if (shouldTraceErrors())
                trace('Error getting objects: ${e.message}');
        }
        return [];
    }

    public function resolveType(typeName:String):Dynamic {
        final full = typeName;

        var cl = Type.resolveClass(full);
        if (cl != null) return cl;

        var scripted = ScriptedTypeUtil.resolveScript(full);
        if (scripted != null) return scripted;

        for (pkg in importedPackages.keys()) {
            final candidate = pkg + "." + typeName;

            cl = Type.resolveClass(candidate);
            if (cl != null) return cl;

            scripted = ScriptedTypeUtil.resolveScript(candidate);
            if (scripted != null) return scripted;
        }

        try {
            final scriptedType = ScriptedTypeUtil.resolveScript(typeName);
            if (scriptedType != null) return scriptedType;
        } catch (e:haxe.Exception) {
            if (shouldTraceErrors())
                trace('Failed to resolve scripted type $typeName: ${e.message}');
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
                } catch (e:haxe.Exception) {
                    onError(e);
                    cbs.remove(cb);
                }
            }
        }

        var result:Dynamic = null;
        if (exists(event)) {
            try {
                result = Reflect.callMethod(null, get(event), args ?? []);
            } catch (e:haxe.Exception) {
                onError(e);
                rule.variables.remove(event);
                if (rule.interp != null)
                    @:privateAccess cast(rule.interp, hscript.Interp).variables.remove(event);
            }
        }

        if (event == "onCreatePost" && originalAdd != null) {
            set("add", originalAdd);
        }

        return result;
    }

    public function exists(variable:String):Bool {
        return active && rule?.variables.exists(variable);
    }

    public function get(variable:String):Dynamic {
        return exists(variable) ? rule.variables.get(variable) : null;
    }

    public function set(variable:String, value:Dynamic):Void {
        if (active) rule?.variables.set(variable, value);
    }

    public function addCallback(event:String, callback:Dynamic):Void {
        if (!callbacks.exists(event))
            callbacks.set(event, []);
        callbacks.get(event).push(callback);
    }

    public function removeCallback(event:String, callback:Dynamic):Bool {
        return if (callbacks.exists(event)) {
            final arr = callbacks.get(event);
            final result = arr.remove(callback);
            if (arr.length == 0) callbacks.remove(event);
            result;
        } else false;
    }

    function onError(e:haxe.Exception, ?customName:String):Void {
        if (!shouldTraceErrors()) return;

        final target = customName ?? scriptName;
        CoolUtil.showPopUp('Error in $target:\n${e.details()}', 'Error on HScript!');
    }

    public function stop():Void {
        if (!active) return;

        active = false;

        if (resetStaticsOnStop && scriptName != null)
            RuleScriptInterp.resetStatics(scriptName);

        rule?.variables?.clear();
        callbacks?.clear();
        importedPackages?.clear();
        rule = null;
        parentInstance = null;
    }
}
#end