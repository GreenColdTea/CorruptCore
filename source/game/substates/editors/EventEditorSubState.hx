package game.substates.editors;

import flixel.FlxSubState;
import flixel.addons.display.FlxTiledSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxColor;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;

import lime.ui.MouseCursor;

import game.backend.Song.SwagSong;
import game.objects.Note.EventNote;
import game.states.editors.ChartEditorState;
import game.states.editors.meta.MetaNote;
import game.states.editors.meta.MetaNote.EventMetaNote;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

@:access(game.PlayState)
class EventEditorSubState extends FlxSubState
{
    public static final UI_MARGIN:Int = 20;

    public var game:PlayState;
    public var slider:PsychUISlider;
    public var grid:EventEditorGrid;
    public var mainBox:PsychUIBox;
    public var camUI:FlxCamera;

    var camCrosshair:FlxSprite;
    
    var lastMouseScreenX:Float = 0;
    var lastMouseScreenY:Float = 0;
    var isDraggingCam:Bool = false;

    var darkTop:FlxSprite;
    var darkBottom:FlxSprite;
    var darkLeft:FlxSprite;
    var darkRight:FlxSprite;
    
    var lineTop:FlxSprite;
    var lineBottom:FlxSprite;
    var lineLeft:FlxSprite;
    var lineRight:FlxSprite;
    var corners:Array<FlxSprite>;

    var editorCamX:Float = 0;
    var editorCamY:Float = 0;
    var targetCamX:Float = 0;
    var targetCamY:Float = 0;
    var editorCamZoom:Float = 1;

    var oldMinX:Null<Float>;
    var oldMaxX:Null<Float>;
    var oldMinY:Null<Float>;
    var oldMaxY:Null<Float>;

    var _song:SwagSong;
    var _paused:Bool = false;
    var _lastValue:Float;
    var _unspawnIdx:Null<Int> = 0;

    public function new(_game:PlayState)
    {
        super();

        game = _game;
        game.persistentUpdate = game.persistentDraw = true;

        targetCamX = editorCamX = game.camFollow.x;
        targetCamY = editorCamY = game.camFollow.y;
        editorCamZoom = 1; 

        oldMinX = FlxG.camera.minScrollX;
        oldMaxX = FlxG.camera.maxScrollX;
        oldMinY = FlxG.camera.minScrollY;
        oldMaxY = FlxG.camera.maxScrollY;

        _song = PlayState.SONG;
    }

    override public function create():Void
    {
        super.create();
        
        game.canPause = false;
        game.cpuControlled = true;
        FlxG.mouse.visible = true;

        camUI = new FlxCamera(); 
        camUI.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(camUI, false);

        cameras = [camUI];

        grid = new EventEditorGrid(UI_MARGIN, FlxG.height - UI_MARGIN - EventEditorGrid.GRID_HEIGHT, this);
        grid.cameras = [camUI];
        add(grid);

        slider = new PsychUISlider(0 + UI_MARGIN, grid.y - 25, onSliderChange, 0, 0, 1, FlxG.width - UI_MARGIN * 2, FlxColor.WHITE, FlxColor.CYAN);
        slider.cameras = [camUI];
        slider.decimals = 3;
        slider.minText.fieldWidth = 100;
        slider.maxText.fieldWidth = 100;
        slider.valueText.fieldWidth = 140;
        slider.minText.text = "00:00:00";
        add(slider);

        mainBox = new PsychUIBox(FlxG.width - 400, 50, 365, 400, ['Events', 'Camera']);
		mainBox.selectedName = 'Events';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		add(mainBox);

        final darkColor = 0x99000000;
        darkTop = new FlxSprite().makeGraphic(1, 1, darkColor);
        darkBottom = new FlxSprite().makeGraphic(1, 1, darkColor);
        darkLeft = new FlxSprite().makeGraphic(1, 1, darkColor);
        darkRight = new FlxSprite().makeGraphic(1, 1, darkColor);

        final lineColor = FlxColor.YELLOW;
        lineTop = new FlxSprite().makeGraphic(1, 1, lineColor);
        lineBottom = new FlxSprite().makeGraphic(1, 1, lineColor);
        lineLeft = new FlxSprite().makeGraphic(1, 1, lineColor);
        lineRight = new FlxSprite().makeGraphic(1, 1, lineColor);

        for (o in [darkTop, darkBottom, darkLeft, darkRight, lineTop, lineBottom, lineLeft, lineRight]) 
        {
            o.cameras = [game.camHUD];
            o.scrollFactor.set(0, 0); 
            o.visible = false;
            add(o);
        }

        corners = [];
        for (i in 0...8) 
        {
            final c = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
            c.cameras = [game.camHUD];
            c.scrollFactor.set(0, 0);
            c.visible = false;
            corners.push(c);
            add(c);
        }

        camCrosshair = new FlxSprite(0, 0).makeGraphic(40, 40, FlxColor.TRANSPARENT);
        camCrosshair.pixels.fillRect(new Rectangle(18, 0, 4, 40), FlxColor.RED);
        camCrosshair.pixels.fillRect(new Rectangle(0, 18, 40, 4), FlxColor.RED);
        camCrosshair.cameras = [game.camHUD];
        camCrosshair.scrollFactor.set(0, 0);
        camCrosshair.setPosition(620, 340);
        camCrosshair.visible = false;
        add(camCrosshair);

        addEventsUI();
        addCameraUI();

        for (tab in mainBox.tabs) 
        {
            tab.cameras = [camUI];
            tab.menu.cameras = [camUI];
            for (m in tab.menu.members)
                if (m != null) m.cameras = [camUI];
        }
        mainBox.cameras = [camUI];

        tweenStuff();
        updateTimeDisplay();
    }

