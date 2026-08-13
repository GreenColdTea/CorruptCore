package game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

import game.modchart.*;
import math.Vector3;

typedef PathInfo = {
  var position:Vector3;
  var dist:Float;
  var start:Float;
  var end:Float;
}

class PathModifier extends NoteModifier {
  private var moveSpeed:Float;
  private var pathData:Array<Array<PathInfo>> = [];
  private var totalDists:Array<Float> = [];

  override function getName():String {
    return 'basePath';
  }

  public function getMoveSpeed():Float {
    return 5000;
  }

  public function getPath():Array<Array<Vector3>> {
    return [];
  }

  public function new(modMgr:ModManager, ?parent:Modifier) {
    super(modMgr, parent);
    initPathData();
  }

  private function initPathData():Void {
    moveSpeed = getMoveSpeed();
    var rawPath:Array<Array<Vector3>> = getPath();
    
    for (direction in 0...rawPath.length) {
      initDirectionPath(direction, rawPath[direction]);
      
      for (vec in rawPath[direction]) {
          vec.put();
      }
    }
  }

  private function initDirectionPath(direction:Int, pathPoints:Array<Vector3>):Void {
    totalDists[direction] = 0;
    pathData[direction] = [];
    
    for (pointIndex in 0...pathPoints.length) {
      final pointPosition = pathPoints[pointIndex];
      
      final pathInfo:PathInfo = {
        position: Vector3.get(pointPosition.x - game.objects.Note.swagWidth / 2, pointPosition.y - game.objects.Note.swagWidth / 2, pointPosition.z),
        start: totalDists[direction],
        end: 0,
        dist: 0
      };
      
      pathData[direction].push(pathInfo);
      
      if (pointIndex > 0)
        updatePathDistances(direction, pointIndex);
    }
  }

  private function updatePathDistances(direction:Int, currentIndex:Int):Void {
    var currentPoint = pathData[direction][currentIndex];
    var previousPoint = pathData[direction][currentIndex - 1];
    
    var segmentDistance = Math.abs(Vector3.distance(previousPoint.position, currentPoint.position));
    totalDists[direction] += segmentDistance;
    
    previousPoint.end = totalDists[direction];
    previousPoint.dist = previousPoint.start - totalDists[direction];
  }

  override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite):Vector3 {
    if (getValue(player) == 0) return pos;

    var pathProgress = calculatePathProgress(timeDiff, data);
    return interpolateAlongPath(data, pathProgress, pos, player);
  }

  private function calculatePathProgress(timeDiff:Float, noteData:Int):Float {
    var visualTimeDiff = -timeDiff;
    var progress = (visualTimeDiff / -moveSpeed) * totalDists[noteData];
    
    if (totalDists[noteData] > 0) {
        progress = progress % totalDists[noteData];
        if (progress < 0) progress += totalDists[noteData];
    }
    
    return progress;
  }

  private function interpolateAlongPath(noteData:Int, progress:Float, originalPos:Vector3, player:Int):Vector3 {
    final path = pathData[noteData];
    
    if (progress <= 0)
        return originalPos.lerp(path[0].position, getValue(player), originalPos);
    
    for (pointIndex in 0...path.length - 1) {
        final currentPoint = path[pointIndex];
        final nextPoint = path[pointIndex + 1];
        
        if (progress >= currentPoint.start && progress <= currentPoint.end) {
            final interpolationAlpha = (currentPoint.start - progress) / currentPoint.dist;
            final tempPathPos = currentPoint.position.lerp(nextPoint.position, interpolationAlpha, Vector3.get());
            
            originalPos.lerp(tempPathPos, getValue(player), originalPos);
            
            tempPathPos.put();
            break;
        }
    }
    
    return originalPos;
  }

  override function getSubmods():Array<String> {
    return [];
  }
}