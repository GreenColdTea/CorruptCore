package game.scripting;

#if LUA_ALLOWED
import hxluajit.Lua;
import hxluajit.LuaL;
import hxluajit.Types;
import hxluajit.wrapper.LuaConverter;
import hxluajit.wrapper.LuaUtils;
import hxluajit.wrapper.LuaError;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.display.FlxBackdrop;

import flixel.system.FlxAssets.FlxShader;

import openfl.Lib;
import openfl.display.BitmapData;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import Type.ValueType;

import game.PlayState;

import game.backend.Controls;
import game.objects.Character;
import game.objects.StrumNote;

#if HSCRIPT_ALLOWED
import rulescript.interps.RuleScriptInterp as Interp;
import rulescript.parsers.HxParser;
#end

#if DISCORD_ALLOWED
import api.Discord;
#end

import game.scripting.lua.*;

using StringTools;

class FunkinLua {
    #if LUA_ALLOWED
    public var lua:cpp.RawPointer<Lua_State> = null;
    #end
    public var scriptName:String = '';
    public var closed:Bool = false;
    public var modFolder:String = null;

    #if HSCRIPT_ALLOWED
    public static var hscript:FunkinHScript = null;
    #end

    public var importedClasses:Map<String, Dynamic> = new Map();

    public static var useCustomFunctions:Bool = false;
    public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var callbacks:Map<String, Dynamic> = new Map<String, Dynamic>();

    public static var lastCalledScript:FunkinLua = null;
    public var lastCalledFunction:String = '';

    public function new(script:String, ?isString:Bool = false) {
        #if LUA_ALLOWED
        lua = LuaL.newstate();
        LuaL.openlibs(lua);

        LuaError.errorHandler = function(error:String) {
            trace('Lua Error: $error');
            #if windows
            CoolUtil.showPopUp(error, 'Lua Error');
            #end
        };

        try {
            var result:Int;
            if (!isString) {
                result = LuaL.dofile(lua, script);
            } else {
                result = LuaL.dostring(lua, script);
            }

            if (result != Lua.OK) {
                var errorMsg:String = Lua.tostring(lua, -1);
                trace('Error loading lua script: $errorMsg');
                #if windows
                if (!isString) CoolUtil.showPopUp(errorMsg, 'Error on lua script!');
                #end
                lua = null;
                return;
            }
        } catch (e:Dynamic) {
            trace('Exception loading lua: $e');
            return;
        }

        scriptName = script;
        var myFolder:Array<String> = this.scriptName.trim().split('/');
        #if MODS_ALLOWED
        if (myFolder[0] + '/' == Mods.getModPath() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) {
            this.modFolder = myFolder[1];
        }
        #end

        #if HSCRIPT_ALLOWED
        initHaxeModule();
        #end

        trace((isString ? 'lua string loaded succesfully' : 'lua file loaded succesfully: $script'));

        set('Function_Stop_Lua', ScriptResult.Function_Stop_Lua);
        set('Function_Stop', ScriptResult.Function_Stop);
        set('Function_Continue', ScriptResult.Function_Continue);

        set('luaDebugMode', false);
        set('luaDeprecatedWarnings', true);
        set('luaPropertyDebugTraces', false);
        set('inChartEditor', false);

        set('curBpm', Conductor.bpm);
        set('bpm', PlayState.SONG.bpm);
        set('scrollSpeed', PlayState.SONG.speed);
        set('crochet', Conductor.crochet);
        set('stepCrochet', Conductor.stepCrochet);
        set('songLength', FlxG.sound.music.length);
        set('songName', PlayState.SONG.song);
        set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
        set('startedCountdown', false);
        set('curStage', PlayState.SONG.stage);

        set('isStoryMode', PlayState.isStoryMode);
        set('difficulty', PlayState.storyDifficulty);

        var difficultyName:String = CoolUtil.difficulties[PlayState.storyDifficulty];
        set('difficultyName', difficultyName);
        set('difficultyPath', Paths.formatToSongPath(difficultyName));
        set('weekRaw', PlayState.storyWeek);
        set('week', WeekData.weeksList[PlayState.storyWeek]);
        set('seenCutscene', PlayState.seenCutscene);

        set('cameraX', 0);
        set('cameraY', 0);

        set('screenWidth', FlxG.width);
        set('screenHeight', FlxG.height);

        // PlayState
        set('curBeat', 0);
        set('curStep', 0);
        set('curDecBeat', 0);
        set('curDecStep', 0);

        set('score', 0);
        set('misses', 0);
        set('hits', 0);

        set('rating', 0);
        set('ratingName', '');
        set('ratingFC', '');
        set('version', Application.current.meta.get('version'));

        set('inGameOver', false);
        set('mustHitSection', false);
        set('altAnim', false);
        set('gfSection', false);

        set('healthGainMult', PlayState.instance.healthGain);
        set('healthLossMult', PlayState.instance.healthLoss);
        set('playbackRate', PlayState.instance.playbackRate);
        set('instakillOnMiss', PlayState.instance.instakillOnMiss);
        set('botPlay', PlayState.instance.cpuControlled);
        set('practice', PlayState.instance.practiceMode);

        for (i in 0...4) {
            set('defaultPlayerStrumX' + i, 0);
            set('defaultPlayerStrumY' + i, 0);
            set('defaultOpponentStrumX' + i, 0);
            set('defaultOpponentStrumY' + i, 0);
        }

        set('defaultBoyfriendX', PlayState.instance.BF_X);
        set('defaultBoyfriendY', PlayState.instance.BF_Y);
        set('defaultOpponentX', PlayState.instance.DAD_X);
        set('defaultOpponentY', PlayState.instance.DAD_Y);
        set('defaultGirlfriendX', PlayState.instance.GF_X);
        set('defaultGirlfriendY', PlayState.instance.GF_Y);

        set('boyfriendName', PlayState.SONG.player1);
        set('dadName', PlayState.SONG.player2);
        set('gfName', PlayState.SONG.gfVersion);

        set('downscroll', ClientPrefs.downScroll);
        set('middlescroll', ClientPrefs.middleScroll);
        set('framerate', ClientPrefs.framerate);
        set('ghostTapping', ClientPrefs.ghostTapping);
        set('hideHud', ClientPrefs.hideHud);
        set('timeBarType', ClientPrefs.timeBarType);
        set('scoreZoom', ClientPrefs.scoreZoom);
        set('cameraZoomOnBeat', ClientPrefs.camZooms);
        set('flashingLights', ClientPrefs.flashing);
        set('noteOffset', ClientPrefs.noteOffset);
        set('healthBarAlpha', ClientPrefs.healthBarAlpha);
        set('noResetButton', ClientPrefs.noReset);
        set('lowQuality', ClientPrefs.lowQuality);
        set('shadersEnabled', ClientPrefs.shaders);
        set('scriptName', scriptName);
        set('currentModDirectory', Mods.currentModDirectory);

        set('buildTarget', CoolUtil.getBuildTarget());

        registerCustomFunctions();

        if (functionExists('onCreate')) call('onCreate', []);
        #end
    }