    public static function formatTime(ms:Float):String
    {
        if (Math.isNaN(ms) || ms < 0) 
            ms = 0;

        final totalSeconds:Int = Math.floor(ms / 1000);
        final minutes:Int = Math.floor(totalSeconds / 60);
        final seconds:Int = totalSeconds % 60;
        final millis:Int = Math.floor(ms % 100);

        return StringTools.lpad(Std.string(minutes), "0", 2) + ":"
             + StringTools.lpad(Std.string(seconds), "0", 2) + ":"
             + StringTools.lpad(Std.string(millis), "0", 2);
    }

    public function updateTimeDisplay():Void
    {
        final songLen:Float = FlxG.sound.music?.length ?? 0;
        final percent:Float = songLen > 0 ? FlxMath.remapToRange(Conductor.songPosition, 0, songLen, 0, 1) : 0;
        
        slider.broadcastSliderEvent = false;
        slider.value = percent;
        slider.broadcastSliderEvent = true;

        grid.setGridPosition(percent);

        slider.valueText.text = formatTime(Conductor.songPosition);
        slider.valueText.x = slider.bar.x + slider.bar.width / 2 - slider.valueText.width / 2;

        slider.minText.text = "00:00:00";
        if (songLen > 0)
        {
            slider.maxText.text = formatTime(songLen);
            slider.maxText.x = slider.bar.x + slider.bar.width - slider.maxText.width / 2;
        }
    }

    public function setSongPosition(time:Float):Void
    {
        final songLength:Float = FlxG.sound.music?.length ?? 0;
        time = FlxMath.bound(time, 0, songLength);

        game.setSongTime(time);
        handlePause();

        Conductor.songPosition = time;

        final curStep:Int = Math.floor(Conductor.getStep(time));
        final curBeat:Int = Math.floor(curStep / 4);

        var curSection:Int = 0;
        if (PlayState.SONG?.notes != null)
        {
            var tempTime:Float = 0;
            for (i in 0...PlayState.SONG.notes.length)
            {
                final sec = PlayState.SONG.notes[i];
                if (sec == null) continue;

                var secBpm:Float = sec.changeBPM ? sec.bpm : Conductor.bpm;
                if (secBpm <= 0) secBpm = 100;

                final secDuration:Float = (1000 * 60 / secBpm) * (sec.sectionBeats ?? 4);
                if (time >= tempTime && time < tempTime + secDuration)
                {
                    curSection = i;
                    break;
                }
                tempTime += secDuration;
            }
        }

        game.curStep = curStep;
        game.curBeat = curBeat;
        game.curDecStep = Conductor.getStep(time);
        game.curDecBeat = game.curDecStep / 4;
        game.curSection = curSection;
        
        game.lastStepHit = curStep - 1;
        game.lastBeatHit = curBeat - 1;

        grid.applyEvents();
        processNotes();
        game.update(0);

        updateTimeDisplay();
    }

    function onSliderChange(value:Float):Void
    {
        @:privateAccess
        var isSliderHovered:Bool = slider._isHovered || slider._isHandleHovered;

        if(!FlxG.mouse.pressed || !isSliderHovered) return;
        
        var songLength:Float = FlxG.sound.music != null ? FlxG.sound.music.length : 0;
        var time:Float = FlxMath.lerp(0, songLength, value);
        setSongPosition(time);
        _lastValue = value;
    }

