package game.states;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end

import game.backend.system.Mods.ModMetadata;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxButtonPlus;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;

import lime.utils.Assets;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.utils.Assets as OpenFlAssets;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.format.JsonParser;
import haxe.zip.Reader;
import haxe.zip.Entry;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

#if MODS_ALLOWED
class ModsMenuState extends MusicBeatState
{
	static var changedAThing = false;
	static var curSelected:Int = 0;

    var mods:Array<ModMetadata> = [];
    var bg:FlxSprite;
    var intendedColor:Int;
    var colorTween:FlxTween;

    var noModsTxt:FlxText;
    var selector:AttachedSprite;
    var needaReset = false;

    public static final defaultColor:FlxColor = 0xFF665AFF;

    var buttonDown:FlxButton;
    var buttonTop:FlxButton;
    var buttonDisableAll:FlxButton;
    var buttonEnableAll:FlxButton;
    var buttonUp:FlxButton;
    var buttonToggle:FlxButton;
    var buttonExtract:FlxButton;
    var buttonsArray:Array<FlxButton> = [];

    var installButton:FlxButton;
    var removeButton:FlxButton;

    var modsList:Array<Dynamic> = [];

    var visibleWhenNoMods:Array<FlxBasic> = [];
    var visibleWhenHasMods:Array<FlxBasic> = [];

    var extractInfoTxt:FlxText;
    var isExtracting:Bool = false;

    var descriptionBg:FlxSprite;
    var descriptionText:FlxText;
    var descriptionScroll:Float = 0;
    var descriptionMaxScroll:Float = 0;

