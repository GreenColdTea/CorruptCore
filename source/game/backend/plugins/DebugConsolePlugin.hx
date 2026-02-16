package game.backend.plugins;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
import openfl.events.TextEvent;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.ui.Keyboard;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;

import haxe.Json;

import game.scripting.FunkinHScript;

using StringTools;

class DebugConsolePlugin extends FlxBasic
{
    static var instance:Null<DebugConsolePlugin> = null;
    
    var console:Sprite;
    var outputText:TextField;
    var inputText:TextField;
    var consoleVisible:Bool = false;
    var consoleWidth:Int = 700;
    var consoleHeight:Int = 400;
    
    var commandHistory:Array<String> = [];
    var historyIndex:Int = 0;
    var currentInput:String = "";
    var prompt:String = "> ";
    
    var cursorVisible:Bool = true;
    var cursorTimer:Float = 0;
    var cursorBlinkRate:Float = 0.5;
    
    var cursorPosition:Int = 0;
    
    var wasMouseVisible:Bool = true;
    
    var hscript:FunkinHScript;
    var hscriptMode:Bool = false;
    
    var isDragging:Bool = false;
    var dragOffsetX:Float = 0;
    var dragOffsetY:Float = 0;
    
    var titleBar:Sprite;
    
    var autoScrollToBottom:Bool = true;
    
    var maxHistorySize:Int = 100;
    var maxOutputLines:Int = 500;
    
    var hiddenInputField:TextField;
    
    var selectionStart:Int = -1;
    var selectionEnd:Int = -1;
    var isSelecting:Bool = false;
    var copyOnRelease:Bool = false;
    
    public static function init()
    {
        if (instance == null) FlxG.plugins.addPlugin(instance = new DebugConsolePlugin());
    }
    
    public function new()
    {
        super();
        this.visible = false;
        initializeHScript();
        createConsole();
        hijackTrace();
        loadConsolePosition();
    }
    
    function initializeHScript():Void
    {
        hscript = new FunkinHScript("", FlxG.state, true);
        hscript.scriptName = "Debug Console[HS]";
        
        hscript.set("console", this);
        hscript.set("print", (v:Dynamic) -> addOutput(Std.string(v), 0xFFFFFF));
        hscript.set("clearConsole", () -> {
            outputText.text = "Debug Console (F12 to toggle)\nDrag title bar to move | Shift+Enter for new line\n";
            inputText.text = prompt;
        });
        hscript.set("copySelectedText", copySelectedText);
        hscript.set("copyAllText", copyAllOutputText);
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
        
        outputText.type = openfl.text.TextFieldType.DYNAMIC;
        outputText.selectable = true;
        outputText.mouseEnabled = true;
        outputText.tabEnabled = false;
        
        outputText.text = "Debug Console (F12 to toggle)\nDrag title bar to move | Shift+Enter for new line | Ctrl+C to copy selected text\n";
        
        outputText.addEventListener(Event.SCROLL, (e:Event) -> autoScrollToBottom = (outputText.scrollV >= outputText.maxScrollV - 1));
        
        outputText.addEventListener(MouseEvent.MOUSE_DOWN, onOutputMouseDown);
        outputText.addEventListener(MouseEvent.MOUSE_MOVE, onOutputMouseMove);
        outputText.addEventListener(MouseEvent.MOUSE_UP, onOutputMouseUp);
        
        inputText = new TextField();
        inputText.x = 12;
        inputText.y = consoleHeight - 45;
        inputText.width = consoleWidth - 24;
        inputText.height = 20;
        inputText.multiline = false;
        inputText.wordWrap = false;
        inputText.defaultTextFormat = new TextFormat("Consolas", 14, 0xE0E0E0);
        inputText.background = false;
        inputText.border = false;
        
        inputText.type = openfl.text.TextFieldType.DYNAMIC;
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
        hiddenInputField.type = openfl.text.TextFieldType.INPUT;
        hiddenInputField.width = 1;
        hiddenInputField.height = 1;
        hiddenInputField.x = -1000;
        hiddenInputField.y = -1000;
        hiddenInputField.visible = false;
        FlxG.stage.addChild(hiddenInputField);
        
        FlxG.stage.addChild(console);
        
        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        FlxG.stage.addEventListener(TextEvent.TEXT_INPUT, onTextInput);
        
        console.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
        console.addEventListener(MouseEvent.MOUSE_DOWN, onConsoleMouseDown);
        
        titleBar.addEventListener(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);
        
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
    }
    
