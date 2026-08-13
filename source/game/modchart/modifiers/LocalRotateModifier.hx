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

    override function shouldExecute(player:Int, val:Float):Bool {
        return (val != 0 || getSubmodValue('${prefix}rotateY', player) != 0 || getSubmodValue('${prefix}rotateZ', player) != 0);
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
        final rotatedZ = MathUtil.rotate(vec.x, vec.y, zAngle);
        final afterZ = Vector3.get(rotatedZ.x, rotatedZ.y, vec.z);

        final rotatedX = MathUtil.rotate(afterZ.z, afterZ.y, xAngle);
        final afterX = Vector3.get(afterZ.x, rotatedX.y, rotatedX.x);

        final rotatedY = MathUtil.rotate(afterX.x, afterX.z, yAngle);
        final afterY = Vector3.get(rotatedY.x, afterX.y, rotatedY.y);

        rotatedZ.putWeak();
        rotatedX.putWeak();
        rotatedY.putWeak();
        
        afterZ.put(); 
        afterX.put();

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
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
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
        final rotationOrigin = calculateRotationOrigin(player);
        final positionOffset = pos.subtract(rotationOrigin);
        
        final scale = FlxG.height;
        positionOffset.z *= scale;
        
        var rotatedOffset = rotateVector3D(positionOffset, 
            getValue(player),                    
            getSubmodValue('${prefix}rotateY', player), 
            getSubmodValue('${prefix}rotateZ', player)  
        );
        
        rotatedOffset.z /= scale;
        
        pos.setTo(rotationOrigin.x + rotatedOffset.x, rotationOrigin.y + rotatedOffset.y, rotationOrigin.z + rotatedOffset.z);
        
        rotationOrigin.put();
        positionOffset.put();
        rotatedOffset.put();
        
        return pos;
    }

    /**
     * Calculates the rotation origin point (center of rotation)
     * Based on player side and note layout
     */
    private function calculateRotationOrigin(player:Int):Vector3 {
        var centerX:Float = (FlxG.width / 2) - Note.swagWidth - 54 + Note.swagWidth * 1.5;
        
        switch (player) {
            case 0:
                centerX += FlxG.width / 2 - Note.swagWidth * 2 - 100;
            case 1:
                centerX -= FlxG.width / 2 - Note.swagWidth * 2 - 100;
        }
        
        centerX -= 56;
        final centerY = FlxG.height / 2 - Note.swagWidth / 2;
        
        return Vector3.get(centerX, centerY);
    }
}