    override function create()
    {
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();
        WeekData.setDirectoryFromWeek();

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Menus", null);
        #end

        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.antialiasing = ClientPrefs.globalAntialiasing;
        add(bg);
        bg.screenCenter();

        noModsTxt = new FlxText(0, 0, FlxG.width, "NO MODS INSTALLED\nPRESS BACK TO EXIT AND INSTALL A MOD", 48);
        if(FlxG.random.bool(0.01)) noModsTxt.text += '\nBITCH.';
        noModsTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        noModsTxt.scrollFactor.set();
        noModsTxt.borderSize = 2;
        add(noModsTxt);
        noModsTxt.screenCenter();
        visibleWhenNoMods.push(noModsTxt);

        var path:String = Paths.txt('modsList');
        if(FileSystem.exists(path))
        {
            var leMods:Array<String> = CoolUtil.coolTextFile(path);
            for (i in 0...leMods.length)
            {
                if(leMods.length > 1 && leMods[0].length > 0) {
                    var modSplit:Array<String> = leMods[i].split('|');
                    if(!Mods.ignoreModFolders.contains(modSplit[0].toLowerCase()))
                    {
                        addToModsList([modSplit[0], (modSplit[1] == '1')]);
                    }
                }
            }
        }

        if (FileSystem.exists(path)){
            for (folder in Mods.getModDirectories())
            {
                if(!Mods.ignoreModFolders.contains(folder))
                {
                    if (Mods.modExists(folder)) {
                        var alreadyInList = false;
                        for (mod in modsList) {
                            if (mod[0] == folder) {
                                alreadyInList = true;
                                break;
                            }
                        }
                        if (!alreadyInList) {
                            addToModsList([folder, true]);
                        }
                    }
                }
            }
        }
        saveTxt();

        selector = new AttachedSprite();
        selector.xAdd = -205;
        selector.yAdd = -68;
        selector.alphaMult = 0.5;
        makeSelectorGraphic();
        add(selector);
        visibleWhenHasMods.push(selector);

        var startX:Int = 1120;

        buttonToggle = new FlxButton(startX, 0, "ON", function()
        {
            if(mods[curSelected].restart)
            {
                needaReset = true;
            }
            modsList[curSelected][1] = !modsList[curSelected][1];
            updateButtonToggle();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        });
        buttonToggle.setGraphicSize(50, 50);
        buttonToggle.updateHitbox();
        add(buttonToggle);
        buttonsArray.push(buttonToggle);
        visibleWhenHasMods.push(buttonToggle);

        buttonToggle.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
        setAllLabelsOffset(buttonToggle, -15, 10);
        startX -= 70;

        buttonUp = new FlxButton(startX, 0, "/\\", function()
        {
            moveMod(-1);
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        });
        buttonUp.setGraphicSize(50, 50);
        buttonUp.updateHitbox();
        add(buttonUp);
        buttonsArray.push(buttonUp);
        visibleWhenHasMods.push(buttonUp);
        buttonUp.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
        setAllLabelsOffset(buttonUp, -15, 10);
        startX -= 70;

        buttonDown = new FlxButton(startX, 0, "\\/", function() {
            moveMod(1);
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        });
        buttonDown.setGraphicSize(50, 50);
        buttonDown.updateHitbox();
        add(buttonDown);
        buttonsArray.push(buttonDown);
        visibleWhenHasMods.push(buttonDown);
        buttonDown.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
        setAllLabelsOffset(buttonDown, -15, 10);

        startX -= 100;
        buttonTop = new FlxButton(startX, 0, "TOP", function() {
            var doRestart:Bool = (mods[0].restart || mods[curSelected].restart);
            for (i in 0...curSelected)
            {
                moveMod(-1, true);
            }

            if(doRestart) needaReset = true;
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        });
        buttonTop.setGraphicSize(80, 50);
        buttonTop.updateHitbox();
        buttonTop.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
        setAllLabelsOffset(buttonTop, 0, 10);
        add(buttonTop);
        buttonsArray.push(buttonTop);
        visibleWhenHasMods.push(buttonTop);

        startX -= 190;
        buttonDisableAll = new FlxButton(startX, 0, "DISABLE ALL", function() {
            for (i in modsList)
            {
                i[1] = false;
            }
            for (mod in mods)
            {
                if (mod.restart)
                {
                    needaReset = true;
                    break;
                }
            }
            updateButtonToggle();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        });
        buttonDisableAll.setGraphicSize(170, 50);
        buttonDisableAll.updateHitbox();
        buttonDisableAll.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
        buttonDisableAll.label.fieldWidth = 170;
        setAllLabelsOffset(buttonDisableAll, 0, 10);
        add(buttonDisableAll);
        buttonsArray.push(buttonDisableAll);
        visibleWhenHasMods.push(buttonDisableAll);

        startX -= 190;
        buttonEnableAll = new FlxButton(startX, 0, "ENABLE ALL", function() {
            for (i in modsList)
            {
                i[1] = true;
            }
            for (mod in mods)
            {
                if (mod.restart)
                {
                    needaReset = true;
                    break;
                }
            }
            updateButtonToggle();
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
        });
        buttonEnableAll.setGraphicSize(170, 50);
        buttonEnableAll.updateHitbox();
        buttonEnableAll.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
        buttonEnableAll.label.fieldWidth = 170;
        setAllLabelsOffset(buttonEnableAll, 0, 10);
        add(buttonEnableAll);
        buttonsArray.push(buttonEnableAll);
        visibleWhenHasMods.push(buttonEnableAll);

        startX -= 120;
        buttonExtract = new FlxButton(startX, 0, "EXTRACT", function() {
            if (!isExtracting && mods.length > 0 && Mods.isZipMod(modsList[curSelected][0])) {
                extractSelectedMod();
            } else {
                FlxG.sound.play(Paths.sound('cancelMenu'));
            }
        });
        buttonExtract.setGraphicSize(100, 50);
        buttonExtract.updateHitbox();
        buttonExtract.label.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.BLACK, CENTER);
        buttonExtract.label.fieldWidth = 100;
        setAllLabelsOffset(buttonExtract, 0, 15);
        add(buttonExtract);
        buttonsArray.push(buttonExtract);
        visibleWhenHasMods.push(buttonExtract);

