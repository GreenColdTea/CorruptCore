package game.objects.audio;

import flixel.FlxSprite;
import flixel.util.FlxColor;

import lime.media.AudioBuffer;

import haxe.io.Bytes;

import openfl.geom.Rectangle;
import openfl.display.BitmapData;

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)
class Waveform extends FlxSprite
{
	public var enabled:Bool = false;
	public var target:String = "INST";
	
	public static inline var HORIZONTAL:Int = 0;
	public static inline var VERTICAL:Int = 1;
	
	public var orientation:Int = HORIZONTAL;
	
	private var _wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	private var _sound:FlxSound;
	private var _startTime:Float = 0;
	private var _endTime:Float = 0;
	private var _width:Int = 0;
	private var _height:Int = 0;
	
	// Добавляем настройки для лучшего отображения
	public var amplification:Float = 1.5; // Усиление для лучшей видимости
	public var showFill:Bool = true; // Заливка внутренней части
	public var showOutline:Bool = true; // Контуры
	
	public function new(x:Float, y:Float, width:Int, height:Int, orientation:Int = HORIZONTAL)
	{
		super(x, y);
		_width = width;
		_height = height;
		this.orientation = orientation;
		makeGraphic(width, height, FlxColor.TRANSPARENT);
	}
	
	public function setSound(sound:FlxSound):Void
	{
		_sound = sound;
	}
	
	public function setTimeRange(startTime:Float, endTime:Float):Void
	{
		_startTime = startTime;
		_endTime = endTime;
	}
	
	public function setOrientation(newOrientation:Int):Void
	{
		if (orientation != newOrientation) {
			orientation = newOrientation;
			updateWaveform();
		}
	}
	
	public function updateWaveform():Void
	{
		#if (lime_cffi && !macro)
		if(!enabled || _sound == null)
		{
			visible = false;
			return;
		}

		visible = true;
		
		var bmp:BitmapData = new BitmapData(_width, _height, true, FlxColor.TRANSPARENT);
		
		_wavData[0][0].resize(0);
		_wavData[0][1].resize(0);
		_wavData[1][0].resize(0);
		_wavData[1][1].resize(0);

		if (_sound._sound != null && _sound._sound.__buffer != null)
		{
			try {
				var bytes:Bytes = _sound._sound.__buffer.data.toBytes();
				
				// Увеличиваем диапазон для захвата звуков, которые могут начинаться/заканчиваться не точно на границах секции
				var padding:Float = 100; // 100ms padding
				var startTimeWithPadding:Float = Math.max(0, _startTime - padding);
				var endTimeWithPadding:Float = Math.min(_sound.length, _endTime + padding);
				
				_wavData = waveformData(_sound._sound.__buffer, bytes, startTimeWithPadding, endTimeWithPadding, amplification, _wavData, 
					orientation == HORIZONTAL ? _height : _width);
			} catch(e:Dynamic) {
				trace("Error processing waveform data: " + e);
				loadGraphic(bmp);
				return;
			}
		}
		else
		{
			loadGraphic(bmp);
			return;
		}

		var leftLength:Int = (_wavData[0][0].length > _wavData[0][1].length ? _wavData[0][0].length : _wavData[0][1].length);
		var rightLength:Int = (_wavData[1][0].length > _wavData[1][1].length ? _wavData[1][0].length : _wavData[1][1].length);
		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		if (length == 0) {
			loadGraphic(bmp);
			return;
		}

		if (orientation == HORIZONTAL) {
			drawHorizontalWaveform(bmp, length);
		} else {
			drawVerticalWaveform(bmp, length);
		}
		
		loadGraphic(bmp);
		#else
		visible = false;
		#end
	}
	
	private function drawHorizontalWaveform(bmp:BitmapData, length:Int):Void
	{
		var centerY:Float = _height / 2;
		var scale:Float = _height / 2;

		for (index in 0...length)
		{
			var xPos:Float = (index / length) * _width;
			
			var lmin:Float = ((index < _wavData[0][0].length && index >= 0) ? _wavData[0][0][index] : 0) * scale;
			var lmax:Float = ((index < _wavData[0][1].length && index >= 0) ? _wavData[0][1][index] : 0) * scale;

			var rmin:Float = ((index < _wavData[1][0].length && index >= 0) ? _wavData[1][0][index] : 0) * scale;
			var rmax:Float = ((index < _wavData[1][1].length && index >= 0) ? _wavData[1][1][index] : 0) * scale;

			// Левый канал - с заливкой
			if(Math.abs(lmin) > 0.01 || Math.abs(lmax) > 0.01) {
				var yTop:Float = centerY - lmax;
				var yBottom:Float = centerY - lmin;
				var lineHeight:Float = Math.max(1, yBottom - yTop);
				
				if (showFill) {
					// Заливка
					bmp.fillRect(new Rectangle(xPos, yTop, 1, lineHeight), FlxColor.fromRGB(100, 150, 255, 200));
				}
				if (showOutline) {
					// Контур (более яркий)
					bmp.setPixel32(Std.int(xPos), Std.int(yTop), FlxColor.fromRGB(70, 130, 255, 255));
					bmp.setPixel32(Std.int(xPos), Std.int(yBottom), FlxColor.fromRGB(70, 130, 255, 255));
				}
			}

			// Правый канал - с заливкой
			if(Math.abs(rmin) > 0.01 || Math.abs(rmax) > 0.01) {
				var yTop:Float = centerY + rmin;
				var yBottom:Float = centerY + rmax;
				var lineHeight:Float = Math.max(1, yBottom - yTop);
				
				if (showFill) {
					// Заливка
					bmp.fillRect(new Rectangle(xPos, yTop, 1, lineHeight), FlxColor.fromRGB(255, 100, 100, 200));
				}
				if (showOutline) {
					// Контур (более яркий)
					bmp.setPixel32(Std.int(xPos), Std.int(yTop), FlxColor.fromRGB(255, 70, 70, 255));
					bmp.setPixel32(Std.int(xPos), Std.int(yBottom), FlxColor.fromRGB(255, 70, 70, 255));
				}
			}
		}
	}
	