    function processNotes():Void
    {
        _unspawnIdx = null;
        for(idx => note in game.unspawnNotes)
        {
            game.invalidateNote(note);

            if(note.strumTime > Conductor.songPosition)
            {
                _unspawnIdx ??= idx;
                note.active = true;
                note.revive();
                note.ignoreNote = false;
                note.wasGoodHit = false;
                note.noteWasHit = false;
                note.hitByOpponent = false;
                game.notes.members.remove(note);
            }

            final strumGroup = game.playerStrums;
            if (note.isSustainNote && note.holdNote != null)
            {
                note.holdNote.hit = note.wasGoodHit;
                
                if (note.wasGoodHit)
                    note.holdNote.timeStuff = Conductor.songPosition - note.strumTime;
                
                note.strum = strumGroup.members[note.noteData];

                note.holdNote.updateVisuals((game.songSpeed * note.multSpeed), strumGroup.members[note.noteData].downScroll);
                note.holdNote.updatePos();
            }
        }

        game.currentUnspawnIndex = _unspawnIdx ?? game.currentUnspawnIndex;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if(FlxG.keys.justPressed.ESCAPE)
            preClose();

        final songLen = FlxG.sound.music?.length ?? 0;

        if (!slider.movingHandle && FlxG.sound.music?.playing)
            updateTimeDisplay();

        if(FlxG.keys.justPressed.SPACE) 
            handlePause(true);

        final mPos = FlxG.mouse.getViewPosition(camUI);
        final mx = mPos.x;
        final my = mPos.y;
        mPos.put();
        
        final canInteractWorld = !((mx >= mainBox.x && mx <= mainBox.x + mainBox.bg.width && my >= mainBox.y && my <= mainBox.y + mainBox.bg.height) || (my >= slider.y - 15));
        if (FlxG.mouse.deltaWheel.y != 0) 
        {
            if (!canInteractWorld && my >= slider.y - 20) {
                final timeChange = (FlxG.mouse.deltaWheel.y * (songLen * 0.03));
                setSongPosition(FlxMath.bound(Conductor.songPosition - timeChange, 0, songLen));
            } else if (mainBox.selectedName == 'Camera' && canInteractWorld) {
                editorCamZoom = FlxMath.bound(editorCamZoom + (FlxG.mouse.deltaWheel.y * 0.1), 0.1, 5.0);
            }
        }

        if (mainBox.selectedName == 'Camera') 
        {
            FlxG.camera.target = null;
            FlxG.camera.minScrollX = null;
            FlxG.camera.maxScrollX = null;
            FlxG.camera.minScrollY = null;
            FlxG.camera.maxScrollY = null;

            if (FlxG.keys.pressed.CONTROL) 
            {
                if (FlxG.keys.anyJustPressed([PLUS, NUMPADPLUS])) editorCamZoom = FlxMath.bound(editorCamZoom + 0.1, 0.1, 5.0);
                else if (FlxG.keys.anyJustPressed([MINUS, NUMPADMINUS])) editorCamZoom = FlxMath.bound(editorCamZoom - 0.1, 0.1, 5.0);
            }

            if (!isDraggingCam && FlxG.sound.music?.playing)
            {
                targetCamX = game.camFollow.x;
                targetCamY = game.camFollow.y;

                camXStepper?.setValueSilent(Math.floor(targetCamX));
                camYStepper?.setValueSilent(Math.floor(targetCamY));
                camZoomStepper?.setValueSilent(game.defaultCamZoom);
            }

            if (!isDraggingCam) {
                final camLerp = FlxMath.bound(0.044 * game.cameraSpeed * game.playbackRate * 60 * elapsed, 0, 1);
                editorCamX = FlxMath.lerp(editorCamX, targetCamX, camLerp);
                editorCamY = FlxMath.lerp(editorCamY, targetCamY, camLerp);
            } else {
                editorCamX = targetCamX;
                editorCamY = targetCamY;
            }

            FlxG.camera.zoom = editorCamZoom * game.defaultCamZoom;
            FlxG.camera.scroll.set(editorCamX - FlxG.width / 2, editorCamY - FlxG.height / 2);

            game.camHUD.zoom = editorCamZoom;
            game.camHUD.scroll.set(0, 0);

            final targetCam = game.camHUD ?? FlxG.camera;
            final fw:Float = targetCam.width;
            final fh:Float = targetCam.height;
            final fx:Float = 0.0;
            final fy:Float = 0.0;
            final huge:Float = Math.max(10000.0, Math.max(fw, fh) * 10);

            darkTop.scale.set(huge * 2, huge); darkTop.updateHitbox(); darkTop.setPosition(fx - huge, fy - huge);
            darkBottom.scale.set(huge * 2, huge); darkBottom.updateHitbox(); darkBottom.setPosition(fx - huge, fy + fh);
            darkLeft.scale.set(huge, fh); darkLeft.updateHitbox(); darkLeft.setPosition(fx - huge, fy);
            darkRight.scale.set(huge, fh); darkRight.updateHitbox(); darkRight.setPosition(fx + fw, fy);

            final t:Float = 2.0;
            lineTop.scale.set(fw + t*2, t); lineTop.updateHitbox(); lineTop.setPosition(fx - t, fy - t);
            lineBottom.scale.set(fw + t*2, t); lineBottom.updateHitbox(); lineBottom.setPosition(fx - t, fy + fh);
            lineLeft.scale.set(t, fh); lineLeft.updateHitbox(); lineLeft.setPosition(fx - t, fy);
            lineRight.scale.set(t, fh); lineRight.updateHitbox(); lineRight.setPosition(fx + fw, fy);

            final cLength:Float = 30.0;
            final cThick:Float = 6.0;
            corners[0].scale.set(cLength, cThick); corners[0].updateHitbox(); corners[0].setPosition(fx - cThick, fy - cThick);
            corners[1].scale.set(cThick, cLength); corners[1].updateHitbox(); corners[1].setPosition(fx - cThick, fy - cThick);
            corners[2].scale.set(cLength, cThick); corners[2].updateHitbox(); corners[2].setPosition(fx + fw + cThick - cLength, fy - cThick);
            corners[3].scale.set(cThick, cLength); corners[3].updateHitbox(); corners[3].setPosition(fx + fw, fy - cThick);
            corners[4].scale.set(cLength, cThick); corners[4].updateHitbox(); corners[4].setPosition(fx - cThick, fy + fh);
            corners[5].scale.set(cThick, cLength); corners[5].updateHitbox(); corners[5].setPosition(fx - cThick, fy + fh + cThick - cLength);
            corners[6].scale.set(cLength, cThick); corners[6].updateHitbox(); corners[6].setPosition(fx + fw + cThick - cLength, fy + fh);
            corners[7].scale.set(cThick, cLength); corners[7].updateHitbox(); corners[7].setPosition(fx + fw, fy + fh + cThick - cLength);

            for (o in [darkTop, darkBottom, darkLeft, darkRight, lineTop, lineBottom, lineLeft, lineRight]) 
                o.visible = true;
            for (c in corners) 
                c.visible = true;

            camCrosshair.visible = true;
            camCrosshair.setPosition(fx + (fw - camCrosshair.width) / 2, fy + (fh - camCrosshair.height) / 2);

            if (FlxG.mouse.justPressed && canInteractWorld) 
            {
                isDraggingCam = true;
                lastMouseScreenX = mx;
                lastMouseScreenY = my;
            }

            if (FlxG.mouse.pressed && isDraggingCam) 
            {
                final dx = mx - lastMouseScreenX;
                final dy = my - lastMouseScreenY;
                
                final zoomMult = Math.max(0.01, editorCamZoom * game.defaultCamZoom);
                targetCamX -= dx / zoomMult;
                targetCamY -= dy / zoomMult;

                editorCamX = targetCamX; 
                editorCamY = targetCamY;
                
                lastMouseScreenX = mx;
                lastMouseScreenY = my;
                
                if (camXStepper != null) camXStepper.value = targetCamX;
                if (camYStepper != null) camYStepper.value = targetCamY;
                syncCameraToEvent();
            }
            
            if (FlxG.mouse.justReleased)
                isDraggingCam = false;
        } else {
            FlxG.camera.target = game.camFollow;
            game.camHUD.zoom = 1;
            game.camHUD.scroll.set(0, 0);

            FlxG.camera.minScrollX = oldMinX;
            FlxG.camera.maxScrollX = oldMaxX;
            FlxG.camera.minScrollY = oldMinY;
            FlxG.camera.maxScrollY = oldMaxY;

            for (o in [darkTop, darkBottom, darkLeft, darkRight, lineTop, lineBottom, lineLeft, lineRight]) 
                o.visible = false;
            for (c in corners) 
                c.visible = false;

            camCrosshair.visible = false;
        }
    }

