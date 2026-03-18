package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;

import game.modchart.*;
import math.Vector3;
import math.*;

/**
 * Applies positional translations to notes and receptors
 * Moves objects along X, Y, and Z axes with global and per-column control
 * Supports additive transformations for complex movement combinations
 */
class TransformModifier extends NoteModifier {
    override function getName():String {
        return 'transformX';
    }

    /**
     * Sets execution order to very late for proper transformation order
     * Ensures translations are applied after most other transformations
     */
    override function getOrder():Int {
        return Modifier.ModifierOrder.LAST;
    }

    /**
     * Returns all transformation submodifiers
     * Includes global and per-column transformations for all three axes
     * "-a" suffix indicates additive transformations that stack with base values
     */
    override function getSubmods():Array<String> {
        var subMods:Array<String> = [
            // Global axis transformations
            "transformY",      // Global Y-axis translation
            "transformZ",      // Global Z-axis translation (depth)
            "transformX-a",    // Global X-axis additive translation
            "transformY-a",    // Global Y-axis additive translation  
            "transformZ-a"     // Global Z-axis additive translation
        ];

        // Add per-column transformations for fine-tuned control
        for (column in 0...4) {
            subMods.push('transform${column}X');    // Column-specific X translation
            subMods.push('transform${column}Y');    // Column-specific Y translation
            subMods.push('transform${column}Z');    // Column-specific Z translation
            subMods.push('transform${column}X-a');  // Column-specific X additive translation
            subMods.push('transform${column}Y-a');  // Column-specific Y additive translation
            subMods.push('transform${column}Z-a');  // Column-specific Z additive translation
        }

        return subMods;
    }

    /**
     * Applies translation transformations to note positions
     * Combines global and per-column translations across all three axes
     * 
     * @param time Note strum time
     * @param visualDiff Visual position difference
     * @param timeDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with translations applied
     */
    override function getPos(
        time:Float, 
        visualDiff:Float, 
        timeDiff:Float, 
        beat:Float, 
        pos:Vector3, 
        data:Int, 
        player:Int, 
        obj:FlxSprite
    ):Vector3 {
        applyGlobalTransformations(pos, player);
        applyColumnTransformations(pos, data, player);
        
        return pos;
    }

    /**
     * Applies global transformations (affecting all columns)
     */
    private function applyGlobalTransformations(pos:Vector3, player:Int):Void {
        // X-axis: base value + additive transformation
        pos.x += getValue(player) + getSubmodValue("transformX-a", player);
        
        // Y-axis: transformation + additive transformation  
        pos.y += getSubmodValue("transformY", player) + getSubmodValue("transformY-a", player);
        
        // Z-axis: transformation + additive transformation (depth)
        pos.z += getSubmodValue("transformZ", player) + getSubmodValue("transformZ-a", player);
    }

    /**
     * Applies column-specific transformations
     */
    private function applyColumnTransformations(pos:Vector3, column:Int, player:Int):Void {
        // X-axis: column transformation + column additive transformation
        pos.x += getSubmodValue('transform${column}X', player) + getSubmodValue('transform${column}X-a', player);
        
        // Y-axis: column transformation + column additive transformation
        pos.y += getSubmodValue('transform${column}Y', player) + getSubmodValue('transform${column}Y-a', player);
        
        // Z-axis: column transformation + column additive transformation (depth)
        pos.z += getSubmodValue('transform${column}Z', player) + getSubmodValue('transform${column}Z-a', player);
    }
}