package game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

import game.modchart.*;
import math.Vector3;

/**
 * Path information structure for tracking points along a path
 */
typedef PathInfo = {
  var position:Vector3; // 3D position of the path point
  var dist:Float;       // Distance to next point (for interpolation)
  var start:Float;      // Cumulative distance from path start to this point
  var end:Float;        // Cumulative distance from path start to next point
}

/**
 * Base class for modifiers that move notes along predefined paths
 * Handles path interpolation and movement calculations for custom note trajectories
 */
class PathModifier extends NoteModifier {
  private var moveSpeed:Float;                    // Speed of note movement along path
  private var pathData:Array<Array<PathInfo>> = []; // Processed path information
  private var totalDists:Array<Float> = [];      // Total distance of each path

  override function getName():String {
    return 'basePath';
  }

  /**
   * Returns the movement speed for notes following the path
   * Override in subclasses to customize path speed
   */
  public function getMoveSpeed():Float {
    return 5000;
  }

  /**
   * Returns the path definition as arrays of Vector3 points
   * Must be overridden in subclasses to provide actual path data
   */
  public function getPath():Array<Array<Vector3>> {
    return [];
  }

  public function new(modMgr:ModManager, ?parent:Modifier) {
    super(modMgr, parent);
    
    initPathData();
  }

  /**
   * Initializes and processes path data for efficient interpolation
   * Calculates distances and prepares path information structures
   */
  private function initPathData():Void {
    moveSpeed = getMoveSpeed();
    var rawPath:Array<Array<Vector3>> = getPath();
    
    // Process each direction/path
    for (direction in 0...rawPath.length) {
      initDirectionPath(direction, rawPath[direction]);
    }
    
    // Debug output for path distances
    for (direction in 0...totalDists.length) {
      trace('Path direction $direction total distance: ${totalDists[direction]}');
    }
  }

  /**
   * Initializes path data for a specific direction/column
   */
  private function initDirectionPath(direction:Int, pathPoints:Array<Vector3>):Void {
    totalDists[direction] = 0;
    pathData[direction] = [];
    
    for (pointIndex in 0...pathPoints.length) {
      var pointPosition = pathPoints[pointIndex];
      
      // Create path info structure for this point
      var pathInfo:PathInfo = {
        position: pointPosition.add(new Vector3(-Note.swagWidth / 2, -Note.swagWidth / 2)),
        start: totalDists[direction],
        end: 0,
        dist: 0
      };
      
      pathData[direction].push(pathInfo);
      
      // Calculate distances between points (skip first point)
      if (pointIndex > 0) {
        updatePathDistances(direction, pointIndex);
      }
    }
  }

  /**
   * Updates distance calculations between path points
   */
  private function updatePathDistances(direction:Int, currentIndex:Int):Void {
    var currentPoint = pathData[direction][currentIndex];
    var previousPoint = pathData[direction][currentIndex - 1];
    
    // Calculate distance between consecutive points
    var segmentDistance = Math.abs(Vector3.distance(previousPoint.position, currentPoint.position));
    totalDists[direction] += segmentDistance;
    
    // Update path info with new distance data
    previousPoint.end = totalDists[direction];
    previousPoint.dist = previousPoint.start - totalDists[direction]; // Negative distance for interpolation
  }

  /**
   * Applies path-based movement to note positions
   * Interpolates note position along predefined path based on timing
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
    // Early return if path modifier is disabled
    if (getValue(player) == 0) {
      return pos;
    }

    var pathProgress = calculatePathProgress(timeDiff, data);
    var interpolatedPosition = interpolateAlongPath(data, pathProgress, pos, player);
    
    return interpolatedPosition;
  }

  /**
   * Calculates progress along the path based on time difference
   */
  private function calculatePathProgress(timeDiff:Float, noteData:Int):Float {
    var visualTimeDiff = -timeDiff; // Convert to positive progress value
    var progress = (visualTimeDiff / -moveSpeed) * totalDists[noteData];
    return progress;
  }

  /**
   * Interpolates position along the path based on progress
   */
  private function interpolateAlongPath(noteData:Int, progress:Float, originalPos:Vector3, player:Int):Vector3 {
    var path = pathData[noteData];
    var outputPos = originalPos.clone();
    
    // Handle progress before path start
    if (progress <= 0) {
      return originalPos.lerp(path[0].position, getValue(player));
    }
    
    // Find the current path segment and interpolate
    for (pointIndex in 0...path.length - 1) {
      var currentPoint = path[pointIndex];
      var nextPoint = path[pointIndex + 1];
      
      if (progress > currentPoint.start && progress < currentPoint.end) {
        var interpolationAlpha = (currentPoint.start - progress) / currentPoint.dist;
        var pathPosition = currentPoint.position.lerp(nextPoint.position, interpolationAlpha);
        outputPos = originalPos.lerp(pathPosition, getValue(player));
        break;
      }
    }
    
    return outputPos;
  }

  override function getSubmods():Array<String> {
    return [];
  }
}