    function handlePause(toggle:Bool = false)
    {
        if(toggle) game.persistentUpdate = !game.persistentUpdate;
        if(FlxG.sound.music == null) return;

        if(!game.persistentUpdate)
        {
            FlxG.sound.music.pause();
            game.vocals?.pause();
            game.opponentVocals?.pause();
        }
        else
        {
            FlxG.sound.music.play();
            game.vocals?.play();
            game.opponentVocals?.play();
        }
    }

    function preClose():Void
    {
        tweenStuff(true);
        FlxG.camera.target = game.camFollow;
        FlxG.camera.zoom = game.defaultCamZoom;
        game.camHUD.zoom = 1;
        game.camHUD.scroll.set(0, 0);
        
        FlxG.camera.minScrollX = oldMinX;
        FlxG.camera.maxScrollX = oldMaxX;
        FlxG.camera.minScrollY = oldMinY;
        FlxG.camera.maxScrollY = oldMaxY;

        FlxTimer.wait(0.5, close);
    }

    function tweenStuff(out:Bool = false):Void
    {
        FlxTween.tween(slider, {y: FlxG.height + slider.height}, 0.5, {ease: FlxEase.cubeOut, type: out ? 1 : 16});
        FlxTween.tween(grid, {y: FlxG.height + grid.height}, 0.5, {ease: FlxEase.cubeOut, type: out ? 1 : 16});
        FlxTween.tween(mainBox, {x: FlxG.width + mainBox.width}, 0.5, {ease: FlxEase.cubeOut, type: out ? 1 : 16});
    }

    var eventDropDown:PsychUIDropDownMenu;
	var descText:FlxText;
	var selectedEventText:FlxText;
    var value1Text:FlxText;
    var value1InputText:PsychUIInputText;
	var value2Text:FlxText;
	var value2InputText:PsychUIInputText;
    
    var camXStepper:PsychUINumericStepper;
    var camYStepper:PsychUINumericStepper;
    var camZoomStepper:PsychUINumericStepper;
    var placeCamEventBtn:PsychUIButton;
    var testCamBtn:PsychUIButton;
    var resetCamBtn:PsychUIButton;

    public var curSelectedNote:Array<Dynamic> = null;
    public var curEventSelected:Int = 0;
    public var selectedNotes:Array<MetaNote> = [];

    var eventStuff:Array<Array<String>> = ChartEditorState.defaultEvents;

    function updateSelectedEvent(index:Int, text:String) {
        function ensureSlots(arr:Array<Dynamic>) {
            while (arr.length < 3) arr.push("");
            arr[index] = text;
        }

        if (selectedNotes.length > 1) {
            for (note in selectedNotes) {
                if (note.chartNoteData < 0 && note.songData[1][0] != null) {
                    ensureSlots(note.songData[1][0]);
                    final evNote:Dynamic = note;
                    if (evNote.updateEventText != null) evNote.updateEventText();
                }
            }
            grid.applyEvents();
        } else if (curSelectedNote != null && curSelectedNote[1][curEventSelected] != null) {
            ensureSlots(curSelectedNote[1][curEventSelected]);
            for(note in grid.loadedEvents) {
                if (note.songData == curSelectedNote) {
                    final evNote:Dynamic = note;
                    if (evNote.updateEventText != null) evNote.updateEventText();
                }
            }
            grid.applyEvents();
        }
    }

