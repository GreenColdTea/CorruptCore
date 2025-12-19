package game.backend;

import flixel.FlxG;
import flixel.input.FlxInput;
import flixel.input.actions.FlxAction;
import flixel.input.actions.FlxActionInput;
import flixel.input.actions.FlxActionInputDigital;
import flixel.input.actions.FlxActionManager;
import flixel.input.actions.FlxActionSet;
import flixel.input.gamepad.FlxGamepadButton;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

#if (haxe >= "4.0.0")
enum abstract Action(String) to String from String
{
	var UI_UP = "ui_up";
	var UI_LEFT = "ui_left";
	var UI_RIGHT = "ui_right";
	var UI_DOWN = "ui_down";
	var UI_UP_P = "ui_up-press";
	var UI_LEFT_P = "ui_left-press";
	var UI_RIGHT_P = "ui_right-press";
	var UI_DOWN_P = "ui_down-press";
	var UI_UP_R = "ui_up-release";
	var UI_LEFT_R = "ui_left-release";
	var UI_RIGHT_R = "ui_right-release";
	var UI_DOWN_R = "ui_down-release";
	var NOTE_UP = "note_up";
	var NOTE_LEFT = "note_left";
	var NOTE_RIGHT = "note_right";
	var NOTE_DOWN = "note_down";
	var NOTE_UP_P = "note_up-press";
	var NOTE_LEFT_P = "note_left-press";
	var NOTE_RIGHT_P = "note_right-press";
	var NOTE_DOWN_P = "note_down-press";
	var NOTE_UP_R = "note_up-release";
	var NOTE_LEFT_R = "note_left-release";
	var NOTE_RIGHT_R = "note_right-release";
	var NOTE_DOWN_R = "note_down-release";
	var ACCEPT = "accept";
	var BACK = "back";
	var PAUSE = "pause";
	var RESET = "reset";
}
#else
@:enum
abstract Action(String) to String from String
{
	var UI_UP = "ui_up";
	var UI_LEFT = "ui_left";
	var UI_RIGHT = "ui_right";
	var UI_DOWN = "ui_down";
	var UI_UP_P = "ui_up-press";
	var UI_LEFT_P = "ui_left-press";
	var UI_RIGHT_P = "ui_right-press";
	var UI_DOWN_P = "ui_down-press";
	var UI_UP_R = "ui_up-release";
	var UI_LEFT_R = "ui_left-release";
	var UI_RIGHT_R = "ui_right-release";
	var UI_DOWN_R = "ui_down-release";
	var NOTE_UP = "note_up";
	var NOTE_LEFT = "note_left";
	var NOTE_RIGHT = "note_right";
	var NOTE_DOWN = "note_down";
	var NOTE_UP_P = "note_up-press";
	var NOTE_LEFT_P = "note_left-press";
	var NOTE_RIGHT_P = "note_right-press";
	var NOTE_DOWN_P = "note_down-press";
	var NOTE_UP_R = "note_up-release";
	var NOTE_LEFT_R = "note_left-release";
	var NOTE_RIGHT_R = "note_right-release";
	var NOTE_DOWN_R = "note_down-release";
	var ACCEPT = "accept";
	var BACK = "back";
	var PAUSE = "pause";
	var RESET = "reset";
}
#end

enum Device
{
	Keys;
	Gamepad(id:Int);
}

/**
 * Since, in many cases multiple actions should use similar keys, we don't want the
 * rebinding UI to list every action. ActionBinders are what the user percieves as
 * an input so, for instance, they can't set jump-press and jump-release to different keys.
 */
enum Control
{
	UI_UP;
	UI_LEFT;
	UI_RIGHT;
	UI_DOWN;
	NOTE_UP;
	NOTE_LEFT;
	NOTE_RIGHT;
	NOTE_DOWN;
	RESET;
	ACCEPT;
	BACK;
	PAUSE;
}

