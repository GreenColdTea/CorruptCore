package game.backend.plugins;

import flixel.FlxG;
import flixel.FlxBasic;

import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
import openfl.events.TextEvent;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.ui.Keyboard;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;

#if HSCRIPT_ALLOWED
import game.scripting.FunkinHScript;
#end

using StringTools;

class DebugConsolePlugin extends FlxBasic
{
	public static var instance:Null<DebugConsolePlugin> = null;

	var console:Sprite;
	var titleBar:Sprite;
	var outputText:TextField;
	var inputText:TextField;
	var hiddenInputField:TextField;

	var consoleVisible:Bool = false;
	var consoleWidth:Int = 700;
	var consoleHeight:Int = 400;

	var commandHistory:Array<String> = [];
	var historyIndex:Int = 0;
	var currentInput:String = "";
	var prompt:String = "> ";
	var cursorPosition:Int = 0;

	var cursorVisible:Bool = true;
	var cursorTimer:Float = 0;
	var cursorBlinkRate:Float = 0.5;

    var wasMouseVisible:Bool = true;

	var isDragging:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;

	var autoScrollToBottom:Bool = true;

	var maxHistorySize:Int = 100;
	var maxOutputLines:Int = 500;
	var outputLines:Array<String> = [];

	var originalTrace:Dynamic;

	#if HSCRIPT_ALLOWED
	var hscript:FunkinHScript;
	#end

	var hscriptMode:Bool = false;

	public static function init():Void
	{
		if (instance == null)
			FlxG.plugins.addPlugin(instance = new DebugConsolePlugin());
	}

	public function new()
	{
		super();

		this.visible = false;

		initializeHScript();
		createConsole();
		hijackTrace();
		loadConsolePosition();
		updateDisplay();
	}

	function initializeHScript():Void
	{
		#if HSCRIPT_ALLOWED
		hscript = new FunkinHScript("", FlxG.state, true);
		hscript.scriptName = "Debug Console[HS]";

		hscript.set("console", this);
		hscript.set("print", (v:Dynamic) -> addOutput(Std.string(v), 0xFFFFFF));
		hscript.set("clearConsole", clearOutput);
		hscript.set("copySelectedText", copySelectedText);
		hscript.set("copyAllText", copyAllOutputText);
		#end
	}

