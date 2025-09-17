package psych.ui;

import flixel.FlxObject;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxDestroyUtil;

import lime.system.Clipboard;

import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

enum abstract AccentCode(Int) from Int from UInt to Int to UInt
{
	var NONE = -1;
	var GRAVE = 0;
	var ACUTE = 1;
	var CIRCUMFLEX = 2;
	var TILDE = 3;
}

enum abstract FilterMode(Int) from Int from UInt to Int to UInt
{
	var NO_FILTER:Int = 0;
	var ONLY_ALPHA:Int = 1;
	var ONLY_NUMERIC:Int = 2;
	var ONLY_ALPHANUMERIC:Int = 3;
	var ONLY_HEXADECIMAL:Int = 4;
	var CUSTOM_FILTER:Int = 5;
}

enum abstract CaseMode(Int) from Int from UInt to Int to UInt
{
	var ALL_CASES:Int = 0;
	var UPPER_CASE:Int = 1;
	var LOWER_CASE:Int = 2;
}

class PsychUIInputText extends FlxSpriteGroup
{
	public static final CHANGE_EVENT = "inputtext_change";

	static final KEY_TILDE = 126;
	static final KEY_ACUTE = 180;

	public static var focusOn(default, set):PsychUIInputText = null;
	
	private var _isHovered:Bool = false;

	private var _dragging:Bool = false;
	private var _dragStartIndex:Int = -1;
	
	//ZALUPA BLYAT
	var useSystemCursor:Bool = flixel.FlxG.mouse.useSystemCursor;
	
	private var _capsLockEnabled:Bool = false;
	private var _numLockEnabled:Bool = true;

	public var name:String;
	public var bg:FlxSprite;
	public var behindText:FlxSprite;
	public var selection:FlxSprite;
	public var textObj:FlxText;
	public var caret:FlxSprite;
	public var onChange:String->String->Void;

	public var fieldWidth(default, set):Int = 0;
	public var maxLength(default, set):Int = 0;
	public var passwordMask(default, set):Bool = false;
	public var text(default, set):String = null;
	
	public var forceCase(default, set):CaseMode = ALL_CASES;
	public var filterMode(default, set):FilterMode = NO_FILTER;
	public var customFilterPattern(default, set):EReg;

	public var selectedFormat:FlxTextFormat = new FlxTextFormat(FlxColor.WHITE);

	// Undo/Redo system
	private var _undoHistory:Array<String> = [];
	private var _redoHistory:Array<String> = [];
	private var _currentState:String = "";
	private var _ignoreHistory:Bool = false;

	public function new(x:Float = 0, y:Float = 0, wid:Int = 100, ?text:String = '', size:Int = 8)
	{
		super(x, y);
		this.bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		this.behindText = new FlxSprite(1, 1).makeGraphic(1, 1, FlxColor.WHITE);
		this.selection = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		this.textObj = new FlxText(1, 1, Math.max(1, wid - 2), '', size);
		this.caret = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);

		add(this.bg);
		add(this.behindText);
		add(this.selection);
		add(this.textObj);
		add(this.caret);

		this.textObj.color = FlxColor.BLACK;
		this.textObj.textField.selectable = false;
		this.textObj.textField.wordWrap = false;
		this.textObj.textField.multiline = false;
		this.selection.color = FlxColor.BLUE;

		@:bypassAccessor fieldWidth = wid;
		setGraphicSize(wid + 2, this.textObj.height + 2);
		updateHitbox();
		
