package game.states.editors.meta;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;

import game.objects.Note;

class MetaNote extends Note
{
	public static var noteTypeTexts:Map<Int, FlxText> = [];
	
	public var isEvent:Bool = false;
	public var songData:Array<Dynamic>;
	public var sustainSprite:FlxSprite;
	public var sustainEndSprite:FlxSprite;

	public var chartY:Float = 0;
	public var chartNoteData:Int = 0;

	public function new(time:Float, data:Int, songData:Array<Dynamic>)
	{
		super(time, data, null, false, true);
		this.songData = songData;
		this.strumTime = time;
		this.chartNoteData = data;
	}

	inline function getNoteSkin():String
	{
		if(texture?.length > 0) return texture;

		if(PlayState.SONG?.arrowSkin?.length > 0)
			return PlayState.SONG.arrowSkin;

		return Note.defaultNoteSkin;
	}

	inline function refreshSustainAssets():Void
	{
		if(sustainSprite == null && sustainEndSprite == null) return;

		var skin:String = getNoteSkin();
		var colorStr:String = Note.colArray[noteData % Note.colArray.length];

		if(sustainSprite != null)
		{
			sustainSprite.frames = Paths.getSparrowAtlas(skin);
			sustainSprite.animation.addByPrefix('hold', colorStr + ' hold piece', 24, true);
			sustainSprite.animation.play('hold', true);
			sustainSprite.updateHitbox();
		}

		if(sustainEndSprite != null)
		{
			sustainEndSprite.frames = Paths.getSparrowAtlas(skin);
			sustainEndSprite.animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
			sustainEndSprite.animation.addByPrefix(Note.colArray[noteData] + 'holdend', Note.colArray[noteData] + ' hold end');
			sustainEndSprite.animation.play(Note.colArray[noteData] + 'holdend', true);
			sustainEndSprite.updateHitbox();
		}
	}

	public function changeNoteData(v:Int)
	{
		this.chartNoteData = v; // despite being so arbitrary its sadly needed to fix a bug on moving notes
		this.songData[1] = v;
		this.noteData = v % ChartEditorState.GRID_COLUMNS_PER_PLAYER;
		this.mustPress = (v < ChartEditorState.GRID_COLUMNS_PER_PLAYER);

		if(!PlayState.isPixelStage)
			loadNoteAnims();
		else
			loadPixelNoteAnims();

		animation.play(Note.colArray[this.noteData % Note.colArray.length] + 'Scroll');
		updateHitbox();

		if(width > height)
			setGraphicSize(ChartEditorState.GRID_SIZE);
		else
			setGraphicSize(0, ChartEditorState.GRID_SIZE);

		updateHitbox();

		if(sustainSprite != null || sustainEndSprite != null)
		{
			refreshSustainAssets();
		}
	}

	public function setStrumTime(v:Float)
	{
		this.songData[0] = v;
		this.strumTime = v;
	}

	var _lastZoom:Float = -1;
	public function setSustainLength(v:Float, stepCrochet:Float, zoom:Float = 1)
	{
		_lastZoom = zoom;
		v = Math.round(v / (stepCrochet / 2)) * (stepCrochet / 2);
		songData[2] = sustainLength = Math.max(Math.min(v, stepCrochet * 128), 0);

		if(sustainLength > 0)
		{
			var needsRefresh = false;
			if(sustainSprite == null)
			{
				sustainSprite = new FlxSprite();
				sustainSprite.scrollFactor.x = 0;
				needsRefresh = true;
			}

			if(sustainEndSprite == null)
			{
				sustainEndSprite = new FlxSprite();
				sustainEndSprite.scrollFactor.x = 0;
				needsRefresh = true;
			}

			if (needsRefresh) refreshSustainAssets();

			final halfSteps:Float = sustainLength / (stepCrochet / 2);

			var height:Float = halfSteps * (ChartEditorState.GRID_SIZE * zoom / 2);
			if (height < ChartEditorState.GRID_SIZE / 4) 
				height = ChartEditorState.GRID_SIZE / 4;

			sustainSprite.setGraphicSize(Std.int(10 * zoom), Std.int(height));
			sustainSprite.updateHitbox();

			sustainEndSprite.setGraphicSize(Std.int(10 * zoom), 0);
			sustainEndSprite.updateHitbox();
		}
		
		setGraphicSize(Std.int(ChartEditorState.GRID_SIZE), sustainLength > 0 ? 0 : Std.int(ChartEditorState.GRID_SIZE));
		updateHitbox();
	}

	public var hasSustain(get, never):Bool;
	function get_hasSustain() return (!isEvent && sustainLength > 0);

	public function updateSustainToZoom(stepCrochet:Float, zoom:Float = 1)
	{
		if(_lastZoom == zoom) return;
		setSustainLength(sustainLength, stepCrochet, zoom);
	}