    private function registerCustomFunctions():Void {
        #if LUA_ALLOWED
        LuaUtils.addFunction(lua, "openCustomSubstate", function(name:String, pauseGame:Bool = false):Void {
            if (pauseGame) {
                PlayState.instance.persistentUpdate = false;
                PlayState.instance.persistentDraw = true;
                PlayState.instance.paused = true;
                if (FlxG.sound.music != null) {
                    FlxG.sound.music.pause();
                    PlayState.instance.vocals.pause();
                }
            }
            PlayState.instance.openSubState(new CustomSubstate(name));
        });

        LuaUtils.addFunction(lua, "closeCustomSubstate", function():Bool {
            if (CustomSubstate.instance != null) {
                PlayState.instance.closeSubState();
                CustomSubstate.instance = null;
                return true;
            }
            return false;
        });

        LuaUtils.addFunction(lua, "getRunningScripts", function():Array<String> {
            var runningScripts:Array<String> = [];
            for (idx in 0...PlayState.instance.luaArray.length) {
                runningScripts.push(PlayState.instance.luaArray[idx].scriptName);
            }
            return runningScripts;
        });

        LuaUtils.addFunction(lua, "callOnLuas", function(funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>):Void {
            if (args == null) args = [];
            if (exclusions == null) exclusions = [];

            var daScriptName:String = scriptName;
            if (ignoreSelf && !exclusions.contains(daScriptName)) {
                exclusions.push(daScriptName);
            }
            PlayState.instance.callOnLuas(funcName, args, ignoreStops, exclusions);
        });

        LuaUtils.addFunction(lua, "callScript", function(luaFile:String, funcName:String, ?args:Array<Dynamic>):Dynamic {
            if (args == null) args = [];
            
            var cervix:String = luaFile + ".lua";
            if (luaFile.endsWith(".lua")) cervix = luaFile;
            
            var doPush:Bool = false;
            #if MODS_ALLOWED
            if (FileSystem.exists(Mods.modFolders(cervix))) {
                cervix = Mods.modFolders(cervix);
                doPush = true;
            } else if (FileSystem.exists(cervix)) {
                doPush = true;
            } else {
                cervix = Paths.getPreloadPath(cervix);
                if (FileSystem.exists(cervix)) {
                    doPush = true;
                }
            }
            #else
            cervix = Paths.getPreloadPath(cervix);
            if (Assets.exists(cervix)) {
                doPush = true;
            }
            #end
            
            if (doPush) {
                for (luaInstance in PlayState.instance.luaArray) {
                    if (luaInstance.scriptName == cervix) {
                        return luaInstance.call(funcName, args);
                    }
                }
            }
            return null;
        });

        #if MODS_ALLOWED
        LuaUtils.addFunction(lua, "getModSetting", function(saveTag:String, ?modName:String = null):Dynamic {
            if (modName == null) {
                if (this.modFolder == null) {
                    luaTrace('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', false, false, FlxColor.RED);
                    return null;
                }
                modName = this.modFolder;
            }
            return CoolUtil.getModSetting(saveTag, modName);
        });
        #end

        LuaUtils.addFunction(lua, "getGlobalFromScript", function(luaFile:String, global:String):Dynamic {
            var cervix:String = luaFile + ".lua";
            if (luaFile.endsWith(".lua")) cervix = luaFile;
            
            var doPush:Bool = false;
            #if MODS_ALLOWED
            if (FileSystem.exists(Mods.modFolders(cervix))) {
                cervix = Mods.modFolders(cervix);
                doPush = true;
            } else if (FileSystem.exists(cervix)) {
                doPush = true;
            } else {
                cervix = Paths.getPreloadPath(cervix);
                if (FileSystem.exists(cervix)) {
                    doPush = true;
                }
            }
            #else
            cervix = Paths.getPreloadPath(cervix);
            if (Assets.exists(cervix)) {
                doPush = true;
            }
            #end
            
            if (doPush) {
                for (luaInstance in PlayState.instance.luaArray) {
                    if (luaInstance.scriptName == cervix) {
                        return LuaUtils.getVariable(luaInstance.lua, global);
                    }
                }
            }
            return null;
        });

        LuaUtils.addFunction(lua, "setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic):Void {
            var cervix:String = luaFile + ".lua";
            if (luaFile.endsWith(".lua")) cervix = luaFile;
            
            var doPush:Bool = false;
            #if MODS_ALLOWED
            if (FileSystem.exists(Mods.modFolders(cervix))) {
                cervix = Mods.modFolders(cervix);
                doPush = true;
            } else if (FileSystem.exists(cervix)) {
                doPush = true;
            } else {
                cervix = Paths.getPreloadPath(cervix);
                if (FileSystem.exists(cervix)) {
                    doPush = true;
                }
            }
            #else
            cervix = Paths.getPreloadPath(cervix);
            if (Assets.exists(cervix)) {
                doPush = true;
            }
            #end
            
            if (doPush) {
                for (luaInstance in PlayState.instance.luaArray) {
                    if (luaInstance.scriptName == cervix) {
                        luaInstance.set(global, val);
                    }
                }
            }
        });