	function addEventsUI():Void
	{
		var tab_group_event = mainBox.getTab('Events').menu;

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		directories.push(Paths.getPreloadPath('custom_events/'));
		#if MODS_ALLOWED
		directories.push(Mods.modFolders('custom_events/'));
		#end

		#if sys
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!eventPushedMap.exists(fileToCheck)) {
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		#end
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);
        descText.cameras = [camUI];

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length) leEvents.push(eventStuff[i][0]);

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
        text.cameras = [camUI];
		tab_group_event.add(text);
		
        eventDropDown = new PsychUIDropDownMenu(20, 50, leEvents, function(id:Int, type:String) {
			var eventName = eventStuff[id][0];
			descText.text = eventStuff[id][1] ?? "No description available lol.";
            
            updateSelectedEvent(0, eventName);

            if (eventName == 'Camera Follow Pos') 
            {
                value1InputText.text = Std.string(Math.floor(targetCamX));
                value2InputText.text = Std.string(Math.floor(targetCamY));
                updateSelectedEvent(1, value1InputText.text);
                updateSelectedEvent(2, value2InputText.text);
            }
		});
        eventDropDown.cameras = [camUI];

		value1Text = new FlxText(20, 90, 0, "Value 1:");
        value1Text.cameras = [camUI];
		tab_group_event.add(value1Text);
		value1InputText = new PsychUIInputText(20, 110, 100, "");
        value1InputText.cameras = [camUI];

		value2Text = new FlxText(20, 130, 0, "Value 2:");
        value2Text.cameras = [camUI];
		tab_group_event.add(value2Text);
		value2InputText = new PsychUIInputText(20, 150, 100, "");
        value2InputText.cameras = [camUI];

		value1InputText.onChange = (old, curText) -> updateSelectedEvent(1, curText);
		value2InputText.onChange = (old, curText) -> updateSelectedEvent(2, curText);

		final removeButton:PsychUIButton = new PsychUIButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null)
			{
				if(curSelectedNote[1].length < 2)
				{
					_song.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if(curEventSelected < 0) curEventSelected = 0;
				else if(curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
			}
		}, 20);
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;
        removeButton.cameras = [camUI];
		tab_group_event.add(removeButton);

		final addButton:PsychUIButton = new PsychUIButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null)
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);
				changeEventSelected(1);
			}
		}, 20);
		addButton.normalStyle.bgColor = FlxColor.GREEN;
		addButton.normalStyle.textColor = FlxColor.WHITE;
        addButton.cameras = [camUI];
		tab_group_event.add(addButton);

		final moveLeftButton:PsychUIButton = new PsychUIButton(addButton.x + addButton.width + 20, addButton.y, '<', () -> changeEventSelected(-1), 20);
        moveLeftButton.cameras = [camUI];
		tab_group_event.add(moveLeftButton);

		final moveRightButton:PsychUIButton = new PsychUIButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', () -> changeEventSelected(1), 20);
        moveRightButton.cameras = [camUI];
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
        selectedEventText.cameras = [camUI];
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);
	}

    function addCameraUI():Void
    {
        final tab = mainBox.getTab('Camera').menu;

        camXStepper = new PsychUINumericStepper(20, 30, 10, targetCamX, null, null, 0, 70);
        camYStepper = new PsychUINumericStepper(110, 30, 10, targetCamY, null, null, 0, 70);
        camZoomStepper = new PsychUINumericStepper(200, 30, 0.1, game.defaultCamZoom, 0.1, 10, 2, 70);

        camXStepper.cameras = [camUI];
        camYStepper.cameras = [camUI];
        camZoomStepper.cameras = [camUI];

        camXStepper.onValueChange = () -> { 
            targetCamX = camXStepper.value; 
            syncCameraToEvent(); 
        };
        camYStepper.onValueChange = () -> { 
            targetCamY = camYStepper.value; 
            syncCameraToEvent(); 
        };
        camZoomStepper.onValueChange = () -> game.defaultCamZoom = camZoomStepper.value;

        final lblX = new FlxText(camXStepper.x, camXStepper.y - 15, 0, "Camera X:"); 
        lblX.cameras = [camUI]; 
        tab.add(lblX);
        tab.add(camXStepper);

        final lblY = new FlxText(camYStepper.x, camYStepper.y - 15, 0, "Camera Y:"); 
        lblY.cameras = [camUI]; 
        tab.add(lblY);
        tab.add(camYStepper);
        
        final lblZ = new FlxText(camZoomStepper.x, camZoomStepper.y - 15, 0, "PlayState Zoom:"); 
        lblZ.cameras = [camUI]; 
        tab.add(lblZ);
        tab.add(camZoomStepper);

        placeCamEventBtn = new PsychUIButton(100, 70, "Place Camera Event Here", () -> {
            final time:Float = Conductor.songPosition;
            final cx:String = Std.string(Math.floor(targetCamX));
            final cy:String = Std.string(Math.floor(targetCamY));
            final cz:String = Std.string(FlxMath.roundDecimal(game.defaultCamZoom, 2));
            
            grid.addEvent(time, [
                ["Camera Follow Pos", cx, cy],
                ["Set Property", "defaultCamZoom", cz]
            ]);
        }, 180);
        placeCamEventBtn.cameras = [camUI];
        tab.add(placeCamEventBtn);
        
        final snapPlayerBtn = new PsychUIButton(20, 110, "Snap to Player", () -> {
            game.moveCamera(false, game.boyfriend, game.boyfriendCameraOffset);
            targetCamX = game.camFollow.x;
            targetCamY = game.camFollow.y;
            camXStepper.value = targetCamX;
            camYStepper.value = targetCamY;
            syncCameraToEvent();
        }, 100);
        snapPlayerBtn.cameras = [camUI];
        tab.add(snapPlayerBtn);

        final snapOpponentBtn = new PsychUIButton(125, 110, "Snap to Opponent", () -> {
            game.moveCamera(true, game.dad, game.opponentCameraOffset);
            targetCamX = game.camFollow.x;
            targetCamY = game.camFollow.y;
            camXStepper.value = targetCamX;
            camYStepper.value = targetCamY;
            syncCameraToEvent();
        }, 100);
        snapOpponentBtn.cameras = [camUI];
        tab.add(snapOpponentBtn);

        resetCamBtn = new PsychUIButton(230, 110, "Reset Camera", () -> {
            game.triggerEventNote("Camera Follow Pos", "", "");
            game.isCameraOnForcedPos = false;
            game.moveCameraSection();
            
            targetCamX = game.camFollow.x;
            targetCamY = game.camFollow.y;
            camXStepper.setValueSilent(Math.floor(targetCamX));
            camYStepper.setValueSilent(Math.floor(targetCamY));
            camZoomStepper.setValueSilent(game.defaultCamZoom);
            
            FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
        }, 105);
        resetCamBtn.normalStyle.bgColor = FlxColor.fromRGB(200, 50, 50);
        resetCamBtn.normalStyle.textColor = FlxColor.WHITE;
        resetCamBtn.cameras = [camUI];
        tab.add(resetCamBtn);
    }

    function syncCameraToEvent() {
        if (eventDropDown.selectedLabel == 'Camera Follow Pos' && curSelectedNote != null) {
            value1InputText.text = Std.string(Math.floor(targetCamX));
            value2InputText.text = Std.string(Math.floor(targetCamY));
            updateSelectedEvent(1, value1InputText.text);
            updateSelectedEvent(2, value2InputText.text);
        }
    }

    public inline function changeEventSelected(change:Int = 0)
	{
		if(curSelectedNote != null && curSelectedNote[2] == null)
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if(curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

    var curNoteTypes:Array<String> = [];
    var stepperSusLength:PsychUINumericStepper;
	var noteTypeDropDown:PsychUIDropDownMenu;
	var currentType:Int = 0;

    function updateNoteUI():Void
	{
		if (selectedNotes.length > 1)
		{
			var firstNote = selectedNotes[0];
			var allSameSustain:Bool = true;
			var allSameType:Bool = true;
			var allSameEvent:Bool = true;
			var firstEventName = null;
			var firstEventVal1 = null;
			var firstEventVal2 = null;

			for (note in selectedNotes)
			{
				if (note.songData[2] != firstNote.songData[2]) allSameSustain = false;
				if (note.songData[3] != firstNote.songData[3]) allSameType = false;
				
				if (note.chartNoteData < 0)
				{
					if (firstEventName == null)
					{
						if (note.songData[1][0] != null) {
							firstEventName = note.songData[1][0][0];
							firstEventVal1 = note.songData[1][0][1];
							firstEventVal2 = note.songData[1][0][2];
						}
					}
					else if (note.songData[1][0][0] != firstEventName || note.songData[1][0][1] != firstEventVal1 || note.songData[1][0][2] != firstEventVal2) {
						allSameEvent = false;
					}
				}
			}
			
            if (firstNote.songData[1][0] != null) {
                eventDropDown.selectedLabel = allSameEvent ? firstNote.songData[1][0][0] : '[Multiple]';
                value1InputText.text = allSameEvent ? firstNote.songData[1][0][1] : '';
                value2InputText.text = allSameEvent ? firstNote.songData[1][0][2] : '';
            }
            
            if (allSameEvent && firstNote.songData[1][0] != null) {
                var selectedEventIndex = -1;
                for (i in 0...eventStuff.length) {
                    if (eventStuff[i][0] == firstNote.songData[1][0][0]) {
                        selectedEventIndex = i;
                        break;
                    }
                }
                if (selectedEventIndex != -1) {
                    descText.text = eventStuff[selectedEventIndex][1];
                }
            } else {
                descText.text = "Multiple Events Selected";
            }
        }
		else if (curSelectedNote != null)
		{
			if(curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if(curSelectedNote[3] != null) {
					if (curSelectedNote[3].length > 0) {
						currentType = curNoteTypes.indexOf(curSelectedNote[3]);
						noteTypeDropDown.selectedLabel = currentType <= 0 ? '' : currentType + '. ' + curSelectedNote[3];
					} else {
						currentType = 0;
						noteTypeDropDown.selectedLabel = '';
					}
				} else {
					currentType = 0;
					noteTypeDropDown.selectedLabel = '';
				}
			} else {
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				final selected:Int = eventDropDown.selectedIndex;
				if(selected > 0 && selected < eventStuff.length)
					descText.text = eventStuff[selected][1];

				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];

                if (curSelectedNote[1][curEventSelected][0] == 'Camera Follow Pos')
                {
                    final vx:Float = Std.parseFloat(value1InputText.text);
                    final vy:Float = Std.parseFloat(value2InputText.text);
                    if (!Math.isNaN(vx)) {
                        targetCamX = vx;
                        if (camXStepper != null) camXStepper.setValueSilent(vx);
                    }
                    if (!Math.isNaN(vy)) {
                        targetCamY = vy;
                        if (camYStepper != null) camYStepper.setValueSilent(vy);
                    }
                }
			}
		}
		else
		{
			stepperSusLength.value = 0;
			currentType = 0;
			noteTypeDropDown.selectedLabel = '';
			eventDropDown.selectedLabel = '';
			value1InputText.text = '';
			value2InputText.text = '';
		}
	}
}