enum KeyboardScheme
{
	Solo;
	Duo(first:Bool);
	None;
	Custom;
}

/**
 * Helper type for control actions
 */
typedef ControlAction = {
	action:FlxActionDigital,
	state:FlxInputState
};

/**
 * A list of actions that a player would invoke via some input device.
 * Uses FlxActions to funnel various inputs to a single action.
 */
class Controls extends FlxActionSet
{
	// Action variables
	var action_ui_up = new FlxActionDigital(Action.UI_UP);
	var action_ui_left = new FlxActionDigital(Action.UI_LEFT);
	var action_ui_right = new FlxActionDigital(Action.UI_RIGHT);
	var action_ui_down = new FlxActionDigital(Action.UI_DOWN);
	var action_ui_upP = new FlxActionDigital(Action.UI_UP_P);
	var action_ui_leftP = new FlxActionDigital(Action.UI_LEFT_P);
	var action_ui_rightP = new FlxActionDigital(Action.UI_RIGHT_P);
	var action_ui_downP = new FlxActionDigital(Action.UI_DOWN_P);
	var action_ui_upR = new FlxActionDigital(Action.UI_UP_R);
	var action_ui_leftR = new FlxActionDigital(Action.UI_LEFT_R);
	var action_ui_rightR = new FlxActionDigital(Action.UI_RIGHT_R);
	var action_ui_downR = new FlxActionDigital(Action.UI_DOWN_R);
	var action_note_up = new FlxActionDigital(Action.NOTE_UP);
	var action_note_left = new FlxActionDigital(Action.NOTE_LEFT);
	var action_note_right = new FlxActionDigital(Action.NOTE_RIGHT);
	var action_note_down = new FlxActionDigital(Action.NOTE_DOWN);
	var action_note_upP = new FlxActionDigital(Action.NOTE_UP_P);
	var action_note_leftP = new FlxActionDigital(Action.NOTE_LEFT_P);
	var action_note_rightP = new FlxActionDigital(Action.NOTE_RIGHT_P);
	var action_note_downP = new FlxActionDigital(Action.NOTE_DOWN_P);
	var action_note_upR = new FlxActionDigital(Action.NOTE_UP_R);
	var action_note_leftR = new FlxActionDigital(Action.NOTE_LEFT_R);
	var action_note_rightR = new FlxActionDigital(Action.NOTE_RIGHT_R);
	var action_note_downR = new FlxActionDigital(Action.NOTE_DOWN_R);
	var action_accept = new FlxActionDigital(Action.ACCEPT);
	var action_back = new FlxActionDigital(Action.BACK);
	var action_pause = new FlxActionDigital(Action.PAUSE);
	var action_reset = new FlxActionDigital(Action.RESET);

	#if (haxe >= "4.0.0")
	var byName:Map<String, FlxActionDigital> = [];
	#else
	var byName:Map<String, FlxActionDigital> = new Map<String, FlxActionDigital>();
	#end

	public var gamepadsAdded:Array<Int> = [];
	public var keyboardScheme = KeyboardScheme.None;

	// Control state accessors
	public var UI_UP(get, never):Bool;
	inline function get_UI_UP() return action_ui_up.check();

	public var UI_LEFT(get, never):Bool;
	inline function get_UI_LEFT() return action_ui_left.check();

	public var UI_RIGHT(get, never):Bool;
	inline function get_UI_RIGHT() return action_ui_right.check();

	public var UI_DOWN(get, never):Bool;
	inline function get_UI_DOWN() return action_ui_down.check();

	public var UI_UP_P(get, never):Bool;
	inline function get_UI_UP_P() return action_ui_upP.check();

	public var UI_LEFT_P(get, never):Bool;
	inline function get_UI_LEFT_P() return action_ui_leftP.check();

	public var UI_RIGHT_P(get, never):Bool;
	inline function get_UI_RIGHT_P() return action_ui_rightP.check();