	public function updateSustainToStepCrochet(stepCrochet:Float)
	{
		if(_lastZoom < 0) return;
		setSustainLength(sustainLength, stepCrochet, _lastZoom);
	}

	var _noteTypeText:FlxText;
	public function findNoteTypeText(num:Int)
	{
		var txt:FlxText = null;
		if(num != 0)
		{
			if(!noteTypeTexts.exists(num))
			{
				txt = new FlxText(0, 0, ChartEditorState.GRID_SIZE, (num > 0) ? Std.string(num) : '?', 14);
				txt.setFormat(Paths.font("pixel-latin.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.SHADOW, FlxColor.BLACK);
				txt.setBorderStyle(SHADOW_XY(2, 2));
				txt.autoSize = false;
				txt.scrollFactor.x = 0;
				noteTypeTexts.set(num, txt);
			}
			else txt = noteTypeTexts.get(num);
		}
		return (_noteTypeText = txt);
	}

	override function draw()
	{
		if(sustainSprite != null && sustainSprite.exists && sustainSprite.visible && sustainLength > 0)
		{
			sustainSprite.x = this.x + this.width / 2 - sustainSprite.width / 2;
			sustainSprite.y = this.y + this.height / 2;
			sustainSprite.alpha = this.alpha;
			sustainSprite.draw();

			if(sustainEndSprite != null && sustainEndSprite.exists && sustainEndSprite.visible)
			{
				sustainEndSprite.x = this.x + this.width / 2 - sustainEndSprite.width / 2;
				sustainEndSprite.y = sustainSprite.y + sustainSprite.height;
				sustainEndSprite.alpha = this.alpha;
				sustainEndSprite.draw();
			}
		}

		super.draw();

		if(_noteTypeText != null && _noteTypeText.exists && _noteTypeText.visible)
		{
			final noteScale = this.width / ChartEditorState.GRID_SIZE;
			
			_noteTypeText.scale.set(noteScale, noteScale);
			
			_noteTypeText.x = this.x + (this.width - _noteTypeText.width) / 2;
			_noteTypeText.y = this.y + (this.height - _noteTypeText.height) / 2;
			
			_noteTypeText.alpha = this.alpha;
			_noteTypeText.draw();
		}
	}

	override function destroy()
	{
		sustainSprite = FlxDestroyUtil.destroy(sustainSprite);
		sustainEndSprite = FlxDestroyUtil.destroy(sustainEndSprite);

		super.destroy();
	}
}

class EventMetaNote extends MetaNote
{
	public var eventText:FlxText;
	public function new(time:Float, eventData:Dynamic)
	{
		super(time, -1, eventData);
		this.isEvent = true;
		events = eventData[1];

		loadGraphic(Paths.image('editors/eventArrow'));
		setGraphicSize(ChartEditorState.GRID_SIZE);
		updateHitbox();

		eventText = new FlxText(50, 0, 400, '', 8);
		eventText.setFormat(Paths.font("pixel-latin.ttf"), 8, FlxColor.WHITE, RIGHT, FlxColor.BLACK);
		eventText.scrollFactor.x = 0;
		eventText.borderSize = 1;
		updateEventText();
	}

	override function draw()
	{
		if(eventText != null && eventText.exists && eventText.visible)
		{
			final noteScale = this.width / ChartEditorState.GRID_SIZE;
			eventText.scale.set(noteScale, noteScale);
			
			final padding = 10 * noteScale;
			eventText.x = this.x - padding - (eventText.width / 2) - (eventText.width / 2) * noteScale;
			eventText.y = this.y + (this.height - eventText.height) / 2;
			
			eventText.alpha = this.alpha;
			eventText.draw();
		}
		super.draw();
	}

	override function setSustainLength(v:Float, stepCrochet:Float, zoom:Float = 1) {}

	public var events:Array<Array<String>>;
	public function updateEventText()
	{
		if (eventText == null) return;
		
		var myTime:Float = Math.floor(this.strumTime);
		if(events.length == 1)
		{
			var event = events[0];
			var text:String = 'Event: ${event[0]} ($myTime ms)\nValue 1: ${event[1]}\nValue 2: ${event[2]}';
			if(event[3]?.length > 0)
				text += '\nValue 3: ${event[3]}';
			eventText.text = text;
		}
		else if(events.length > 1)
		{
			var eventNames:Array<String> = [for (event in events) event[0]];
			eventText.text = '${events.length} Events ($myTime ms):\n${eventNames.join(', ')}';
		}
		else eventText.text = 'ERROR FAILSAFE';
	}

	override function destroy()
	{
		eventText = FlxDestroyUtil.destroy(eventText);
		super.destroy();
	}
}