        LuaUtils.addFunction(lua, "isRunning", function(luaFile:String):Bool {
            var cervix:String = luaFile + ".lua";
            if (luaFile.endsWith(".lua")) cervix = luaFile;
            
            var doPush:Bool = false;
            #if MODS_ALLOWED
            if (FileSystem.exists(Mods.modFolders(cervix))) {
                cervix = Mods.modFolders(cervix);
                doPush = true;
            } else if (FileSystem.exists(cervix)) {
                doPush = true;
            } else {
                cervix = Paths.getPreloadPath(cervix);
                if (FileSystem.exists(cervix)) {
                    doPush = true;
                }
            }
            #else
            cervix = Paths.getPreloadPath(cervix);
            if (Assets.exists(cervix)) {
                doPush = true;
            }
            #end

            if (doPush) {
                for (luaInstance in PlayState.instance.luaArray) {
                    if (luaInstance.scriptName == cervix) {
                        return true;
                    }
                }
            }
            return false;
        });

        LuaUtils.addFunction(lua, "addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false):Void {
            var cervix:String = luaFile + ".lua";
            if (luaFile.endsWith(".lua")) cervix = luaFile;
            
            var doPush:Bool = false;
            #if MODS_ALLOWED
            if (FileSystem.exists(Mods.modFolders(cervix))) {
                cervix = Mods.modFolders(cervix);
                doPush = true;
            } else if (FileSystem.exists(cervix)) {
                doPush = true;
            } else {
                cervix = Paths.getPreloadPath(cervix);
                if (FileSystem.exists(cervix)) {
                    doPush = true;
                }
            }
            #else
            cervix = Paths.getPreloadPath(cervix);
            if (Assets.exists(cervix)) {
                doPush = true;
            }
            #end

            if (doPush) {
                if (!ignoreAlreadyRunning) {
                    for (luaInstance in PlayState.instance.luaArray) {
                        if (luaInstance.scriptName == cervix) {
                            luaTrace('addLuaScript: The script "$cervix" is already running!');
                            return;
                        }
                    }
                }
                PlayState.instance.luaArray.push(new FunkinLua(cervix));
                return;
            }
            luaTrace("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
        });

        LuaUtils.addFunction(lua, "removeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false):Void {
            var cervix:String = luaFile + ".lua";
            if (luaFile.endsWith(".lua")) cervix = luaFile;
            
            var doPush:Bool = false;
            #if MODS_ALLOWED
            if (FileSystem.exists(Mods.modFolders(cervix))) {
                cervix = Mods.modFolders(cervix);
                doPush = true;
            } else if (FileSystem.exists(cervix)) {
                doPush = true;
            } else {
                cervix = Paths.getPreloadPath(cervix);
                if (FileSystem.exists(cervix)) {
                    doPush = true;
                }
            }
            #else
            cervix = Paths.getPreloadPath(cervix);
            if (Assets.exists(cervix)) {
                doPush = true;
            }
            #end

            if (doPush) {
                if (!ignoreAlreadyRunning) {
                    for (luaInstance in PlayState.instance.luaArray) {
                        if (luaInstance.scriptName == cervix) {
                            PlayState.instance.luaArray.remove(luaInstance);
                            return;
                        }
                    }
                }
                return;
            }
            luaTrace("removeLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
        });

        #if HSCRIPT_ALLOWED
        LuaUtils.addFunction(lua, "runHaxeCode", function(codeToRun:String):Dynamic {
            var retVal:Dynamic = null;
            initHaxeModule();
            try {
                if (hscript != null) {
                    retVal = hscript.executeString(codeToRun);
                }
            } catch (e:Dynamic) {
                luaTrace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
            }

            if (retVal != null && !isOfTypes(retVal, [Bool, Int, Float, String, Array])) {
                retVal = null;
            }
            return retVal;
        });