class EventEditorGrid extends FlxSpriteGroup
{
    public static final TILE_SIZE:Int = 60;
    public static final TIME_TO_Y:Int = 400;
    public static var GRID_WIDTH(get, never):Int;
    inline static function get_GRID_WIDTH():Int return FlxG.width;
    public static final GRID_HEIGHT:Int = TILE_SIZE * 1;
    public static final BORDER_RADIUS:Int = 30;
    public static final BORDER_THICKNESS:Int = 6;

    public var loadedEvents:Array<EventMetaNote>;

    var parent:EventEditorSubState;
    var game:PlayState;
    var bg:FlxSprite;
    var gridSprite:FlxTiledSprite;
    var tileSelect:FlxSprite;
    var tileEvent:FlxSprite;
    var border:FlxSprite;
    var inactiveEvents:Array<EventMetaNote>;
    var currentSelectedEvent:Null<EventMetaNote>;
    var currentOverlapEvent:Null<EventMetaNote>;
    var currentGrabbedEvent:Null<EventMetaNote>;
    var rememberedEvents:Array<Array<String>>;
    var wasPressing:Bool = false;
    var isGrabbing:Bool = false;
    var skipGrab:Bool = false;

    var _totalWidth:Int;
    var _mousePoint:FlxPoint = FlxPoint.get();
    
