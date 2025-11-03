package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;

import game.modchart.*;
import math.Vector3;

/**
 * Applies 3D rotation transformations around a specified origin point
 * Rotates notes in 3D space (X, Y, Z axes) around a customizable center point
 * Based on Schmovin' rotation system with X-Y-Z Euler angle order
 * This version supports custom rotation origins and prefix namespacing
 */
class RotateModifier extends NoteModifier {
    private var daOrigin:Vector3;  // Custom rotation origin point
    private var prefix:String;     // Namespace prefix for modifier submodifiers
    
    /**
     * Creates a new RotateModifier with optional prefix and custom origin
     * 
     * @param modMgr Reference to the modifier manager
     * @param prefix Prefix for modifier names (e.g., 'center' for 'centerrotateX')
     * @param origin Custom rotation origin point (uses note position if null)
     * @param parent Parent modifier if this is a submodifier
     */
    public function new(modMgr:ModManager, ?prefix:String = '', ?origin:Vector3, ?parent:Modifier) {
        this.prefix = prefix;
        this.daOrigin = origin;
        super(modMgr, parent);
    }

    override function getName():String {
        return '${prefix}rotateX';
    }

    /**
     * Sets execution order to very late for proper transformation order
     * Ensures rotation is applied after most other transformations
     */
    override function getOrder():Int {
        return Modifier.ModifierOrder.LAST + 2;
    }

    /**
     * Returns the rotation submodifiers for Y and Z axes
     */
    override function getSubmods():Array<String> {
        return [
            '${prefix}rotateY', // Y-axis rotation
            '${prefix}rotateZ'  // Z-axis rotation
        ];
    }

    /**
     * Applies 3D rotation to a vector using Z-X-Y Euler angle order
     * Based on Schmovin' rotation implementation
     * Rotation order: Z -> X -> Y
     * 
     * @param vec The vector to rotate
     * @param xAngle Rotation angle around X-axis (radians)
     * @param yAngle Rotation angle around Y-axis (radians) 
     * @param zAngle Rotation angle around Z-axis (radians)
     * @return The rotated vector
     */
    private function rotateVector3D(vec:Vector3, xAngle:Float, yAngle:Float, zAngle:Float):Vector3 {
        // First rotation: around Z-axis (affects X and Y)
        var rotatedZ = MathUtil.rotate(vec.x, vec.y, zAngle);
        var afterZ = new Vector3(rotatedZ.x, rotatedZ.y, vec.z);

        // Second rotation: around X-axis (affects Y and Z)
        var rotatedX = MathUtil.rotate(afterZ.z, afterZ.y, xAngle);
        var afterX = new Vector3(afterZ.x, rotatedX.y, rotatedX.x);

        // Third rotation: around Y-axis (affects X and Z)
        var rotatedY = MathUtil.rotate(afterX.x, afterX.z, yAngle);
        var afterY = new Vector3(rotatedY.x, afterX.y, rotatedY.y);

        // Clean up temporary objects to prevent memory leaks
        rotatedZ.putWeak();
        rotatedX.putWeak();
        rotatedY.putWeak();

        return afterY;
    }

    /**
     * Applies 3D rotation transformation to note positions
     * Rotates notes around specified origin point with configurable axes
     * 
     * @param time Note strum time
     * @param visualDiff Visual position difference
     * @param timeDiff Time difference (strumTime - currentTime)
     * @param beat Current beat with decimal precision
     * @param pos Current position vector to modify
     * @param data Note direction/column (0-3)
     * @param player Player index (0 = BF, 1 = Dad, -1 = Both)
     * @param obj The game object (note or receptor)
     * @return Modified position vector with 3D rotation applied
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
        var rotationOrigin = getRotationOrigin(data, player);
        
        // Convert to local coordinates relative to rotation origin
        var localOffset = pos.subtract(rotationOrigin);
        
        // Apply scale to Z-axis for consistent depth effect
        var depthScale = FlxG.height;
        localOffset.z *= depthScale;
        
        // Apply 3D rotation to local coordinates
        var rotatedOffset = rotateVector3D(
            localOffset, 
            getValue(player),                    // X-axis rotation
            getSubmodValue('${prefix}rotateY', player), // Y-axis rotation  
            getSubmodValue('${prefix}rotateZ', player)  // Z-axis rotation
        );
        
        // Restore Z-axis scale and convert back to world coordinates
        rotatedOffset.z /= depthScale;
        return rotationOrigin.add(rotatedOffset);
    }

    /**
     * Calculates the rotation origin point
     * Uses custom origin if provided, otherwise calculates based on note position
     */
    private function getRotationOrigin(noteData:Int, player:Int):Vector3 {
        if (daOrigin != null) {
            return daOrigin;
        } else {
            // Default to note's base position centered vertically
            var baseX = modMgr.getBaseX(noteData, player);
            var centerY = FlxG.height / 2 - Note.swagWidth / 2;
            return new Vector3(baseX, centerY);
        }
    }
}