    private function onOutputMouseMove(event:MouseEvent):Void
    {
        if (!consoleVisible) return;
        
        if (event.buttonDown)
        {
            var charIndex = outputText.getCharIndexAtPoint(event.localX, event.localY);
            if (charIndex >= 0)
            {
                if (selectionStart < 0)
                {
                    selectionStart = outputText.caretIndex;
                    isSelecting = true;
                }
                
                if (charIndex < selectionStart) 
                    outputText.setSelection(charIndex, selectionStart);
                else 
                    outputText.setSelection(selectionStart, charIndex);
            }
        }
        else
        {
            isSelecting = false;
        }
    }

    private function onOutputMouseDown(event:MouseEvent):Void
    {
        if (!consoleVisible) return;
        
        outputText.setSelection(0, 0);
        selectionStart = -1;
        selectionEnd = -1;
        isSelecting = false;
        
        FlxG.stage.focus = outputText;
        event.stopPropagation();
    }

    private function onOutputMouseUp(event:MouseEvent):Void
    {
        if (!consoleVisible) return;
        
        isSelecting = false;
        
        if (copyOnRelease)
        {
            copySelectedText();
            copyOnRelease = false;
        }
        
        event.stopPropagation();
    }
    
    private function onConsoleMouseDown(event:MouseEvent):Void
    {
        if (consoleVisible && event.target != outputText && event.target != titleBar)
        {
            FlxG.stage.focus = hiddenInputField;
            outputText.setSelection(0, 0);
        }
    }
    
    private function onTitleBarMouseDown(event:MouseEvent):Void
    {
        isDragging = true;
        dragOffsetX = event.stageX - console.x;
        dragOffsetY = event.stageY - console.y;
        event.stopPropagation();
        
        FlxG.stage.focus = hiddenInputField;
    }
    
    private function onStageMouseUp(event:MouseEvent):Void
    {
        if (isDragging) {
            isDragging = false;
            saveConsolePosition();
        }
    }
    
    private function onStageMouseMove(event:MouseEvent):Void
    {
        if (isDragging && consoleVisible) {
            console.x = event.stageX - dragOffsetX;
            console.y = event.stageY - dragOffsetY;
            
            var stageWidth = FlxG.stage.stageWidth;
            var stageHeight = FlxG.stage.stageHeight;
            
            if (console.x < 0) console.x = 0;
            if (console.y < 0) console.y = 0;
            if (console.x + consoleWidth > stageWidth) console.x = stageWidth - consoleWidth;
            if (console.y + consoleHeight > stageHeight) console.y = stageHeight - consoleHeight;
        }
    }
    
    private function saveConsolePosition():Void
    {
        if (FlxG.save.data != null) {
            FlxG.save.data.consoleX = console.x;
            FlxG.save.data.consoleY = console.y;
            FlxG.save.flush();
        }
    }
    
    private function loadConsolePosition():Void
    {
        if (FlxG.save.data != null) {
            if (FlxG.save.data.consoleX != null) console.x = FlxG.save.data.consoleX;
            if (FlxG.save.data.consoleY != null) console.y = FlxG.save.data.consoleY;
            
            var stageWidth = FlxG.stage.stageWidth;
            var stageHeight = FlxG.stage.stageHeight;
            
            if (console.x < 0) console.x = 0;
            if (console.y < 0) console.y = 0;
            if (console.x + consoleWidth > stageWidth) console.x = stageWidth - consoleWidth;
            if (console.y + consoleHeight > stageHeight) console.y = stageHeight - consoleHeight;
        }
    }
    
    private function onMouseWheel(event:MouseEvent):Void
    {
        if (!consoleVisible) return;
        
        var scrollAmount = event.delta > 0 ? -1 : 1;
        outputText.scrollV += scrollAmount * 3;
        
        if (outputText.scrollV < 1) outputText.scrollV = 1;
        if (outputText.scrollV > outputText.maxScrollV) outputText.scrollV = outputText.maxScrollV;
        
        event.stopPropagation();
    }
    
    private function hijackTrace():Void
    {
        var originalTrace = haxe.Log.trace;
        
        haxe.Log.trace = (v:Dynamic, ?infos:haxe.PosInfos) -> {
            var message = 'TRACE: $v';
            addOutput(message, 0x8888FF);
            originalTrace(v, infos);
        };
    }
    