	public var UI_DOWN_P(get, never):Bool;
	inline function get_UI_DOWN_P() return action_ui_downP.check();

	public var UI_UP_R(get, never):Bool;
	inline function get_UI_UP_R() return action_ui_upR.check();

	public var UI_LEFT_R(get, never):Bool;
	inline function get_UI_LEFT_R() return action_ui_leftR.check();

	public var UI_RIGHT_R(get, never):Bool;
	inline function get_UI_RIGHT_R() return action_ui_rightR.check();

	public var UI_DOWN_R(get, never):Bool;
	inline function get_UI_DOWN_R() return action_ui_downR.check();

	public var NOTE_UP(get, never):Bool;
	inline function get_NOTE_UP() return action_note_up.check();

	public var NOTE_LEFT(get, never):Bool;
	inline function get_NOTE_LEFT() return action_note_left.check();

	public var NOTE_RIGHT(get, never):Bool;
	inline function get_NOTE_RIGHT() return action_note_right.check();

	public var NOTE_DOWN(get, never):Bool;
	inline function get_NOTE_DOWN() return action_note_down.check();

	public var NOTE_UP_P(get, never):Bool;
	inline function get_NOTE_UP_P() return action_note_upP.check();

	public var NOTE_LEFT_P(get, never):Bool;
	inline function get_NOTE_LEFT_P() return action_note_leftP.check();

	public var NOTE_RIGHT_P(get, never):Bool;
	inline function get_NOTE_RIGHT_P() return action_note_rightP.check();

	public var NOTE_DOWN_P(get, never):Bool;
	inline function get_NOTE_DOWN_P() return action_note_downP.check();

	public var NOTE_UP_R(get, never):Bool;
	inline function get_NOTE_UP_R() return action_note_upR.check();

	public var NOTE_LEFT_R(get, never):Bool;
	inline function get_NOTE_LEFT_R() return action_note_leftR.check();

	public var NOTE_RIGHT_R(get, never):Bool;
	inline function get_NOTE_RIGHT_R() return action_note_rightR.check();

	public var NOTE_DOWN_R(get, never):Bool;
	inline function get_NOTE_DOWN_R() return action_note_downR.check();

	public var ACCEPT(get, never):Bool;
	inline function get_ACCEPT() return action_accept.check();

	public var BACK(get, never):Bool;
	inline function get_BACK() return action_back.check();

	public var PAUSE(get, never):Bool;
	inline function get_PAUSE() return action_pause.check();

	public var RESET(get, never):Bool;
	inline function get_RESET() return action_reset.check();

	// Mapping for forEachBound
	private var controlActionsMap:Map<Control, Array<ControlAction>>;

	#if (haxe >= "4.0.0")
	public function new(name, scheme = None)
	{
		super(name);

		// Add all actions
		add(action_ui_up);
		add(action_ui_left);
		add(action_ui_right);
		add(action_ui_down);
		add(action_ui_upP);
		add(action_ui_leftP);
		add(action_ui_rightP);
		add(action_ui_downP);
		add(action_ui_upR);
		add(action_ui_leftR);
		add(action_ui_rightR);
		add(action_ui_downR);
		add(action_note_up);
		add(action_note_left);
		add(action_note_right);
		add(action_note_down);
		add(action_note_upP);
		add(action_note_leftP);
		add(action_note_rightP);
		add(action_note_downP);
		add(action_note_upR);
		add(action_note_leftR);
		add(action_note_rightR);
		add(action_note_downR);
		add(action_accept);
		add(action_back);
		add(action_pause);
		add(action_reset);

		// Populate byName map
		for (action in digitalActions)
			byName[action.name] = action;

		// Init control actions mapping
		initControlActionsMap();

		setKeyboardScheme(scheme, false);
	}
	#else
	public function new(name, scheme:KeyboardScheme = null)
	{
		super(name);

		// Same as above but for older Haxe
		add(action_ui_up);
		add(action_ui_left);
		add(action_ui_right);
		add(action_ui_down);
		add(action_ui_upP);
		add(action_ui_leftP);
		add(action_ui_rightP);
		add(action_ui_downP);
		add(action_ui_upR);
		add(action_ui_leftR);
		add(action_ui_rightR);
		add(action_ui_downR);
		add(action_note_up);
		add(action_note_left);
		add(action_note_right);
		add(action_note_down);
		add(action_note_upP);
		add(action_note_leftP);
		add(action_note_rightP);
		add(action_note_downP);
		add(action_note_upR);
		add(action_note_leftR);
		add(action_note_rightR);
		add(action_note_downR);
		add(action_accept);
		add(action_back);
		add(action_pause);
		add(action_reset);

		for (action in digitalActions)
			byName[action.name] = action;

		initControlActionsMap();

		if (scheme == null)
			scheme = None;
		setKeyboardScheme(scheme, false);
	}
	#end