        extractInfoTxt = new FlxText(148, 0, FlxG.width - 216, "", 16);
        extractInfoTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.YELLOW, LEFT);
        extractInfoTxt.scrollFactor.set();
        add(extractInfoTxt);
        visibleWhenHasMods.push(extractInfoTxt);

        descriptionBg = new FlxSprite(148, 0).makeGraphic(FlxG.width - 275, 120, FlxColor.BLACK);
        descriptionBg.alpha = 0.6;
        descriptionBg.scrollFactor.set();
        add(descriptionBg);
        visibleWhenHasMods.push(descriptionBg);

        descriptionText = new FlxText(descriptionBg.x + 5, descriptionBg.y + 5, descriptionBg.width, "", 16);
        descriptionText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
        descriptionText.scrollFactor.set();
        add(descriptionText);
        visibleWhenHasMods.push(descriptionText);

        remove(descriptionText);
        remove(descriptionBg);
        add(descriptionBg);
        add(descriptionText);

        var i:Int = 0;
        var len:Int = modsList.length;
        while (i < modsList.length)
        {
            var values:Array<Dynamic> = modsList[i];
            if(!Mods.modExists(values[0]))
            {
                modsList.remove(modsList[i]);
                continue;
            }

            var newMod:ModMetadata = new ModMetadata(values[0]);
            mods.push(newMod);

            newMod.alphabet = new Alphabet(0, 0, mods[i].name, true);
            var scale:Float = Math.min(840 / newMod.alphabet.width, 1);
            newMod.alphabet.scaleX = scale;
            newMod.alphabet.scaleY = scale;
            newMod.alphabet.y = i * 150;
            newMod.alphabet.x = 310;
            add(newMod.alphabet);
            
            var loadedIcon:BitmapData = null;
            var iconBytes = null;
            for (ext in Paths.IMAGE_EXTS) {
                iconBytes = Mods.getFileFromMod(values[0], 'pack.$ext');
                if (iconBytes != null) break;
            }
            if(iconBytes != null)
            {
                try {
                    loadedIcon = BitmapData.fromBytes(iconBytes);
                } catch(e:Dynamic) {
                    trace('Error loading icon for mod ${values[0]}: $e');
                }
            }

            newMod.icon = new AttachedSprite();
            if(loadedIcon != null)
            {
                newMod.icon.loadGraphic(loadedIcon, true, 150, 150);
                var totalFrames = Math.floor(loadedIcon.width / 150) * Math.floor(loadedIcon.height / 150);
                newMod.icon.animation.add("icon", [for (i in 0...totalFrames) i],10);
                newMod.icon.animation.play("icon");
            }
            else
            {
                newMod.icon.loadGraphic(Paths.image('unknownMod'));
            }
            newMod.icon.sprTracker = newMod.alphabet;
            newMod.icon.xAdd = -newMod.icon.width - 30;
            newMod.icon.yAdd = -45;
            add(newMod.icon);
            i++;
        }

        if(curSelected >= mods.length) curSelected = 0;

        if(mods.length < 1)
            bg.color = defaultColor;
        else
            bg.color = mods[curSelected].color;

        intendedColor = bg.color;
        changeSelection();
        updatePosition();
        FlxG.sound.play(Paths.sound('scrollMenu'));

        FlxG.mouse.visible = true;

        super.create();
    }

    function updateDescriptionText()
    {
        if (mods.length == 0 || curSelected >= mods.length) return;

        var mod = mods[curSelected];
        var description = mod.description;
        if (mod.restart)
            description += " (This Mod will restart the game!)";
        
        descriptionText.text = description;
        
        descriptionText.autoSize = true;

        var textHeight = descriptionText.height;
        descriptionText.autoSize = false;
        descriptionMaxScroll = Math.max(0, textHeight - descriptionBg.height + 10);
        descriptionScroll = 0;
        descriptionText.y = descriptionBg.y + 5;
        descriptionText.clipRect = null;
    }

    function addToModsList(values:Array<Dynamic>)
    {
        for (i in 0...modsList.length)
        {
            if(modsList[i][0] == values[0])
            {
                return;
            }
        }
        modsList.push(values);
    }

    function updateButtonToggle()
    {
        if (modsList[curSelected][1])
        {
            buttonToggle.label.text = 'ON';
            buttonToggle.color = FlxColor.GREEN;
        }
        else
        {
            buttonToggle.label.text = 'OFF';
            buttonToggle.color = FlxColor.RED;
        }
    }

    function moveMod(change:Int, skipResetCheck:Bool = false)
    {
        if(mods.length > 1)
        {
            var doRestart:Bool = (mods[0].restart);

            var newPos:Int = curSelected + change;
            if(newPos < 0)
            {
                modsList.push(modsList.shift());
                mods.push(mods.shift());
            }
            else if(newPos >= mods.length)
            {
                modsList.insert(0, modsList.pop());
                mods.insert(0, mods.pop());
            }
            else
            {
                var lastArray:Array<Dynamic> = modsList[curSelected];
                modsList[curSelected] = modsList[newPos];
                modsList[newPos] = lastArray;

                var lastMod:ModMetadata = mods[curSelected];
                mods[curSelected] = mods[newPos];
                mods[newPos] = lastMod;
            }
            changeSelection(change);

            if(!doRestart) doRestart = mods[curSelected].restart;
            if(!skipResetCheck && doRestart) needaReset = true;
        }
    }

    function saveTxt()
    {
        var fileStr:String = '';
        for (values in modsList)
        {
            if(fileStr.length > 0) fileStr += '\n';
            fileStr += values[0] + '|' + (values[1] ? '1' : '0');
        }

        var path:String = 'modsList';
        File.saveContent(Paths.txt(path), fileStr);
        Mods.pushGlobalMods();
    }

    function extractSelectedMod() {
        if (mods.length == 0) return;

        var modName = modsList[curSelected][0];
        
        if (!Mods.isZipMod(modName)) {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            return;
        }

        var info = Mods.getZipModInfo(modName);
        var sizeMB = Math.round(info.size / (1024 * 1024) * 100) / 100;
        
        var confirmText = 'Extract "${mods[curSelected].name}"?\n';
        confirmText += 'Files: ${info.fileCount}, Size: ${sizeMB} MB\n';
        confirmText += 'This may take a while for large mods.\n';
        
        var confirmSubState = new ModExtractConfirmSubstate(confirmText, function(confirmed:Bool) {
            if (confirmed) {
                isExtracting = true;
                for (button in buttonsArray) {
                    button.visible = false;
                }
                
                openSubState(new ModExtractProgressSubstate(modName, info.fileCount, function(success) {
                    if (success) {
                        FlxG.sound.play(Paths.sound('confirmMenu'));
                        extractInfoTxt.text = "Extraction complete! ZIP deleted.";
                        
                        FlxG.camera.flash(FlxColor.GREEN, 0.5, () -> {
                            FlxG.resetState();
                        });
                    } else {
                        FlxG.sound.play(Paths.sound('cancelMenu'));
                        extractInfoTxt.text = "Extraction failed or cancelled!";
                        
                        new FlxTimer().start(2, (_) -> {
                            isExtracting = false;
                            for (button in buttonsArray) {
                                button.visible = true;
                            }
                            extractInfoTxt.text = "";
                            changeSelection();
                        });
                    }
                }));
            }
        });
        
        openSubState(confirmSubState);
    }

    var noModsSine:Float = 0;
    var canExit:Bool = true;
    override function update(elapsed:Float)
    {
        if(noModsTxt.visible)
        {
            noModsSine += 180 * elapsed;
            noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);
        }

        if (!isExtracting)
        {
            if (mods.length > 0 && descriptionMaxScroll > 0) {
                var mouseWheel = FlxG.mouse.wheel;
                if (mouseWheel != 0) {
                    descriptionScroll -= mouseWheel * 30;
                    descriptionScroll = FlxMath.bound(descriptionScroll, 0, descriptionMaxScroll);
                    descriptionText.y = descriptionBg.y + 5 - descriptionScroll;
                }
                
                if (controls.UI_UP_P) {
                    descriptionScroll -= 40;
                    descriptionScroll = FlxMath.bound(descriptionScroll, 0, descriptionMaxScroll);
                    descriptionText.y = descriptionBg.y + 5 - descriptionScroll;
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
                }

                if (controls.UI_DOWN_P) {
                    descriptionScroll += 40;
                    descriptionScroll = FlxMath.bound(descriptionScroll, 0, descriptionMaxScroll);
                    descriptionText.y = descriptionBg.y + 5 - descriptionScroll;
                    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
                }
            }

            if(canExit && controls.BACK)
            {
                colorTween?.cancel();

                FlxG.sound.play(Paths.sound('cancelMenu'));
                FlxG.mouse.visible = false;

                saveTxt();
                if(needaReset)
                {
                    TitleState.initialized = false;
                    TitleState.closedState = false;
                    FlxG.sound?.music?.fadeOut(0.3);
                    FreeplayState.vocals?.fadeOut(0.3);
                    FreeplayState.vocals = null;
                    FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
                }
                else
                {
                    FlxG.switchState(() -> new MainMenuState());
                }
            }

            if(controls.UI_UP_P)
            {
                changeSelection(-1);
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }

            if(controls.UI_DOWN_P)
            {
                changeSelection(1);
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }
        }

        updatePosition(elapsed);
        super.update(elapsed);
    }

    function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
    {
        for (point in button.labelOffsets)
        {
            point.set(x, y);
        }
    }

    function changeSelection(change:Int = 0)
    {
        var noMods:Bool = (mods.length < 1);
        for (obj in visibleWhenHasMods)
        {
            obj.visible = !noMods;
        }
        for (obj in visibleWhenNoMods)
        {
            obj.visible = noMods;
        }
        if(noMods) return;

        curSelected += change;
        if(curSelected < 0)
            curSelected = mods.length - 1;
        else if(curSelected >= mods.length)
            curSelected = 0;

        descriptionScroll = 0;

        if (buttonExtract != null) {
            var isZipMod = Mods.isZipMod(modsList[curSelected][0]);
            buttonExtract.visible = isZipMod && !isExtracting;
            
            if (isZipMod) {
                var info = Mods.getZipModInfo(modsList[curSelected][0]);
                var sizeMB = Math.round(info.size / (1024 * 1024) * 100) / 100;
                extractInfoTxt.text = 'ZIP Mod: ${info.fileCount} files, ${sizeMB} MB';
            } else {
                extractInfoTxt.text = "";
            }
        }

        var newColor:Int = mods[curSelected].color;
        if(newColor != intendedColor) {
            colorTween?.cancel();
            intendedColor = newColor;
            colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
                onComplete: (_) -> colorTween = null
            });
        }

        var i:Int = 0;
        for (mod in mods)
        {
            mod.alphabet.alpha = 0.6;
            if(i == curSelected)
            {
                mod.alphabet.alpha = 1;
                selector.sprTracker = mod.alphabet;
                
                updateDescriptionText();
                
                var stuffArray:Array<FlxSprite> = [descriptionBg, descriptionText, selector, mod.alphabet, mod.icon];
                for (obj in stuffArray)
                {
                    remove(obj);
                    insert(members.length, obj);
                }
                
                for (obj in buttonsArray)
                {
                    remove(obj);
                    insert(members.length, obj);
                }
            }
            i++;
        }
        updateButtonToggle();
    }

    function updatePosition(elapsed:Float = -1)
    {
        var i:Int = 0;
        for (mod in mods)
        {
            var intendedPos:Float = (i - curSelected) * 225 + 200;
            if(i > curSelected) intendedPos += 225;
            mod.alphabet.y = (elapsed != -1) ? FlxMath.lerp(mod.alphabet.y, intendedPos, MathUtil.boundTo(elapsed * 12, 0, 1)) : intendedPos;

            if(i == curSelected)
            {
                var descriptionY = mod.alphabet.y + 160;
                descriptionBg.y = descriptionY;
                descriptionText.y = descriptionY + 5 - descriptionScroll;
                
                extractInfoTxt.y = mod.alphabet.y + 290;
                for (button in buttonsArray)
                {
                    button.y = mod.alphabet.y + 310;
                }
            }
            i++;
        }
    }

    var cornerSize:Int = 11;
    function makeSelectorGraphic()
    {
        selector.makeGraphic(1100, 450, FlxColor.BLACK);
        selector.pixels.fillRect(new Rectangle(0, 190, selector.width, 5), 0x0);

        selector.pixels.fillRect(new Rectangle(0, 0, cornerSize, cornerSize), 0x0);
        drawCircleCornerOnSelector(false, false);
        selector.pixels.fillRect(new Rectangle(selector.width - cornerSize, 0, cornerSize, cornerSize), 0x0);
        drawCircleCornerOnSelector(true, false);
        selector.pixels.fillRect(new Rectangle(0, selector.height - cornerSize, cornerSize, cornerSize), 0x0);
        drawCircleCornerOnSelector(false, true);
        selector.pixels.fillRect(new Rectangle(selector.width - cornerSize, selector.height - cornerSize, cornerSize, cornerSize), 0x0);
        drawCircleCornerOnSelector(true, true);
    }

    function drawCircleCornerOnSelector(flipX:Bool, flipY:Bool)
    {
        var antiX:Float = (selector.width - cornerSize);
        var antiY:Float = flipY ? (selector.height - 1) : 0;
        if(flipY) antiY -= 2;
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 1), Std.int(Math.abs(antiY - 8)), 10, 3), FlxColor.BLACK);
        if(flipY) antiY += 1;
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 2), Std.int(Math.abs(antiY - 6)),  9, 2), FlxColor.BLACK);
        if(flipY) antiY += 1;
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 3), Std.int(Math.abs(antiY - 5)),  8, 1), FlxColor.BLACK);
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 4), Std.int(Math.abs(antiY - 4)),  7, 1), FlxColor.BLACK);
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 5), Std.int(Math.abs(antiY - 3)),  6, 1), FlxColor.BLACK);
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 6), Std.int(Math.abs(antiY - 2)),  5, 1), FlxColor.BLACK);
        selector.pixels.fillRect(new Rectangle((flipX ? antiX : 8), Std.int(Math.abs(antiY - 1)),  3, 1), FlxColor.BLACK);
    }
}