        LuaUtils.addFunction(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = ''):Void {
            initHaxeModule();
            try {
                var str:String = '';
                if (libPackage.length > 0) {
                    str = libPackage + '.';
                }
                hscript.set(libName, Type.resolveClass(str + libName));
            } catch (e:Dynamic) {
                luaTrace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
            }
        });
        #end

        LuaUtils.addFunction(lua, "getProperty", function(variable:String):Dynamic {
            var result:Dynamic = null;
            var killMe:Array<String> = variable.split('.');
            if (killMe.length > 1) {
                result = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
            } else {
                result = getVarInArray(getInstance(), variable);
            }
            return result;
        });

        LuaUtils.addFunction(lua, "setProperty", function(variable:String, value:Dynamic):Bool {
            var killMe:Array<String> = variable.split('.');
            if (killMe.length > 1) {
                setVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1], value);
            } else {
                setVarInArray(getInstance(), variable, value);
            }
            return true;
        });

        LuaUtils.addFunction(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic):Dynamic {
            var shitMyPants:Array<String> = obj.split('.');
            var realObject:Dynamic = Reflect.getProperty(getInstance(), obj);
            if (shitMyPants.length > 1) {
                realObject = getPropertyLoopThingWhatever(shitMyPants, true, false);
            }

            if (Std.isOfType(realObject, FlxTypedGroup)) {
                var result:Dynamic = getGroupStuff(realObject.members[index], variable);
                return result;
            }

            var leArray:Dynamic = realObject[index];
            if (leArray != null) {
                var result:Dynamic = null;
                if (Type.typeof(variable) == ValueType.TInt) {
                    result = leArray[variable];
                } else {
                    result = getGroupStuff(leArray, variable);
                }
                return result;
            }
            luaTrace("getPropertyFromGroup: Object #" + index + " from group: " + obj + " doesn't exist!", false, false, FlxColor.RED);
            return null;
        });

        LuaUtils.addFunction(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic):Void {
            var shitMyPants:Array<String> = obj.split('.');
            var realObject:Dynamic = Reflect.getProperty(getInstance(), obj);
            if (shitMyPants.length > 1) {
                realObject = getPropertyLoopThingWhatever(shitMyPants, true, false);
            }

            if (Std.isOfType(realObject, FlxTypedGroup)) {
                setGroupStuff(realObject.members[index], variable, value);
                return;
            }

            var leArray:Dynamic = realObject[index];
            if (leArray != null) {
                if (Type.typeof(variable) == ValueType.TInt) {
                    leArray[variable] = value;
                    return;
                }
                setGroupStuff(leArray, variable, value);
            }
        });

        LuaUtils.addFunction(lua, "removeFromGroup", function(obj:String, index:Int, dontDestroy:Bool = false):Void {
            if (Std.isOfType(Reflect.getProperty(getInstance(), obj), FlxTypedGroup)) {
                var sex = Reflect.getProperty(getInstance(), obj).members[index];
                if (!dontDestroy) {
                    sex.kill();
                }
                Reflect.getProperty(getInstance(), obj).remove(sex, true);
                if (!dontDestroy) {
                    sex.destroy();
                }
                return;
            }
            Reflect.getProperty(getInstance(), obj).remove(Reflect.getProperty(getInstance(), obj)[index]);
        });

        LuaUtils.addFunction(lua, "getPropertyFromClass", function(classVar:String, variable:String):Dynamic {
            var killMe:Array<String> = variable.split('.');
            if (killMe.length > 1) {
                var coverMeInPiss:Dynamic = getVarInArray(Type.resolveClass(classVar), killMe[0]);
                for (i in 1...killMe.length-1) {
                    coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
                }
                return getVarInArray(coverMeInPiss, killMe[killMe.length-1]);
            }
            return getVarInArray(Type.resolveClass(classVar), variable);
        });

        LuaUtils.addFunction(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic):Bool {
            var killMe:Array<String> = variable.split('.');
            if (killMe.length > 1) {
                var coverMeInPiss:Dynamic = getVarInArray(Type.resolveClass(classVar), killMe[0]);
                for (i in 1...killMe.length-1) {
                    coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
                }
                setVarInArray(coverMeInPiss, killMe[killMe.length-1], value);
                return true;
            }
            setVarInArray(Type.resolveClass(classVar), variable, value);
            return true;
        });

        final luaFuncs:Array<Dynamic> = [
            LuaColor,
            LuaControls,
            LuaFileManager,
            LuaObject,
            LuaPlayState,
            LuaSave,
            LuaSound,
            LuaSprites,
            LuaText,
            LuaTimer,
            LuaTween,
            LuaRandom,
            LuaShader,
            LuaDeprecated
        ];
        
        for (luaFunc in luaFuncs) {
            if (luaFunc != null && Reflect.isFunction(luaFunc.init)) {
                luaFunc.init(this);
            }
        }

        LuaUtils.addFunction(lua, "debugPrint", function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = ''):Void {
            text1 = (text1 == null) ? '' : text1;
            text2 = (text2 == null) ? '' : text2;
            text3 = (text3 == null) ? '' : text3;
            text4 = (text4 == null) ? '' : text4;
            text5 = (text5 == null) ? '' : text5;
            luaTrace('' + text1 + text2 + text3 + text4 + text5, true, false);
        });

        LuaUtils.addFunction(lua, "import", function(className:String, ?packagePath:String = ""):Void {
            #if HSCRIPT_ALLOWED
            importClass(className, packagePath);
            #end
        });

        LuaUtils.addFunction(lua, "getParent", function():Dynamic {
            return Std.isOfType(FlxG.state, PlayState) ? PlayState.instance : FlxG.state.subState ?? FlxG.state;
        });

        LuaUtils.addFunction(lua, "close", function():Bool {
            closed = true;
            return closed;
        });

        LuaUtils.addFunction(lua, "changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Bool {
            #if DISCORD_ALLOWED
            DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
            #else
            luaTrace('changePresence: Discord presence is not allowed in this platform.', false, false, FlxColor.RED);
            #end
            return true;
        });

        // String functions
        LuaUtils.addFunction(lua, "stringStartsWith", function(str:String, start:String):Bool {
            return str.startsWith(start);
        });

        LuaUtils.addFunction(lua, "stringEndsWith", function(str:String, end:String):Bool {
            return str.endsWith(end);
        });

        LuaUtils.addFunction(lua, "stringSplit", function(str:String, split:String):Array<String> {
            return str.split(split);
        });

        LuaUtils.addFunction(lua, "stringTrim", function(str:String):String {
            return str.trim();
        });

       LuaUtils.addFunction(lua, "directoryFileList", function(folder:String):Array<String> {
            var list:Array<String> = [];
            
            #if sys
            if (FileSystem.exists(folder)) {
                for (file in FileSystem.readDirectory(folder)) {
                    if (!list.contains(file)) {
                        list.push(file);
                    }
                }
            }
            #else
            var folderWithSlash:String = folder.endsWith("/") ? folder : folder + "/";
            var allAssets:Array<String> = Assets.list();
            
            for (assetPath in allAssets) {
                if (assetPath.startsWith(folderWithSlash)) {
                    var parts:Array<String> = assetPath.split("/");
                    if (parts.length > 0) {
                        var fileName:String = parts[parts.length - 1];
                        if (fileName.length > 0 && !list.contains(fileName)) {
                            list.push(fileName);
                        }
                    }
                }
            }
            #end
            
            return list;
        });

        #if HSCRIPT_ALLOWED
        LuaUtils.addFunction(lua, "setOnHScript", PlayState.instance.setOnHScript);

        LuaUtils.addFunction(lua, "callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Dynamic {
            excludeScripts = (excludeScripts == null) ? [] : excludeScripts;
            if (ignoreSelf && !excludeScripts.contains(scriptName)) {
                excludeScripts.push(scriptName);
            }
            return PlayState.instance.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
        });
        #end

        if (useCustomFunctions && customFunctions != null) {
            for (tag => func in customFunctions) {
                LuaUtils.addFunction(lua, Std.string(tag), func);
            }
        }
        #end
    }

    public static function isOfTypes(value:Any, types:Array<Dynamic>):Bool {
        for (type in types) {
            if (Std.isOfType(value, type)) return true;
        }
        return false;
    }

    public function addLocalCallback(name:String, func:Dynamic):Void {
        callbacks.set(name, func);
        #if LUA_ALLOWED
        LuaUtils.addFunction(lua, name, func);
        #end
    }

    #if HSCRIPT_ALLOWED
    public function initHaxeModule():Void {
        if (hscript == null) {
            trace('initializing haxe interp for: $scriptName');
            hscript = new FunkinHScript("", PlayState.instance, true);
            hscript.scriptName = scriptName;
        }
    }
    #end

    public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Bool {
        if (variable == null || variable.length == 0) {
            #if LUA_ALLOWED
            if (getBool('luaDebugMode')) {
                trace('ERROR: setVarInArray - variable is null or empty (instance: $instance)');
            }
            #end
            return false;
        }

        var shit:Array<String> = variable.split('[');
        if (shit.length > 1) {
            var blah:Dynamic = null;
            var propName:String = shit[0];
            var instanceInfo:String = getObjectInfo(instance);

            if (PlayState.instance != null && PlayState.instance.variables.exists(propName)) {
                blah = PlayState.instance.variables.get(propName);
            } else if (instance != null && Reflect.hasField(instance, propName)) {
                blah = Reflect.getProperty(instance, propName);
            }

            if (blah == null) {
                #if LUA_ALLOWED
                if (getBool('luaDebugPropertyTraces')) trace('WARNING: Property not found: "${shit[0]}" (object: $instanceInfo, full path: $variable)');
                #end
                return false;
            }

            for (i in 1...shit.length) {
                var arrayPart:String = shit[i];
                if (arrayPart.endsWith(']')) arrayPart = arrayPart.substr(0, arrayPart.length - 1);

                if (arrayPart.length == 0) continue;

                var key:Dynamic = try Std.parseInt(arrayPart) catch(e:Dynamic) arrayPart;

                if (i == shit.length - 1) {
                    if (Std.isOfType(blah, Array) || Reflect.hasField(blah, 'set') || Reflect.isObject(blah)) {
                        try {
                            Reflect.setProperty(blah, key, value);
                            return true;
                        } catch (e:Dynamic) {
                            var blahInfo:String = getObjectInfo(blah);
                            #if LUA_ALLOWED
                            if (getBool('luaDebugPropertyTraces')) trace('ERROR: Failed to set property "$variable" on object: $blahInfo - ${e.message}');
                            #end
                            return false;
                        }
                    }
                    var blahInfo:String = getObjectInfo(blah);
                    #if LUA_ALLOWED if (getBool('luaDebugPropertyTraces')) #end trace('WARNING: Cannot set index on non-array: "${shit[0]}" (object: $blahInfo, type: ${Type.getClassName(Type.getClass(blah))})');
                    return false;
                } else {
                    if (blah != null && (Reflect.isObject(blah) || Std.isOfType(blah, Array))) {
                        try {
                            blah = Reflect.getProperty(blah, key);
                        } catch (e:Dynamic) {
                            var blahInfo:String = getObjectInfo(blah);
                            #if LUA_ALLOWED
                            if (getBool('luaDebugPropertyTraces')) trace('ERROR: Failed to access index "$key" on object: $blahInfo while setting "$variable" - ${e.message}');
                            #end
                            return false;
                        }
                    } else {
                        var blahInfo:String = getObjectInfo(blah);
                        #if LUA_ALLOWED
                        if (getBool('luaDebugPropertyTraces')) trace('WARNING: Cannot access index on non-container: ${shit.slice(0, i).join('[')} (object: $blahInfo, type: ${Type.getClassName(Type.getClass(blah))})');
                        #end
                        return false;
                    }
                }
            }
            return false;
        }

        try {
            var instanceInfo:String = getObjectInfo(instance);

            if (PlayState.instance != null && PlayState.instance.variables.exists(variable)) {
                PlayState.instance.variables.set(variable, value);
                return true;
            }

            if (instance != null) {
                Reflect.setProperty(instance, variable, value);
                return true;
            }

            #if LUA_ALLOWED
            #if LUA_ALLOWED if (getBool('luaDebugPropertyTraces')) #end trace('WARNING: Instance is null for property: "$variable" (called from Lua script, object info: $instanceInfo)');
            #end
            return false;
        } catch (e:Dynamic) {
            var instanceInfo:String = getObjectInfo(instance);
            #if LUA_ALLOWED
            #if LUA_ALLOWED if (getBool('luaDebugPropertyTraces')) #end trace('ERROR: Failed to set property "$variable" on object: $instanceInfo - ${e.message}');
            #end
            return false;
        }
    }

    public static function getVarInArray(instance:Dynamic, variable:String):Any {
        var shit:Array<String> = variable.split('[');
        if (shit.length > 1) {
            var blah:Dynamic = null;
            if (PlayState.instance.variables.exists(shit[0])) {
                var retVal:Dynamic = PlayState.instance.variables.get(shit[0]);
                if (retVal != null) {
                    blah = retVal;
                }
            } else {
                blah = Reflect.getProperty(instance, shit[0]);
            }

            for (i in 1...shit.length) {
                var leNumStr:Dynamic = shit[i].substr(0, shit[i].length - 1);
                var leNum:Dynamic = try Std.parseInt(leNumStr) catch (_) null;
                leNum = (leNum == null) ? leNumStr : leNum;

                blah = Reflect.getProperty(blah, leNum);
            }
            return blah;
        }

        if (PlayState.instance.variables.exists(variable)) {
            var retVal:Dynamic = PlayState.instance.variables.get(variable);
            if (retVal != null) {
                return retVal;
            }
        }

        return Reflect.getProperty(instance, variable);
    }

    private static function getObjectInfo(obj:Dynamic):String {
        if (obj == null) return "null";

        var className:String = Type.getClassName(Type.getClass(obj));
        var result:String = 'type: $className';

        if (Std.isOfType(obj, FlxSprite)) {
            var sprite:FlxSprite = cast obj;
            result += ', x: ${sprite.x}, y: ${sprite.y}, visible: ${sprite.visible}';
        } else if (Std.isOfType(obj, Character)) {
            var char:Character = cast obj;
            result += ', curCharacter: ${char.curCharacter}, x: ${char.x}, y: ${char.y}';
        } else if (Std.isOfType(obj, FlxText)) {
            var text:FlxText = cast obj;
            result += ', text: "${text.text}", x: ${text.x}, y: ${text.y}';
        } else if (Std.isOfType(obj, FlxCamera)) {
            var cam:FlxCamera = cast obj;
            result += ', x: ${cam.scroll.x}, y: ${cam.scroll.y}, zoom: ${cam.zoom}';
        } else if (Std.isOfType(obj, String)) {
            result += ', value: "$obj"';
        } else if (Std.isOfType(obj, Int) || Std.isOfType(obj, Float)) {
            result += ', value: $obj';
        } else if (Std.isOfType(obj, Bool)) {
            result += ', value: $obj';
        }

        return result;
    }

    function getGroupStuff(leArray:Dynamic, variable:String):Dynamic {
        var killMe:Array<String> = variable.split('.');
        if (killMe.length > 1) {
            var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
            for (i in 1...killMe.length-1) {
                coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
            }
            return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
        }
        return Reflect.getProperty(leArray, variable);
    }

    function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic):Void {
        var killMe:Array<String> = variable.split('.');
        if (killMe.length > 1) {
            var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
            for (i in 1...killMe.length-1) {
                coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
            }
            Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
            return;
        }
        Reflect.setProperty(leArray, variable, value);
    }

    public static function cameraFromString(cam:String):FlxCamera {
        switch (cam.toLowerCase()) {
            case 'camhud' | 'hud': return PlayState.instance.camHUD;
            case 'camother' | 'other': return PlayState.instance.camOther;
        }
        return PlayState.instance.camGame;
    }

    public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE):Void {
        #if LUA_ALLOWED
        if (ignoreCheck || getBool('luaDebugMode')) {
            if (deprecated && !getBool('luaDeprecatedWarnings')) {
                return;
            }
            PlayState.instance.addTextToDebug(text, color);
            trace(text);
        }
        #end
    }

    function getErrorMessage(status:Int):String {
        #if LUA_ALLOWED
        var v:String = Lua.tostring(lua, -1);
        Lua.pop(lua, 1);

        if (v != null) v = v.trim();
        if (v == null || v == "") {
            if (status == 2) return "Runtime Error"; // LUA_ERRRUN = 2
            else if (status == 4) return "Memory Allocation Error"; // LUA_ERRMEM = 4
            else if (status == 5) return "Critical Error"; // LUA_ERRERR = 5
            return "Unknown Error";
        }

        return v;
        #end
        return null;
    }

    function typeToString(type:Int):String {
        #if LUA_ALLOWED
        if (type == 1) return "boolean"; // LUA_TBOOLEAN = 1
        else if (type == 3) return "number"; // LUA_TNUMBER = 3
        else if (type == 4) return "string"; // LUA_TSTRING = 4
        else if (type == 5) return "table"; // LUA_TTABLE = 5
        else if (type == 6) return "function"; // LUA_TFUNCTION = 6
        
        if (type <= 0) return "nil"; // LUA_TNIL = 0
        #end
        return "unknown";
    }

    public function call(func:String, args:Array<Dynamic>):Dynamic {
        #if LUA_ALLOWED
        if (closed || lua == null) return Function_Continue;

        lastCalledFunction = func;
        lastCalledScript = this;

        try {
            Lua.getglobal(lua, func);
            var type:Int = Lua.type(lua, -1);
            
            if (type != 6) { // 6 = LUA_TFUNCTION
                Lua.pop(lua, 1);
                
                if (func != 'onCreate' && func != 'onUpdate' && func != 'onStepHit' && 
                    func != 'onBeatHit' && func != 'eventEarlyTrigger') {
                    trace('Lua function "$func" not found');
                }
                return Function_Continue;
            }

            for (arg in args) {
                LuaConverter.toLua(lua, arg);
            }

            var status:Int = Lua.pcall(lua, args.length, 1, 0);

            if (status != Lua.OK) {
                var error:String = Lua.tostring(lua, -1);
                if (error != 'attempt to call a nil value' && !error.contains('onCreate') && !error.contains('eventEarlyTrigger')) {
                    luaTrace('ERROR ($func): $error', false, false, FlxColor.RED);
                }
                Lua.pop(lua, 1);
                return Function_Continue;
            }

            var result:Dynamic = LuaConverter.fromLua(lua, -1);
            Lua.pop(lua, 1);

            if (result == null) result = Function_Continue;
            return result;
        } catch (e:Dynamic) {
            trace('Error calling Lua function $func: $e');
        }
        #end
        return Function_Continue;
    }

    public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool = true):Dynamic {
        if (killMe.length == 0) {
            #if LUA_ALLOWED if (getBool('luaDebugPropertyTraces')) #end trace('ERROR: getPropertyLoopThingWhatever - empty path array');
            return null;
        }

        var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0], checkForTextsToo);
        var end:Int = killMe.length;
        if (getProperty) end = killMe.length - 1;

        for (i in 1...end) {
            if (coverMeInPiss == null) {
                #if LUA_ALLOWED if (getBool('luaDebugPropertyTraces')) #end trace('WARNING: getPropertyLoopThingWhatever - null object at path: ${killMe.slice(0, i).join(".")} (full path: ${killMe.join(".")})');
                return null;
            }
            coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
        }
        return coverMeInPiss;
    }

    public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic {
        var coverMeInPiss:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
        if (coverMeInPiss == null) {
            coverMeInPiss = getVarInArray(getInstance(), objectName);
        }
        return coverMeInPiss;
    }

    public function set(variable:String, data:Dynamic):Void {
        #if LUA_ALLOWED
        if (lua == null) return;
        LuaUtils.setVariable(lua, variable, data);
        #end
    }

    #if LUA_ALLOWED
    static function getBool(variable:String):Bool {
        if (lastCalledScript == null) return false;

        var lua:cpp.RawPointer<Lua_State> = lastCalledScript.lua;
        if (lua == null) return false;

        var result:Dynamic = LuaUtils.getVariable(lua, variable);
        return (result == true || result == 'true');
    }
    #end

    public function stop():Void {
        #if LUA_ALLOWED
        if (lua == null) return;

        LuaUtils.cleanupStateFunctions(lua);
        Lua.close(lua);
        lua = null;
        #end
    }

    public static inline function getInstance():Dynamic {
        return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
    }

    public function safeCall(func:String, args:Array<Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if (functionExists(func)) {
			return call(func, args);
		}
		#end
		return Function_Continue;
	}

    public function functionExists(func:String):Bool {
        #if LUA_ALLOWED
        if (lua == null) return false;
        
        Lua.getglobal(lua, func);
        var exists:Bool = Lua.type(lua, -1) == 6; // 6 = LUA_TFUNCTION
        Lua.pop(lua, 1);
        return exists;
        #else
        return false;
        #end
    }

    #if HSCRIPT_ALLOWED
    public function importClass(className:String, ?packagePath:String = ""):Void {
        initHaxeModule();
        try {
            var fullPath:String = className;
            if (packagePath.length > 0) {
                fullPath = packagePath + '.' + className;
            }

            var clazz = Type.resolveClass(fullPath);
            if (clazz != null) {
                importedClasses.set(className, clazz);
                set(className, createLuaClassWrapper(clazz, className));
            } else {
                luaTrace('Cannot import class: $fullPath', false, false, FlxColor.RED);
            }
        } catch (e:Dynamic) {
            luaTrace('Error importing class $className: $e', false, false, FlxColor.RED);
        }
    }

    private function createLuaClassWrapper(clazz:Class<Dynamic>, className:String):Dynamic {
        #if LUA_ALLOWED
        var wrapper:Dynamic = {};
        
        Reflect.setField(wrapper, "new", function(args:Array<Dynamic> = null):Dynamic {
            args ??= [];
            return createLuaInstance(clazz, args);
        });
        
        return wrapper;
        #else
        return null;
        #end
    }

    private function createLuaInstance(clazz:Class<Dynamic>, args:Array<Dynamic> = null):Dynamic {
        args ??= [];
        
        try {
            var instance = Type.createInstance(clazz, args);
            return createLuaObjectWrapper(instance);
        } catch (e:Dynamic) {
            trace('Error creating instance of $clazz: $e');
            return null;
        }
    }

    private function createLuaObjectWrapper(obj:Dynamic):Dynamic {
        #if LUA_ALLOWED
        var wrapper:Dynamic = {};
        
        var fields = Reflect.fields(obj);
        for (field in fields) {
            var value = Reflect.field(obj, field);
            if (Reflect.isFunction(value)) {
                Reflect.setField(wrapper, field, function(args:Array<Dynamic> = null):Dynamic {
                    args ??= [];
                    return Reflect.callMethod(obj, value, args);
                });
            } else {
                Reflect.setField(wrapper, field, value);
            }
        }
        
        return wrapper;
        #else
        return null;
        #end
    }
    #end
}

