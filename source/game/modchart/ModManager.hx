package game.modchart;

import flixel.tweens.FlxEase;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;
import flixel.FlxG;

import math.Vector3;

import game.modchart.Modifier.ModifierType;
import game.modchart.modifiers.*;
import game.modchart.events.*;

/**
 * Handles chart modifiers on gameplay elements
 * Combines concepts from Schmovin', Andromeda, and custom modifier systems
 */
class ModManager {
    private var state:PlayState;
    
    // Modifier storage
    public var notemodRegister:Map<String, Modifier> = [];
    public var miscmodRegister:Map<String, Modifier> = [];
    public var register:Map<String, Modifier> = [];
    public var modArray:Array<Modifier> = [];
    
    // Active modifiers per player
    public var activeMods:Array<Array<String>> = [[], []];
    
    public var receptors:Array<Array<StrumNote>> = [];
    public var timeline:EventTimeline = new EventTimeline();

    @:deprecated("registerByType is deprecated. Use notemodRegister and miscmodRegister instead")
    public var registerByType:Map<ModifierType, Map<String, Modifier>> = [
        NOTE_MOD => [],
        MISC_MOD => []
    ];

    public function new(state:PlayState) {
        this.state = state;
    }

    /**
     * Registers all default modifiers used in the game
     */
    public function registerDefaultModifiers() {
        var defaultModifiers:Array<Class<Any>> = [
            FlipModifier, ReverseModifier, InvertModifier, 
            DrunkModifier, BeatModifier, AlphaModifier, 
            ScaleModifier, ConfusionModifier, OpponentModifier, 
            TransformModifier, InfinitePathModifier, PerspectiveModifier,
            AccelModifier, XModifier, TornadoModifier, ZigZagModifier,
            SquareModifier
        ];
        
        for (modClass in defaultModifiers)
            quickRegister(Type.createInstance(modClass, [this]));

        quickRegister(new RotateModifier(this));
        quickRegister(new RotateModifier(this, 'center', new Vector3(
            (FlxG.width / 2) - (Note.swagWidth / 2), 
            (FlxG.height / 2) - Note.swagWidth / 2
        )));
        quickRegister(new LocalRotateModifier(this, 'local'));
        
        // Note spawn time conf
        quickRegister(new SubModifier("noteSpawnTime", this));
        setValue("noteSpawnTime", 1250);
        setValue("xmod", 1);
	    for(i in 0...4)
		    setValue('xmod$i', 1);
    }

    /**
     * Quick registration helper for modifiers
     */
    public inline function quickRegister(mod:Modifier) {
        registerMod(mod.getName(), mod);
    }

    /**
     * Registers a modifier and its submodifiers
     */
    public function registerMod(modName:String, mod:Modifier, registerSubmods:Bool = true) {
        register.set(modName, mod);
        
        // Categorize modifier by type
        switch (mod.getModType()) {
            case NOTE_MOD:
                notemodRegister.set(modName, mod);
            case MISC_MOD:
                miscmodRegister.set(modName, mod);
        }

        timeline.addMod(modName);
        modArray.push(mod);

        // Register submodifiers recursively
        if (registerSubmods) {
            for (submodName in mod.submods.keys()) {
                var submod = mod.submods.get(submodName);
                quickRegister(submod);
            }
        }

        // Initialize modifier value
        setValue(modName, 0);
        
        // Sort modifiers by execution order
        modArray.sort((a, b) -> Std.int(a.getOrder() - b.getOrder()));
    }

    public function get(modName:String):Modifier {
        return register.get(modName);
    }

    inline public function getPercent(modName:String, player:Int):Float {
        return register.get(modName).getPercent(player);
    }

    inline public function getValue(modName:String, player:Int):Float {
        return register.get(modName).getValue(player);
    }

    inline public function setPercent(modName:String, percent:Float, player:Int = -1) {
        setValue(modName, percent / 100, player);
    }