class ModExtractConfirmSubstate extends MusicBeatSubstate
{
    var callback:Bool->Void;
    var background:FlxSprite;
    var text:FlxText;
    var yesButton:FlxButton;
    var noButton:FlxButton;

    public function new(message:String, callback:Bool->Void)
    {
        super();

        this.callback = callback;

        background = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        background.alpha = 0.8;
        add(background);

        text = new FlxText(50, FlxG.height / 2 - 150, FlxG.width - 100, message, 24);
        text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
        add(text);

        var warningText = new FlxText(50, FlxG.height / 2 + 20, FlxG.width - 100, 
            "Note: Original ZIP file will be deleted after successful extraction.", 16);
        warningText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.YELLOW, CENTER);
        add(warningText);

        yesButton = new FlxButton(FlxG.width / 2 - 120, FlxG.height / 2 + 70, "YES", () -> {
            close();
            callback(true);
        });
        yesButton.setGraphicSize(100, 50);
        add(yesButton);

        noButton = new FlxButton(FlxG.width / 2 + 20, FlxG.height / 2 + 70, "NO", () -> {
            close();
            callback(false);
        });
        noButton.setGraphicSize(100, 50);
        add(noButton);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE || controls.BACK) {
            close();
            callback(false);
        }
    }
}

class ModExtractProgressSubstate extends MusicBeatSubstate
{
    var mod:String;
    var callback:Bool->Void;
    var background:FlxSprite;
    var progressText:FlxText;
    var progressBar:FlxSprite;
    var progressBarBg:FlxSprite;
    var cancelButton:FlxButton;
    