class ModchartSprite extends FlxSprite {
    public var wasAdded:Bool = false;
    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

    public function new(?x:Float = 0, ?y:Float = 0) {
        super(x, y);
        antialiasing = ClientPrefs.globalAntialiasing;
    }
}

#if flixel_animate
class ModchartAnimateSprite extends FlxAnimate
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	public function new(?x:Float = 0, ?y:Float = 0, ?path:String)
	{
		super(x, y, path);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
	{
		anim.play(name, forced, reverse, startFrame);
		
		var daOffset = animOffsets.get(name);
		if (animOffsets.exists(name)) offset.set(daOffset[0], daOffset[1]);
	}

	public function addOffset(name:String, x:Float, y:Float)
	{
		animOffsets.set(name, [x, y]);
	}
}
#end

class ModchartBackdrop extends FlxBackdrop {
    public var wasAdded:Bool = false;
    public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

    public function new(graphic:Dynamic, ?x:Float = 0, ?y:Float = 0, repeatX:Bool = true, repeatY:Bool = true) {
        super(x, y);

        if (graphic != null) {
            loadGraphic(graphic, repeatX, repeatY);
        }

        antialiasing = ClientPrefs.globalAntialiasing;
    }
}

class ModchartText extends FlxText {
    public var wasAdded:Bool = false;
    