		// Initialize undo/redo system
		_currentState = text;
		_undoHistory.push(_currentState);
		this.text = text;

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	}
	
	public var selectIndex:Int = -1;
	public var caretIndex(default, set):Int = -1;
	var _caretTime:Float = 0;

	var _nextAccent:AccentCode = NONE;
	public var inInsertMode:Bool = false;
	function onKeyDown(e:KeyboardEvent)
	{
		if(focusOn != this) return;

		var keyCode:Int = e.keyCode;
		var charCode:Int = e.charCode;
		var flxKey:FlxKey = cast keyCode;

		// NumLock
		if (flxKey == NUMLOCK)
		{
			_numLockEnabled = !_numLockEnabled;
			return;
		}

		if (flxKey == CAPSLOCK)
		{
			_capsLockEnabled = !_capsLockEnabled;
			return;
		}

		// Fix missing cedilla
		switch(keyCode)
		{
			case 231: //ç and Ç
				charCode = e.shiftKey ? 0xC7 : 0xE7;
		}

		if (_capsLockEnabled != e.shiftKey && charCode >= 97 && charCode <= 122) // a-z
		{
			charCode -= 32;
		}
		else if (_capsLockEnabled && e.shiftKey && charCode >= 65 && charCode <= 90) // A-Z
		{
			charCode += 32;
		}

		// Control key actions
		if(e.controlKey)
		{
			switch(flxKey)
			{
				case A: //select all text
					selectIndex = 0;
					caretIndex = text.length;
					updateCaret();

				case X, C: //cut/copy selected text to clipboard
					if(caretIndex >= 0 && selectIndex != 0 && caretIndex != selectIndex)
					{
						Clipboard.text = text.substring(caretIndex, selectIndex);
						if(flxKey == X)
							deleteSelection();
					}

				case V: //paste from clipboard
					if(Clipboard.text == null) return;

					if(selectIndex > -1 && selectIndex != caretIndex)
						deleteSelection();

					var lastText = text;
					text = text.substring(0, caretIndex) + Clipboard.text + text.substring(caretIndex);
					caretIndex += Clipboard.text.length;
					saveToHistory(lastText);
					if(onChange != null) onChange(lastText, text);
					if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);

				case Z: //undo
					if(e.shiftKey) 
						redo();
					else 
						undo();

				case Y: //redo
					redo();

				case BACKSPACE:
					if(selectIndex < 0 || selectIndex == caretIndex)
					{
						var lastText = text;
						var deletedText:String = text.substr(0, Std.int(Math.max(0, caretIndex-1)));
						var space:Int = deletedText.lastIndexOf(' ');
						if(space > -1 && space != caretIndex-1)
						{
							var start:String = deletedText.substring(0, space+1);
							var end:String = text.substring(caretIndex);
							caretIndex -= Std.int(Math.max(0, text.length - (start.length + end.length)));
							text = start + end;
						}
						else
						{
							text = text.substring(caretIndex);
							caretIndex = 0;
						}
						selectIndex = -1;
						saveToHistory(lastText);
						if(onChange != null) onChange(lastText, text);
						if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
					}
					else deleteSelection();

				case DELETE:
					if(selectIndex < 0 || selectIndex == caretIndex)
					{
						// This is| a test
						// This is test
						var deletedText:String = text.substring(caretIndex);
						var spc:Int = 0;
						var space:Int = deletedText.indexOf(' ');
						while(deletedText.substr(spc, 1) == ' ')
						{
							spc++;
							space = deletedText.substr(spc).indexOf(' ');
						}

						var lastText = text;
						if(space > -1)
						{
							text = text.substr(0, caretIndex) + text.substring(caretIndex + space + spc);
						}
						else text = text.substr(0, caretIndex);
						saveToHistory(lastText);
						if(onChange != null) onChange(lastText, text);
						if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
					}
					else deleteSelection();

				case LEFT:
					if(caretIndex > 0)
					{
						do
						{
							caretIndex--;
							var a:String = text.substr(caretIndex-1, 1);
							var b:String = text.substr(caretIndex, 1);
							//trace(a, b);
							if(a == ' ' && b != ' ') break;
						}
						while(caretIndex > 0);
					}

				case RIGHT:
					if(caretIndex < text.length)
					{
						do
						{
							caretIndex++;
							var a:String = text.substr(caretIndex-1, 1);
							var b:String = text.substr(caretIndex, 1);
							//trace(a, b);
							if(a != ' ' && b == ' ') break;
						}
						while(caretIndex < text.length);
					}

				default:
			}
			updateCaret();
			return;
		}

		static final ignored:Array<FlxKey> = [SHIFT, CONTROL, ESCAPE];
		if(ignored.contains(flxKey)) return;

		var lastAccent = _nextAccent;
		switch(keyCode)
		{
			case KEY_TILDE:
				_nextAccent = !e.shiftKey ? TILDE : CIRCUMFLEX;
				if(lastAccent == NONE) return;
			case KEY_ACUTE:
				_nextAccent = !e.shiftKey ? ACUTE : GRAVE;
				if(lastAccent == NONE) return;
			case Keyboard.NUMPAD_DIVIDE:
				_typeLetter(47); // /
				_nextAccent = NONE;
				updateCaret();
				return;
			default:
				lastAccent = NONE;
		}

		//trace(keyCode, charCode, flxKey);
		switch(flxKey)
		{
			case LEFT: //move caret to left
				if(!FlxG.keys.pressed.SHIFT) selectIndex = -1;
				else if(selectIndex == -1) selectIndex = caretIndex;
				caretIndex = Std.int(Math.max(0, caretIndex - 1));

			case RIGHT: //move caret to right
				if(!FlxG.keys.pressed.SHIFT) selectIndex = -1;
				else if(selectIndex == -1) selectIndex = caretIndex;
				caretIndex = Std.int(Math.min(text.length, caretIndex + 1));

			case HOME: //move caret to the begin
				if(!FlxG.keys.pressed.SHIFT) selectIndex = -1;
				else if(selectIndex == -1) selectIndex = caretIndex;
				caretIndex = 0;

			case END: //move caret to the end
				if(!FlxG.keys.pressed.SHIFT) selectIndex = -1;
				else if(selectIndex == -1) selectIndex = caretIndex;
				caretIndex = text.length;

			case INSERT: //change to insert mode
				inInsertMode = !inInsertMode;

			case BACKSPACE: //Delete letter to the left of caret
				if(caretIndex <= 0) return;

				if(selectIndex > -1 && selectIndex != caretIndex)
					deleteSelection();
				else
				{
					var lastText = text;
					text = text.substring(0, caretIndex-1) + text.substring(caretIndex);
					caretIndex--;
					saveToHistory(lastText);
					if(onChange != null) onChange(lastText, text);
					if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
				}
				_nextAccent = NONE;

			case DELETE: //Delete letter to the right of caret
				if(selectIndex > -1 && selectIndex != caretIndex)
				{
					deleteSelection();
					updateCaret();
					return;
				}

				if(caretIndex >= text.length) return;

				var lastText = text;
				if(caretIndex < 1)
					text = text.substr(1);
				else
					text = text.substring(0, caretIndex) + text.substring(caretIndex+1);

				if(caretIndex >= text.length) caretIndex = text.length;
				
				saveToHistory(lastText);
				if(onChange != null) onChange(lastText, text);
				if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
			
			case SPACE: //space or last accent pressed
				if(_nextAccent != NONE) _typeLetter(getAccentCharCode(_nextAccent));
				else _typeLetter(charCode);
				_nextAccent = NONE;

			case A, O: //these support all accents
				var grave:Int = 0x0;
				var capital:Int = 0x0;
				switch(flxKey)
				{
					case A:
						grave = 0xC0;
						capital = 0x41;
					case O:
						grave = 0xD2;
						capital = 0x4f;
					default:
				}
				if(_nextAccent != NONE)
					charCode += grave - capital + _nextAccent;

				_typeLetter(charCode);
				_nextAccent = NONE;

			case E, I, U: //these support grave, acute and circumflex
				var grave:Int = 0x0;
				var capital:Int = 0x0;
				switch(flxKey)
				{
					case E:
						grave = 0xC8;
						capital = 0x45;
					case I:
						grave = 0xCC;
						capital = 0x49;
					case U:
						grave = 0xD9;
						capital = 0x55;
					default:
				}
				if(_nextAccent == GRAVE || _nextAccent == ACUTE || _nextAccent == CIRCUMFLEX) //Supported accents
					charCode += grave - capital + _nextAccent;
				else if(_nextAccent == TILDE) //Unsupported accent
					_typeLetter(getAccentCharCode(_nextAccent));

				_typeLetter(charCode);
				_nextAccent = NONE;

			case N: //it only supports tilde
				if(_nextAccent == TILDE)
					charCode += 0xD1 - 0x4E;
				else
					_typeLetter(getAccentCharCode(_nextAccent));

				_typeLetter(charCode);
				_nextAccent = NONE;

			case ESCAPE:
				focusOn = null;

			case ENTER:
				onPressEnter(e);

			case LBRACKET:
				if(e.shiftKey) _typeLetter(123); // {
				else _typeLetter(91); // [
				_nextAccent = NONE;
				updateCaret();
				return;
				
			case RBRACKET:
				if(e.shiftKey) _typeLetter(125); // }
				else _typeLetter(93); // ]
				_nextAccent = NONE;
				updateCaret();
				return;

			//numpad
			case NUMPADZERO:
				if(_numLockEnabled) _typeLetter(48); // 0
			case NUMPADONE:
				if(_numLockEnabled) _typeLetter(49); // 1
			case NUMPADTWO:
				if(_numLockEnabled) _typeLetter(50); // 2
			case NUMPADTHREE:
				if(_numLockEnabled) _typeLetter(51); // 3
			case NUMPADFOUR:
				if(_numLockEnabled) _typeLetter(52); // 4
			case NUMPADFIVE:
				if(_numLockEnabled) _typeLetter(53); // 5
			case NUMPADSIX:
				if(_numLockEnabled) _typeLetter(54); // 6
			case NUMPADSEVEN:
				if(_numLockEnabled) _typeLetter(55); // 7
			case NUMPADEIGHT:
				if(_numLockEnabled) _typeLetter(56); // 8
			case NUMPADNINE:
				if(_numLockEnabled) _typeLetter(57); // 9

			case NUMPADMINUS:
				_typeLetter(45); // -
				_nextAccent = NONE;
				updateCaret();
				return;

			default:
				if(charCode < 1)
					if((charCode = getAccentCharCode(_nextAccent)) < 1)
						return;

				if(lastAccent != NONE) _typeLetter(getAccentCharCode(lastAccent));
				else if(_nextAccent != NONE) _typeLetter(getAccentCharCode(_nextAccent));
				_typeLetter(charCode);
				_nextAccent = NONE;
		}
		updateCaret();
	}

	// Undo/Redo functionality
	private function saveToHistory(lastText:String):Void
	{
		if (_ignoreHistory) return;
		
		_undoHistory.push(lastText);
		_currentState = text;
		
		// Limit history size to prevent memory issues
		if (_undoHistory.length > 100)
		{
			_undoHistory.shift();
		}
		
		// Clear redo history when new changes are made
		_redoHistory = [];
	}

	private function undo():Void
	{
		if (_undoHistory.length == 0) return;
		
		_ignoreHistory = true;
		var lastState = _undoHistory.pop();
		_redoHistory.push(text);
		text = lastState;
		_currentState = lastState;
		caretIndex = text.length;
		selectIndex = -1;
		_ignoreHistory = false;
		
		if(onChange != null) onChange(text, text);
		if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}

	private function redo():Void
	{
		if (_redoHistory.length == 0) return;
		
		_ignoreHistory = true;
		var nextState = _redoHistory.pop();
		_undoHistory.push(text);
		text = nextState;
		_currentState = nextState;
		caretIndex = text.length;
		selectIndex = -1;
		_ignoreHistory = false;
		
		if(onChange != null) onChange(text, text);
		if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}

	public dynamic function onPressEnter(e:KeyboardEvent)
		focusOn = null;

	public var unfocus:Void->Void;
	public static function set_focusOn(v:PsychUIInputText)
	{
		if(focusOn != null && focusOn != v && focusOn.exists)
		{
			if(focusOn.unfocus != null) focusOn.unfocus();
			focusOn.resetCaret();
			
			if (focusOn.useSystemCursor && focusOn._isHovered)
				Mouse.cursor = MouseCursor.AUTO;
		}
		
		if (v != null && v.useSystemCursor)
			Mouse.cursor = MouseCursor.IBEAM;
			
		return (focusOn = v);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var isOver = FlxG.mouse.overlaps(behindText, camera);
		
		if (isOver && !_isHovered)
		{
			if (useSystemCursor && focusOn != this) 
				Mouse.cursor = MouseCursor.IBEAM;
			_isHovered = true;
		}
		else if (!isOver && _isHovered)
		{
			if (useSystemCursor && focusOn != this) 
				Mouse.cursor = MouseCursor.AUTO;
			_isHovered = false;
		}

		if(FlxG.mouse.justPressed)
		{
			if(FlxG.mouse.overlaps(behindText, camera))
			{
				focusOn = this;
				#if (flixel < "5.9.0")
				var mousePos = FlxG.mouse.getScreenPosition(camera);
				#else
				var mousePos = FlxG.mouse.getViewPosition(camera);
				#end
				caretIndex = getCaretIndexAtPoint(mousePos.x);
				_dragStartIndex = caretIndex;
				selectIndex = -1;
				_dragging = true;
				updateCaret();
			}
			else if(focusOn == this)
				focusOn = null;
		}

		if (_dragging && FlxG.mouse.pressed && focusOn == this)
		{
			#if (flixel < "5.9.0")
			var mousePos = FlxG.mouse.getScreenPosition(camera);
			#else
			var mousePos = FlxG.mouse.getViewPosition(camera);
			#end
			var newCaretIndex = getCaretIndexAtPoint(mousePos.x);
			if(newCaretIndex != caretIndex)
			{
				caretIndex = newCaretIndex;
				if(selectIndex == -1) selectIndex = _dragStartIndex;
				updateCaret();
			}
		}

		if(FlxG.mouse.justReleased)
		{
			_dragging = false;
			_dragStartIndex = -1;
		}

		if(focusOn == this)
		{
			_caretTime = (_caretTime + elapsed) % 1;
			if(textObj != null && textObj.exists)
			{
				var drewSelection:Bool = false;
				if(selection != null && selection.exists)
				{
					if(selectIndex != -1 && selectIndex != caretIndex)
					{
						selection.visible = true;
						drewSelection = true;
					}
					else selection.visible = false;
				}
		
				if(caret != null && caret.exists)
				{
					if(!drewSelection && _caretTime < 0.5 && caret.x >= textObj.x)
					{
						caret.visible = true;
						caret.color = textObj.color;
					}
					else caret.visible = false;
				}
			}
		}
		else
		{
			_caretTime = 0;
			inInsertMode = false;
			if(selection != null && selection.exists) selection.visible = false;
			if(caret != null && caret.exists) caret.visible = false;
		}
	}

	function getCaretIndexAtPoint(mouseX:Float):Int
	{
		var textObjX:Float = textObj.getScreenPosition(camera).x;
		var localX:Float = mouseX - textObjX + textObj.textField.scrollH;
		
		var index:Int = textObj.textField.getCharIndexAtPoint(localX, textObj.textField.textHeight / 2);
		if (index < 0) {
			return (localX < 0) ? 0 : text.length;
		}
		
		var charBounds = textObj.textField.getCharBoundaries(index);
		if (charBounds == null) return index;
		
		if (localX < charBounds.left + charBounds.width / 2)
			return index;
		else
			return index + 1;
	}

	override public function destroy()
	{
		if (_isHovered && useSystemCursor)
			Mouse.cursor = MouseCursor.AUTO;
		
		_boundaries = null;
		if(focusOn == this) focusOn = null;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		super.destroy();
	}

	inline public function resetCaret()
	{
		selectIndex = -1;
		caretIndex = 0;
		updateCaret();
	}

	inline public function updateCaret()
	{
		if(textObj == null || !textObj.exists) return;

		var textField = textObj.textField;
		_caretTime = 0;
		
		if(caret != null && caret.exists)
		{
			caret.y = textObj.y + 2;
			caret.x = textObj.x + 1 - textField.scrollH;
			
			if(caretIndex > 0 && _boundaries.length > 0)
			{
				var boundaryIndex = Std.int(Math.min(_boundaries.length - 1, caretIndex - 1));
				caret.x += _boundaries[boundaryIndex];
			}
			caret.visible = (_caretTime < 0.5);
		}
		
		if(selection != null && selection.exists)
		{
			if(selectIndex != -1 && selectIndex != caretIndex)
			{
				selection.visible = true;
				selection.y = textObj.y + 2;
				
				var startX = textObj.x + 1 - textField.scrollH;
				if(selectIndex > 0 && _boundaries.length > 0)
				{
					var selectBoundaryIndex = Std.int(Math.min(_boundaries.length - 1, selectIndex - 1));
					startX += _boundaries[selectBoundaryIndex];
				}
				
				var endX = textObj.x + 1 - textField.scrollH;
				if(caretIndex > 0 && _boundaries.length > 0)
				{
					var caretBoundaryIndex = Std.int(Math.min(_boundaries.length - 1, caretIndex - 1));
					endX += _boundaries[caretBoundaryIndex];
				}
				
				selection.x = Math.min(startX, endX);
				selection.scale.x = Math.abs(endX - startX);
				selection.scale.y = textField.textHeight;
				selection.updateHitbox();
				
				textObj.removeFormat(selectedFormat);
				var start = Math.min(selectIndex, caretIndex);
				var end = Math.max(selectIndex, caretIndex);
				textObj.addFormat(selectedFormat, Std.int(start), Std.int(end));
			}
			else
			{
				selection.visible = false;
				textObj.removeFormat(selectedFormat);
			}
		}
	}

	inline function deleteSelection()
	{
		var lastText:String = text;
		if(selectIndex > caretIndex)
		{
			text = text.substring(0, caretIndex) + text.substring(selectIndex);
		}
		else
		{
			text = text.substring(0, selectIndex) + text.substring(caretIndex);
			caretIndex = selectIndex;
		}
		selectIndex = -1;
		saveToHistory(lastText);
		if(onChange != null) onChange(lastText, text);
		if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}

	function set_caretIndex(v:Int)
	{
		caretIndex = v;
		updateCaret();
		return v;
	}

	override public function setGraphicSize(width:Float = 0, height:Float = 0)
	{
		super.setGraphicSize(width, height);
		bg.setGraphicSize(width, height);
		behindText.setGraphicSize(width - 2, height - 2);
		if(textObj != null && textObj.exists)
		{
			textObj.scale.x = 1;
			textObj.scale.y = 1;
			if(caret != null && caret.exists) caret.setGraphicSize(1, textObj.height - 4);
		}
	}
	
	override public function updateHitbox()
	{
		super.updateHitbox();
		bg.updateHitbox();
		behindText.updateHitbox();
		if(textObj != null && textObj.exists)
		{
			textObj.updateHitbox();
			if(caret != null && caret.exists) caret.updateHitbox();
		}
	}

	function set_fieldWidth(v:Int)
	{
		textObj.fieldWidth = Math.max(1, v - 2);
		textObj.textField.selectable = false;
		textObj.textField.wordWrap = false;
		textObj.textField.multiline = false;
		return (fieldWidth = v);
	}

	function set_maxLength(v:Int)
	{
		var lastText = text;
		v = Std.int(Math.max(0, v));
		if(v > 0 && text.length > v) text = text.substr(0, v);
		saveToHistory(lastText);
		if(onChange != null) onChange(lastText, text);
		if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
		return (maxLength = v);
	}

	function set_passwordMask(v:Bool)
	{
		passwordMask = v;
		text = text;
		return passwordMask;
	}

	var _boundaries:Array<Float> = [];
	function set_text(v:String)
	{
		for (i in 0..._boundaries.length) _boundaries.pop();
		v = filter(v);

		textObj.text = '';
		if(v != null && v.length > 0)
		{
			if(v.length > 1)
				for (i in 0...v.length)
				{
					var toPrint:String = v.substr(i, 1);
					if(toPrint == '\n') toPrint = ' ';
					textObj.textField.appendText(!passwordMask ? toPrint : '*');
					_boundaries.push(textObj.textField.textWidth);
				}
			else
			{
				textObj.text = !passwordMask ? v : '*';
				_boundaries.push(textObj.textField.textWidth);
			}
		}
		text = v;
		updateCaret();
		return v;
	}

	inline public static function getAccentCharCode(accent:AccentCode)
	{
		switch(accent)
		{
			case TILDE:
				return 0x7E;
			case CIRCUMFLEX:
				return 0x5E;
			case ACUTE:
				return 0xB4;
			case GRAVE:
				return 0x60;
			default:
				return 0x0;
		}
	}

	public var broadcastInputTextEvent:Bool = true;
	function _typeLetter(charCode:Int)
	{
		if(charCode < 1) return;
		
		if(selectIndex > -1 && selectIndex != caretIndex)
			deleteSelection();

		var letter:String = String.fromCharCode(charCode);
		letter = filter(letter);
		if(letter.length > 0 && (maxLength == 0 || (text.length + letter.length) <= maxLength))
		{
			var lastText = text;
			//trace('Drawing character: $letter');
			if(!inInsertMode)
				text = text.substring(0, caretIndex) + letter + text.substring(caretIndex);
			else
				text = text.substring(0, caretIndex) + letter + text.substring(caretIndex+1);

			caretIndex += letter.length;
			saveToHistory(lastText);
			if(onChange != null) onChange(lastText, text);
			if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
		}
		_caretTime = 0;
	}

	// from FlxInputText
	function set_forceCase(v:CaseMode)
	{
		forceCase = v;
		text = filter(text);
		return forceCase;
	}

	function set_filterMode(v:FilterMode)
	{
		filterMode = v;
		text = filter(text);
		return filterMode;
	}

	function set_customFilterPattern(cfp:EReg)
	{
		customFilterPattern = cfp;
		filterMode = CUSTOM_FILTER;
		return customFilterPattern;
	}
	
	private function filter(text:String):String
	{
		switch(forceCase)
		{
			case UPPER_CASE:
				text = text.toUpperCase();
			case LOWER_CASE:
				text = text.toLowerCase();
			default:
		}
		if (forceCase == UPPER_CASE)
			text = text.toUpperCase();
		else if (forceCase == LOWER_CASE)
			text = text.toLowerCase();

		if (filterMode != NO_FILTER)
		{
			var pattern:EReg;
			switch (filterMode)
			{
				case ONLY_ALPHA:
					pattern = ~/[^a-zA-Z]*/g;
				case ONLY_NUMERIC:
					pattern = ~/[^0-9]*/g;
				case ONLY_ALPHANUMERIC:
					pattern = ~/[^a-zA-Z0-9]*/g;
				case ONLY_HEXADECIMAL:
					pattern = ~/[^a-fA-F0-9]*/g;
				case CUSTOM_FILTER:
					pattern = customFilterPattern;
				default:
					throw new openfl.errors.Error("PsychUIInputText: Unknown filterMode (" + filterMode + ")");
			}
			text = pattern.replace(text, "");
		}
		return text;
	}
}