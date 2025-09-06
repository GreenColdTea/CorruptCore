package game.objects;

import game.backend.Conductor.BPMChangeEvent;
import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.FlxSubState;
import flixel.FlxSprite;
import flixel.FlxCamera;

class CustomFadeTransition extends MusicBeatSubstate {

    public static var finishCallback:Void->Void;
    private var leTween:FlxTween = null;
    var isTransIn:Bool = false;
    var transBlack:FlxSprite;
    var transGradient:FlxSprite;

    var duration:Float;
	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

    override function create() {
        // connecting to camera
        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

        var zoom:Float = MathUtil.boundTo(FlxG.camera.zoom, 0.05, 1);
        var width:Int = Std.int(FlxG.width / zoom);
        var height:Int = Std.int(FlxG.height / zoom);

        // gradient
        transGradient = FlxGradient.createGradientFlxSprite(width, height, [FlxColor.BLACK, 0x0]);
        transGradient.scrollFactor.set(0, 0);
        transGradient.alpha = isTransIn ? 1 : 0;
        add(transGradient);

        // Ngga bg
        transBlack = new FlxSprite().makeGraphic(width, height, FlxColor.BLACK);
        transBlack.scrollFactor.set(0, 0);
        transBlack.alpha = isTransIn ? 1 : 0;
        add(transBlack);

        // fade in/out anim script
        if (isTransIn) {
            transGradient.alpha = transBlack.alpha = 1;
            FlxTween.tween(transGradient, {alpha: 0}, duration, {
                onComplete: _ -> close(),
                ease: FlxEase.linear
            });
            FlxTween.tween(transBlack, {alpha: 0}, duration, {ease: FlxEase.linear});
        } else {
            transGradient.alpha = transBlack.alpha = 0;
            leTween = FlxTween.tween(transGradient, {alpha: 1}, duration, {
                onComplete: (_) -> {
                    if (finishCallback != null) {
                        finishCallback();
                    }
                },
                ease: FlxEase.linear
            });
            FlxTween.tween(transBlack, {alpha: 1}, duration, {ease: FlxEase.linear});
        }

        super.create();
    }

    override function destroy() {
        if (leTween != null) {
            finishCallback();
            leTween.cancel();
        }
        super.destroy();
    }
}
