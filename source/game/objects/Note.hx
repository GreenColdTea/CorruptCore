package game.objects;

import math.Vector3;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.util.FlxColor;

import openfl.display.BitmapData;

import game.states.editors.ChartEditorState;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

class Note extends flixel.addons.effects.FlxSkewedSprite
{
	public static final SUSTAIN_SIZE:Int = 44;
	public static final defaultNoteSkin:String = 'NOTE_assets';

	public var vec3Cache:Vector3 = new Vector3(1, 1, 0);
	public var defScale:FlxPoint = FlxPoint.get(1, 1);

	public var extraData:Map<String,Dynamic> = [];

	public var rawData:Dynamic;

	public var row:Int = 0;

	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var noteData:Int = 0;

	public var canBeHit(get, never):Bool;
	public var tooLate(get, never):Bool;

	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var holdNote:Sustain = null;
	public var strum:StrumNote = null;

	public var spawned:Bool = false;

	public var tail:Array<Note> = [];
	public var parent:Note;
	public var blockHit:Bool = false;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var mAngle:Float = 0;
	public var bAngle:Float = 0;
	public var typeOffsetX:Float = 0;
	public var typeOffsetY:Float = 0;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var colorSwap:ColorSwap;
	public var inEditor:Bool = false;

	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 0.5;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;

	public static var swagWidth:Float = 160 * 0.7;
	
	public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	private var pixelInt:Array<Int> = [0, 1, 2, 3];

	public var noteSplashDisabled:Bool = false;
	public var noteSplashTexture:String = null;
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0;
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000;

	public var hitsoundDisabled:Bool = false;