	function createConsole():Void
	{
		console = new Sprite();

		console.graphics.beginFill(0x0D0D0D, 0.95);
		console.graphics.drawRoundRect(0, 0, consoleWidth, consoleHeight, 10, 10);
		console.graphics.endFill();

		console.graphics.lineStyle(2, 0x444444, 0.8);
		console.graphics.drawRoundRect(0, 0, consoleWidth, consoleHeight, 10, 10);

		titleBar = new Sprite();
		titleBar.graphics.beginFill(0x333333, 0.8);
		titleBar.graphics.drawRoundRect(0, 0, consoleWidth, 25, 10, 10);
		titleBar.graphics.endFill();

		var titleText = new TextField();
		titleText.x = 10;
		titleText.y = 5;
		titleText.width = consoleWidth - 20;
		titleText.height = 20;
		titleText.defaultTextFormat = new TextFormat("Consolas", 12, 0xE0E0E0);
		titleText.text = "Debug Console (Drag to move | Ctrl+C to copy)";
		titleText.selectable = false;
		titleText.mouseEnabled = false;
		titleBar.addChild(titleText);

		console.addChild(titleBar);

		console.x = (FlxG.stage.stageWidth - consoleWidth) / 2;
		console.y = 20;

		outputText = new TextField();
		outputText.x = 12;
		outputText.y = 30;
		outputText.width = consoleWidth - 24;
		outputText.height = consoleHeight - 80;
		outputText.multiline = true;
		outputText.wordWrap = true;
		outputText.defaultTextFormat = new TextFormat("Consolas", 14, 0xE0E0E0);
		outputText.background = false;
		outputText.border = false;
		outputText.type = TextFieldType.DYNAMIC;
		outputText.selectable = true;
		outputText.mouseEnabled = true;
		outputText.tabEnabled = false;

		outputText.addEventListener(Event.SCROLL, onOutputScroll);
		outputText.addEventListener(MouseEvent.MOUSE_DOWN, onOutputMouseDown);
		outputText.addEventListener(MouseEvent.MOUSE_UP, onOutputMouseUp);

		inputText = new TextField();
		inputText.x = 12;
		inputText.y = consoleHeight - 45;
		inputText.width = consoleWidth - 24;
		inputText.height = 24;
		inputText.multiline = false;
		inputText.wordWrap = false;
		inputText.defaultTextFormat = new TextFormat("Consolas", 14, 0xE0E0E0);
		inputText.background = false;
		inputText.border = false;
		inputText.type = TextFieldType.DYNAMIC;
		inputText.selectable = false;
		inputText.mouseEnabled = false;
		inputText.tabEnabled = false;
		inputText.text = prompt;

		console.addChild(outputText);
		console.addChild(inputText);

		console.visible = false;
		console.tabEnabled = true;
		console.focusRect = false;

		hiddenInputField = new TextField();
		hiddenInputField.type = TextFieldType.INPUT;
		hiddenInputField.width = 1;
		hiddenInputField.height = 1;
		hiddenInputField.x = -1000;
		hiddenInputField.y = -1000;
		hiddenInputField.visible = false;

		FlxG.stage.addChild(hiddenInputField);
		FlxG.stage.addChild(console);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		FlxG.stage.addEventListener(TextEvent.TEXT_INPUT, onTextInput);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);

		console.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
		console.addEventListener(MouseEvent.MOUSE_DOWN, onConsoleMouseDown);

		titleBar.addEventListener(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);