    public function new(x:Float, y:Float, text:String, width:Float) {
        super(x, y, width, text, 16);
        setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        cameras = [PlayState.instance.camHUD];
        scrollFactor.set();
        borderSize = 2;
    }
}

class DebugLuaText extends FlxText {
    private var disableTime:Float = 6;
    public var readyToRemove:Bool = false;
    public var parentGroup:FlxTypedGroup<DebugLuaText>;

    public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>, color:FlxColor) {
        this.parentGroup = parentGroup;
        super(10, 10, FlxG.width - 20, text, 16);
        
        setFormat(Paths.font("vcr.ttf"), 16, color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        scrollFactor.set();
        borderSize = 1;
        
        wordWrap = true;
        
        updateHitbox();
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        disableTime -= elapsed;
        
        if (disableTime < 0) disableTime = 0;
        if (disableTime < 1) alpha = disableTime;
        
        if (disableTime <= 0 && alpha <= 0) {
            readyToRemove = true;
        }
    }
}

class DebugTextGroup extends FlxTypedGroup<DebugLuaText> {
    private var totalHeight:Float = 0;
    
    public function new() {
        super();
    }
    
    public function addText(text:DebugLuaText) {
        insert(0, text);
        recalculatePositions();
    }
    
    public function removeText(text:DebugLuaText) {
        remove(text);
        recalculatePositions();
    }
    
