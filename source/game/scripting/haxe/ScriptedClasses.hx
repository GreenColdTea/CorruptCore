package game.scripting.haxe;

import rulescript.scriptedClass.RuleScriptedClass;

class ScriptedClasses {}

class ScriptedFlxBasic extends flixel.FlxBasic implements RuleScriptedClass {}
class ScriptedFlxObject extends flixel.FlxObject implements RuleScriptedClass {}
class ScriptedFlxStrip extends flixel.FlxStrip implements RuleScriptedClass {}
class ScriptedFlxSprite extends flixel.FlxSprite implements RuleScriptedClass {}
class ScriptedFlxText extends flixel.text.FlxText implements RuleScriptedClass {}
class ScriptedFlxCamera extends flixel.FlxCamera implements RuleScriptedClass {}
class ScriptedFlxSound extends flixel.sound.FlxSound implements RuleScriptedClass {}
class ScriptedFlxTimer extends flixel.util.FlxTimer implements RuleScriptedClass {}
class ScriptedFlxTween extends flixel.tweens.FlxTween implements RuleScriptedClass {}

class ScriptedFlxExtendedMouseSprite extends flixel.addons.display.FlxExtendedMouseSprite implements RuleScriptedClass {}
class ScriptedFlxExtendedSprite extends flixel.addons.display.FlxExtendedSprite implements RuleScriptedClass {}
class ScriptedFlxRuntimeShader extends flixel.addons.display.FlxRuntimeShader implements RuleScriptedClass {}
class ScriptedFlxSliceSprite extends flixel.addons.display.FlxSliceSprite implements RuleScriptedClass {}
class ScriptedFlxSkewedSprite extends flixel.addons.effects.FlxSkewedSprite implements RuleScriptedClass {}
class ScriptedFlxNapeSprite extends flixel.addons.nape.FlxNapeSprite implements RuleScriptedClass {}
class ScriptedFlxNapeSpace extends flixel.addons.nape.FlxNapeSpace implements RuleScriptedClass {}

class ScriptedCharacter extends game.objects.Character implements RuleScriptedClass {}
class ScriptedBaseStage extends game.stages.backend.BaseStage implements RuleScriptedClass {}

class ScriptedOption extends game.substates.backend.Option implements RuleScriptedClass {}