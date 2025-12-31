@echo off
cls
title Necessary Libraries Installer
echo.
echo Installing necessary libraries. Please wait...
echo.
haxelib setup C:\haxelib
haxelib install tjson --quiet
haxelib install hxjsonast --quiet
haxelib git flixel https://github.com/GreenColdTea/flixel.git
haxelib git lime https://github.com/GreenColdTea/lime-9.0.0
haxelib git openfl https://github.com/GreenColdTea/openfl.git
haxelib install format --quiet
haxelib install hxp --quiet
haxelib install flixel-waveform --quiet --skip-dependencies
haxelib run lime setup flixel
haxelib set flixel-tools 1.5.1
haxelib set flixel-addons 4.0.1
haxelib set hxdiscord_rpc 1.3.0
haxelib set hxopus 2.0.0
haxelib install hxflac
haxelib git away3d https://github.com/openfl/away3d.git
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp
haxelib git hxvlc https://github.com/MAJigsaw77/hxvlc.git --quiet --skip-dependencies
haxelib git flxgif https://github.com/GreenColdTea/flxgif.git
haxelib git flxsoundfilters https://github.com/TheZoroForce240/FlxSoundFilters.git
haxelib git rulescript https://github.com/GreenColdTea/RuleScript.git dev --skip-dependencies
haxelib git hscript https://github.com/HaxeFoundation/hscript.git 31882f176a9deb4bda3aaba83f6ebc1981a060b3
haxelib git sl-windows-api https://github.com/GreenColdTea/windows-api-improved.git
haxelib git flixel-animate https://github.com/MaybeMaru/flixel-animate.git 48a00207e84ab3541c82056ea0349cd1df0a8478
haxelib git hxluajit https://github.com/MAJigsaw77/hxluajit.git
haxelib git hxluajit-wrapper https://github.com/MAJigsaw77/hxluajit-wrapper.git --skip-dependencies
haxelib list
echo.
echo Done! Press any key to close the app!
pause
