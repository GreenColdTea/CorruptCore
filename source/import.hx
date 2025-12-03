#if !macro
import game.Paths;

//Flixel
#if (flixel >= '5.3.0')
import flixel.sound.FlxSound;
#else
import flixel.system.FlxSound;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

import lime.app.Application;

// Android things (will be neccesary in the future)
#if android
import android.content.Context as AndroidContext;
import android.widget.Toast as AndroidToast;
import android.os.Environment as AndroidEnvironment;
import android.Permissions as AndroidPermissions;
import android.Settings as AndroidSettings;
import android.Tools as AndroidTools;
import android.os.Build.VERSION as AndroidVersion;
import android.os.Build.VERSION_CODES as AndroidVersionCode;
import android.os.BatteryManager as AndroidBatteryManager;
#end

import psych.ui.*;

import game.backend.ClientPrefs;
import game.backend.utils.CoolUtil;
import game.backend.utils.MemoryUtil;

#if flixel_animate
import animate.*;
import animate.FlxAnimate;
#end

#if flxgif
import flxgif.*;
#end

#if flxsoundfilters
import flixel.sound.filters.*;
#end

#if away3d
import away3d.*;
#end

//mb lol
#if haxeui_flixel
import haxe.ui.backend.flixel.UIState;
#end

// Windows API
#if sl_windows_api
import winapi.*;
import winapi.gdi.*;
#end

#if sys
import sys.*;
import sys.io.*;
#end
#end

using StringTools;

