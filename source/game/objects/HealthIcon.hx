package game.objects;

import flixel.FlxSprite;
import flixel.math.FlxMath;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public var targetScale:Float = 1;
	public var lerpSpeed:Float = 7;
	public var autoUpdateScale:Bool = true;
	
	public var bobbingEnabled:Bool = true;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);

		if (autoUpdateScale && bobbingEnabled)
			updateIconScale(elapsed);
	}

	/**
	 * Updates icon scale using lerp for smooth animation
	 * @param elapsed Time elapsed since last frame
	 */
	public function updateIconScale(elapsed:Float):Void
	{
		if (bobbingEnabled && (scale.x != targetScale || scale.y != targetScale))
		{
			var lerpVal:Float = FlxMath.lerp(scale.x, targetScale, 1 - Math.exp(-elapsed * lerpSpeed));
			scale.set(lerpVal, lerpVal);
			updateHitbox();
		}
	}

	/**
	 * Sets target scale for lerp animation
	 * @param newScale New target scale
	 */
	public function setTargetScale(newScale:Float):Void
	{
		if (bobbingEnabled)
			targetScale = newScale;
	}

	/**
	 * Temporarily scales up the icon (e.g., when hitting a note)
	 * @param flashScale Scale for flash effect (default 1.15)
	 * @param resetScale Scale to return to after flash (default 1)
	 */
	public function flash(flashScale:Float = 1.15, resetScale:Float = 1):Void
	{
		if (bobbingEnabled)
		{
			scale.set(flashScale, flashScale);
			targetScale = resetScale;
			updateHitbox();
		}
	}

	/**
	 * Enables or disables bobbing animation
	 * @param enabled Whether bobbing should be enabled
	 */
	public function setBobbingEnabled(enabled:Bool):Void
	{
		bobbingEnabled = enabled;
		if (!enabled)
		{
			scale.set(1, 1);
			targetScale = 1;
			updateHitbox();
		}
	}

	var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = false) 
	{
		if (this.char != char) {
			var usedName:String = 'icons/$char';
			var graphic:flixel.graphics.FlxGraphic = Paths.image(usedName, allowGPU);

			if (graphic == null) {
				usedName = 'icons/icon-$char';
				graphic = Paths.image(usedName, allowGPU);
			}
			
			if (graphic == null) {
				usedName = 'icons/icon-face';
				graphic = Paths.image(usedName, allowGPU);
			}

			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;

			scale.set(targetScale, targetScale);
			updateHitbox();

			animation.add(char, [for (i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			
			this.char = char;
			antialiasing = (char.endsWith('-pixel') ? false : ClientPrefs.globalAntialiasing);
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();

		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	inline public function getCharacter():String 
		return char;
}