		clearOutput();
	}

	function clearOutput():Void
	{
		outputLines = [];
		addOutput("Debug Console (F12 to toggle)", 0xE0E0E0);
		addOutput("Drag title bar to move | Shift+Enter for new line | Ctrl+C to copy selected text", 0xAAAAAA);
	}

	function onOutputScroll(event:Event):Void
	{
		autoScrollToBottom = outputText.scrollV >= outputText.maxScrollV - 1;
	}

	function onOutputMouseDown(event:MouseEvent):Void
	{
		if (!consoleVisible) return;

		FlxG.stage.focus = outputText;
		event.stopPropagation();
	}

	function onOutputMouseUp(event:MouseEvent):Void
	{
		if (!consoleVisible) return;

		event.stopPropagation();
	}

	function onConsoleMouseDown(event:MouseEvent):Void
	{
		if (!consoleVisible) return;

		if (event.target != outputText && event.target != titleBar)
			focusInput();
	}

	function onTitleBarMouseDown(event:MouseEvent):Void
	{
		if (!consoleVisible) return;

		isDragging = true;
		dragOffsetX = event.stageX - console.x;
		dragOffsetY = event.stageY - console.y;

		focusInput();
		event.stopPropagation();
	}

	function onStageMouseUp(event:MouseEvent):Void
	{
		if (isDragging)
		{
			isDragging = false;
			saveConsolePosition();
		}
	}

	function onStageMouseMove(event:MouseEvent):Void
	{
		if (!isDragging || !consoleVisible) return;

		console.x = event.stageX - dragOffsetX;
		console.y = event.stageY - dragOffsetY;

		clampConsoleToStage();
	}

	function clampConsoleToStage():Void
	{
		var stageWidth = FlxG.stage.stageWidth;
		var stageHeight = FlxG.stage.stageHeight;

		if (console.x < 0) console.x = 0;
		if (console.y < 0) console.y = 0;
		if (console.x + consoleWidth > stageWidth) console.x = stageWidth - consoleWidth;
		if (console.y + consoleHeight > stageHeight) console.y = stageHeight - consoleHeight;
	}

	function saveConsolePosition():Void
	{
		if (FlxG.save.data == null) return;

		FlxG.save.data.consoleX = console.x;
		FlxG.save.data.consoleY = console.y;
		FlxG.save.flush();
	}

	function loadConsolePosition():Void
	{
		if (FlxG.save.data == null) return;

		if (FlxG.save.data.consoleX != null)
			console.x = FlxG.save.data.consoleX;

		if (FlxG.save.data.consoleY != null)
			console.y = FlxG.save.data.consoleY;

		clampConsoleToStage();
	}

	function onMouseWheel(event:MouseEvent):Void
	{
		if (!consoleVisible) return;

		outputText.scrollV += event.delta > 0 ? -3 : 3;

		if (outputText.scrollV < 1)
			outputText.scrollV = 1;

		if (outputText.scrollV > outputText.maxScrollV)
			outputText.scrollV = outputText.maxScrollV;

		event.stopPropagation();
	}

	function hijackTrace():Void
	{
		if (originalTrace != null) return;

		originalTrace = haxe.Log.trace;

		haxe.Log.trace = (v:Dynamic, ?infos:haxe.PosInfos) -> {
			addOutput('TRACE: ${Std.string(v)}', 0x8888FF);

			if (originalTrace != null)
				originalTrace(v, infos);
		};
	}

	function restoreTrace():Void
	{
		if (originalTrace != null)
		{
			haxe.Log.trace = originalTrace;
			originalTrace = null;
		}
	}

	function onKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode == Keyboard.F12)
		{
			if (consoleVisible)
				hideConsole();
			else
				showConsole();

			event.preventDefault();
			event.stopImmediatePropagation();
			return;
		}

		if (!consoleVisible)
			return;

		switch (event.keyCode)
		{
			case Keyboard.ENTER:
				if (event.shiftKey)
				{
					insertTextAtCursor("\n");
				}
				else
				{
					if (currentInput.trim() != "")
						executeCommand();
				}
				blockEvent(event);

			case Keyboard.BACKSPACE:
				if (cursorPosition > 0)
				{
					currentInput = currentInput.substring(0, cursorPosition - 1) + currentInput.substring(cursorPosition);
					cursorPosition--;
					updateDisplay();
					resetCursor();
				}
				blockEvent(event);

			case Keyboard.DELETE:
				if (cursorPosition < currentInput.length)
				{
					currentInput = currentInput.substring(0, cursorPosition) + currentInput.substring(cursorPosition + 1);
					updateDisplay();
					resetCursor();
				}
				blockEvent(event);

			case Keyboard.LEFT:
				if (cursorPosition > 0)
				{
					cursorPosition--;
					updateDisplay();
					resetCursor();
				}
				blockEvent(event);

			case Keyboard.RIGHT:
				if (cursorPosition < currentInput.length)
				{
					cursorPosition++;
					updateDisplay();
					resetCursor();
				}
				blockEvent(event);

			case Keyboard.UP:
				navigateHistory(-1);
				blockEvent(event);

			case Keyboard.DOWN:
				navigateHistory(1);
				blockEvent(event);

			case Keyboard.HOME:
				cursorPosition = 0;
				updateDisplay();
				resetCursor();
				blockEvent(event);

			case Keyboard.END:
				cursorPosition = currentInput.length;
				updateDisplay();
				resetCursor();
				blockEvent(event);

			case Keyboard.TAB:
				autoComplete();
				blockEvent(event);

			case Keyboard.ESCAPE:
				hideConsole();
				blockEvent(event);

			case Keyboard.F10:
				hscriptMode = !hscriptMode;
				addOutput("HScript mode: " + (hscriptMode ? "ON" : "OFF"), hscriptMode ? 0x88FF88 : 0xFF8888);
				updateDisplay();
				blockEvent(event);

			case Keyboard.V:
				if (event.ctrlKey || event.commandKey)
				{
					pasteFromClipboard();
					blockEvent(event);
				}

			case Keyboard.C:
				if (event.ctrlKey || event.commandKey)
				{
					if (FlxG.stage.focus == outputText && outputText.selectionBeginIndex != outputText.selectionEndIndex)
						copySelectedText();
					else if (event.shiftKey)
						copyAllOutputText();
					else
						copyCurrentInput();

					blockEvent(event);
				}

			case Keyboard.A:
				if (event.ctrlKey || event.commandKey)
				{
					if (FlxG.stage.focus == outputText)
						outputText.setSelection(0, outputText.length);
					else
					{
						cursorPosition = currentInput.length;
						updateDisplay();
					}

					blockEvent(event);
				}

			default:
		}
	}

	inline function blockEvent(event:KeyboardEvent):Void
	{
		event.preventDefault();
		event.stopImmediatePropagation();
	}

	function onTextInput(event:TextEvent):Void
	{
		if (!consoleVisible) return;
		if (FlxG.stage.focus == outputText) return;

		var text = event.text;

		if (text == null || text.length == 0)
			return;

		if (text == "\n" || text == "\r")
		{
			event.preventDefault();
			return;
		}

		insertTextAtCursor(text);
		event.preventDefault();
		event.stopImmediatePropagation();
	}

	function focusInput():Void
	{
		if (FlxG.stage.focus != hiddenInputField)
			FlxG.stage.focus = hiddenInputField;
	}

	function resetCursor():Void
	{
		cursorVisible = true;
		cursorTimer = 0;
	}

	function insertTextAtCursor(text:String):Void
	{
		currentInput = currentInput.substring(0, cursorPosition) + text + currentInput.substring(cursorPosition);
		cursorPosition += text.length;

		updateDisplay();
		resetCursor();
	}

	function pasteFromClipboard():Void
	{
		try
		{
			#if (sys || desktop)
			var clipboardText = Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT);

			if (clipboardText != null)
				insertTextAtCursor(Std.string(clipboardText));
			#else
			addOutput("Clipboard access not available on this platform", 0xFFFF88);
			#end
		}
		catch (e:Dynamic)
		{
			addOutput('Clipboard error: $e', 0xFF8888);
		}
	}

	function copySelectedText():Void
	{
		try
		{
			if (outputText.selectionBeginIndex == outputText.selectionEndIndex)
			{
				addOutput("No text selected", 0xFFFF88);
				return;
			}

			var selectedText = outputText.text.substring(outputText.selectionBeginIndex, outputText.selectionEndIndex);

			#if (sys || desktop)
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, selectedText);
			#end

			addOutput('Copied ${selectedText.length} characters to clipboard', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('Failed to copy: $e', 0xFF8888);
		}
	}

	function copyAllOutputText():Void
	{
		try
		{
			var text = outputText.text;

			#if (sys || desktop)
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, text);
			#end

			addOutput('Copied all ${text.length} characters to clipboard', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('Failed to copy all text: $e', 0xFF8888);
		}
	}

	function copyCurrentInput():Void
	{
		try
		{
			#if (sys || desktop)
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, currentInput);
			#end

			addOutput('Copied input to clipboard', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('Failed to copy input: $e', 0xFF8888);
		}
	}

	function navigateHistory(direction:Int):Void
	{
		if (commandHistory.length == 0) return;

		historyIndex += direction;

		if (historyIndex < 0)
			historyIndex = 0;

		if (historyIndex > commandHistory.length)
			historyIndex = commandHistory.length;

		if (historyIndex == commandHistory.length)
			currentInput = "";
		else
			currentInput = commandHistory[historyIndex];

		cursorPosition = currentInput.length;
		updateDisplay();
		resetCursor();
	}

	function autoComplete():Void
	{
		if (currentInput.trim() == "") return;

		var suggestions = getAutoCompleteSuggestions(currentInput);

		if (suggestions.length == 1)
		{
			currentInput = suggestions[0];
			cursorPosition = currentInput.length;
			updateDisplay();
		}
		else if (suggestions.length > 1)
		{
			addOutput("Suggestions: " + suggestions.join(", "), 0xFFFF88);
		}
	}

	function getAutoCompleteSuggestions(input:String):Array<String>
	{
		var suggestions:Array<String> = [];
		var commands = ["help", "clear", "objects", "fields", "call", "set", "new", "cursor", "hscript", "memory", "copy"];

		for (cmd in commands)
		{
			if (cmd.toLowerCase().startsWith(input.toLowerCase()))
				suggestions.push(cmd);
		}

		return suggestions;
	}

	function updateDisplay():Void
	{
		var modePrefix = hscriptMode ? "[HS] " : "";
		var before = modePrefix + prompt + currentInput.substring(0, cursorPosition);
		var after = currentInput.substring(cursorPosition);
		var cursor = cursorVisible ? "▌" : " ";

		inputText.text = before + cursor + after;
	}

    function blockGameInput():Void
    {
        FlxG.keys.reset();
        FlxG.mouse.reset();

        #if FLX_GAMEPAD
        if (FlxG.gamepads != null)
        {
            for (gamepad in FlxG.gamepads.getActiveGamepads())
                gamepad.reset();
        }
        #end
    }

	function addOutput(message:String, color:Int = 0xE0E0E0):Void
	{
		if (outputText == null) return;

		var colorHex = StringTools.hex(color, 6);
		var safe = StringTools.htmlEscape(message);
		outputLines.push('<font color="#$colorHex">$safe</font>');

		while (outputLines.length > maxOutputLines)
			outputLines.shift();

		var oldScroll = outputText.scrollV;
		outputText.htmlText = outputLines.join("\n");

		if (autoScrollToBottom)
			outputText.scrollV = outputText.maxScrollV;
		else
			outputText.scrollV = oldScroll;
	}

	function executeCommand():Void
	{
		var command = currentInput.trim();

		if (command == "")
			return;

		commandHistory.push(command);

		while (commandHistory.length > maxHistorySize)
			commandHistory.shift();

		historyIndex = commandHistory.length;

		addOutput((hscriptMode ? "[HS] " : "") + prompt + command, 0x88FF88);

		currentInput = "";
		cursorPosition = 0;

		try
		{
			if (hscriptMode)
				executeHScript(command);
			else
				processCommand(command);
		}
		catch (e:Dynamic)
		{
			addOutput('Error: $e', 0xFF8888);
		}

		updateDisplay();
	}

	function executeHScript(code:String):Void
	{
		#if HSCRIPT_ALLOWED
		try
		{
			var result = hscript.executeString(code);

			if (result != null)
				addOutput("Result: " + Std.string(result), 0x88FFFF);
		}
		catch (e:Dynamic)
		{
			addOutput('HScript Error: $e', 0xFF8888);
		}
		#else
		addOutput("HScript is not enabled.", 0xFF8888);
		#end
	}

	function processCommand(command:String):Void
	{
		var args = command.split(" ").filter(arg -> arg != "");
		if (args.length == 0) return;

		var cmd = args[0].toLowerCase();

		switch (cmd)
		{
			case "help":
				showHelp();

			case "clear", "cls":
				clearOutput();

			case "objects", "obj":
				listAvailableObjects();

			case "fields", "props":
				if (args.length > 1)
					inspectObject(args[1]);
				else
					addOutput("Usage: fields <objectName>", 0xFF8888);

			case "call", "method":
				if (args.length > 2)
					callMethod(args[1], args[2], args.slice(3));
				else
					addOutput("Usage: call <object> <method> [args...]", 0xFF8888);

			case "set":
				if (args.length > 3)
					setProperty(args[1], args[2], args.slice(3).join(" "));
				else
					addOutput("Usage: set <object> <property> <value>", 0xFF8888);

			case "new", "create":
				if (args.length > 1)
					createInstance(args[1], args.slice(2));
				else
					addOutput("Usage: new <className> [args...]", 0xFF8888);

			case "cursor":
				if (args.length > 1)
				{
					switch (args[1])
					{
						case "show":
							FlxG.mouse.visible = true;
							addOutput("Cursor shown", 0x88FF88);

						case "hide":
							FlxG.mouse.visible = false;
							addOutput("Cursor hidden", 0x88FF88);

						default:
							addOutput("Usage: cursor [show|hide]", 0xFF8888);
					}
				}
				else
				{
					FlxG.mouse.visible = !FlxG.mouse.visible;
					addOutput("Cursor " + (FlxG.mouse.visible ? "shown" : "hidden"), 0x88FF88);
				}

			case "hscript":
				hscriptMode = !hscriptMode;
				addOutput("HScript mode: " + (hscriptMode ? "ON" : "OFF"), hscriptMode ? 0x88FF88 : 0xFF8888);
				updateDisplay();

			case "memory", "mem":
				addOutput("Memory Stats:", 0x88FFFF);
				addOutput('Command history: ${commandHistory.length}/${maxHistorySize}', 0x88FFFF);
				addOutput('Output lines: ${outputLines.length}/${maxOutputLines}', 0x88FFFF);
				addOutput('HScript variables: ${countHScriptVariables()}', 0x88FFFF);

			case "copy":
				if (args.length > 1)
				{
					switch (args[1].toLowerCase())
					{
						case "all":
							copyAllOutputText();

						case "input":
							copyCurrentInput();

						default:
							addOutput("Usage: copy [all|input]", 0xFF8888);
					}
				}
				else
				{
					addOutput("Usage: copy [all|input]", 0xFF8888);
				}

			default:
				addOutput("Unknown command: '" + cmd + "'. Type 'help' for available commands.", 0xFF8888);
		}
	}

	function showHelp():Void
	{
		addOutput("Available commands:", 0x88FFFF);
		addOutput("  help - show this message", 0x88FFFF);
		addOutput("  clear - clear console", 0x88FFFF);
		addOutput("  objects - list available runtime objects", 0x88FFFF);
		addOutput("  fields <object> - show object fields/properties", 0x88FFFF);
		addOutput("  set <object> <property> <value> - set property value", 0x88FFFF);
		addOutput("  call <object> <method> [args] - call method", 0x88FFFF);
		addOutput("  new <class> [args] - create new instance", 0x88FFFF);
		addOutput("  cursor [show|hide] - show/hide mouse cursor", 0x88FFFF);
		addOutput("  hscript - toggle HScript mode", 0x88FFFF);
		addOutput("  memory - show memory usage", 0x88FFFF);
		addOutput("  copy all - copy all console output", 0x88FFFF);
		addOutput("  copy input - copy current input", 0x88FFFF);

		addOutput("Keys:", 0xFFFF88);
		addOutput("  F12 - toggle console", 0xFFFF88);
		addOutput("  F10 - toggle HScript mode", 0xFFFF88);
		addOutput("  Up/Down - command history", 0xFFFF88);
		addOutput("  Ctrl+C - copy selected output or current input", 0xFFFF88);
		addOutput("  Ctrl+Shift+C - copy all output", 0xFFFF88);
		addOutput("  Ctrl+V - paste", 0xFFFF88);
	}

	function listAvailableObjects():Void
	{
		#if HSCRIPT_ALLOWED
		var variables:Array<String> = [];

		try
		{
			var ruleField = Reflect.field(hscript, "rule");
			var variablesField = ruleField != null ? Reflect.field(ruleField, "variables") : null;

			if (variablesField != null)
			{
				var map:Map<String, Dynamic> = cast variablesField;

				for (key in map.keys())
					variables.push(key);
			}
		}
		catch (e:Dynamic) {}

		addOutput("Available objects:", 0xFFFF88);

		for (name in variables)
		{
			try
			{
				var value = hscript.get(name);
				var clazz = Type.getClass(value);
				var typeName = clazz != null ? Type.getClassName(clazz) : "Dynamic";
				addOutput('  $name - $typeName', 0xFFFF88);
			}
			catch (e:Dynamic)
			{
				addOutput('  $name - <unknown>', 0xFFFF88);
			}
		}
		#else
		addOutput("HScript is not enabled.", 0xFF8888);
		#end
	}

	function inspectObject(objectName:String):Void
	{
		#if HSCRIPT_ALLOWED
		try
		{
			var obj = hscript.get(objectName);

			if (obj == null)
			{
				addOutput('Object "$objectName" not found', 0xFF8888);
				return;
			}

			addOutput('Fields and properties of $objectName:', 0x88FF88);

			var clazz = Type.getClass(obj);

			if (clazz == null)
			{
				for (field in Reflect.fields(obj))
					addFieldOutput(obj, field);

				return;
			}

			for (field in Type.getInstanceFields(clazz))
			{
				if (!field.startsWith("_"))
					addFieldOutput(obj, field);
			}
		}
		catch (e:Dynamic)
		{
			addOutput('Error inspecting object: $e', 0xFF8888);
		}
		#else
		addOutput("HScript is not enabled.", 0xFF8888);
		#end
	}

	function addFieldOutput(obj:Dynamic, field:String):Void
	{
		try
		{
			var value = Reflect.field(obj, field);
			var valueStr = value == null ? "null" : Std.string(value);

			if (valueStr.length > 80)
				valueStr = valueStr.substr(0, 77) + "...";

			addOutput('  $field = $valueStr', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('  $field = <cannot access>', 0xFF8888);
		}
	}

	function createInstance(className:String, args:Array<String>):Void
	{
		#if HSCRIPT_ALLOWED
		try
		{
			var clazz:Class<Dynamic> = Type.resolveClass(className);

			if (clazz == null)
			{
				addOutput('Class "$className" not found', 0xFF8888);
				return;
			}

			var parsedArgs:Array<Dynamic> = [];

			for (arg in args)
				parsedArgs.push(parseArgument(arg));

			var instance = Type.createInstance(clazz, parsedArgs);
			var instanceName = 'instance_${Std.int(Math.random() * 10000)}';

			hscript.set(instanceName, instance);

			addOutput('Created instance: $instanceName of $className', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('Error creating instance: $e', 0xFF8888);
		}
		#else
		addOutput("HScript is not enabled.", 0xFF8888);
		#end
	}

	function parseArgument(arg:String):Dynamic
	{
		var trimmed = arg.trim();

		if (trimmed == "true") return true;
		if (trimmed == "false") return false;
		if (trimmed == "null") return null;

		if ((trimmed.startsWith("\"") && trimmed.endsWith("\"")) || (trimmed.startsWith("'") && trimmed.endsWith("'")))
			return trimmed.substr(1, trimmed.length - 2);

		if (trimmed.indexOf(".") != -1)
		{
			var floatValue = Std.parseFloat(trimmed);

			if (!Math.isNaN(floatValue))
				return floatValue;
		}

		var intValue = Std.parseInt(trimmed);

		if (intValue != null && Std.string(intValue) == trimmed)
			return intValue;

		return arg;
	}

	function setProperty(objectName:String, propertyPath:String, valueExpr:String):Void
	{
		#if HSCRIPT_ALLOWED
		try
		{
			var obj = hscript.get(objectName);

			if (obj == null)
			{
				addOutput('Object "$objectName" not found', 0xFF8888);
				return;
			}

			var value = parseArgument(valueExpr);
			var parts = propertyPath.split(".");
			var target = obj;

			for (i in 0...parts.length - 1)
			{
				target = Reflect.field(target, parts[i]);

				if (target == null)
				{
					addOutput('Property "${parts.slice(0, i + 1).join(".")}" not found', 0xFF8888);
					return;
				}
			}

			var finalProp = parts[parts.length - 1];
			Reflect.setField(target, finalProp, value);

			addOutput('Set $objectName.$propertyPath = $value', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('Error: $e', 0xFF8888);
		}
		#else
		addOutput("HScript is not enabled.", 0xFF8888);
		#end
	}

	function callMethod(objectName:String, methodPath:String, args:Array<String>):Void
	{
		#if HSCRIPT_ALLOWED
		try
		{
			var obj = hscript.get(objectName);

			if (obj == null)
			{
				addOutput('Object "$objectName" not found', 0xFF8888);
				return;
			}

			var parsedArgs:Array<Dynamic> = [];

			for (arg in args)
				parsedArgs.push(parseArgument(arg));

			var method = Reflect.field(obj, methodPath);

			if (method == null)
			{
				addOutput('Method "$methodPath" not found on "$objectName"', 0xFF8888);
				return;
			}

			var result = Reflect.callMethod(obj, method, parsedArgs);
			addOutput('Result: $result', 0x88FF88);
		}
		catch (e:Dynamic)
		{
			addOutput('Error calling $objectName.$methodPath: $e', 0xFF8888);
		}
		#else
		addOutput("HScript is not enabled.", 0xFF8888);
		#end
	}

	function showConsole():Void
	{
		consoleVisible = true;
		console.visible = true;

		wasMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = true;

		focusInput();

		hiddenInputField.text = "";

		currentInput = "";
		cursorPosition = 0;
		historyIndex = commandHistory.length;

		resetCursor();
		updateDisplay();
	}

	function hideConsole():Void
	{
		consoleVisible = false;
		console.visible = false;

		FlxG.mouse.visible = wasMouseVisible;

		if (FlxG.stage.focus == hiddenInputField || FlxG.stage.focus == outputText)
			FlxG.stage.focus = FlxG.stage;
	}

	function countHScriptVariables():Int
	{
		var count = 0;

		#if HSCRIPT_ALLOWED
		try
		{
			var ruleField = Reflect.field(hscript, "rule");
			var variablesField = ruleField != null ? Reflect.field(ruleField, "variables") : null;

			if (variablesField != null)
			{
				var map:Map<String, Dynamic> = cast variablesField;

				for (_ in map.keys())
					count++;
			}
		}
		catch (e:Dynamic) {}
		#end

		return count;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!consoleVisible)
			return;

		cursorTimer += elapsed;

		if (cursorTimer >= cursorBlinkRate)
		{
			cursorTimer = 0;
			cursorVisible = !cursorVisible;
			updateDisplay();
		}

		if (FlxG.stage.focus != hiddenInputField && FlxG.stage.focus != outputText)
			focusInput();

        blockGameInput();
	}

	override public function destroy():Void
	{
		restoreTrace();

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        FlxG.stage.removeEventListener(TextEvent.TEXT_INPUT, onTextInput);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);

		if (console != null)
		{
			console.removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
			console.removeEventListener(MouseEvent.MOUSE_DOWN, onConsoleMouseDown);
			console.parent?.removeChild(console);
			console = null;
		}

		if (titleBar != null)
		{
			titleBar.removeEventListener(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);
			titleBar = null;
		}

		if (outputText != null)
		{
			outputText.removeEventListener(Event.SCROLL, onOutputScroll);
			outputText.removeEventListener(MouseEvent.MOUSE_DOWN, onOutputMouseDown);
			outputText.removeEventListener(MouseEvent.MOUSE_UP, onOutputMouseUp);
			outputText = null;
		}

		if (hiddenInputField != null)
		{
			hiddenInputField.parent?.removeChild(hiddenInputField);
			hiddenInputField = null;
		}

		#if HSCRIPT_ALLOWED
		if (hscript != null)
		{
			hscript.stop();
			hscript = null;
		}
		#end

		if (instance == this)
			instance = null;

		super.destroy();
	}
}