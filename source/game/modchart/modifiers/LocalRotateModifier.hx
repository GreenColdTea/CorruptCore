package game.modchart.modifiers;

import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;

import game.modchart.*;
import math.Vector3;

/**
 * Applies 3D rotation transformations around a local origin point
 * Rotates notes in 3D space (X, Y, Z axes) relative to a specified center point
 * Based on Schmovin' rotation system with X-Y-Z Euler angle order
 */
class LocalRotateModifier extends NoteModifier {
    private var prefix:String; // Namespace prefix for modifier submodifiers

    /**
     * Creates a new LocalRotateModifier with optional prefix for namespacing
     * 
     * @param modMgr Reference to the modifier manager
     * @param prefix Prefix for modifier names (e.g., 'local' for 'localrotateX')
     * @param parent Parent modifier if this is a submodifier
     */
    public function new(modMgr:ModManager, ?prefix:String = '', ?parent:Modifier) {
        this.prefix = prefix;
        super(modMgr, parent);
    }
    
    override function getName():String {
        return '${prefix}rotateX';
    }

    /**
     * Sets execution order to after reverse operations for proper transformation order
     */
    override function getOrder():Int {
        return Modifier.ModifierOrder.POST_REVERSE;
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
     * Linear interpolation helper function
     */
    private inline function lerp(start:Float, end:Float, ratio:Float):Float {
        return start + (end - start) * ratio;
    }

    /**
     * Applies 3D rotation to a vector using X-Y-Z Euler angle order
     * Based on Schmovin' rotation implementation
     * 
     * @param vec The vector to rotate
     * @param xAngle Rotation angle around X-axis (radians)
     * @param yAngle Rotation angle around Y-axis (radians) 
     * @param zAngle Rotation angle around Z-axis (radians)
     * @return The rotated vector
     */
    private function rotateVector3D(vec:Vector3, xAngle:Float, yAngle:Float, zAngle:Float):Vector3 {
        // First rotation: around Z-axis
        var rotatedZ = MathUtil.rotate(vec.x, vec.y, zAngle);
        var afterZ = new Vector3(rotatedZ.x, rotatedZ.y, vec.z);

        // Second rotation: around X-axis
        var rotatedX = MathUtil.rotate(afterZ.z, afterZ.y, xAngle);
        var afterX = new Vector3(afterZ.x, rotatedX.y, rotatedX.x);

        // Third rotation: around Y-axis
        var rotatedY = MathUtil.rotate(afterX.x, afterX.z, yAngle);
        var afterY = new Vector3(rotatedY.x, afterX.y, rotatedY.y);

        // Clean up temporary objects
        rotatedZ.putWeak();
        rotatedX.putWeak();
        rotatedY.putWeak();

        return afterY;
    }

    /**
     * Applies 3D rotation transformation to note positions
     * Rotates notes around a local origin point (player's side center)
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
        var rotationOrigin = calculateRotationOrigin(player);
        
        // Calculate offset from rotation origin
        var positionOffset = pos.subtract(rotationOrigin);
        
        // Apply scale to Z-axis for depth effect
        var scale = FlxG.height;
        positionOffset.z *= scale;
        
        // Apply 3D rotation
        var rotatedOffset = rotateVector3D(
            positionOffset, 
            getValue(player),                    // X-axis rotation
            getSubmodValue('${prefix}rotateY', player), // Y-axis rotation
            getSubmodValue('${prefix}rotateZ', player)  // Z-axis rotation
        );
        
        // Restore Z-axis scale and apply final position
        rotatedOffset.z /= scale;
        return rotationOrigin.add(rotatedOffset);
    }

    /**
     * Calculates the rotation origin point (center of rotation)
     * Based on player side and note layout
     */
    private function calculateRotationOrigin(player:Int):Vector3 {
        // Calculate center X position for the player's side
        var centerX:Float = (FlxG.width / 2) - Note.swagWidth - 54 + Note.swagWidth * 1.5;
        
        switch (player) {
            case 0: // Player 1 (BF)
                centerX += FlxG.width / 2 - Note.swagWidth * 2 - 100;
            case 1: // Player 2 (Dad)
                centerX -= FlxG.width / 2 - Note.swagWidth * 2 - 100;
        }
        
        centerX -= 56; // Additional offset
        
        // Center Y position
        var centerY = FlxG.height / 2 - Note.swagWidth / 2;
        
        return new Vector3(centerX, centerY);
    }
}