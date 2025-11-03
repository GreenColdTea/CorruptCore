package game.modchart.modifiers;

import flixel.math.FlxMath;
import flixel.FlxG;

import math.Vector3;

/**
 * Creates an infinite looping path for notes to follow
 * Uses a mathematical curve (lemniscate/figure-8 pattern) for continuous note movement
 */
class InfinitePathModifier extends PathModifier {
    override function getName():String {
        return 'infinite';
    }

    /**
     * Returns the movement speed for notes following the infinite path
     * Controls how quickly notes move along the predefined curve
     */
    override function getMoveSpeed():Float {
        return 1850;
    }

    /**
     * Generates an infinite looping path (lemniscate/figure-8 pattern)
     * Creates a continuous closed curve for notes to follow indefinitely
     * 
     * @return 2D array of Vector3 points defining the path for each note column
     */
    override function getPath():Array<Array<Vector3>> {
        var infinitePath:Array<Array<Vector3>> = [[], [], [], []];
        var angleStep:Int = 15; // Degrees between each path point
        
        // Generate path points from 0 to 360 degrees
        var currentAngle:Int = 0;
        while (currentAngle < 360) {
            var pathPoint = calculatePathPoint(currentAngle);
            
            // All note columns share the same path shape
            for (noteData in 0...infinitePath.length) {
                infinitePath[noteData].push(pathPoint);
            }
            
            currentAngle += angleStep;
        }
        
        return infinitePath;
    }

    /**
     * Calculates a single point on the infinite path using parametric equations
     * Creates a lemniscate (figure-8) pattern centered on screen
     * 
     * @param angle Current angle in degrees for parametric calculation
     * @return Vector3 position on the infinite path
     */
    private function calculatePathPoint(angle:Float):Vector3 {
        var radians = angle * Math.PI / 180;
        
        // Parametric equations for a lemniscate (figure-8 curve)
        // x = a * sin(t)
        // y = a * sin(t) * cos(t)
        var scaleFactor:Float = 600;
        var screenCenterX = FlxG.width / 2;
        var screenCenterY = FlxG.height / 2;
        
        var x = screenCenterX + FlxMath.fastSin(radians) * scaleFactor;
        var y = screenCenterY + (FlxMath.fastSin(radians) * FlxMath.fastCos(radians)) * scaleFactor;
        
        return new Vector3(x, y, 0);
    }
}