    var totalFiles:Int = 0;
    var extractedFiles:Int = 0;
    var isExtracting:Bool = true;
    var extractionSuccess:Bool = false;

    public function new(mod:String, totalFiles:Int, callback:Bool->Void)
    {
        super();
        this.mod = mod;
        this.totalFiles = totalFiles;
        this.callback = callback;
    }

    override function create()
    {
        super.create();
        
        background = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        background.alpha = 0.8;
        add(background);

        var titleText = new FlxText(0, FlxG.height / 2 - 100, FlxG.width, "Extracting Mod...", 32);
        titleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
        titleText.screenCenter(X);
        add(titleText);

        progressBarBg = new FlxSprite(FlxG.width / 2 - 150, FlxG.height / 2 - 25);
        progressBarBg.makeGraphic(300, 30, FlxColor.GRAY);
        add(progressBarBg);

        progressBar = new FlxSprite(FlxG.width / 2 - 148, FlxG.height / 2 - 23);
        progressBar.makeGraphic(1, 26, FlxColor.GREEN);
        add(progressBar);

        progressText = new FlxText(0, FlxG.height / 2 + 20, FlxG.width, "Preparing...", 24);
        progressText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
        progressText.screenCenter(X);
        add(progressText);

        cancelButton = new FlxButton(FlxG.width / 2 - 50, FlxG.height / 2 + 70, "CANCEL", () -> {
            isExtracting = false;
            close();
            callback(false);
        });
        cancelButton.setGraphicSize(100, 40);
        add(cancelButton);

        new FlxTimer().start(0.1, (_) -> startExtraction());
    }

