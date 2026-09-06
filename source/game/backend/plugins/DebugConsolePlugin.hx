package game.backend.plugins;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxState;

import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
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

	var consoleVisible:Bool = false;
	var consoleWidth:Int = 700;
	var consoleHeight:Int = 400;

	var commandHistory:Array<String> = [];
	var historyIndex:Int = 0;
	var prompt:String = "> ";

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

		createConsole();
		hijackTrace();
		loadConsolePosition();
		initializeHScript();
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onGlobalKeyDown);
	}

	function initializeHScript():Void
	{
		#if HSCRIPT_ALLOWED
		hscript = new FunkinHScript("", null, true);
		hscript.scriptName = "Debug Console[HS]";

		hscript.set("console", this);
		hscript.set("print", (v:Dynamic) -> addOutput(Std.string(v), 0xFFFFFF));
		hscript.set("clearConsole", clearOutput);
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
		titleText.text = "Debug Console (Drag to move)";
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
		outputText.type = TextFieldType.DYNAMIC;
		outputText.selectable = true;
		outputText.addEventListener(Event.SCROLL, onOutputScroll);

		inputText = new TextField();
		inputText.x = 12;
		inputText.y = consoleHeight - 45;
		inputText.width = consoleWidth - 24;
		inputText.height = 24;
		inputText.type = TextFieldType.INPUT;
		inputText.defaultTextFormat = new TextFormat("Consolas", 14, 0xE0E0E0);
		inputText.text = "";
		inputText.addEventListener(KeyboardEvent.KEY_DOWN, onInputKeyDown);

		var promptText = new TextField();
		promptText.x = 12;
		promptText.y = inputText.y;
		promptText.width = 15;
		promptText.height = 24;
		promptText.defaultTextFormat = new TextFormat("Consolas", 14, 0x88FF88);
		promptText.text = ">";
		promptText.selectable = false;
		inputText.x += 15;
		inputText.width -= 15;

		console.addChild(outputText);
		console.addChild(promptText);
		console.addChild(inputText);

		console.visible = false;
		FlxG.stage.addChild(console);

		titleBar.addEventListener(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);

		clearOutput();
	}

	function clearOutput():Void
	{
		outputLines = [];
		addOutput("Debug Console (F12 to toggle)", 0xE0E0E0);
		addOutput("Drag title bar to move | Ctrl+C to copy selected text", 0xAAAAAA);
	}

	function onOutputScroll(event:Event):Void
	{
		autoScrollToBottom = outputText.scrollV >= outputText.maxScrollV - 1;
	}

	function onTitleBarMouseDown(event:MouseEvent):Void
	{
		if (!consoleVisible) return;
		isDragging = true;
		dragOffsetX = event.stageX - console.x;
		dragOffsetY = event.stageY - console.y;
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
		if (FlxG.save.data != null)
		{
			FlxG.save.data.consoleX = console.x;
			FlxG.save.data.consoleY = console.y;
			FlxG.save.flush();
		}
	}

	function loadConsolePosition():Void
	{
		if (FlxG.save.data != null)
		{
			if (FlxG.save.data.consoleX != null) console.x = FlxG.save.data.consoleX;
			if (FlxG.save.data.consoleY != null) console.y = FlxG.save.data.consoleY;
			clampConsoleToStage();
		}
	}

	function hijackTrace():Void
	{
		if (originalTrace != null) return;
		originalTrace = haxe.Log.trace;

		haxe.Log.trace = (v:Dynamic, ?infos:haxe.PosInfos) -> {
			addOutput('TRACE: ${Std.string(v)}', 0x8888FF);
			if (originalTrace != null) originalTrace(v, infos);
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

	function onGlobalKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode == Keyboard.F12)
		{
			consoleVisible ? hideConsole() : showConsole();
		}
	}

	function onInputKeyDown(event:KeyboardEvent):Void
	{
		if (!consoleVisible) return;

		switch (event.keyCode)
		{
			case Keyboard.ENTER:
				final command = inputText.text.trim();
				if (command != "")
				{
					commandHistory.push(command);
					if (commandHistory.length > maxHistorySize) commandHistory.shift();
					historyIndex = commandHistory.length;
					
					addOutput((hscriptMode ? "[HS] " : "") + prompt + command, 0x88FF88);
					inputText.text = "";
					
					hscriptMode ? executeHScript(command) : processCommand(command);
				}

			case Keyboard.UP:
				navigateHistory(-1);

			case Keyboard.DOWN:
				navigateHistory(1);

			case Keyboard.TAB:
				autoComplete();
				event.preventDefault();

			case Keyboard.F10:
				hscriptMode = !hscriptMode;
				addOutput("HScript mode: " + (hscriptMode ? "ON" : "OFF"), hscriptMode ? 0x88FF88 : 0xFF8888);
		}
	}

	function navigateHistory(direction:Int):Void
	{
		if (commandHistory.length == 0) return;

		historyIndex += direction;
		if (historyIndex < 0) historyIndex = 0;
		if (historyIndex > commandHistory.length) historyIndex = commandHistory.length;

		inputText.text = historyIndex == commandHistory.length ? "" : commandHistory[historyIndex];
		FlxG.stage.focus = inputText;
		inputText.setSelection(inputText.text.length, inputText.text.length);
	}

	function autoComplete():Void
	{
		final input = inputText.text.trim();
		if (input == "") return;

		final commands = ["help", "clear", "objects", "fields", "call", "set", "new", "hscript", "memory"];
		final suggestions = commands.filter(cmd -> cmd.toLowerCase().startsWith(input.toLowerCase()));

		if (suggestions.length == 1)
		{
			inputText.text = suggestions[0];
			inputText.setSelection(inputText.text.length, inputText.text.length);
		}
		else if (suggestions.length > 1)
		{
			addOutput("Suggestions: " + suggestions.join(", "), 0xFFFF88);
		}
	}

	function addOutput(message:String, color:Int = 0xE0E0E0):Void
	{
		if (outputText == null) return;

		final colorHex = StringTools.hex(color, 6);
		final safe = StringTools.htmlEscape(message);
		outputLines.push('<font color="#$colorHex">$safe</font>');

		if (outputLines.length > maxOutputLines) outputLines.shift();

		final oldScroll = outputText.scrollV;
		outputText.htmlText = outputLines.join("\n");
		outputText.scrollV = autoScrollToBottom ? outputText.maxScrollV : oldScroll;
	}

	function executeHScript(code:String):Void
	{
		#if HSCRIPT_ALLOWED
		try
		{
			hscript.set("instance", FlxG.state.subState ?? FlxG.state);
			final result = hscript.executeString(code);
			if (result != null) addOutput("Result: " + Std.string(result), 0x88FFFF);
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
		final args = command.split(" ").filter(arg -> arg != "");
		final cmd = args[0].toLowerCase();

		switch (cmd)
		{
			case "help":
				addOutput("Available commands: help, clear, hscript, memory", 0x88FFFF);
			case "clear", "cls":
				clearOutput();
			case "hscript":
				hscriptMode = !hscriptMode;
				addOutput("HScript mode: " + (hscriptMode ? "ON" : "OFF"), 0x88FF88);
			case "memory", "mem":
				addOutput('History: ${commandHistory.length}/${maxHistorySize} | Lines: ${outputLines.length}/${maxOutputLines}', 0x88FFFF);
			default:
				addOutput("Unknown command. Type 'help' or enable 'hscript' mode.", 0xFF8888);
		}
	}

	function showConsole():Void
	{
		consoleVisible = true;
		console.visible = true;

		FlxG.keys.enabled = false;
		FlxG.mouse.enabled = false;

		wasMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = true;

		FlxG.stage.focus = inputText;
		inputText.setSelection(inputText.text.length, inputText.text.length);
	}

	function hideConsole():Void
	{
		consoleVisible = false;
		console.visible = false;

		FlxG.keys.enabled = true;
		FlxG.mouse.enabled = true;
		FlxG.mouse.visible = wasMouseVisible;

		FlxG.stage.focus = FlxG.stage;
	}

	override public function destroy():Void
	{
		restoreTrace();

		if (FlxG.stage != null)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onGlobalKeyDown);
			FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
			FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
		}

		if (console != null)
		{
			console.parent?.removeChild(console);
			console = null;
		}

		#if HSCRIPT_ALLOWED
		if (hscript != null)
		{
			hscript.stop();
			hscript = null;
		}
		#end

		if (instance == this) instance = null;
		super.destroy();
	}
}