    /**
     * Sets modifier value and manages active modifier list
     */
    public function setValue(modName:String, value:Float, player:Int = -1) {
        if (player == -1) {
            // Apply to all players if no specific player specified
            for (playerNum in 0...2) {
                setValue(modName, value, playerNum);
            }
            return;
        }

        var modifier = register.get(modName);
        if (modifier == null) {
            trace('Warning: Modifier "$modName" not found in register');
            return;
        }
        
        var parentMod = modifier?.parent ?? modifier;
        if (parentMod == null) {
            trace('Warning: Parent modifier for "$modName" is null');
            return;
        }
        
        var parentName = parentMod.getName();

        activeMods[player] ??= [];
        modifier.setValue(value, player);

        updateActiveModifiersList(modName, parentName, value, player, modifier, parentMod);
    }

    /**
     * Updates the active modifiers list based on current modifier states
     */
    private function updateActiveModifiersList(
        modName:String, 
        parentName:String, 
        value:Float, 
        player:Int, 
        modifier:Modifier, 
        parentMod:Modifier
    ) {
        var shouldExecute = parentMod.shouldExecute(player, value);
        
        if (!activeMods[player].contains(parentName) && shouldExecute) {
            // Add modifier and its parent to active list
            if (modifier.getName() != parentName) {
                activeMods[player].push(modifier.getName());
            }
            activeMods[player].push(parentName);
        } else if (!shouldExecute) {
            // Remove modifier from active list
            removeModifierFromActiveList(modName, parentName, player, modifier, parentMod);
        }

        // Maintain execution order
        activeMods[player].sort((a, b) -> Std.int(register.get(a).getOrder() - register.get(b).getOrder()));
    }

    /**
     * Removes modifier from active list after checking dependencies
     */
    private function removeModifierFromActiveList(
        modName:String, 
        parentName:String, 
        player:Int, 
        modifier:Modifier, 
        parentMod:Modifier
    ) 
    {
        // Remove the specific modifier
        if (modifier != parentMod) {
            activeMods[player].remove(modifier.getName());
        }

        // Check if parent modifier should remain active
        if (parentMod != null) {
            var shouldKeepParent = parentMod.shouldExecute(player, parentMod.getValue(player)) ||
                                  hasActiveSubmodifiers(parentMod, player);
            
            if (!shouldKeepParent) {
                activeMods[player].remove(parentMod.getName());
            }
        } else {
            activeMods[player].remove(modifier.getName());
        }
    }

    /**
     * Checks if any submodifiers of a parent are still active
     */
    private function hasActiveSubmodifiers(parentMod:Modifier, player:Int):Bool {
        for (submod in parentMod.submods) {
            if (submod.shouldExecute(player, submod.getValue(player))) {
                return true;
            }
        }
        return false;
    }

    public function update(elapsed:Float) {
        for (mod in modArray) {
            if (mod.active && mod.doesUpdate()) {
                mod.update(elapsed);
            }
        }
    }

    public function updateTimeline(curStep:Float) {
        timeline.update(curStep);
    }

    /**
     * Updates visual properties of game objects based on active modifiers
     */
    public function updateObject(beat:Float, obj:FlxSprite, position:Vector3, player:Int) {
        for (modName in activeMods[player]) {
            var modifier = notemodRegister.get(modName);
            
            if (modifier == null || !obj.active) continue;

            if (Std.isOfType(obj, Note)) {
                var note:Note = cast obj;
                modifier.updateNote(beat, note, position, player);
            } else if (Std.isOfType(obj, StrumNote)) {
                var strum:StrumNote = cast obj;
                modifier.updateReceptor(beat, strum, position, player);
            }
        }

        // Update object properties after modifier applications
        if (Std.isOfType(obj, Note)) {
            obj.updateHitbox();
        }
        
        obj.centerOrigin();
        obj.centerOffsets();

        // Apply type-specific offsets for notes
        if (Std.isOfType(obj, Note)) {
            var note:Note = cast obj;
            note.offset.x += note.typeOffsetX;
            note.offset.y += note.typeOffsetY;
        }
    }

