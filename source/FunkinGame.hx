package;

import flixel.FlxGame;
import flixel.FlxG;
import flixel.FlxState;
import flixel.util.typeLimit.NextState.InitialState;

#if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
import game.scripting.HScriptGlobal;
import game.scripting.HScriptState;
#end

@:access(flixel.FlxGame)
class FunkinGame extends FlxGame
{
    public function new(gameWidth = 0, gameHeight = 0, ?initialState:InitialState, updateFramerate = 60, drawFramerate = 60, skipSplash = false, startFullscreen = false)
    {
        super(gameWidth, gameHeight, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
    }

    override function switchState():Void
    {
        FlxG.cameras.reset();
        FlxG.inputs.onStateSwitch();
        #if FLX_SOUND_SYSTEM
        FlxG.sound.destroy();
        #end

        FlxG.signals.preStateSwitch.dispatch();

        #if FLX_RECORD
        flixel.math.FlxRandom.updateStateSeed();
        #end

        if (_state != null)
            _state.destroy();

        FlxG.bitmap.clearCache();

        _state = _nextState.createInstance();

        #if (HSCRIPT_ALLOWED && SCRIPTABLE_STATES)
        final stateClass = Type.getClassName(Type.getClass(_state));
        if (HScriptGlobal.stateRedirectMap.exists(stateClass) && HScriptGlobal.stateRedirectMap.get(stateClass))
        {
            _state = new HScriptState(stateClass);
        }
        #end

        _state._constructor = _nextState.getConstructor();
        _nextState = null;

        if (_gameJustStarted)
            FlxG.signals.preGameStart.dispatch();

        FlxG.signals.preStateCreate.dispatch(_state);

        _state.create();

        if (_gameJustStarted)
            gameStart();

        #if FLX_DEBUG
        debugger.console.registerObject("state", _state);
        #end

        FlxG.signals.postStateSwitch.dispatch();

        draw();
        
        #if flash 
        _total = ticks = getTicks();
        #else
        ticks = getTicks();
        #end
        
        _skipNextTickUpdate = true;
    }
}