    public function new(x:Float, y:Float, _parent:EventEditorSubState)
    {
        super(x, y);

        parent = _parent;
        game = parent.game;

        loadedEvents = [];
        inactiveEvents = [];

        buildGrid();
        loadEvents();

        tileSelect = new FlxSprite().makeGraphic(TILE_SIZE, TILE_SIZE, 0x77000000);
        tileSelect.cameras = [parent.camUI];
        add(tileSelect);

        tileEvent = new FlxSprite().loadGraphic(Paths.image('editors/eventArrow'));
        tileEvent.setGraphicSize(TILE_SIZE);
        tileEvent.updateHitbox();
        tileEvent.alpha = 0.5;
        tileEvent.cameras = [parent.camUI];
        add(tileEvent);
    }
    
    var _rawStep:Array<Float> = [];
    var _prevScrollX:Float = 0;
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if(FlxG.mouse.overlaps(gridSprite, camera))
        {
            final mousePos = FlxG.mouse.getViewPosition(camera, _mousePoint);
            _rawStep[0] = (mousePos.x - gridSprite.x + Math.abs(gridSprite.scrollX)) / TILE_SIZE;
            _rawStep[1] = Math.floor((mousePos.y - gridSprite.y + Math.abs(gridSprite.scrollY)) / TILE_SIZE);
            
            if(!FlxG.keys.pressed.SHIFT) _rawStep[0] = Math.floor(_rawStep[0]);
            
            final targetPos:Float = gridSprite.x + gridSprite.scrollX + _rawStep[0] * TILE_SIZE;
            final targetPosY:Float = gridSprite.y + gridSprite.scrollY + _rawStep[1] * TILE_SIZE;
            tileSelect.x = targetPos;
            tileSelect.y = targetPosY;

            _handleMouse();
        }