	private function get_canBeHit():Bool {
		if (!mustPress) return false;
		
		if (isSustainNote) {
			return Conductor.songPosition >= strumTime - (Conductor.safeZoneOffset * lateHitMult) && 
				   Conductor.songPosition <= strumTime + sustainLength + (Conductor.safeZoneOffset * earlyHitMult);
		}
		
		return strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult)
			&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult);
	}

	private function get_tooLate():Bool {
		if (isSustainNote) {
			return mustPress && !wasGoodHit && Conductor.songPosition > strumTime + sustainLength + Conductor.safeZoneOffset;
		}
		return mustPress && !wasGoodHit && strumTime < Conductor.songPosition - Conductor.safeZoneOffset;
	}

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		return value;
	}

	public function resizeByRatio(ratio:Float) {
		if(isSustainNote && !animation?.curAnim?.name?.endsWith('end')) {
			if(scale != null && defScale != null) {
				scale.y *= ratio;
				defScale.y = scale.y;
				updateHitbox();
			}
		}
	}

	private function set_texture(value:String):String {
		if(texture != value) reloadNote('', value);
		texture = value;
		return value;
	}

	private function set_noteType(value:String):String {
		if(noteData < 0) return '';

		noteSplashTexture = PlayState.SONG.splashSkin;
		if (noteData > -1 && noteData < ClientPrefs.arrowHSV.length)
		{
			colorSwap.hue = ClientPrefs.arrowHSV[noteData][0] / 360;
			colorSwap.saturation = ClientPrefs.arrowHSV[noteData][1] / 100;
			colorSwap.brightness = ClientPrefs.arrowHSV[noteData][2] / 100;
		}

		if(noteData > -1 && noteType != value) {
			switch(value) {
				case 'Hurt Note':
					ignoreNote = mustPress;
					reloadNote('HURT');
					noteSplashTexture = 'HURTnoteSplashes';
					colorSwap.hue = 0;
					colorSwap.saturation = 0;
					colorSwap.brightness = 0;
					lowPriority = true;
					missHealth = isSustainNote ? 0.1 : 0.3;
					hitCausesMiss = true;
				case 'Alt Animation':
					animSuffix = '-alt';
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
			}
			noteType = value;
		}
		noteSplashHue = colorSwap.hue;
		noteSplashSat = colorSwap.saturation;
		noteSplashBrt = colorSwap.brightness;
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false)
	{
		super();

		animation = new PsychAnimationController(this);

		prevNote ??= this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.rawData = null;

		x += (ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.noteOffset;

		this.noteData = noteData;

		if(noteData > -1) {
			texture = '';
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;

			x += swagWidth * (noteData);

			if(!isSustainNote && noteData > -1 && noteData < 4)
				animation.play(colArray[noteData % 4] + 'Scroll');
		}

		if(prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			hitsoundDisabled = true;

			#if MODCHART_ALLOWED flipX = #end flipY = ClientPrefs.downScroll;

			offsetX += width / 2;
			copyAngle = false;

			animation.play(colArray[noteData % 4] + 'holdend');

			defScale.copyFrom(scale);
			updateHitbox();

			offsetX -= width / 2;

			if (PlayState.isPixelStage)
				offsetX += 30;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.noteData % 4] + 'hold');

				prevNote.scale.y *= Conductor.stepCrochet / 102 * 1.05;
				if(PlayState.instance != null)
				{
					prevNote.scale.y *= PlayState.instance.songSpeed;
				}

				if(PlayState.isPixelStage) {
					prevNote.scale.y *= 1.22;
					prevNote.scale.y *= (6 / height);
				}

				prevNote.defScale?.copyFrom(prevNote.scale);
				prevNote.updateHitbox();
			}

			if(PlayState.isPixelStage) {
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
		} else if(!isSustainNote) {
			earlyHitMult = 1;
		}

		defScale?.copyFrom(scale);
		x += offsetX;
	}

	var _lastNoteOffX:Float = 0;
	var lastNoteOffsetXForPixelAutoAdjusting:Float = 0;
	public var originalHeightForCalcs:Float = 6;
	public var correctionOffset:Float = 0;

	public function reloadNote(?prefix:String, ?texture:String, ?postfix:String) {
		prefix ??= '';
		texture ??= '';
		postfix ??= '';

		var skin:String = texture;
		if(texture.length < 1) {
			skin = PlayState.SONG.arrowSkin;
			if(skin == null || skin.length < 1) skin = defaultNoteSkin;
		}

		var animName:String = null;
		if(animation?.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var arraySkin:Array<String> = skin.split('/');
		arraySkin[arraySkin.length-1] = prefix + arraySkin[arraySkin.length-1] + postfix;

		var lastScaleY:Float = scale?.y ?? 1.0;
		scale ??= FlxPoint.get(1, 1);
		
		var skinName:String = arraySkin.join('/');
		if(PlayState.isPixelStage) {
			if(isSustainNote) {
				var graphic = Paths.image('pixelUI/' + skinName + 'ENDS');
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 2));
			} else {
				var graphic = Paths.image('pixelUI/' + skinName);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 5));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			loadPixelNoteAnims();
			antialiasing = false;

			if(isSustainNote) {
				offsetX += _lastNoteOffX;
				_lastNoteOffX = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= _lastNoteOffX;
			}
		} else {
			frames = Paths.getSparrowAtlas(skinName);
			loadNoteAnims();
			antialiasing = ClientPrefs.globalAntialiasing;
			if(!isSustainNote)
			{
				centerOffsets();
				centerOrigin();
			}
		}

		if(isSustainNote) {
			scale.y = lastScaleY;
		}

		defScale?.copyFrom(scale);
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);
	}

	function loadNoteAnims() {
		animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0');

		if (isSustainNote)
		{
			animation.addByPrefix('purpleholdend', 'pruple end hold');
			animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end');
			animation.addByPrefix(colArray[noteData] + 'hold', colArray[noteData] + ' hold piece');
		}

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if(isSustainNote) {
			animation.add(colArray[noteData] + 'holdend', [pixelInt[noteData] + 4]);
			animation.add(colArray[noteData] + 'hold', [pixelInt[noteData]]);
		} else {
			animation.add(colArray[noteData] + 'Scroll', [pixelInt[noteData] + 4]);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!inEditor)
		{
			if (!mustPress)
			{
				if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				{
					if ((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					{
						wasGoodHit = true;
					}
				}
			}
			
			if (tooLate && alpha > 0.3)
			{
				alpha = 0.3;
			}
		}
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect
	{
		clipRect = rect;
		if (frames != null)
			frame = frames.frames[animation.frameIndex];
		return rect;
	}

	override function destroy()
	{
		texture = '';
		vec3Cache = null;
		defScale?.put();
		clipRect = flixel.util.FlxDestroyUtil.put(clipRect);
		super.destroy();
	}
}

class Sustain extends game.graphics.TileRenderer
{
	private var lastFlip:Bool = false;
	private var lastSpeed:Float = -1.0;

	public var hit:Bool = false;
	public var timeStuff:Float = 0.;
	public var parent:Note;

	public function updateVisuals(speed:Float = 1, flipped:Bool = false)
	{
		final dirty:Bool = lastFlip != flipped || lastSpeed != speed || hit;

		if (this.alpha != parent.alpha)
			this.alpha = parent.alpha;

		if (this.antialiasing != parent.antialiasing)
			this.antialiasing = parent.antialiasing;

		if (this.shader != parent.shader)
			this.shader = parent.shader;
			
		if (!dirty)
			return;

		lastFlip = flipped;
		lastSpeed = speed;

		height = (0.45 * speed * (parent.sustainLength - timeStuff));
		angle = lastFlip ? 180 : 0;
		flipX = lastFlip;
	}

	public function updatePos()
	{
		if (x != parent.x)
			x = parent.x;
		
		final yOffset:Float = (Note.swagWidth * 0.5) - 2.5;
		final eatenPixels:Float = (0.45 * lastSpeed * timeStuff);

		if (hit)
		{
			y = parent.strum.y + yOffset;
			parent.y = parent.strum.y;
			return;
		}
		y = parent.y + yOffset - (lastFlip ? eatenPixels : -eatenPixels);
	}

	public function new(p:Note)
	{
		super();
		parent = p;
		reloadSkin();
	}

	public function reloadSkin()
	{
		if (parent == null || parent.animation == null) return;
		
		frames = parent.frames;
		animation.copyFrom(parent.animation);
		
		final animName = Note.colArray[parent.noteData % 4] + 'hold';
		
		animation.play(animName);
		tailAnim = animName + 'end';
		
		scale.copyFrom(parent.scale);
		updateHitbox();

		offset.y = origin.y = 0;
	}
}