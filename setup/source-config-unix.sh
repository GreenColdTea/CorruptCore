#!/bin/bash
clear
echo
echo "Installing necessary libraries. Please wait..."
echo

haxelib setup ~/haxelib

haxelib install tjson --quiet
haxelib install hxjsonast --quiet
haxelib set flixel 6.1.2
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
haxelib git rulescript https://github.com/Kriptel/RuleScript.git dev --skip-dependencies
haxelib git hscript https://github.com/HaxeFoundation/hscript.git caa5f0bf7fcf145edd1f48e3c7575e6ae5be5c32
haxelib git sl-windows-api https://github.com/GreenColdTea/windows-api-improved.git
haxelib git flixel-animate https://github.com/MaybeMaru/flixel-animate.git c61476f4b3a3d225631ab3065e4e925a4b63c076
haxelib git hxluajit https://github.com/MAJigsaw77/hxluajit.git
haxelib git hxluajit-wrapper https://github.com/MAJigsaw77/hxluajit-wrapper.git --skip-dependencies
haxelib list

echo
read -n 1 -s -r -p "Done! Press any key to close the app!"
echo
