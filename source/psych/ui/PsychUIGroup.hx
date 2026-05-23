package psych.ui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

class PsychUIGroup extends FlxSpriteGroup
{
    public function new(x:Float = 0, y:Float = 0)
    {
        super(x, y);
    }
    
    public function updateHitboxes():Void
    {
        for (member in members)
        {
            if (Std.isOfType(member, FlxSprite))
                cast(member, FlxSprite).updateHitbox();
        }
    }
}