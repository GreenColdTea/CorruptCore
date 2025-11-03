@echo off
cls
title Necessary Libraries Installer
echo.
echo Installing necessary libraries. Please wait...
echo.
haxelib setup C:\haxelib
haxelib install tjson --quiet
haxelib install hxjsonast --quiet
haxelib install flxgif --quiet
haxelib set flixel 6.1.1
haxelib git lime https://github.com/GreenColdTea/lime-9.0.0
haxelib git openfl https://github.com/GreenColdTea/openfl.git
haxelib install format --quiet
haxelib install hxp --quiet
haxelib install flixel-waveform --quiet --skip-dependencies
haxelib run lime setup flixel
haxelib set flixel-tools 1.5.1
haxelib set flixel-addons 3.3.2
haxelib set hxdiscord_rpc 1.3.0
haxelib set hxopus 2.0.0
haxelib git away3d https://github.com/openfl/away3d.git
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp
haxelib git hxvlc https://github.com/MAJigsaw77/hxvlc.git --quiet --skip-dependencies
haxelib git flxsoundfilters https://github.com/TheZoroForce240/FlxSoundFilters.git
haxelib git rulescript https://github.com/Kriptel/RuleScript.git dev --skip-dependencies
haxelib git hscript https://github.com/HaxeFoundation/hscript.git 92ffe9c519bbccf783df0b3400698c5b3cc645ef
haxelib git sl-windows-api https://github.com/GreenColdTea/windows-api-improved.git
haxelib git flixel-animate https://github.com/MaybeMaru/flixel-animate.git 220463c8089444d6c9957b68919fe88e6cba495f
haxelib git hxluajit https://github.com/MAJigsaw77/hxluajit.git
haxelib git hxluajit-wrapper https://github.com/MAJigsaw77/hxluajit-wrapper.git --skip-dependencies
haxelib list
echo.
echo Done! Press any key to close the app!
pause
