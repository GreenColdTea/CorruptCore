package game.modchart;

import flixel.FlxSprite;
import math.Vector3;

// Based on Schmovin' and Andromeda's modifier systems

/**
 * Types of modifiers that can be applied
 */
enum ModifierType {
    NOTE_MOD; // Affects note positioning and movement
    MISC_MOD; // Affects other gameplay elements
}

/**
 * Execution order constants for modifier prioritization
 */
enum abstract ModifierOrder(Int) to Int {
    var FIRST = -1000; // Highest priority - executes first
    var PRE_REVERSE = -3; // Before reverse operations
    var REVERSE = -2; // Reverse operations
    var POST_REVERSE = -1; // After reverse operations
    var DEFAULT = 0; // Standard execution order
    var LAST = 1000; // Lowest priority - executes last
}

/**
 * Base class for all gameplay modifiers
 * Handles visual transformations and effects on notes and receptors
 */
class Modifier {
    public var modMgr:ModManager; // Reference to the modifier manager
    public var percents:Array<Float> = [0, 0]; // Modifier intensity per player [player1, player2]
    public var submods:Map<String, Modifier> = []; // Child modifiers
    public var parent:Modifier; // Parent modifier for submodifiers
    public var active:Bool = false; // Performance optimization flag

    public function new(modMgr:ModManager, ?parent:Modifier) {
        this.modMgr = modMgr;
        this.parent = parent;
        
        // Initialize all declared submodifiers
        for (submodName in getSubmods()) {
            submods.set(submodName, new SubModifier(submodName, modMgr, this));
        }
    }

    /**
     * Returns the type of modifier (note-affecting or miscellaneous)
     * Override in subclasses for note modifiers
     */
    public function getModType():ModifierType {
        return MISC_MOD;
    }

    /**
     * Returns the execution order priority
     * Override in subclasses to control modifier execution order
     */
    public function getOrder():Int {
        return DEFAULT;
    }

    /**
     * Returns whether this modifier should update each frame
     * Override for modifiers that need continuous updates
     */
    public function doesUpdate():Bool {
        return getModType() == MISC_MOD;
    }

    /**
     * Returns whether this modifier should ignore position calculations
     * Override to true for non-position-affecting modifiers
     */
    public function ignorePos():Bool {
        return false;
    }

    /**
     * Returns whether this modifier should skip receptor updates
     * Override to false for modifiers that affect receptors
     */
    public function ignoreUpdateReceptor():Bool {
        return true;
    }

    /**
     * Returns whether this modifier should skip note updates
     * Override to false for modifiers that affect notes
     */
    public function ignoreUpdateNote():Bool {
        return true;
    }

    public function ignoreUpdateSplash():Bool {
        return true;
    }

    public function ignoreUpdateHoldCover():Bool {
        return true;
    }

    /**
     * Determines if modifier should execute based on current value
     * Override for modifiers that need to run even at 0% intensity
     */
    public function shouldExecute(player:Int, value:Float):Bool {
        return value != 0;
    }

    /**
     * Returns the unique name identifier for this modifier
     * MUST be overridden in subclasses
     */
    public function getName():String {
        throw new haxe.exceptions.NotImplementedException("Modifier name must be implemented in subclass");
        return '';
    }

    /**
     * Gets the raw value (0-1) for the specified player
     */
    public function getValue(player:Int):Float {
        return percents[player];
    }

    /**
     * Gets the percentage value (0-100) for the specified player
     */
    public function getPercent(player:Int):Float {
        return getValue(player) * 100;
    }

    /**
     * Sets the raw value (0-1) for the specified player(s)
     */
    public function setValue(value:Float, player:Int = -1) {
        if (player == -1) {
            // Apply to all players
            for (idx in 0...percents.length) {
                percents[idx] = value;
            }
        } else {
            percents[player] = value;
        }
    }

    /**
     * Sets the percentage value (0-100) for the specified player(s)
     */
    public function setPercent(percent:Float, player:Int = -1) {
        setValue(percent / 100, player);
    }

    /**
     * Returns list of submodifier names this modifier contains
     * Override in subclasses that have child modifiers
     */
    public function getSubmods():Array<String> {
        return [];
    }

    /**
     * Gets percentage value of a submodifier
     */
    public function getSubmodPercent(modName:String, player:Int):Float {
        return submods.exists(modName) ? submods.get(modName).getPercent(player) : 0;
    }

    /**
     * Gets raw value of a submodifier
     */
    public function getSubmodValue(modName:String, player:Int):Float {
        return submods.exists(modName) ? submods.get(modName).getValue(player) : 0;
    }

    /**
     * Sets percentage value of a submodifier
     */
    public function setSubmodPercent(modName:String, endPercent:Float, player:Int) {
        if (submods.exists(modName)) {
            submods.get(modName).setPercent(endPercent, player);
        }
    }

    /**
     * Sets raw value of a submodifier
     */
    public function setSubmodValue(modName:String, endValue:Float, player:Int) {
        if (submods.exists(modName)) {
            submods.get(modName).setValue(endValue, player);
        }
    }

    /**
     * Updates receptor visual properties
     * Override in subclasses that affect receptors
     * 
     * @param beat Current beat with decimal precision
     * @param receptor The strum note receptor to update
     * @param pos Current position vector
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     */
    public function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int) {}

    /**
     * Updates note visual properties
     * Override in subclasses that affect notes
     * 
     * @param beat Current beat with decimal precision
     * @param note The note to update
     * @param pos Current position vector
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     */
    public function updateNote(beat:Float, note:Note, pos:Vector3, player:Int) {}

    public function updateSplash(beat:Float, splash:game.objects.NoteSplash, pos:Vector3, player:Int) {}

    public function updateHoldCover(beat:Float, cover:game.objects.NoteHoldCover, pos:Vector3, player:Int) {}

    /**
     * Calculates and returns modified position for game objects
     * Override in subclasses that affect object positioning
     * 
     * @param time Note/receptor strum time
     * @param diff Visual difference (strumTime - currentTime with scroll speed math)
     * @param tDiff Time difference
     * @param beat Current beat with decimal precision
     * @param pos Current position vector
     * @param data Column/direction/note data
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector
     */
    public function getPos(
        time:Float, 
        diff:Float, 
        tDiff:Float, 
        beat:Float, 
        pos:Vector3, 
        data:Int, 
        player:Int, 
        obj:FlxSprite
    ):Vector3 {
        return pos; // Base implementation returns og position
    }

    public function update(elapsed:Float) {}
}