    function startExtraction() {
        if (!isExtracting) return;
        
        var frameCallback:openfl.events.Event->Void = null;
        frameCallback = (_) -> {
            FlxG.stage.removeEventListener(openfl.events.Event.ENTER_FRAME, frameCallback);
            
            try {
                extractionSuccess = extractWithProgress();
                
                if (extractionSuccess) {
                    Mods.deleteZipMod(mod);
                    
                    progressText.text = "Extraction complete!";
                    progressBar.makeGraphic(296, 26, FlxColor.GREEN);
                    
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                    new FlxTimer().start(1, (_) -> {
                        close();
                        callback(true);
                    });
                } else {
                    progressText.text = "Extraction failed!";
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                    new FlxTimer().start(2, (_) -> {
                        close();
                        callback(false);
                    });
                }
            } catch (e:Dynamic) {
                trace('Error during extraction: $e');
                progressText.text = "Extraction error!";
                FlxG.sound.play(Paths.sound('cancelMenu'));
                new FlxTimer().start(2, (_) -> {
                    close();
                    callback(false);
                });
            }
        };
        FlxG.stage.addEventListener(openfl.events.Event.ENTER_FRAME, frameCallback);
    }

    function extractWithProgress():Bool {
        if (!Mods.isZipMod(mod)) {
            return false;
        }

        var zipPath = '${Mods.getModPath(mod)}.zip';
        var extractPath = Mods.getModPath(mod);

        if (FileSystem.exists(extractPath)) return false;

        try {
            FileSystem.createDirectory(extractPath);

            var bytes = File.getBytes(zipPath);
            var input = new BytesInput(bytes);
            var entriesList = Reader.readZip(input);
            var entries:Array<Entry> = [];
            
            var iter = entriesList.iterator();
            while (iter.hasNext()) {
                entries.push(iter.next());
            }
            
            var fileCount = 0;
            
            for (entry in entries) {
                var fileName:String = entry.fileName;
                if (!StringTools.endsWith(fileName, "/")) {
                    fileCount++;
                }
            }
            
            totalFiles = fileCount;
            extractedFiles = 0;

            var hasRootFolder = true;
            var rootFolderName:String = null;
            
            for (entry in entries) {
                var fileName:String = entry.fileName;
                var parts = fileName.split('/');
                
                if (rootFolderName == null && parts.length > 0 && parts[0] != '') {
                    rootFolderName = parts[0];
                }
                
                if (parts.length == 1 && !StringTools.endsWith(fileName, "/")) {
                    hasRootFolder = false;
                    break;
                }
            }

            var shouldStripRootFolder = (hasRootFolder && rootFolderName != null && rootFolderName == mod);

            for (entry in entries) {
                if (!isExtracting) {
                    Mods.deleteDirectory(extractPath);
                    return false;
                }
                
                var fileName:String = entry.fileName;
                
                if (StringTools.endsWith(fileName, "/")) {
                    continue;
                }

                var targetFileName:String = fileName;
                
                if (shouldStripRootFolder && StringTools.startsWith(fileName, rootFolderName + '/')) {
                    targetFileName = fileName.substring(rootFolderName.length + 1);
                }

                var fullPath:String = extractPath + "/" + targetFileName;
                
                var dirPath = haxe.io.Path.directory(fullPath);
                if (!FileSystem.exists(dirPath)) {
                    FileSystem.createDirectory(dirPath);
                }
                
                var data = Reader.unzip(entry);
                File.saveBytes(fullPath, data);
                extractedFiles++;

                var progress = extractedFiles / totalFiles;
                var barWidth = Std.int(296 * progress);
                progressBar.makeGraphic(barWidth, 26, FlxColor.GREEN);
                
                progressText.text = 'Extracting: $extractedFiles/$totalFiles (${Std.int(progress * 100)}%)';
            }

            Mods.zipModsCache.remove(mod);
            return true;

        } catch (e:Dynamic) {
            trace('Error extracting ZIP mod $mod: $e');
            
            try {
                if (FileSystem.exists(extractPath)) {
                    Mods.deleteDirectory(extractPath);
                }
            } catch (cleanupError:Dynamic) {
                trace('Error cleaning up after failed extraction: $cleanupError');
            }
            
            return false;
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE || controls.BACK) {
            isExtracting = false;
            close();
            callback(false);
        }
    }
}
#end