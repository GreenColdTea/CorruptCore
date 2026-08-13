package game.modchart.modifiers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

import game.modchart.*;
import math.Vector3;

using StringTools;
// NOTE: THIS SHOULDNT HAVE ITS PERCENTAGE MODIFIED
// THIS IS JUST HERE TO ALLOW OTHER MODIFIERS TO HAVE PERSPECTIVE

// did my research
// i now know what a frustrum is lmao
// stuff ill forget after tonight

// its the next day and yea i forgot already LOL
// something somethng clipping idk

// either way
// perspective projection woo

final class PerspectiveModifier extends NoteModifier {
  override function getName() return 'perspectiveDONTUSE';

	override function getOrder() return Modifier.ModifierOrder.LAST + 100;

  override function shouldExecute(player:Int, val:Float) return true;

  var fov = Math.PI/2;
  var near = 0;
  var far = 2;

  function FastTan(rad:Float) // thanks schmoovin
  {
    return Math.sin(rad) / Math.cos(rad);
  }


  public function getVector(curZ:Float, pos:Vector3):Vector3 {
      final halfX = FlxG.width / 2;
      final halfY = FlxG.height / 2;
      
      final oX = pos.x - halfX;
      final oY = pos.y - halfY;

      final aspect = 1.0;

      var shit = curZ - 1;
      if(shit > 0) shit = 0; 

      final ta = FastTan(fov / 2);
      final x = oX * aspect / ta;
      final y = oY / ta;
      final a = (near + far) / (near - far);
      final b = 2 * near * far / (near - far);
      final z = (a * shit + b);

      pos.setTo((x / z) + halfX, (y / z) + halfY, z);

      return pos;
  }

  /*override function getReceptorPos(receptor:Receptor, pos:Vector3, data:Int, player:Int){ // maybe replace FlxPoint with a Vector3?
    // HI 4MBR0S3 IM SORRY :(( I GENUINELY FUCKIN FORGOT TO CREDIT PLEASEDONTHATEMEILOVEYOURSTUFF:(
    var vec = getVector(receptor.z,pos);
    pos.x=vec.x;
    pos.y=vec.y;

    return pos;
  }*/
	override function getPos(time:Float, visualDiff:Float, timeDiff:Float, beat:Float, pos:Vector3, data:Int, player:Int, obj:FlxSprite)
    return getVector(pos.z,pos);
  

	override function updateReceptor(beat:Float, receptor:StrumNote, pos:Vector3, player:Int){
    receptor.scale.scale(1/pos.z);
  }
  

	override function updateNote(beat:Float, note:Note, pos:Vector3, player:Int){
    note.scale.scale(1/pos.z);
  }
  

}
