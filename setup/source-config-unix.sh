#!/bin/bash
clear
echo
echo "Installing necessary libraries. Please wait..."
echo

haxelib setup ~/haxelib

haxelib install tjson --quiet
haxelib install hxjsonast --quiet
haxelib install flxgif --quiet
haxelib set flixel 6.1.1
haxelib git lime https://github.com/GreenColdTea/lime-9.0.0
haxelib install format
haxelib install hxp
haxelib set openfl 9.4.2
haxelib install hxvlc --quiet --skip-dependencies
haxelib run lime setup flixel
haxelib set flixel-tools 1.5.1
haxelib set flixel-addons 3.3.2
haxelib set hxdiscord_rpc 1.3.0
haxelib git hxcpp https://github.com/FunkinCrew/hxcpp
haxelib git away3d https://github.com/openfl/away3d.git
haxelib git flxsoundfilters https://github.com/TheZoroForce240/FlxSoundFilters.git
haxelib git rulescript https://github.com/Kriptel/RuleScript.git dev --skip-dependencies
haxelib git hscript https://github.com/HaxeFoundation/hscript.git 92ffe9c519bbccf783df0b3400698c5b3cc645ef
haxelib git sl-windows-api https://github.com/GreenColdTea/windows-api-improved.git
haxelib git flixel-animate https://github.com/MaybeMaru/flixel-animate.git 9aacdf7afe5ffdcd086a2898ebb7abb966b95a3d
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git

haxelib list

echo
read -n 1 -s -r -p "Done! Press any key to close the app!"
echo