    private function onKeyDown(event:KeyboardEvent):Void
    {
        if (!consoleVisible) return;
        
        switch(event.keyCode)
        {
            case Keyboard.ENTER:
                if (event.shiftKey) {
                    insertTextAtCursor("\n");
                    event.preventDefault();
                } else {
                    if (StringTools.trim(currentInput) == "") {
                        event.preventDefault();
                        return;
                    }
                    executeCommand();
                    resetCursor();
                    event.preventDefault();
                }
                
            case Keyboard.BACKSPACE:
                if (currentInput.length > 0 && cursorPosition > 0) {
                    currentInput = currentInput.substring(0, cursorPosition - 1) + currentInput.substring(cursorPosition);
                    cursorPosition--;
                    updateDisplay();
                    resetCursor();
                }
                event.preventDefault();
                
            case Keyboard.LEFT:
                if (event.shiftKey && FlxG.stage.focus == outputText) {
                    if (!isSelecting) {
                        isSelecting = true;
                        selectionStart = outputText.caretIndex;
                    }
                } else {
                    if (cursorPosition > 0) {
                        cursorPosition--;
                        updateDisplay();
                        resetCursor();
                    }
                }
                event.preventDefault();
                
            case Keyboard.RIGHT:
                if (event.shiftKey && FlxG.stage.focus == outputText) {
                    if (!isSelecting) {
                        isSelecting = true;
                        selectionStart = outputText.caretIndex;
                    }
                } else {
                    if (cursorPosition < currentInput.length) {
                        cursorPosition++;
                        updateDisplay();
                        resetCursor();
                    }
                }
                event.preventDefault();
                
            case Keyboard.HOME:
                if (event.shiftKey && FlxG.stage.focus == outputText) {
                    if (!isSelecting) {
                        isSelecting = true;
                        selectionStart = outputText.caretIndex;
                    }
                    outputText.setSelection(0, selectionStart);
                } else {
                    cursorPosition = 0;
                    updateDisplay();
                    resetCursor();
                }
                event.preventDefault();
                
            case Keyboard.END:
                if (event.shiftKey && FlxG.stage.focus == outputText) {
                    if (!isSelecting) {
                        isSelecting = true;
                        selectionStart = outputText.caretIndex;
                    }
                    outputText.setSelection(selectionStart, outputText.length);
                } else {
                    cursorPosition = currentInput.length;
                    updateDisplay();
                    resetCursor();
                }
                event.preventDefault();
                
            case Keyboard.TAB:
                if (currentInput.trim() != "") {
                    autoComplete();
                    event.preventDefault();
                }
                
            case Keyboard.ESCAPE:
                hideConsole();
                event.preventDefault();
                
            case Keyboard.F10:
                hscriptMode = !hscriptMode;
                addOutput("HScript mode: " + (hscriptMode ? "ON" : "OFF"), hscriptMode ? 0x88FF88 : 0xFF8888);
                event.preventDefault();
                
            case Keyboard.V:
                if (event.ctrlKey || event.commandKey) {
                    pasteFromClipboard();
                    event.preventDefault();
                }
                
            case Keyboard.C:
                if (event.ctrlKey || event.commandKey) {
                    if (FlxG.stage.focus == outputText && outputText.selectionBeginIndex != outputText.selectionEndIndex)
                        copySelectedText();
                    else if (event.shiftKey)
                        copyAllOutputText();
                    else if (currentInput.length > 0 && FlxG.stage.focus == hiddenInputField)
                        copyCurrentInput();

                    event.preventDefault();
                }
                
            case Keyboard.A:
                if ((event.ctrlKey || event.commandKey) && FlxG.stage.focus == outputText) {
                    outputText.setSelection(0, outputText.length);
                    isSelecting = true;
                    selectionStart = 0;
                    copyOnRelease = event.shiftKey;
                    event.preventDefault();
                } else if ((event.ctrlKey || event.commandKey) && FlxG.stage.focus == hiddenInputField) {
                    hiddenInputField.setSelection(0, hiddenInputField.length);
                    event.preventDefault();
                }
                
            default:
                if (FlxG.stage.focus == hiddenInputField)
                    event.preventDefault();
        }
    }
    
