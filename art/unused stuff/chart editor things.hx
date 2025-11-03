class ContextMenu extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var menuBg:FlxSprite;
	var buttons:Array<PsychUIButton> = [];

	public function new(x:Float, y:Float, note:Note, deleteCallback:Note->Void, copyCallback:Note->Void, pasteCallback:Void->Void)
	{
		super();
		
		closeCallback = () -> close();
		
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT);
		bg.scrollFactor.set();
		bg.alpha = 0.0001;
		bg.setPosition(0, 0);
		add(bg);
		
		menuBg = new FlxSprite(x, y).makeGraphic(0, 0, FlxColor.BLACK);
		menuBg.alpha = 0.8;
		menuBg.scrollFactor.set();
		add(menuBg);
		
		var buttonY = y + 5;
		createButton("Delete", x + 5, buttonY, function() {
			deleteCallback(note);
			closeMenu();
		});
		
		buttonY += 30;
		createButton("Copy", x + 5, buttonY, function() {
			copyCallback(note);
			closeMenu();
		});
		
		buttonY += 30;
		createButton("Paste", x + 5, buttonY, function() {
			pasteCallback();
			closeMenu();
		});
		
		//note properties removed for event notes due to critical error
		if (note.noteData > -1) {
			buttonY += 30;
			createButton("Properties", x + 5, buttonY, () -> openNoteProperties(note));
		}
		
		var buttonCount = note.noteData > -1 ? 4 : 3;
		menuBg.makeGraphic(90, buttonCount * 30, FlxColor.BLACK);
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function createButton(label:String, x:Float, y:Float, onClick:Void->Void)
	{
		var button = new PsychUIButton(x, y, label, onClick);
		button.scrollFactor.set();
		add(button);
		buttons.push(button);
		return button;
	}

	function closeMenu():Void
	{
		if (closeCallback != null) closeCallback();
	}

	function openNoteProperties(note:Note):Void
	{
		var parent:ChartEditorState = cast FlxG.state.subState._parentState;
		@:privateAccess {
			openSubState(new NotePropertiesSubstate(note, function(updatedNote:Note) {
				parent.saveToUndo();
				parent.updateNoteData(note, updatedNote);
				parent.updateGrid();
				closeSubState();
			}, parent.eventStuff));
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.mouse.justPressed) {
			var mousePoint = FlxG.mouse.getViewPosition(camera);
			
			if (!menuBg.getScreenBounds(null, camera).containsPoint(mousePoint))
				closeMenu();
		}
		
		if (FlxG.keys.justPressed.ESCAPE)
			closeMenu();
	}
}

class NotePropertiesSubstate extends MusicBeatSubstate
{
    var note:Note;
    var onSaveCallback:Note->Void;
    var onCloseCallback:Void->Void;
	var eventStuff:Array<Dynamic>;
    
	var descText:FlxText;
    var strumTimeStepper:PsychUINumericStepper;
    var noteDataStepper:PsychUINumericStepper;
    var sustainStepper:PsychUINumericStepper;
    var typeInput:PsychUIInputText;
    var value1Input:PsychUIInputText;
    var value2Input:PsychUIInputText;
    var eventDropdown:PsychUIDropDownMenu;
    