        if(_prevScrollX != (_prevScrollX = gridSprite.scrollX))
            updateEventsPosition();
    }

    function buildGrid():Void
    {
        if(gridSprite != null) 
        {
            remove(gridSprite);
            gridSprite.destroy();
        }

        final _bmp = new BitmapData(TILE_SIZE * 2, TILE_SIZE, 0xFF101020);
        _bmp.fillRect(new Rectangle(0, 0, TILE_SIZE, TILE_SIZE), 0xFF404050);

        var time:Float = 0;
        var tiles:Int = 0;
        while(time < FlxG.sound.music.length)
        {
            final stepCrotchet:Float = Conductor.getCrotchetAtTime(time) / 4;
            time += stepCrotchet;
            tiles++;
        }

        _totalWidth = TILE_SIZE * tiles;

        gridSprite = new FlxTiledSprite(_bmp, GRID_WIDTH, GRID_HEIGHT, true, true);
        gridSprite.cameras = [parent.camUI];
        add(gridSprite);
    }

    public function loadEvents():Void
    {
        for(idx => event in PlayState.SONG.events)
        {
            if (event == null || event[1] == null) continue;
            final eventNote = new EventMetaNote(event[0], event);
            eventNote.chartNoteData = -1;
            eventNote.mustPress = false;
            eventNote.setGraphicSize(TILE_SIZE);
            eventNote.updateHitbox();
            eventNote.cameras = [parent.camUI];
            add(eventNote);

            loadedEvents.push(eventNote);
        }

        updateEventsPosition();
    }

    function sortByTimeMeta(a:EventMetaNote, b:EventMetaNote):Int
        return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);

    function _handleMouse():Void
    {
        if(!isGrabbing)
        {
            tileEvent.alpha = 0;
            currentSelectedEvent = null;
            currentOverlapEvent = null;
            FlxG.stage.window.cursor = MouseCursor.DEFAULT;

            for(event in loadedEvents) 
                if(FlxG.mouse.overlaps(event, camera)) 
                {
                    currentOverlapEvent = event;
                    FlxG.stage.window.cursor = MouseCursor.MOVE;
                    break;
                }
        }

        if(currentOverlapEvent == null)
        {
            tileEvent.x = tileSelect.x; tileEvent.y = tileSelect.y;
            tileEvent.alpha = 0.5;

            if(FlxG.mouse.justPressed)
                currentOverlapEvent = addEvent(Conductor.stepToSeconds(_rawStep[0]), rememberedEvents);
        }

        if(FlxG.mouse.justPressed && FlxG.keys.pressed.ALT && currentOverlapEvent != null) 
        {
            if(inactiveEvents.contains(currentOverlapEvent)) inactiveEvents.remove(currentOverlapEvent);
            else inactiveEvents.push(currentOverlapEvent);

            skipGrab = true;

            updateEventsPosition();
            applyEvents();

            return;
        }
        
        if(FlxG.mouse.pressed && !wasPressing)
        {
            wasPressing = true;

            if(currentOverlapEvent != null)
            {
                currentSelectedEvent = currentOverlapEvent;
                parent.curSelectedNote = currentSelectedEvent.songData;
                rememberedEvents = currentSelectedEvent.events != null ? currentSelectedEvent.events.copy() : [["", "", ""]];

                if(FlxG.keys.pressed.CONTROL) parent.selectedNotes.push(currentSelectedEvent);
                else parent.selectedNotes = [currentSelectedEvent];

                parent.changeEventSelected();
                
                if(!skipGrab)
                {
                    isGrabbing = true;
                    currentGrabbedEvent = currentSelectedEvent;
                    applyEvents();
                }
            }
        }
        else if(FlxG.mouse.pressed && wasPressing && isGrabbing && currentGrabbedEvent != null)
        {
            final _prevX:Float = currentGrabbedEvent.x;
            final _prevY:Float = currentGrabbedEvent.y;
            currentGrabbedEvent.x = tileSelect.x;
            currentGrabbedEvent.y = tileSelect.y;
            
            if(currentGrabbedEvent.x != _prevX || currentGrabbedEvent.y != _prevY) 
            {
                final snd:FlxSound = FlxG.sound.play(Paths.sound('charting-sounds/note-place'));
                if(FlxG.keys.pressed.SHIFT) 
                {
                    snd.pitch = 70;
                    snd.volume = 0.03;
                }
            }
        }
        else if(FlxG.mouse.released && wasPressing && isGrabbing)
        {
            isGrabbing = wasPressing = false;
            setEventData(loadedEvents.indexOf(currentGrabbedEvent), Conductor.stepToSeconds(_rawStep[0]));
            
            currentSelectedEvent = null;
            currentGrabbedEvent = null;
            applyEvents();
            updateEventsPosition();
        }

        if(FlxG.mouse.pressedRight && currentOverlapEvent != null && parent.mainBox.selectedName != 'Camera')
        {
            wasPressing = isGrabbing = false;
            deleteEvent(currentOverlapEvent);
        }

        if(FlxG.mouse.justReleased) wasPressing = false;
        if(FlxG.mouse.released) skipGrab = false;
    }

    function updateEventsPosition():Void
    {
        for(idx => event in loadedEvents)
        {
            if(event == currentSelectedEvent && isGrabbing) continue;

            final step = Conductor.getStep(event.strumTime);
            event.x = gridSprite.x + step * TILE_SIZE + gridSprite.scrollX;
            event.y = gridSprite.y;
            event.alpha = inactiveEvents.contains(event) ? 0.35 : 1;
        }
    }

    public function applyEvents(hard:Bool = false):Void
    {
        try {
            game.eventNotes.resize(0);
            PlayState.SONG.events = [];

			for (event in loadedEvents)
			{
                if (event == null || event.events == null) continue;

                final cleanSubEvents:Array<Array<String>> = [];
				for (i in 0...event.events.length)
				{
                    final sub = event.events[i];
                    if (sub == null) continue;
                    final evName:String = sub[0] != null ? Std.string(sub[0]) : '';
                    final val1:String = sub[1] != null ? Std.string(sub[1]) : '';
                    final val2:String = sub[2] != null ? Std.string(sub[2]) : '';
                    cleanSubEvents.push([evName, val1, val2]);

                    if(inactiveEvents.contains(event) || currentGrabbedEvent == event || !hard && event.strumTime < Conductor.songPosition) continue;

					final subEvent:EventNote = {
						strumTime: event.strumTime + ClientPrefs.noteOffset,
						event: evName,
						value1: val1,
						value2: val2
					};
					@:privateAccess subEvent.strumTime -= game.eventNoteEarlyTrigger(subEvent);
					game.eventNotes.push(subEvent);
				}

                if (cleanSubEvents.length > 0)
                    PlayState.SONG.events.push([event.strumTime, cleanSubEvents]);
			}
		} catch (e:Dynamic) {}

        if(game.eventNotes.length > 1) 
			game.eventNotes.sort(sortByTime);
    }

    public function addEvent(time:Float, ?events:Dynamic):EventMetaNote
    {
        var cleanEvents:Array<Array<String>> = [];
        if (events != null && Std.isOfType(events, Array))
        {
            final rawList:Array<Dynamic> = cast events;
            for (sub in rawList)
            {
                if (sub != null && Std.isOfType(sub, Array))
                {
                    final subArr:Array<Dynamic> = cast sub;
                    final evName:String = subArr[0] != null ? Std.string(subArr[0]) : "";
                    final val1:String   = subArr[1] != null ? Std.string(subArr[1]) : "";
                    final val2:String   = subArr[2] != null ? Std.string(subArr[2]) : "";
                    cleanEvents.push([evName, val1, val2]);
                }
            }
        }
        
        if (cleanEvents.length == 0)
            cleanEvents = [["", "", ""]];

        final eventNote = new EventMetaNote(time, [time, cleanEvents]);
        eventNote.chartNoteData = -1;
        eventNote.mustPress = false;
        eventNote.setGraphicSize(TILE_SIZE);
        eventNote.updateHitbox();
        eventNote.cameras = [parent.camUI];
        add(eventNote);

        loadedEvents.push(eventNote);

        final snd:FlxSound = FlxG.sound.play(Paths.sound('charting-sounds/note-place'));
        applyEvents();
        updateEventsPosition();

        return eventNote;
    }

    function deleteEvent(event:EventMetaNote):Void
    {
        if(event == null) return;

        loadedEvents.remove(event);
        remove(event);
        event.destroy();

        currentSelectedEvent = null;
        currentGrabbedEvent = null;

        FlxG.sound.play(Paths.sound('charting-sounds/note-erase'));
        applyEvents();
        updateEventsPosition();
    }

    function sortByTime(Obj1:EventNote, Obj2:EventNote):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

    function setEventData(idx:Int, time:Float):Void
        loadedEvents[idx].setStrumTime(time);

    public function setGridPosition(dt:Float):Void
        gridSprite.scrollX = _totalWidth * -dt;
}