	private function drawVerticalWaveform(bmp:BitmapData, length:Int):Void
	{
		var centerX:Float = _width / 2;
		var scale:Float = _width / 2;

		for (index in 0...length)
		{
			var yPos:Float = (index / length) * _height;
			
			var lmin:Float = ((index < _wavData[0][0].length && index >= 0) ? _wavData[0][0][index] : 0) * scale;
			var lmax:Float = ((index < _wavData[0][1].length && index >= 0) ? _wavData[0][1][index] : 0) * scale;

			var rmin:Float = ((index < _wavData[1][0].length && index >= 0) ? _wavData[1][0][index] : 0) * scale;
			var rmax:Float = ((index < _wavData[1][1].length && index >= 0) ? _wavData[1][1][index] : 0) * scale;

			// Левый канал
			if(Math.abs(lmin) > 0.01 || Math.abs(lmax) > 0.01) {
				var xLeft:Float = centerX - lmax;
				var xRight:Float = centerX - lmin;
				var lineWidth:Float = Math.max(1, xRight - xLeft);
				
				if (showFill) {
					bmp.fillRect(new Rectangle(xLeft, yPos, lineWidth, 1), FlxColor.fromRGB(100, 150, 255, 200));
				}
				if (showOutline) {
					bmp.setPixel32(Std.int(xLeft), Std.int(yPos), FlxColor.fromRGB(70, 130, 255, 255));
					bmp.setPixel32(Std.int(xRight), Std.int(yPos), FlxColor.fromRGB(70, 130, 255, 255));
				}
			}

			// Правый канал
			if(Math.abs(rmin) > 0.01 || Math.abs(rmax) > 0.01) {
				var xLeft:Float = centerX + rmin;
				var xRight:Float = centerX + rmax;
				var lineWidth:Float = Math.max(1, xRight - xLeft);
				
				if (showFill) {
					bmp.fillRect(new Rectangle(xLeft, yPos, lineWidth, 1), FlxColor.fromRGB(255, 100, 100, 200));
				}
				if (showOutline) {
					bmp.setPixel32(Std.int(xLeft), Std.int(yPos), FlxColor.fromRGB(255, 70, 70, 255));
					bmp.setPixel32(Std.int(xRight), Std.int(yPos), FlxColor.fromRGB(255, 70, 70, 255));
				}
			}
		}
	}
	
	public function resize(newWidth:Int, newHeight:Int):Void
	{
		_width = newWidth;
		_height = newHeight;
		makeGraphic(_width, _height, FlxColor.TRANSPARENT);
	}
	
	private function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz * channels);
		var totalSamples:Int = Std.int((endTime - time) * khz);

		// Увеличиваем количество шагов для лучшего разрешения
		if (steps == null) steps = Math.min(2048, orientation == HORIZONTAL ? _width : _height);
		
		// Защита от выхода за границы
		if (index < 0) index = 0;
		var maxIndex:Int = bytes.length - channels * 2;
		if (index > maxIndex) {
			// Если вышли за границы, возвращаем пустые данные
			return [[[0], [0]], [[0], [0]]];
		}

		var samplesPerRow:Float = totalSamples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = samplesPerRowI > 0;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		var samplesProcessed:Int = 0;
		var maxSamples:Int = Std.int(totalSamples * channels);

		while (index <= maxIndex && gotIndex <= steps && samplesProcessed < maxSamples) {
			if (index >= 0) {
				var byte:Int = 0;
				try {
					byte = bytes.getUInt16(index * 2);
				} catch(e:Dynamic) {
					break;
				}

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					try {
						byte = bytes.getUInt16((index * 2) + 2);
					} catch(e:Dynamic) {
						break;
					}

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			if (simpleSample ? v1 : rows >= samplesPerRow) {
				if (simpleSample) v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) 
					array[0][0].push(lRMin);
				else 
					array[0][0][gotIndex - 1] = lRMin;

				if (gotIndex > array[0][1].length) 
					array[0][1].push(lRMax);
				else 
					array[0][1][gotIndex - 1] = lRMax;

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length) 
						array[1][0].push(rRMin);
					else 
						array[1][0][gotIndex - 1] = rRMin;

					if (gotIndex > array[1][1].length) 
						array[1][1].push(rRMax);
					else 
						array[1][1][gotIndex - 1] = rRMax;
				}
				else
				{
					if (gotIndex > array[1][0].length) 
						array[1][0].push(lRMin);
					else 
						array[1][0][gotIndex - 1] = lRMin;

					if (gotIndex > array[1][1].length) 
						array[1][1].push(lRMax);
					else 
						array[1][1][gotIndex - 1] = lRMax;
				}

				lmin = 0;
				lmax = 0;
				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			samplesProcessed++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}
	
	public function clearWaveform():Void
	{
		makeGraphic(1, 1, FlxColor.TRANSPARENT);
		_wavData = [[[0], [0]], [[0], [0]]];
		_sound = null;
	}
	
	override public function destroy():Void
	{
		clearWaveform();
		super.destroy();
	}
}