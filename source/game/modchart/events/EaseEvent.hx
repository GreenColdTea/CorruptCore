package game.modchart.events;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

/**
 * Handles smooth transitions of modifier values over time
 * Applies easing functions to gradually change modifier values between steps
 */
class EaseEvent extends ModEvent {
    public var endStep:Float = 0;          // Step when the ease animation completes
    public var startVal:Null<Float>;       // Starting value (null = use current value)
    public var easeFunc:EaseFunction;      // Easing function to use for transition
    public var length:Float = 0;           // Total duration in steps

    /**
     * Creates a new ease event for smooth modifier value transitions
     * 
     * @param step Starting step for the ease animation
     * @param endStep Ending step for the ease animation
     * @param modName Name of the modifier to animate
     * @param target Target value to ease towards
     * @param easeFunc Easing function to use for the transition
     * @param player Player index (0 = Player, 1 = Opponent, -1 = Both)
     * @param modMgr Reference to the modifier manager
     * @param startVal Optional starting value (uses current value if null)
     */
    public function new(
        step:Float, 
        endStep:Float, 
        modName:String, 
        target:Float, 
        easeFunc:EaseFunction, 
        player:Int = 0, 
        modMgr:ModManager, 
        ?startVal:Float
    ) {
        super(step, modName, target, player, modMgr);
        
        this.endStep = endStep;
        this.easeFunc = easeFunc;
        this.startVal = startVal;

        if (mod == null)
            trace('Warning: Modifier "$modName" is null!');

        length = endStep - step;
    }

    /**
     * Custom easing function that mimics FlxTween behavior
     * 
     * @param e Easing function reference
     * @param t Current time (progress through animation)
     * @param b Beginning value (start value)
     * @param c Change in value (target - start)
     * @param d Total duration
     * @return Current eased value
     */
    private function ease(e:EaseFunction, t:Float, b:Float, c:Float, d:Float):Float {
        var normalizedTime = t / d;
        return c * e(normalizedTime) + b;
    }

    /**
     * Executes the ease event based on current step progress
     * 
     * @param curStep Current step in the timeline
     */
    override function run(curStep:Float) {
        if (curStep <= endStep) {
            // Animation in progress - calculate current eased value
            executeEaseStep(curStep);
        } else {
            // Animation complete - set final value
            completeEaseAnimation();
        }
    }

    /**
     * Calculates and applies the current eased value during animation
     */
    private function executeEaseStep(curStep:Float) {
        if (startVal == null)
            startVal = mod.getValue(player);
        
        var timePassed = curStep - executionStep;
        var valueChange = endVal - startVal;
        
        var currentValue = ease(easeFunc, timePassed, startVal, valueChange, length);
        manager.setValue(modName, currentValue, player);
    }

    /**
     * Finalizes the ease animation by setting the target value
     */
    private function completeEaseAnimation() {
        finished = true;
        manager.setValue(modName, endVal, player);
    }
}