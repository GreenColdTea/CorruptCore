package game.backend;

import game.PlayState;
import game.backend.ClientPrefs;

class Rating
{
    public var name:String = '';
    public var image:String = '';
    public var counter:String = '';
    public var hitWindow:Null<Int> = 0; //ms
    public var ratingMod:Float = 1;
    public var score:Int = 350;
    public var noteSplash:Bool = true;

    public function new(name:String)
    {
        this.name = name;
        this.image = name;
        this.counter = name + 's';
        this.hitWindow = Reflect.field(ClientPrefs, name + 'Window');
		
        hitWindow ??= 0;
    }

    public static function judgeNote(arr:Array<Rating>, diff:Float = 0):Rating
    {
        final data:Array<Rating> = arr;
        
        for(i in 0...data.length - 1)
            if (diff <= data[i].hitWindow)
                return data[i];

        return data[data.length - 1];
    }

    public function increase(blah:Int = 1)
    {
        Reflect.setField(PlayState.instance, counter, Reflect.field(PlayState.instance, counter) + blah);
    }
}