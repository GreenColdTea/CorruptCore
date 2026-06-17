package game.scripting.haxe;

import rulescript.scriptedClass.RuleScriptedClass;

class ScriptedClasses {}

class ScriptedFlxBasic extends flixel.FlxBasic implements RuleScriptedClass {}
class ScriptedFlxObject extends flixel.FlxObject implements RuleScriptedClass {}
class ScriptedFlxStrip extends flixel.FlxStrip implements RuleScriptedClass {}
class ScriptedFlxSprite extends flixel.FlxSprite implements RuleScriptedClass {}
class ScriptedFlxState extends flixel.FlxState implements RuleScriptedClass {}
class ScriptedFlxSubState extends flixel.FlxSubState implements RuleScriptedClass {}
class ScriptedFlxText extends flixel.text.FlxText implements RuleScriptedClass {}
class ScriptedFlxCamera extends flixel.FlxCamera implements RuleScriptedClass {}

class ScriptedFlxSound extends flixel.sound.FlxSound implements RuleScriptedClass {}
class ScriptedFlxTimer extends flixel.util.FlxTimer implements RuleScriptedClass {}
class ScriptedFlxTween extends flixel.tweens.FlxTween implements RuleScriptedClass {}
class ScriptedFlxPath extends flixel.path.FlxPath implements RuleScriptedClass {}

class ScriptedFlxGroup extends flixel.group.FlxGroup implements RuleScriptedClass {}
class ScriptedFlxSpriteGroup extends flixel.group.FlxSpriteGroup implements RuleScriptedClass {}
class ScriptedFlxTypedGroup<T:flixel.FlxBasic> extends flixel.group.FlxGroup.FlxTypedGroup<T> implements RuleScriptedClass {}

class ScriptedFlxBar extends flixel.ui.FlxBar implements RuleScriptedClass {}
class ScriptedFlxButton extends flixel.ui.FlxButton implements RuleScriptedClass {}

class ScriptedFlxExtendedMouseSprite extends flixel.addons.display.FlxExtendedMouseSprite implements RuleScriptedClass {}
class ScriptedFlxExtendedSprite extends flixel.addons.display.FlxExtendedSprite implements RuleScriptedClass {}
class ScriptedFlxRuntimeShader extends flixel.addons.display.FlxRuntimeShader implements RuleScriptedClass {}
class ScriptedFlxSliceSprite extends flixel.addons.display.FlxSliceSprite implements RuleScriptedClass {}
class ScriptedFlxSkewedSprite extends flixel.addons.effects.FlxSkewedSprite implements RuleScriptedClass {}
class ScriptedFlxTrail extends flixel.addons.effects.FlxTrail implements RuleScriptedClass {}
class ScriptedFlxBackdrop extends flixel.addons.display.FlxBackdrop implements RuleScriptedClass {}
class ScriptedFlxTiledSprite extends flixel.addons.display.FlxTiledSprite implements RuleScriptedClass {}
class ScriptedFlxWaveSprite extends flixel.addons.effects.chainable.FlxWaveEffect implements RuleScriptedClass {}
class ScriptedFlxTransitionableState extends flixel.addons.transition.FlxTransitionableState implements RuleScriptedClass {}
class ScriptedFlxTransitionSprite extends flixel.addons.transition.FlxTransitionSprite implements RuleScriptedClass {}

class ScriptedFlxNapeSprite extends flixel.addons.nape.FlxNapeSprite implements RuleScriptedClass {}
class ScriptedFlxNapeSpace extends flixel.addons.nape.FlxNapeSpace implements RuleScriptedClass {}

class ScriptedFlxEmitter extends flixel.effects.particles.FlxEmitter implements RuleScriptedClass {}
class ScriptedFlxParticle extends flixel.effects.particles.FlxParticle implements RuleScriptedClass {}

class ScriptedCharacter extends game.objects.Character implements RuleScriptedClass {}
class ScriptedBaseStage extends game.stages.backend.BaseStage implements RuleScriptedClass {}
class ScriptedBGSprite extends game.objects.BGSprite implements RuleScriptedClass {}

class ScriptedNote extends game.objects.Note implements RuleScriptedClass {}
class ScriptedStrumNote extends game.objects.StrumNote implements RuleScriptedClass {}
class ScriptedNoteHoldCover extends game.objects.NoteHoldCover implements RuleScriptedClass {}
class ScriptedNoteSplash extends game.objects.NoteSplash implements RuleScriptedClass {}
class ScriptedHealthIcon extends game.objects.HealthIcon implements RuleScriptedClass {}
class ScriptedAlphabet extends game.objects.Alphabet implements RuleScriptedClass {}

class ScriptedMusicBeatState extends MusicBeatState implements RuleScriptedClass {}
class ScriptedMusicBeatSubstate extends MusicBeatSubstate implements RuleScriptedClass {}
class ScriptedOption extends game.substates.backend.Option implements RuleScriptedClass {}

class ScriptedAttachedSprite extends game.objects.AttachedSprite implements RuleScriptedClass {}
class ScriptedAttachedText extends game.objects.AttachedText implements RuleScriptedClass {}

#if flixel_animate
class ScriptedFlxAnimate extends animate.FlxAnimate implements RuleScriptedClass {}
#end

#if flxgif
class ScriptedFlxGifSprite extends flxgif.FlxGifSprite implements RuleScriptedClass {}
class ScriptedFlxGifBackdrop extends flxgif.FlxGifBackdrop implements RuleScriptedClass {}
#end

#if flxsoundfilters
class ScriptedFlxFilteredSound extends flixel.sound.filters.FlxFilteredSound implements RuleScriptedClass {}
#end

#if VIDEOS_ALLOWED
class ScriptedFunkinVideoSprite extends game.objects.FunkinVideoSprite implements RuleScriptedClass {}
#end

#if MODCHART_ALLOWED
class ScriptedModifier extends game.modchart.Modifier implements RuleScriptedClass {}
class ScriptedNoteModifier extends game.modchart.NoteModifier implements RuleScriptedClass {}
#end