	private function initControlActionsMap():Void
	{
		controlActionsMap = new Map<Control, Array<ControlAction>>();
		
		controlActionsMap.set(Control.UI_UP, [
			{action: action_ui_up, state: PRESSED},
			{action: action_ui_upP, state: JUST_PRESSED},
			{action: action_ui_upR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.UI_LEFT, [
			{action: action_ui_left, state: PRESSED},
			{action: action_ui_leftP, state: JUST_PRESSED},
			{action: action_ui_leftR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.UI_RIGHT, [
			{action: action_ui_right, state: PRESSED},
			{action: action_ui_rightP, state: JUST_PRESSED},
			{action: action_ui_rightR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.UI_DOWN, [
			{action: action_ui_down, state: PRESSED},
			{action: action_ui_downP, state: JUST_PRESSED},
			{action: action_ui_downR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.NOTE_UP, [
			{action: action_note_up, state: PRESSED},
			{action: action_note_upP, state: JUST_PRESSED},
			{action: action_note_upR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.NOTE_LEFT, [
			{action: action_note_left, state: PRESSED},
			{action: action_note_leftP, state: JUST_PRESSED},
			{action: action_note_leftR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.NOTE_RIGHT, [
			{action: action_note_right, state: PRESSED},
			{action: action_note_rightP, state: JUST_PRESSED},
			{action: action_note_rightR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.NOTE_DOWN, [
			{action: action_note_down, state: PRESSED},
			{action: action_note_downP, state: JUST_PRESSED},
			{action: action_note_downR, state: JUST_RELEASED}
		]);
		
		controlActionsMap.set(Control.ACCEPT, [
			{action: action_accept, state: JUST_PRESSED}
		]);
		
		controlActionsMap.set(Control.BACK, [
			{action: action_back, state: JUST_PRESSED}
		]);
		
		controlActionsMap.set(Control.PAUSE, [
			{action: action_pause, state: JUST_PRESSED}
		]);
		
		controlActionsMap.set(Control.RESET, [
			{action: action_reset, state: JUST_PRESSED}
		]);
	}

	override function update()
	{
		super.update();
	}

	// inline
	public function checkByName(name:Action):Bool
	{
		#if debug
		if (!byName.exists(name))
			throw 'Invalid name: $name';
		#end
		return byName[name].check();
	}

	public function getDialogueName(action:FlxActionDigital):String
	{
		// Return 1st input's name
		if (action.inputs.length > 0)
		{
			var input = action.inputs[0];
			return switch input.device
			{
				case KEYBOARD: return '[${(input.inputID : FlxKey)}]';
				case GAMEPAD: return '(${(input.inputID : FlxGamepadInputID)})';
				case device: throw 'unhandled device: $device';
			}
		}
		return '[Unknown]';
	}

	public function getDialogueNameFromToken(token:String):String
	{
		return getDialogueName(getActionFromControl(Control.createByName(token.toUpperCase())));
	}

	function getActionFromControl(control:Control):FlxActionDigital
	{
		return switch (control)
		{
			case UI_UP: action_ui_up;
			case UI_DOWN: action_ui_down;
			case UI_LEFT: action_ui_left;
			case UI_RIGHT: action_ui_right;
			case NOTE_UP: action_note_up;
			case NOTE_DOWN: action_note_down;
			case NOTE_LEFT: action_note_left;
			case NOTE_RIGHT: action_note_right;
			case ACCEPT: action_accept;
			case BACK: action_back;
			case PAUSE: action_pause;
			case RESET: action_reset;
		}
	}

	static function init():Void
	{
		var actions = new FlxActionManager();
		FlxG.inputs.addUniqueType(actions);
	}

	/**
	 * Calls a function passing each action bound by the specified control
	 */
	function forEachBound(control:Control, func:FlxActionDigital->FlxInputState->Void)
	{
		if (controlActionsMap.exists(control))
		{
			for (item in controlActionsMap[control])
			{
				func(item.action, item.state);
			}
		}
	}

	public function replaceBinding(control:Control, device:Device, ?toAdd:Int, ?toRemove:Int)
	{
		if (toAdd == toRemove)
			return;

		switch (device)
		{
			case Keys:
				if (toRemove != null)
					unbindKeys(control, [toRemove]);
				if (toAdd != null)
					bindKeys(control, [toAdd]);

			case Gamepad(id):
				if (toRemove != null)
					unbindButtons(control, id, [toRemove]);
				if (toAdd != null)
					bindButtons(control, id, [toAdd]);
		}
	}

	public function copyFrom(controls:Controls, ?device:Device)
	{
		#if (haxe >= "4.0.0")
		for (name => action in controls.byName)
		{
			for (input in action.inputs)
			{
				if (device == null || isDevice(input, device))
					byName[name].add(cast input);
			}
		}
		#else
		for (name in controls.byName.keys())
		{
			var action = controls.byName[name];
			for (input in action.inputs)
			{
				if (device == null || isDevice(input, device))
					byName[name].add(cast input);
			}
		}
		#end

		switch (device)
		{
			case null:
				// add all
				#if (haxe >= "4.0.0")
				for (gamepad in controls.gamepadsAdded)
					if (!gamepadsAdded.contains(gamepad))
						gamepadsAdded.push(gamepad);
				#else
				for (gamepad in controls.gamepadsAdded)
					if (gamepadsAdded.indexOf(gamepad) == -1)
						gamepadsAdded.push(gamepad);
				#end

				mergeKeyboardScheme(controls.keyboardScheme);

			case Gamepad(id):
				gamepadsAdded.push(id);
			case Keys:
				mergeKeyboardScheme(controls.keyboardScheme);
		}
	}

	inline public function copyTo(controls:Controls, ?device:Device)
	{
		controls.copyFrom(this, device);
	}

	function mergeKeyboardScheme(scheme:KeyboardScheme):Void
	{
		if (scheme != None)
		{
			switch (keyboardScheme)
			{
				case None:
					keyboardScheme = scheme;
				default:
					keyboardScheme = Custom;
			}
		}
	}

	/**
	 * Filter out NONE keys from array
	 */
	private function filterNoneKeys(keys:Array<FlxKey>):Array<FlxKey>
	{
		var filtered:Array<FlxKey> = [];
		for (key in keys)
		{
			if (key != NONE)
				filtered.push(key);
		}
		return filtered;
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function bindKeys(control:Control, keys:Array<FlxKey>)
	{
		var filteredKeys = filterNoneKeys(keys);

		#if (haxe >= "4.0.0")
		inline forEachBound(control, (action, state) -> addKeys(action, filteredKeys, state));
		#else
		forEachBound(control, function(action, state) addKeys(action, filteredKeys, state));
		#end
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function unbindKeys(control:Control, keys:Array<FlxKey>)
	{
		var filteredKeys = filterNoneKeys(keys);

		#if (haxe >= "4.0.0")
		inline forEachBound(control, (action, _) -> removeKeys(action, filteredKeys));
		#else
		forEachBound(control, function(action, _) removeKeys(action, filteredKeys));
		#end
	}

	inline static function addKeys(action:FlxActionDigital, keys:Array<FlxKey>, state:FlxInputState)
	{
		for (key in keys)
			if (key != NONE)
				action.addKey(key, state);
	}

	static function removeKeys(action:FlxActionDigital, keys:Array<FlxKey>)
	{
		var i = action.inputs.length;
		while (i-- > 0)
		{
			var input = action.inputs[i];
			if (input.device == KEYBOARD && keys.indexOf(cast input.inputID) != -1)
				action.remove(input);
		}
	}

	public function setKeyboardScheme(scheme:KeyboardScheme, reset = true)
	{
		if (reset)
			removeKeyboard();

		keyboardScheme = scheme;
		var keysMap = ClientPrefs.keyBinds;
		
		#if (haxe >= "4.0.0")
		switch (scheme)
		{
			case Solo:
				inline bindKeys(Control.UI_UP, keysMap.get('ui_up'));
				inline bindKeys(Control.UI_DOWN, keysMap.get('ui_down'));
				inline bindKeys(Control.UI_LEFT, keysMap.get('ui_left'));
				inline bindKeys(Control.UI_RIGHT, keysMap.get('ui_right'));
				inline bindKeys(Control.NOTE_UP, keysMap.get('note_up'));
				inline bindKeys(Control.NOTE_DOWN, keysMap.get('note_down'));
				inline bindKeys(Control.NOTE_LEFT, keysMap.get('note_left'));
				inline bindKeys(Control.NOTE_RIGHT, keysMap.get('note_right'));

				inline bindKeys(Control.ACCEPT, keysMap.get('accept'));
				inline bindKeys(Control.BACK, keysMap.get('back'));
				inline bindKeys(Control.PAUSE, keysMap.get('pause'));
				inline bindKeys(Control.RESET, keysMap.get('reset'));
			case Duo(true):
				inline bindKeys(Control.UI_UP, [W]);
				inline bindKeys(Control.UI_DOWN, [S]);
				inline bindKeys(Control.UI_LEFT, [A]);
				inline bindKeys(Control.UI_RIGHT, [D]);
				inline bindKeys(Control.NOTE_UP, [W]);
				inline bindKeys(Control.NOTE_DOWN, [S]);
				inline bindKeys(Control.NOTE_LEFT, [A]);
				inline bindKeys(Control.NOTE_RIGHT, [D]);
				inline bindKeys(Control.ACCEPT, [G, Z]);
				inline bindKeys(Control.BACK, [H, X]);
				inline bindKeys(Control.PAUSE, [ONE]);
				inline bindKeys(Control.RESET, [R]);
			case Duo(false):
				inline bindKeys(Control.UI_UP, [FlxKey.UP]);
				inline bindKeys(Control.UI_DOWN, [FlxKey.DOWN]);
				inline bindKeys(Control.UI_LEFT, [FlxKey.LEFT]);
				inline bindKeys(Control.UI_RIGHT, [FlxKey.RIGHT]);
				inline bindKeys(Control.NOTE_UP, [FlxKey.UP]);
				inline bindKeys(Control.NOTE_DOWN, [FlxKey.DOWN]);
				inline bindKeys(Control.NOTE_LEFT, [FlxKey.LEFT]);
				inline bindKeys(Control.NOTE_RIGHT, [FlxKey.RIGHT]);
				inline bindKeys(Control.ACCEPT, [O]);
				inline bindKeys(Control.BACK, [P]);
				inline bindKeys(Control.PAUSE, [ENTER]);
				inline bindKeys(Control.RESET, [BACKSPACE]);
			case None: // nothing
			case Custom: // nothing
		}
		#else
		switch (scheme)
		{
			case Solo:
				bindKeys(Control.UI_UP, [W, FlxKey.UP]);
				bindKeys(Control.UI_DOWN, [S, FlxKey.DOWN]);
				bindKeys(Control.UI_LEFT, [A, FlxKey.LEFT]);
				bindKeys(Control.UI_RIGHT, [D, FlxKey.RIGHT]);
				bindKeys(Control.NOTE_UP, [W, FlxKey.UP]);
				bindKeys(Control.NOTE_DOWN, [S, FlxKey.DOWN]);
				bindKeys(Control.NOTE_LEFT, [A, FlxKey.LEFT]);
				bindKeys(Control.NOTE_RIGHT, [D, FlxKey.RIGHT]);
				bindKeys(Control.ACCEPT, [Z, SPACE, ENTER]);
				bindKeys(Control.BACK, [BACKSPACE, ESCAPE]);
				bindKeys(Control.PAUSE, [P, ENTER, ESCAPE]);
				bindKeys(Control.RESET, [R]);
			case Duo(true):
				bindKeys(Control.UI_UP, [W]);
				bindKeys(Control.UI_DOWN, [S]);
				bindKeys(Control.UI_LEFT, [A]);
				bindKeys(Control.UI_RIGHT, [D]);
				bindKeys(Control.NOTE_UP, [W]);
				bindKeys(Control.NOTE_DOWN, [S]);
				bindKeys(Control.NOTE_LEFT, [A]);
				bindKeys(Control.NOTE_RIGHT, [D]);
				bindKeys(Control.ACCEPT, [G, Z]);
				bindKeys(Control.BACK, [H, X]);
				bindKeys(Control.PAUSE, [ONE]);
				bindKeys(Control.RESET, [R]);
			case Duo(false):
				bindKeys(Control.UI_UP, [FlxKey.UP]);
				bindKeys(Control.UI_DOWN, [FlxKey.DOWN]);
				bindKeys(Control.UI_LEFT, [FlxKey.LEFT]);
				bindKeys(Control.UI_RIGHT, [FlxKey.RIGHT]);
				bindKeys(Control.NOTE_UP, [FlxKey.UP]);
				bindKeys(Control.NOTE_DOWN, [FlxKey.DOWN]);
				bindKeys(Control.NOTE_LEFT, [FlxKey.LEFT]);
				bindKeys(Control.NOTE_RIGHT, [FlxKey.RIGHT]);
				bindKeys(Control.ACCEPT, [O]);
				bindKeys(Control.BACK, [P]);
				bindKeys(Control.PAUSE, [ENTER]);
				bindKeys(Control.RESET, [BACKSPACE]);
			case None: // nothing
			case Custom: // nothing
		}
		#end
	}

	function removeKeyboard()
	{
		for (action in this.digitalActions)
		{
			var i = action.inputs.length;
			while (i-- > 0)
			{
				var input = action.inputs[i];
				if (input.device == KEYBOARD)
					action.remove(input);
			}
		}
	}

	public function addGamepad(id:Int, ?buttonMap:Map<Control, Array<FlxGamepadInputID>>):Void
	{
		gamepadsAdded.push(id);
		
		#if (haxe >= "4.0.0")
		for (control => buttons in buttonMap)
			inline bindButtons(control, id, buttons);
		#else
		for (control in buttonMap.keys())
			bindButtons(control, id, buttonMap[control]);
		#end
	}

	inline function addGamepadLiteral(id:Int, ?buttonMap:Map<Control, Array<FlxGamepadInputID>>):Void
	{
		gamepadsAdded.push(id);

		#if (haxe >= "4.0.0")
		for (control => buttons in buttonMap)
			inline bindButtons(control, id, buttons);
		#else
		for (control in buttonMap.keys())
			bindButtons(control, id, buttonMap[control]);
		#end
	}

	public function removeGamepad(deviceID:Int = FlxInputDeviceID.ALL):Void
	{
		for (action in this.digitalActions)
		{
			var i = action.inputs.length;
			while (i-- > 0)
			{
				var input = action.inputs[i];
				if (input.device == GAMEPAD && (deviceID == FlxInputDeviceID.ALL || input.deviceID == deviceID))
					action.remove(input);
			}
		}

		gamepadsAdded.remove(deviceID);
	}

	public function addDefaultGamepad(id):Void
	{
		#if !switch
		addGamepadLiteral(id, [
			Control.ACCEPT => [A, START],
			Control.BACK => [B],
			Control.UI_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP],
			Control.UI_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
			Control.UI_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
			Control.UI_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
			Control.NOTE_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP, Y],
			Control.NOTE_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN, A],
			Control.NOTE_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT, X],
			Control.NOTE_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT, B],
			Control.PAUSE => [START],
			Control.RESET => [8]
		]);
		#else
		addGamepadLiteral(id, [
			//Swap A and B for switch
			Control.ACCEPT => [B, START],
			Control.BACK => [A],
			Control.UI_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP],
			Control.UI_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN],
			Control.UI_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT],
			Control.UI_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT],
			Control.NOTE_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP, X],
			Control.NOTE_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN, B],
			Control.NOTE_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT, Y],
			Control.NOTE_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT, A],
			Control.PAUSE => [START],
			Control.RESET => [8],
		]);
		#end
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function bindButtons(control:Control, id, buttons)
	{
		#if (haxe >= "4.0.0")
		inline forEachBound(control, (action, state) -> addButtons(action, buttons, state, id));
		#else
		forEachBound(control, function(action, state) addButtons(action, buttons, state, id));
		#end
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function unbindButtons(control:Control, gamepadID:Int, buttons)
	{
		#if (haxe >= "4.0.0")
		inline forEachBound(control, (action, _) -> removeButtons(action, gamepadID, buttons));
		#else
		forEachBound(control, function(action, _) removeButtons(action, gamepadID, buttons));
		#end
	}

	inline static function addButtons(action:FlxActionDigital, buttons:Array<FlxGamepadInputID>, state, id)
	{
		for (button in buttons)
			action.addGamepad(button, state, id);
	}

	static function removeButtons(action:FlxActionDigital, gamepadID:Int, buttons:Array<FlxGamepadInputID>)
	{
		var i = action.inputs.length;
		while (i-- > 0)
		{
			var input = action.inputs[i];
			if (isGamepad(input, gamepadID) && buttons.indexOf(cast input.inputID) != -1)
				action.remove(input);
		}
	}

	public function getInputsFor(control:Control, device:Device, ?list:Array<Int>):Array<Int>
	{
		if (list == null)
			list = [];

		switch (device)
		{
			case Keys:
				for (input in getActionFromControl(control).inputs)
				{
					if (input.device == KEYBOARD)
						list.push(input.inputID);
				}
			case Gamepad(id):
				for (input in getActionFromControl(control).inputs)
				{
					if (input.deviceID == id)
						list.push(input.inputID);
				}
		}
		return list;
	}

	public function removeDevice(device:Device)
	{
		switch (device)
		{
			case Keys:
				setKeyboardScheme(None);
			case Gamepad(id):
				removeGamepad(id);
		}
	}

	static function isDevice(input:FlxActionInput, device:Device)
	{
		return switch device
		{
			case Keys: input.device == KEYBOARD;
			case Gamepad(id): isGamepad(input, id);
		}
	}

	inline static function isGamepad(input:FlxActionInput, deviceID:Int)
	{
		return input.device == GAMEPAD && (deviceID == FlxInputDeviceID.ALL || input.deviceID == deviceID);
	}
}