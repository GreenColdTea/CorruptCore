package game.states.editors;

import game.objects.Note;
import game.objects.NoteSplash;
import game.objects.StrumNote;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.input.keyboard.FlxKey;

import haxe.Json;

@:access(game.objects.NoteSplash)
@:access(game.objects.Note.colArray)
class NoteSplashEditorState extends MusicBeatState
{
    var strums:FlxTypedSpriteGroup<StrumNote> = new FlxTypedSpriteGroup();
    var splashes:FlxTypedSpriteGroup<NoteSplash> = new FlxTypedSpriteGroup();
    var ghosts:FlxTypedSpriteGroup<NoteSplash> = new FlxTypedSpriteGroup<NoteSplash>();
    var config = NoteSplash.createConfig();

    var tipText:FlxText;
    var errorText:FlxText;
    var curText:FlxText;

    static var imageSkin:String = null;
    var splash:NoteSplash;

    var UI:PsychUIBox;
    var properUI:PsychUIBox;

    var showGhosts:Bool = false;
    var ghostAlpha:Float = 0.3;
    var ghostCheckbox:PsychUICheckBox;

    override function create()
    {
        imageSkin ??=  NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();

        FlxG.mouse.enabled = true;
        FlxG.mouse.visible = true;

        FlxG.sound.volumeUpKeys = [];
        FlxG.sound.volumeDownKeys = [];
        FlxG.sound.muteKeys = [];

        #if DISCORD_ALLOWED
        api.Discord.DiscordClient.changePresence('Note Splash Editor');
        #end

        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.scrollFactor.set();
        bg.color = 0xFF505050;
        add(bg);      

        UI = new PsychUIBox(0, 0, 0, 0, ["Animation"]);
        UI.canMove = UI.canMinimize = false;
        UI.y += 20;
        UI.x = FlxG.width - 300;
        UI.resize(290, 240);

        properUI = new PsychUIBox(0, 0, 0, 0, ["Properties"]);
        properUI.canMove = properUI.canMinimize = false;
        properUI.resize(280, 240);
        properUI.y += 20;
        properUI.x = UI.x - properUI.width - 5;
        add(properUI);
        add(UI);

        var tipText:FlxText = new FlxText();
        tipText.setFormat(null, 24);
        tipText.text = "Press F1 for Help";
        tipText.setPosition(properUI.x - properUI.width + 15, UI.y);
        add(tipText);

        for (i in 0...4)
        {
            var babyArrow:StrumNote = new StrumNote(-273, 50, i % 4, 1);
            babyArrow.postAddedToGroup();
            babyArrow.screenCenter(Y);
            babyArrow.ID = i;
            strums.add(babyArrow);
        }

        add(strums);
        add(ghosts);
        add(splashes);

        splash = new NoteSplash(0, 0, imageSkin);
        splash.inEditor = true;
        splash.alpha = .0;
        splashes.add(splash);

        if (splash.config != null)
            config = splash.config;

        addPropertiesTab();
        addAnimTab();

        errorText = new FlxText();
        errorText.setFormat(null, 16, FlxColor.RED);
        errorText.text = "ERROR!";
        errorText.y = FlxG.height - errorText.height;
        errorText.alpha = .0;
        add(errorText);

        curText = new FlxText();
        curText.setFormat(null, 24, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        curText.text = 'Copied Offsets: [0, 0]\nCurrent Animation: NONE';
        curText.y = FlxG.height - curText.height;
        curText.x += 5;
        add(curText);

        super.create();
    }

    var animDropDown:PsychUIDropDownMenu;
    var curAnim:String;
    var addButton:PsychUIButton;
    var curAnimText = null;
    var numericStepperData:PsychUINumericStepper;
    var templateButton:PsychUIButton;
    function addAnimTab()
    {
        var UI = UI.getTab("Animation").menu;

        UI.add(new FlxText(20, 20, 0, "Animation Name:", 8));
        var name_input:PsychUIInputText = new PsychUIInputText(20, 37.5, 100, "", 8);
        name_input.name = "name_input";
        curAnimText = name_input;
        UI.add(name_input);

        UI.add(new FlxText(name_input.x, name_input.y + 30, 0, "Animation Prefix:", 8));
        var prefix_input:PsychUIInputText = new PsychUIInputText(20, name_input.y + 47.5, 100, "", 8);
        UI.add(prefix_input);

        UI.add(new FlxText(150, 20, 0, "Note Data:"));
        numericStepperData = new PsychUINumericStepper(150, 37.5, 1, .0, .0, 999, 0);

        numericStepperData.onValueChange = function() {
            if (curAnim != null && config?.animations.exists(curAnim)) {
                var animData = config.animations.get(curAnim);
                animData.noteData = Std.int(numericStepperData.value);
                config.animations.set(curAnim, animData);
                
                updatePreviewSplash();
            }
        };

        UI.add(numericStepperData);

        UI.add(new FlxText(150, name_input.y + 30, 0, "Indices (OPTIONAL):"));
        var indices_input:PsychUIInputText = new PsychUIInputText(150, name_input.y + 47.5, 100, "", 8);
        UI.add(indices_input);

        UI.add(new FlxText(20, 110, 0, "Min FPS:"));
        var minFps:PsychUINumericStepper = new PsychUINumericStepper(20, 127.5, 1, 22, 1, 120);
        UI.add(minFps);

        UI.add(new FlxText(150, 110, 0, "Max FPS:"));
        var maxFps:PsychUINumericStepper = new PsychUINumericStepper(150, 127.5, 1, 26, 1, 120);
        UI.add(maxFps);

        animDropDown = new PsychUIDropDownMenu(130, 57, [""], function(id:Int, name:String)
        {
            if (config != null && name.length > 0)
            {
                var i = config.animations.get(name);
                if (i != null)
                {
                    name_input.text = name;
                    prefix_input.text = i.prefix; 
                    numericStepperData.min = 0;     
                    numericStepperData.value = i.noteData;
                    curAnim = name;
                    minFps.value = i.fps[0];
                    maxFps.value = i.fps[1];
                    if (i.indices?.length > 0)
                        indices_input.text = i.indices.toString().substring(1, i.indices.toString().length - 2);

                    updatePreviewSplash();
                }
            }
        });

        function setAnimDropDown()
        {
            var anims:Array<String> = [];
            if (config != null && config.animations != null)
                for (i in config.animations.keys())
                {
                    anims.push(i);
                }

            if (anims.length < 1)
                anims.push("");

            if (curAnim == null && anims[0].length > 0)
                curAnim = anims[0];

            animDropDown.list = anims;
            animDropDown.selectedLabel = curAnim;
        }

        setAnimDropDown();

        templateButton.onClick = function()
        {
            NoteSplash.configs.clear();
            config = NoteSplash.createConfig();

            curAnim = null;
            name_input.text = "";
            prefix_input.text = "";        
            indices_input.text = "";  
            numericStepperData.value = 0;
            minFps.value = 22;
            maxFps.value = 26;
            setAnimDropDown();
            clearGhosts();
            updatePreviewSplash();
        }

        addButton = new PsychUIButton(20, 185, "Add/Update", function()
        {       
            var indices:Array<Int> = [];
            if (indices_input.text.split(',').length > 1)
            {
                for (i in indices_input.text.split(','))
                {
                    var index:Null<Int> = Std.parseInt(i);
                    if (!Math.isNaN(index) && index != null)
                    {
                        indices.push(index);
                    }
                }
            }

            var offsets:Array<Float> = [0, 0];
            var conf = config.animations.get(name_input.text);

            if (conf != null)
                offsets = conf.offsets;

            if (offsets == null)
                offsets = [0, 0];
            else 
                offsets = offsets.copy();

            config = NoteSplash.addAnimationToConfig(config, scaleNumericStepper.value, name_input.text, prefix_input.text, [cast minFps.value, cast maxFps.value], offsets, indices, cast numericStepperData.value);
            curAnim = name_input.text;
            updatePreviewSplash();
            setAnimDropDown();
        }); 
        UI.add(addButton);

        var removeButton:PsychUIButton = new PsychUIButton(185, 185, "Remove", function()
        {
            if (config != null)
            {
                if (config.animations.exists(curAnim))
                { 
                    config.animations.remove(curAnim);

                    curAnim = null;
                    name_input.text = "";
                    prefix_input.text = "";
                    indices_input.text = "";  
                    numericStepperData.value = 0;
                    setAnimDropDown();
                    clearGhosts();
                    updatePreviewSplash();
                }
            }
        });
        UI.add(removeButton);
        properUI.getTab("Properties").menu.add(animDropDown);

        reloadImage = function()
        {
            imageSkin = imageInputText.text;

            errorText.color = FlxColor.RED;
            FlxTween.cancelTweensOf(errorText);

            var image = Paths.image(imageSkin);
            if (image == null)
            {
                var triedExtensions:String = Paths.IMAGE_EXTS.join(", ");
                errorText.text = 'ERROR! Couldn\'t find $imageSkin.[$triedExtensions]';
                errorText.alpha = 1;
                return;
            }
            else
            {
                errorText.color = FlxColor.GREEN;
                errorText.alpha = 1;
                errorText.text = 'Successfully loaded $imageSkin (format auto-detected)';
            }

            NoteSplash.configs.clear();

            FlxTween.tween(errorText, {alpha: 0}, 1, {startDelay: 1, onComplete: (twn) -> {
                errorText.color = FlxColor.RED;
            }});

            splash.loadSplash(imageSkin);
            splash.alpha = 0.0001;

            if (splash.config != null) config = splash.config;
            else config = NoteSplash.createConfig();

            scaleNumericStepper.value = config.scale;

            curAnim = null;
            name_input.text = "";
            prefix_input.text = "";        
            indices_input.text = "";  
            numericStepperData.value = 0;
            minFps.value = 22;
            maxFps.value = 26;
            setAnimDropDown();
            clearGhosts();
            updatePreviewSplash();
        }
    }

    function updatePreviewSplash()
    {
        if (splash == null || curAnim == null || !config.animations.exists(curAnim)) 
        {
            splash.alpha = 0.0001;
            return;
        }

        var animData = config.animations.get(curAnim);
        if (animData == null) return;

        clearOldSplashes();

        splash.scale.set(config.scale, config.scale);
        splash.updateHitbox();

        splash.config = config;
        
        var strum = strums.members[animData.noteData % 4];
        if (strum != null)
        {
            splash.babyArrow = strum;
            splash.x = strum.x - Note.swagWidth * 0.95;
            splash.y = strum.y - Note.swagWidth;
        }

        if (splash.animation.exists(curAnim))
        {
            splash.animation.play(curAnim, true);
            splash.alpha = 1;
            
            if (animData.offsets != null && animData.offsets.length >= 2)
            {
                splash.offset.set(10 + animData.offsets[0], 10 + animData.offsets[1]);
            }
            else
            {
                splash.offset.set(10, 10);
            }
        }
        else
        {
            splash.alpha = 0.0001;
        }
    }

    var imageInputText:PsychUIInputText;
    var scaleNumericStepper:PsychUINumericStepper;
    function addPropertiesTab()
    {
        var ui = properUI.getTab("Properties").menu;

        ui.add(new FlxText(20, 10, 0, "Image:"));
        imageInputText = new PsychUIInputText(60, 10, 120, imageSkin, 8);
        ui.add(imageInputText);

        var reloadButton:PsychUIButton = new PsychUIButton(185, 6.8, "Reload Image", function()
        {
            reloadImage();
        });
        ui.add(reloadButton);

        ui.add(new FlxText(20, 40, "Scale:"));
        scaleNumericStepper = new PsychUINumericStepper(20, 57.5, 0.1, 1, 0, 4, 2, 60);
        ui.add(scaleNumericStepper);

        scaleNumericStepper.value = config.scale ?? 1;

        scaleNumericStepper.onValueChange = () -> {
            config.scale = scaleNumericStepper.value;
            updatePreviewSplash();
            if (showGhosts) updateGhosts();
        };

        ui.add(new FlxText(130, 40, "Animations:"));

        ghostCheckbox = new PsychUICheckBox(20, 85, "Show Ghosts", 100, function() {
            showGhosts = ghostCheckbox.checked;
            if (showGhosts) {
                updateGhosts();
            } else {
                clearGhosts();
            }
        });
        ghostCheckbox.checked = showGhosts;
        ui.add(ghostCheckbox);

        ui.add(new FlxText(20, 110, 0, "Ghost Alpha:"));
        var ghostAlphaStepper = new PsychUINumericStepper(20, 127.5, 0.05, ghostAlpha, 0, 1, 2, 60);
        ghostAlphaStepper.onValueChange = function() {
            ghostAlpha = ghostAlphaStepper.value;
            updateGhostsAlpha();
        };
        ui.add(ghostAlphaStepper);

        var saveButton:PsychUIButton = new PsychUIButton(20, 160, "Save", saveSplash);
        ui.add(saveButton);

        templateButton = new PsychUIButton(20, 185, "Template");
        ui.add(templateButton);

        var loadButton:PsychUIButton = new PsychUIButton(180, 185, "Convert TXT", loadTxt);
        ui.add(loadButton);

        var allowPixelCheck:PsychUICheckBox = new PsychUICheckBox(180, 105, "Allow Pixel?");
        allowPixelCheck.onClick = () -> if (config != null) config.allowPixel = allowPixelCheck.checked;
        allowPixelCheck.checked = config != null && cast(config.allowPixel, Null<Bool>) != null ? config.allowPixel : false;
        ui.add(allowPixelCheck);

        var allowHSBCheck:PsychUICheckBox = new PsychUICheckBox(180, allowPixelCheck.y + 20, "Allow HSB?");
        allowHSBCheck.onClick = () -> if (config != null) config.allowHSB = allowHSBCheck.checked;
        allowHSBCheck.checked = config != null && cast(config.allowHSB, Null<Bool>) != null ? config.allowHSB : false;
        ui.add(allowHSBCheck);

        var noAntialiasingCheck:PsychUICheckBox = new PsychUICheckBox(180, allowHSBCheck.y + 20, "No Antialiasing");
        noAntialiasingCheck.onClick = () -> if (config != null) config.no_antialiasing = noAntialiasingCheck.checked;
        noAntialiasingCheck.checked = config != null && cast(config.no_antialiasing, Null<Bool>) != null ? config.no_antialiasing : false;
        ui.add(noAntialiasingCheck);
    }

    function updateGhosts() {
        clearGhosts();
        
        if (!showGhosts || config == null || config.animations == null || curAnim == null) return;

        var animData = config.animations.get(curAnim);
        if (animData == null) return;
        
        var ghost:NoteSplash = new NoteSplash(0, 0, imageSkin);
        ghost.inEditor = true;
        ghost.config = config;

        ghost.scale.set(config.scale, config.scale);
        ghost.updateHitbox();
        
        if (ghost.animation.exists(curAnim)) {
            ghost.babyArrow = strums.members[animData.noteData % 4];
            
            ghost.animation.onFinish.removeAll();
            ghost.animation.play(curAnim, false);
            
            ghost.animation.finish();
            
            ghost.alpha = ghostAlpha;
            ghost.color = 0x888888;
            
            if (animData.offsets?.length >= 2) {
                ghost.offset.set(10 + animData.offsets[0], 10 + animData.offsets[1]);
            } else {
                ghost.offset.set(10, 10);
            }

            if (ghost.babyArrow != null) {
                ghost.x = ghost.babyArrow.x - Note.swagWidth * 0.95;
                ghost.y = ghost.babyArrow.y - Note.swagWidth;
            }
            
            ghost.spawned = false;
            ghosts.add(ghost);
        }
    }

    function updateGhostsPositions() {
        ghosts.forEach(function(ghost:NoteSplash) {
            if (ghost.babyArrow != null) {
                ghost.x = ghost.babyArrow.x - Note.swagWidth * 0.95;
                ghost.y = ghost.babyArrow.y - Note.swagWidth;
            }
        });
    }

    function updateGhostsOffsets() {
        ghosts.forEach(function(ghost:NoteSplash) {
            var animName = ghost.animation.curAnim?.name;
            if (animName != null && config.animations.exists(animName)) {
                var animData = config.animations.get(animName);
                if (animData.offsets?.length >= 2) {
                    ghost.offset.set(10 + animData.offsets[0], 10 + animData.offsets[1]);
                } else {
                    ghost.offset.set(10, 10);
                }
            }
        });
    }
    
    function clearGhosts() {
        ghosts.forEach(function(ghost:FlxSprite) {
            ghost.kill();
        });
        ghosts.clear();
    }
    
    function updateGhostsAlpha() {
        ghosts.forEach(function(ghost:FlxSprite) {
            ghost.alpha = ghostAlpha;
        });
    }

    function clearOldSplashes() {
        splashes.forEach(function(splash:NoteSplash) {
            if (splash != this.splash) {
                splash.kill();
                splashes.remove(splash, true);
                splash.destroy();
            }
        });
        splashes.clear();
        splashes.add(this.splash);
    }

    dynamic function reloadImage() // Dynamic because needs to be changed later
    {
        //
    }

    var holdingArrowsTime:Float = 0;
    var holdingArrowsElapsed:Float = 0;
    var copiedOffset:Array<Float> = [0, 0];
    override function update(elapsed:Float)
    { 
        super.update(elapsed);

        errorText.x = FlxG.width - errorText.width - 5;

        curText.text = 'Copied Offsets: ${Std.string(copiedOffset).replace(',', ', ')}\n';
        curText.text += 'Current Animation: ${curAnim == null || curAnim.length < 1  ? "NONE" : curAnim}';

        if (config != null && !curText.text.contains('NONE'))
        {
            var offsets:Array<Float> = try config.animations.get(curAnim).offsets catch (e) [0, 0];
            curText.text += ' ($offsets)'.replace(',', ', ');
        }

        if (config != null)
        {
            var currentAnim:String = curAnimText.text;
            if (config.animations.exists(currentAnim) && config.animations.get(currentAnim) != null)
                addButton.label = 'Update';
            else
                addButton.label = 'Add';

            config.scale = scaleNumericStepper.value;
        }
        
        if (showGhosts) updateGhostsPositions();
        
        var blockInput:Bool = PsychUIInputText.focusOn != null;
        if (!blockInput && config?.animations != null && config.animations.exists(curAnim) && curAnim?.length > 0)
        {
            function updateSplash()
            {
                if (config.animations.get(curAnim) != null)
                {
                    updatePreviewSplash();
                    FlxTween.cancelTweensOf(errorText);
                    errorText.alpha = 0;
                    
                    if (showGhosts) updateGhostsOffsets();
                }
            }

            var changedOffset = false;
            if (FlxG.keys.pressed.CONTROL && config.animations.get(curAnim) != null)
            {
                if (FlxG.keys.justPressed.C)
                {
                    copiedOffset = config.animations.get(curAnim).offsets.copy();
                }
                else if (FlxG.keys.justPressed.V)
                {
                    var conf = config.animations.get(curAnim);
                    conf.offsets = copiedOffset.copy(); 
                    config.animations.set(curAnim, conf);
                    changedOffset = true;
                }
                else if(FlxG.keys.justPressed.R)
                {
                    var conf = config.animations.get(curAnim);
                    conf.offsets = [0, 0];
                    config.animations.set(curAnim, conf);
                    changedOffset = true;
                }
            }

            var multiplier:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER)) ? 10 : 1;

            var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
            if(moveKeysP.contains(true))
            {
                config.animations[curAnim].offsets[0] += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * multiplier;
                config.animations[curAnim].offsets[1] += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * multiplier;
                changedOffset = true;
            }

            var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
            if(moveKeys.contains(true))
            {
                holdingArrowsTime += elapsed;
                if(holdingArrowsTime > 0.6)
                {
                    holdingArrowsElapsed += elapsed;
                    while(holdingArrowsElapsed > (1/60))
                    {
                        config.animations[curAnim].offsets[0] += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * multiplier;
                        config.animations[curAnim].offsets[1] += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * multiplier;

                        updatePreviewSplash();

                        holdingArrowsElapsed -= (1/60);
                        changedOffset = true;
                    }
                }
            }
            else holdingArrowsTime = 0;

            if(changedOffset) {
                updateSplash();
            }
            
            if(FlxG.keys.justPressed.SPACE) {
                clearOldSplashes();

                var testSplash:NoteSplash = new NoteSplash(0, 0, imageSkin);
                testSplash.inEditor = true;
                testSplash.config = config;

                testSplash.scale.set(config.scale, config.scale);
                testSplash.updateHitbox();
                
                if (curAnim != null && testSplash.animation.exists(curAnim)) {
                    var animData = config.animations.get(curAnim);
                    if (animData != null) {
                        testSplash.babyArrow = strums.members[animData.noteData % 4];
                        testSplash.animation.play(curAnim, true);
                        testSplash.alpha = 1;
                        
                        if (animData.offsets?.length >= 2) {
                            testSplash.offset.set(10 + animData.offsets[0], 10 + animData.offsets[1]);
                        } else {
                            testSplash.offset.set(10, 10);
                        }
                        
                        testSplash.x = testSplash.babyArrow.x - Note.swagWidth * 0.95;
                        testSplash.y = testSplash.babyArrow.y - Note.swagWidth;
                        
                        testSplash.spawned = true;
                        splashes.add(testSplash);
                    }
                } else {
                    testSplash.babyArrow = strums.members[0];
                    testSplash.spawnSplashNote(0, 0, 0, null, false);
                    splashes.add(testSplash);
                }
            }
        }