    private function copySelectedText():Void
    {
        try {
            if (outputText.selectionBeginIndex == outputText.selectionEndIndex) {
                addOutput("No text selected", 0xFFFF88);
                return;
            }
            
            var selectedText = outputText.text.substring(outputText.selectionBeginIndex, outputText.selectionEndIndex);
            if (selectedText.length > 0) {
                #if (sys || desktop)
                Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, selectedText);
                #end
                var len = selectedText.length;
                if (len > 100) {
                    addOutput('Copied $len characters to clipboard', 0x88FF88);
                } else {
                    var displayText = selectedText;
                    if (displayText.contains("\n")) {
                        displayText = displayText.replace("\n", "\\n");
                    }
                    addOutput('Copied to clipboard: "$displayText"', 0x88FF88);
                }
            }
        } catch (e:Dynamic) {
            addOutput('Failed to copy: $e', 0xFF8888);
        }
    }
    
    private function copyAllOutputText():Void
    {
        try {
            var text = outputText.text;
            if (text.length > 0) {
                #if (sys || desktop)
                Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, text);
                #end
                addOutput('Copied all ${text.length} characters to clipboard', 0x88FF88);
            } else {
                addOutput("No text to copy", 0xFFFF88);
            }
        } catch (e:Dynamic) {
            addOutput('Failed to copy all text: $e', 0xFF8888);
        }
    }
    
    private function copyCurrentInput():Void
    {
        try {
            if (currentInput.length > 0) {
                #if (sys || desktop)
                Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, currentInput);
                #end
                addOutput('Copied input to clipboard: "$currentInput"', 0x88FF88);
            } else {
                addOutput("Input is empty", 0xFFFF88);
            }
        } catch (e:Dynamic) {
            addOutput('Failed to copy input: $e', 0xFF8888);
        }
    }
    
    private function insertTextAtCursor(text:String):Void
    {
        currentInput = currentInput.substring(0, cursorPosition) + text + currentInput.substring(cursorPosition);
        cursorPosition += text.length;
        updateDisplay();
        resetCursor();
    }
    
    private function pasteFromClipboard():Void
    {
        try {
            #if (sys || desktop)
            var clipboardText = Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT);
            if (clipboardText != null && Std.isOfType(clipboardText, String)) {
                var text:String = cast clipboardText;
                insertTextAtCursor(text);
            }
            #else
            addOutput("Clipboard access not available on this platform", 0xFFFF88);
            #end
        } catch (e:Dynamic) {
            addOutput('Clipboard error: $e', 0xFF8888);
        }
    }
    
    private function onTextInput(event:TextEvent):Void
    {
        if (!consoleVisible || FlxG.stage.focus == outputText) return;
        
        var char = event.text;
        if (char == null || char.length == 0) return;
        
        var charCode = char.charCodeAt(0);
        if (charCode < 32 && char != "\n" && char != "\r" && char != "\t") return;
        
        if (char == "\n" || char == "\r") {
            event.preventDefault();
            return;
        }
        
        currentInput = currentInput.substring(0, cursorPosition) + char + currentInput.substring(cursorPosition);
        cursorPosition++;
        
        updateDisplay();
        event.preventDefault();
    }
    
    private function resetCursor():Void
    {
        cursorVisible = true;
        cursorTimer = 0;
    }
    
    private function navigateHistory(direction:Int):Void
    {
        if (commandHistory.length == 0) return;
        
        historyIndex += direction;
        historyIndex = Std.int(Math.max(0, Math.min(commandHistory.length, historyIndex)));
        
        if (historyIndex == commandHistory.length)
        {
            currentInput = "";
            cursorPosition = 0;
        }
        else
        {
            currentInput = commandHistory[historyIndex];
            cursorPosition = currentInput.length;
        }
        
        updateDisplay();
    }
    
    private function autoComplete():Void
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
            {
                suggestions.push(cmd);
            }
        }
        
        return suggestions;
    }
    
    private function updateDisplay():Void
    {
        var modePrefix = hscriptMode ? "[HS] " : "";
        var inputBeforeCursor = modePrefix + prompt + currentInput.substring(0, cursorPosition);
        var inputAfterCursor = currentInput.substring(cursorPosition);
        var cursorChar = cursorVisible ? "▌" : " ";
        var inputLine = inputBeforeCursor + cursorChar + inputAfterCursor;
        
        inputText.text = inputLine;
    }
    
    private function addOutput(message:String, color:Int = 0xE0E0E0):Void
    {
        var currentScrollV = outputText.scrollV;
        var currentMaxScrollV = outputText.maxScrollV;
        
        var colorHex = StringTools.hex(color, 6);
        var coloredMessage = '<font color="#${colorHex}">${StringTools.htmlEscape(message)}</font>';
        
        var currentText = outputText.htmlText;
        outputText.htmlText = currentText == "" ? coloredMessage : currentText + "\n" + coloredMessage;
        
        var lines = outputText.text.split("\n");
        if (lines.length > maxOutputLines) {
            var startIndex = lines.length - maxOutputLines;
            outputText.text = lines.slice(startIndex).join("\n");
        }
        
        if (autoScrollToBottom) {
            outputText.scrollV = outputText.maxScrollV;
        } else {
            outputText.scrollV = currentScrollV;
        }
    }
    
    private function executeCommand():Void
    {
        var command:String = StringTools.trim(currentInput);

        if (command == "") {
            addOutput("Empty command", 0xFFFF88);
            currentInput = "";
            cursorPosition = 0;
            updateDisplay();
            return;
        }
        
        commandHistory.push(command);
        
        if (commandHistory.length > maxHistorySize)
            commandHistory.shift();
        
        historyIndex = commandHistory.length;
        
        addOutput((hscriptMode ? "[HS] " : "") + prompt + command, 0x88FF88);
        
        currentInput = "";
        cursorPosition = 0;
        
        try {
            if (hscriptMode) executeHScript(command);
            else processCommand(command);
        } catch (e:Dynamic) {
            addOutput('Error: $e', 0xFF8888);
        }
        
        updateDisplay();
    }
    
    private function executeHScript(code:String):Void
    {
        try
        {
            var result = hscript.executeString(code);
            if (result != null)
            {
                addOutput("Result: " + Std.string(result), 0x88FFFF);
            }
        }
        catch (e:Dynamic)
        {
            addOutput('HScript Error: $e', 0xFF8888);
        }
    }
    
    private function processCommand(command:String):Void
    {
        var args:Array<String> = command.split(" ").filter(arg -> arg != "");
        var cmd:String = args[0].toLowerCase();
        
        switch(cmd)
        {
            case "help":
                showHelp();
                
            case "clear", "cls":
                outputText.text = "Debug Console (F12 to toggle)\nDrag title bar to move | Shift+Enter for new line | Ctrl+C to copy selected text\n";
                inputText.text = prompt;
                
            case "objects", "obj":
                listAvailableObjects();
                
            case "fields", "props":
                if (args.length > 1)
                {
                    inspectObject(args[1]);
                }
                else
                {
                    addOutput("Usage: fields <objectName>", 0xFF8888);
                }
                
            case "call", "method":
                if (args.length > 2)
                {
                    callMethod(args[1], args[2], args.slice(3));
                }
                else
                {
                    addOutput("Usage: call <object> <method> [args...]", 0xFF8888);
                }
                
            case "set":
                if (args.length > 3)
                {
                    setProperty(args[1], args[2], args.slice(3).join(" "));
                }
                else
                {
                    addOutput("Usage: set <object> <property> <value>", 0xFF8888);
                }
                
            case "new", "create":
                if (args.length > 1)
                {
                    createInstance(args[1], args.slice(2));
                }
                else
                {
                    addOutput("Usage: new <className> [args...]", 0xFF8888);
                }
                
            case "cursor":
                if (args.length > 1)
                {
                    if (args[1] == "show")
                    {
                        FlxG.mouse.visible = true;
                        addOutput("Cursor shown", 0x88FF88);
                    }
                    else if (args[1] == "hide")
                    {
                        FlxG.mouse.visible = false;
                        addOutput("Cursor hidden", 0x88FF88);
                    }
                    else
                    {
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
                
            case "memory", "mem":
                var stats = getMemoryStats();
                addOutput('Memory Stats:', 0x88FFFF);
                addOutput('Command history: ${commandHistory.length}/${maxHistorySize}', 0x88FFFF);
                addOutput('Output lines: ${outputText.text.split("\n").length}', 0x88FFFF);
                addOutput('HScript variables: ${countHScriptVariables()}', 0x88FFFF);
                
            case "copy":
                if (args.length > 1)
                {
                    switch(args[1].toLowerCase())
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
    
    private function showHelp():Void
    {
        var helpSections:Map<String, Array<String>> = [
            "Available commands:" => [
                "help - show this message",
                "clear - clear console", 
                "objects - list available runtime objects",
                "fields <object> - show object fields/properties",
                "set <object> <property> <value> - set property value",
                "call <object> <method> [args] - call method",
                "new <class> [args] - create new instance",
                "cursor [show|hide] - show/hide mouse cursor",
                "hscript - toggle HScript mode",
                "memory - show memory usage",
                "copy all - copy all console output",
                "copy input - copy current input"
            ],
            "Copy/Paste:" => [
                "Ctrl+C - copy selected text",
                "Ctrl+Shift+C - copy all output text",
                "Ctrl+V - paste from clipboard",
                "Ctrl+A - select all text in output",
                "Ctrl+Shift+A - select all and copy"
            ],
            "Navigation:" => [
                "Arrow keys - move cursor",
                "Shift+Arrows - select text in output",
                "Home/End - move to start/end of line", 
                "Shift+Home/End - select to start/end",
                "Shift+Enter - new line",
                "Drag title bar - move console"
            ],
            "HScript Examples:" => [
                "> FlxG.camera.zoom = 1.5",
                "> for (i in 0...10) trace(i)",
                "> var x = 10; x * 2"
            ]
        ];

        for (sectionTitle => sectionContent in helpSections) {
            addOutput(sectionTitle, 0x88FFFF);
            for (line in sectionContent) {
                addOutput("  " + line, 0x88FFFF);
            }
        }
    }
        
    function listAvailableObjects():Void
    {
        var variables = [];
        try
        {
            var ruleField = Reflect.field(hscript, "rule");
            if (ruleField != null)
            {
                var variablesField = Reflect.field(ruleField, "variables");
                if (variablesField != null)
                {
                    var map:Map<String, Dynamic> = cast variablesField;
                    for (key in map.keys())
                    {
                        variables.push(key);
                    }
                }
            }
        }
        catch (e:Dynamic) {}
        
        addOutput("Available objects:", 0xFFFF88);
        for (name in variables)
        {
            try
            {
                var value = hscript.get(name);
                var typeName = Type.getClassName(Type.getClass(value)) ?? "Dynamic";
                addOutput('  $name - $typeName', 0xFFFF88);
            }
            catch (e:Dynamic)
            {
                addOutput('  $name - <unknown>', 0xFFFF88);
            }
        }
    }
    
    private function inspectObject(objectName:String):Void
    {
        try
        {
            var obj = hscript.get(objectName);
            if (obj == null)
            {
                addOutput('Object "$objectName" not found', 0xFF8888);
                return;
            }
            
            addOutput('Fields and properties of $objectName:', 0x88FF88);
            
            var fields = Type.getInstanceFields(Type.getClass(obj));
            for (field in fields)
            {
                if (!field.startsWith("_"))
                {
                    try
                    {
                        var value = Reflect.field(obj, field);
                        var valueStr = value == null ? "null" : Std.string(value);
                        if (valueStr.length > 50) valueStr = valueStr.substr(0, 47) + "...";
                        addOutput('  $field = $valueStr', 0x88FF88);
                    }
                    catch (e:Dynamic)
                    {
                        addOutput('  $field = <cannot access>', 0xFF8888);
                    }
                }
            }
        }
        catch (e:Dynamic)
        {
            addOutput('Error inspecting object: $e', 0xFF8888);
        }
    }
    
    private function createInstance(className:String, args:Array<String>):Void
    {
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
            {
                parsedArgs.push(parseArgument(arg));
            }
            
            var instance:Dynamic = Type.createInstance(clazz, parsedArgs);
            
            var instanceName = 'instance_${Std.int(Math.random() * 10000)}';
            hscript.set(instanceName, instance);
            
            addOutput('Created instance: $instanceName of $className', 0x88FF88);
        }
        catch (e:Dynamic)
        {
            addOutput('Error creating instance: $e', 0xFF8888);
        }
    }
    
    private function parseArgument(arg:String):Dynamic
    {
        var intVal = Std.parseInt(arg);
        if (intVal != null) return intVal;
        
        var floatVal = Std.parseFloat(arg);
        if (!Math.isNaN(floatVal) && floatVal != 0) return floatVal;
        
        if (arg == "true") return true;
        if (arg == "false") return false;
        if (arg == "null") return null;
        
        return arg;
    }
    
    private function setProperty(objectName:String, propertyPath:String, valueExpr:String):Void
    {
        try
        {
            var obj = hscript.get(objectName);
            if (obj == null)
            {
                addOutput('Object "$objectName" not found', 0xFF8888);
                return;
            }
            
            var value:Dynamic = parseArgument(valueExpr);
            
            var parts = propertyPath.split(".");
            var targetObj = obj;
            
            for (i in 0...parts.length - 1)
            {
                targetObj = Reflect.field(targetObj, parts[i]);
                if (targetObj == null)
                {
                    addOutput('Property "${parts.slice(0, i + 1).join(".")}" not found', 0xFF8888);
                    return;
                }
            }
            
            var finalProp = parts[parts.length - 1];
            Reflect.setField(targetObj, finalProp, value);
            addOutput('Set $objectName.$propertyPath = $value', 0x88FF88);
        }
        catch (e:Dynamic)
        {
            addOutput('Error: $e', 0xFF8888);
        }
    }
    
    private function callMethod(objectName:String, methodPath:String, args:Array<String>):Void
    {
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
            {
                parsedArgs.push(parseArgument(arg));
            }
            
            var result = Reflect.callMethod(obj, Reflect.field(obj, methodPath), parsedArgs);
            addOutput('Result: $result', 0x88FF88);
        }
        catch (e:Dynamic)
        {
            addOutput('Error calling $objectName.$methodPath: $e', 0xFF8888);
        }
    }
    
    private function showConsole():Void
    {
        consoleVisible = true;
        console.visible = true;
        
        wasMouseVisible = FlxG.mouse.visible;
        FlxG.mouse.visible = true;
        
        console.stage.focus = hiddenInputField;
        hiddenInputField.text = "";
        
        currentInput = "";
        cursorPosition = 0;
        historyIndex = commandHistory.length;
        
        resetCursor();
        updateDisplay();
    }
    
    private function hideConsole():Void
    {
        consoleVisible = false;
        console.visible = false;
        
        FlxG.mouse.visible = wasMouseVisible;
        
        FlxG.stage.focus = FlxG.stage;
    }
    
    private function getMemoryStats():Dynamic
    {
        return {
            historySize: commandHistory.length,
            maxHistorySize: maxHistorySize,
            outputLines: outputText.text.split("\n").length,
            maxOutputLines: maxOutputLines,
            hscriptVars: countHScriptVariables()
        };
    }
    
    private function countHScriptVariables():Int
    {
        var count = 0;
        try
        {
            var ruleField = Reflect.field(hscript, "rule");
            if (ruleField != null)
            {
                var variablesField = Reflect.field(ruleField, "variables");
                if (variablesField != null)
                {
                    var map:Map<String, Dynamic> = cast variablesField;
                    for (_ in map.keys())
                    {
                        count++;
                    }
                }
            }
        }
        catch (e:Dynamic) {}
        return count;
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (FlxG.keys.justPressed.F12)
        {
            if (consoleVisible)
            {
                hideConsole();
            }
            else
            {
                showConsole();
            }
        }
        
        if (consoleVisible)
        {
            cursorTimer += elapsed;
            if (cursorTimer >= cursorBlinkRate)
            {
                cursorTimer = 0;
                cursorVisible = !cursorVisible;
                updateDisplay();
            }
            
            if (FlxG.stage.focus != hiddenInputField && FlxG.stage.focus != console && FlxG.stage.focus != outputText) {
                FlxG.stage.focus = hiddenInputField;
            }

            FlxG.keys.reset();
        }
    }
    
    override public function destroy():Void
    {
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        FlxG.stage.removeEventListener(TextEvent.TEXT_INPUT, onTextInput);
        console.removeEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
        console.removeEventListener(MouseEvent.MOUSE_DOWN, onConsoleMouseDown);
        titleBar.removeEventListener(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
        FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
        
        outputText.removeEventListener(MouseEvent.MOUSE_DOWN, onOutputMouseDown);
        outputText.removeEventListener(MouseEvent.MOUSE_MOVE, onOutputMouseMove);
        outputText.removeEventListener(MouseEvent.MOUSE_UP, onOutputMouseUp);

        console?.parent?.removeChild(console);
        hiddenInputField?.parent?.removeChild(hiddenInputField);
        hscript?.stop();

        super.destroy();
    }
}