    override function update(elapsed:Float) {
        super.update(elapsed);
        
        var i:Int = 0;
        while (i < length) {
            var text = members[i];
            if (text != null && text.readyToRemove) {
                removeText(text);
                text.destroy();
            } else {
                i++;
            }
        }
    }
    
    public function recalculatePositions() {
        totalHeight = 10;
        
        forEachAlive(function(text:DebugLuaText) {
            text.y = totalHeight;
            totalHeight += text.height + 5;
        });
    }
}

class CustomSubstate extends MusicBeatSubstate {
    public static var name:String = 'unnamed';
    public static var instance:CustomSubstate;

    override function create() {
        instance = this;

        PlayState.instance?.callOnLuas('onCustomSubstateCreate', [name]);
        super.create();
        PlayState.instance?.callOnLuas('onCustomSubstateCreatePost', [name]);
    }
    
    public function new(name:String) {
        CustomSubstate.name = name;
        super();
    }
    
    override function update(elapsed:Float) {
        PlayState.instance?.callOnLuas('onCustomSubstateUpdate', [name, elapsed]);
        super.update(elapsed);
        PlayState.instance?.callOnLuas('onCustomSubstateUpdatePost', [name, elapsed]);
    }

    override function destroy() {
        PlayState.instance?.callOnLuas('onCustomSubstateDestroy', [name]);
        super.destroy();
    }
}