    /**
     * Gets the base X position for a note based on direction and player
     */
    public function getBaseX(direction:Int, player:Int):Float {
        var baseX:Float = PlayState.STRUM_X_MIDDLESCROLL + Note.swagWidth * direction;
        
        if (ClientPrefs.middleScroll) {
            if (player == 1) { // opponent strums
                baseX += 360;
                if (direction > 1) {
                    baseX += FlxG.width / 2 + 25;
                }
            } else { // player strums
                var totalWidth = Note.swagWidth * 4;
                var screenCenter = FlxG.width / 2;
                baseX = screenCenter - totalWidth / 2 + Note.swagWidth * direction;
            }
        } else {
            baseX = (FlxG.width / 2) - Note.swagWidth - 54 + Note.swagWidth * direction;
            
            switch (player) {
                case 0: // player strums
                    baseX += FlxG.width / 2 - Note.swagWidth * 2 - 100;
                case 1: // opponent strums
                    baseX -= FlxG.width / 2 - Note.swagWidth * 2 - 100;
            }
            baseX -= 56;
        }
        
        return baseX;
    }

    /**
     * Calculates visual position based on song timing
     */
    inline public function getVisPos(songPos:Float = 0, strumTime:Float = 0, songSpeed:Float = 1):Float {
        return -(0.45 * (songPos - strumTime) * songSpeed);
    }

    /**
     * Gets the final position of an object after applying all modifier transformations
     */
    public function getPos(
        time:Float, 
        diff:Float, 
        tDiff:Float, 
        beat:Float, 
        data:Int, 
        player:Int, 
        obj:FlxSprite, 
        ?exclusions:Array<String>, 
        ?position:Vector3
    ):Vector3 {
        exclusions = exclusions ?? [];
        position = position ?? new Vector3();

        if (!obj.active) return position;

        // Start with base position
        position.x = getBaseX(data, player);
        position.y = 50 + diff;
        position.z = 0;

        // Apply all active modifiers
        for (modName in activeMods[player]) {
            if (exclusions.contains(modName)) continue;
            
            var modifier = notemodRegister.get(modName);
            if (modifier == null || !obj.active) continue;
            
            position = modifier.getPos(time, diff, tDiff, beat, position, data, player, obj);
        }
        
        return position;
    }

    public function queueEaseP(step:Float, endStep:Float, modName:String, percent:Float, style:String = 'linear', player:Int = -1, ?startPercent:Float) {
        queueEase(step, endStep, modName, percent / 100, style, player, startPercent != null ? startPercent / 100 : null);
    }
    
    public function queueSetP(step:Float, modName:String, percent:Float, player:Int = -1) {
        queueSet(step, modName, percent / 100, player);
    }
    
    public function queueEase(step:Float, endStep:Float, modName:String, target:Float, style:String = 'linear', player:Int = -1, ?startValue:Float) {
        if (player == -1) {
            queueEase(step, endStep, modName, target, style, 0, startValue);
            queueEase(step, endStep, modName, target, style, 1, startValue);
        } else {
            var easeFunction = getEaseFunction(style);
            timeline.addEvent(new EaseEvent(step, endStep, modName, target, easeFunction, player, this));
        }
    }

    public function queueSet(step:Float, modName:String, target:Float, player:Int = -1) {
        if (player == -1) {
            queueSet(step, modName, target, 0);
            queueSet(step, modName, target, 1);
        } else {
            timeline.addEvent(new SetEvent(step, modName, target, player, this));
        }
    }

    public function queueFunc(step:Float, endStep:Float, callback:(CallbackEvent, Float) -> Void) {
        timeline.addEvent(new StepCallbackEvent(step, endStep, callback, this));
    }
    
    public function queueFuncOnce(step:Float, callback:(CallbackEvent, Float) -> Void) {
        timeline.addEvent(new CallbackEvent(step, callback, this));
    }

    /**
     * Gets easing function by name, defaults to linear
     */
    private function getEaseFunction(style:String):Float->Float 
    {
        var easeFunc:Float->Float = FlxEase.linear;
        
        try {
            var customEase = Reflect.getProperty(FlxEase, style);
            if (customEase != null) {
                easeFunc = customEase;
            }
        } catch (e:Dynamic) {
            trace('Ease function "$style" not found, using linear');
        }
        
        return easeFunc;
    }
}