        if (!blockInput)
        {
            if (controls.BACK)
                FlxG.switchState(() -> new MasterEditorMenu());
            if (FlxG.keys.justPressed.F1)
                openSubState(new NoteSplashEditorHelpSubState());
        }

        if (FlxG.mouse.overlaps(strums))
        {
            strums.forEach(function(strum:StrumNote)
            {
                if (FlxG.mouse.overlaps(strum))
                {
                    if (!FlxG.mouse.justPressed)
                    {
                        if (strum.animation.curAnim.name != 'pressed' && strum.animation.curAnim.name != 'confirm')
                            strum.playAnim('pressed');
                    }
                    else
                    {
                        clearOldSplashes();
                        strum.playAnim('confirm', true);

                        var splash:NoteSplash = new NoteSplash(0, 0, imageSkin);
                        splash.inEditor = true;
                        splash.config = config;
                        splash.babyArrow = strum;

                        splash.scale.set(config.scale, config.scale);
                        splash.updateHitbox();
                        
                        if (curAnim != null && splash.animation.exists(curAnim))
                        {
                            splash.animation.play(curAnim, true);
                            splash.alpha = 1;
                            
                            var animData = config.animations.get(curAnim);
                            if (animData?.offsets?.length >= 2)
                            {
                                splash.offset.set(10 + animData.offsets[0], 10 + animData.offsets[1]);
                            }
                            else
                            {
                                splash.offset.set(10, 10);
                            }
                            
                            splash.x = strum.x - Note.swagWidth * 0.95;
                            splash.y = strum.y - Note.swagWidth;
                            
                            splash.spawned = true;
                            splashes.add(splash);
                        }
                        else
                        {
                            splash.spawnSplashNote(0, 0, strum.ID % 4);
                            splashes.add(splash);
                        }
                    }
                }
                else strum.playAnim('static');
            });
        }
        else
        {
            for (strum in strums)
                strum.playAnim('static');
        }
    }

    var _file:FileReference;
    function onSaveComplete(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
        FlxG.log.notice("Successfully saved file.");
    }

    /**
     * Called when the save file dialog is cancelled.
     */
    function onSaveCancel(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
    }

    /**
     * Called if there is an error while saving the gameplay recording.
     */
    function onSaveError(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
        FlxG.log.error("Problem saving file");
    }

    function saveSplash()
    {
        imageSkin = imageInputText.text;
        var data:String = Json.stringify(config, "\t");
        if (data.length > 0)
        {
            _file = new FileReference();
            _file.addEventListener(Event.COMPLETE, onSaveComplete);
            _file.addEventListener(Event.CANCEL, onSaveCancel);
            _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file.save(data, imageSkin + ".json");
        }
    }

    public function loadTxt()
    {
        var jsonFilter:FileFilter = new FileFilter('Select a note splash TXT', '*.txt');
        _file = new FileReference();
        _file.addEventListener(Event.SELECT, onLoadComplete);
        _file.addEventListener(Event.CANCEL, onLoadCancel);
        _file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file.browse([#if !mac jsonFilter #end]);
    }

    function onLoadComplete(_):Void
    {
        _file.removeEventListener(Event.SELECT, onLoadComplete);
        _file.removeEventListener(Event.CANCEL, onLoadCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

        try 
        {
            var txtLoaded:Dynamic = Json.parse(Json.stringify(_file));
            var txt:String = null;
            var file:String = "config.json";
            #if MODS_ALLOWED
            if (txtLoaded.__path != null)
            {
                try txt = File.getContent(txtLoaded.__path) catch (e) txt = null;
                file = txtLoaded.__path;
                file = file.substring(0, file.length - 4) + ".json";
            }

            var conf = parseTxt(txt);
            _file = new FileReference();
            _file.addEventListener(Event.COMPLETE, onSaveComplete);
            _file.addEventListener(Event.CANCEL, onSaveCancel);
            _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file.save(Json.stringify(conf, "\t"), file);
            #end
        }
        catch (e)
        {
            trace(e.stack);
        }
    }

    /**
     * Called when the save file dialog is cancelled.
     */
    function onLoadCancel(_):Void
    {
        _file.removeEventListener(Event.SELECT, onLoadComplete);
        _file.removeEventListener(Event.CANCEL, onLoadCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file = null;
        trace("Cancelled file loading.");
    }

    /**
     * Called if there is an error while saving the gameplay recording.
     */
    function onLoadError(_):Void
    {
        _file.removeEventListener(Event.SELECT, onLoadComplete);
        _file.removeEventListener(Event.CANCEL, onLoadCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file = null;
        trace("Problem loading file");
    }

    override function destroy()
    {
        Mouse.cursor = MouseCursor.AUTO;

        NoteSplash.configs.clear();

        super.destroy();

        FlxG.sound.music.volume = 1;
        FlxG.sound.muteKeys = [FlxKey.ZERO];
        FlxG.sound.volumeDownKeys = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
        FlxG.sound.volumeUpKeys = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
    }

    public static function parseTxt(content:String):NoteSplashConfig
    {
        var config = NoteSplash.createConfig();
        if (content == null)
            return config;

        var trim:String = content.trim();
        if (trim.length < 1) // empty txt
            return config;

        var configs = content.split('\n');
        // checks for empty txts
        if (configs.length < 2 || configs[0].trim() == "")
            return config;

        var animation:String = configs[0].rtrim();
        var fps:Array<Null<Int>> = [22, 26];
        if (configs[1] != null && configs[1].trim() != "")
        {
            var newFps = configs[1].trim().split(" ");
            fps = [Std.parseInt(newFps[0]), Std.parseInt(newFps[1])];

            fps[0] ??= 22;
            fps[1] ??= 26;
        }

        var offsets:Array<Array<Null<Float>>> = [[0, 0]];
        if (configs.length > 2)
        {
            offsets = [];
            for (i in 2...configs.length)
            {
                var offset = configs[i].trim();
                if (offset != "")
                {
                    var offset:Array<String> = offset.split(" ");
                    var x:Float = Std.parseFloat(offset[0]);
                    var y:Float = Std.parseFloat(offset[1]);
                    if (Math.isNaN(x)) x = 0;
                    if (Math.isNaN(y)) y = 0;
                    offsets.push([x, y]);
                }
            }
        }

        var i = 0;
        var k = 1;
        while (true)
        {
            for (col in Note.colArray)
            {
                var anim = k <= 1 ? col : '$col' + k;
                var offset = offsets[FlxMath.wrap(i, 0, Std.int(offsets.length - 1))];

                config = NoteSplash.addAnimationToConfig(config, 1, anim, '$animation $col $k', fps, offset, [], i);
                i++;
            }
            if (offsets[i] == null) break;
            k++;
        }

        return config;
    }
}

@:allow(NoteSplashEditorState)
class NoteSplashEditorHelpSubState extends MusicBeatSubstate
{
    public function new()
    {
        super();

        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        add(bg);

        var str:Array<String> = ["Click on a Strum or Press Space",
        "to spawn a Splash",
        "",
        "Arrow Keys - Move Offset",
        "Hold Shift - Move Offsets 10x faster",
        "",
        "Ctrl + C - Copy Current Offset",
        "Ctrl + V - Paste Copied Offset on Current Splash",
        "Ctrl + R - Reset Current Offset",
        "",
        "On every 4 subsequent note datas",
        "an extra set of animations will be added"];

        var helpTexts:FlxSpriteGroup = new FlxSpriteGroup();
        for (i => txt in str)
        {
            if(txt.length < 1) continue;

            var helpText:FlxText = new FlxText(0, 0, 0, txt, 24);
            helpText.setFormat(null, 24, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
            helpText.borderColor = FlxColor.BLACK;
            helpText.scrollFactor.set();
            helpText.borderSize = 1;
            helpText.screenCenter();
            add(helpText);
            helpText.y += ((i - str.length/2) * 32) + 16;
            helpTexts.add(helpText);
        }
        add(helpTexts);

        var noteDataText:FlxText = new FlxText();
        noteDataText.setFormat(null, 24, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
        noteDataText.text = "NOTE DATAS:\nLEFT: 0\nDOWN: 1\nUP: 2\nRIGHT: 3";
        noteDataText.x = FlxG.width - noteDataText.width - 5;
        noteDataText.y = FlxG.height - noteDataText.height - 5;

        add(noteDataText);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (controls.BACK || FlxG.keys.justPressed.F1)
            close();
    }
}