    public function new(note:Note, onSaveCallback:Note->Void, eventStuff:Array<Dynamic>)
	{
        super();
        this.note = note;
        this.onSaveCallback = onSaveCallback;
		this.eventStuff = eventStuff; 
        
        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        bg.scrollFactor.set();
        add(bg);
        
        var panel = new FlxSprite(FlxG.width / 2 - 150, FlxG.height / 2 - 150).makeGraphic(300, 300, FlxColor.GRAY);
		panel.scrollFactor.set();
        add(panel);
        
        var title = new FlxText(panel.x, panel.y + 10, 300, "Note Properties", 16);
        title.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		title.scrollFactor.set();
        add(title);
        
        var yOffset:Int = 50;
        
        if (note.noteData > -1)
        {
            var timeLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Strum Time:");
			timeLabel.scrollFactor.set();
            add(timeLabel);
            
            strumTimeStepper = new PsychUINumericStepper(panel.x + 120, panel.y + yOffset, 10, note.strumTime, 0, 999999, 0);
			strumTimeStepper.scrollFactor.set();
            add(strumTimeStepper);
            yOffset += 30;
            
            var dataLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Note Data:");
			dataLabel.scrollFactor.set();
            add(dataLabel);
            
			noteDataStepper = new PsychUINumericStepper(panel.x + 120, panel.y + yOffset, 1, note.noteData, 0, 7, 0);
			noteDataStepper.scrollFactor.set();
            add(noteDataStepper);
            yOffset += 30;
            
            var sustainLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Sustain:");
			sustainLabel.scrollFactor.set();
            add(sustainLabel);
            
            sustainStepper = new PsychUINumericStepper(panel.x + 120, panel.y + yOffset, 10, note.sustainLength, 0, 9999, 0);
			sustainStepper.scrollFactor.set();
            add(sustainStepper);
            yOffset += 30;
            
            var typeLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Note Type:");
			typeLabel.scrollFactor.set();
            add(typeLabel);
            
            typeInput = new PsychUIInputText(panel.x + 120, panel.y + yOffset, 150, note.noteType != null ? note.noteType : "");
			typeInput.scrollFactor.set();
            add(typeInput);
        }
        else
        {
            var eventLabel = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Event Type:");
			eventLabel.scrollFactor.set();
            add(eventLabel);
            
            var eventList = [];
            for (i in 0...eventStuff.length) {
                eventList.push({label: eventStuff[i][0], id: Std.string(i)});
            }
            
            var eventNames:Array<String> = [for (event in eventStuff) event[0]];
			eventDropdown = new PsychUIDropDownMenu(panel.x + 120, panel.y + yOffset, 
				eventNames, 
				function(id:Int, value:String) {
					if (id >= 0 && id < eventStuff.length) {
						var eventName = eventStuff[id][0];
						var eventDesc = eventStuff[id][1];
						descText.text = eventDesc;
						
						if (value1Input != null && value1Input.text == "") {
							var defaultValues = getDefaultEventValues(eventName);
							value1Input.text = defaultValues[0];
							value2Input.text = defaultValues[1];
						}
					}
				}
			);
            eventDropdown.selectedIndex = Std.parseInt(note.eventName);
			eventDropdown.scrollFactor.set();
			
            yOffset += 30;
            
            var val1Label = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Value 1:");
			val1Label.scrollFactor.set();
            add(val1Label);
            
            value1Input = new PsychUIInputText(panel.x + 120, panel.y + yOffset, 150, note.eventVal1 != null ? note.eventVal1 : "");
			value1Input.scrollFactor.set();
            add(value1Input);

            yOffset += 30;
            
            var val2Label = new FlxText(panel.x + 20, panel.y + yOffset, 100, "Value 2:");
			val2Label.scrollFactor.set();
            add(val2Label);
            
            value2Input = new PsychUIInputText(panel.x + 120, panel.y + yOffset, 150, note.eventVal2 != null ? note.eventVal2 : "");
			value2Input.scrollFactor.set();
            add(value2Input);

			var currentEventIndex = -1;
			for (i in 0...eventStuff.length)
			{
				if (eventStuff[i][0] == note.eventName)
				{
					currentEventIndex = i;
					break;
				}
			}

			descText = new FlxText(panel.x + 20, panel.y + yOffset + 30, 260, "", 12);
			descText.wordWrap = true;
			descText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE);
			descText.scrollFactor.set();
			add(descText);

			if (currentEventIndex != -1)
			{
				eventDropdown.selectedIndex = currentEventIndex;
				descText.text = eventStuff[currentEventIndex][1];
			}
			else
			{
				eventDropdown.selectedLabel = note.eventName;
				descText.text = "Custom Event";
			}
        }
        
        yOffset += 40;

		if (note.noteData == -1) yOffset += 80;
        
        var saveButton = new PsychUIButton(panel.x + 50, panel.y + yOffset, "Save", () -> {
            saveChanges();
            close();
        });
        add(saveButton);
        
        var cancelButton = new PsychUIButton(panel.x + 150, panel.y + yOffset, "Cancel", () -> close());
        add(cancelButton);

		add(eventDropdown);
        
        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
    }
    
    function saveChanges()
    {
        var updatedNote = new Note(0, 0);
        updatedNote.noteData = note.noteData;
        
        if (note.noteData > -1) //Nomal note
        {
			var newData = Std.int(noteDataStepper.value);
        	if (note.noteData > 3) newData += 4;
        
            updatedNote.strumTime = strumTimeStepper.value;
            updatedNote.noteData = newData;
            updatedNote.sustainLength = sustainStepper.value;
            updatedNote.noteType = typeInput.text;
        }
        else //Event
        {
            updatedNote.strumTime = note.strumTime;
			updatedNote.eventName = eventDropdown.selectedLabel;
			updatedNote.eventVal1 = value1Input.text;
			updatedNote.eventVal2 = value2Input.text;
			
			if (value1Input != null) updatedNote.eventVal1 = value1Input.text;
			if (value2Input != null) updatedNote.eventVal2 = value2Input.text;
        }
        
        onSaveCallback(updatedNote);
    }

	function getDefaultEventValues(eventName:String):Array<String>
	{
		switch(eventName)
		{
			case 'Dadbattle Spotlight':
				return ['1', '0'];
			case 'Hey!':
				return ['BF', '0.6'];
			case 'Set GF Speed':
				return ['1', ''];
			case 'Add Camera Zoom':
				return ['0.015', '0.03'];
			case 'Play Animation':
				return ['idle', 'BF'];
			case 'Camera Follow Pos':
				return ['', ''];
			case 'Alt Idle Animation':
				return ['BF', '-alt'];
			case 'Screen Shake':
				return ['0, 0.05', '0, 0.05'];
			case 'Change Character':
				return ['BF', 'bf-car'];
			case 'Change Scroll Speed':
				return ['1', '1'];
			case 'Lyrics':
				return ['Hello! --FF0000', '2'];
			case 'Set Property':
				return ['health', '0.5'];
			default:
				return ['', ''];
		}
	}
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (FlxG.keys.justPressed.ESCAPE)
        {
            close();
        }
    }
}