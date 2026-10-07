package game.objects;

#if VIDEOS_ALLOWED
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.addons.display.FlxPieDial;
import flixel.math.FlxMath;

import hxvlc.flixel.FlxVideoSprite;

class FunkinVideoSprite extends FlxVideoSprite
{
	public static final ARG_LOOPING:String = ':input-repeat=2147483647';
	public static final ARG_MUTED:String = ':no-audio';
	public static final ARG_HW_ACCEL:String = ':avcodec-hw=any';
	public static final ARG_DROP_LATE:String = ':drop-late-frames';
	public static final ARG_SKIP_FRAMES:String = ':skip-frames';
	
	/** Whether the video pauses/resumes automatically with the game state. */
	public var isStateAffected:Bool = true;
	
	/** Whether the video sprite destroys itself automatically when finished. */
	public var autoDestroyOnComplete:Bool = true;

	/** Whether the player can skip this video by holding ENTER. */
	public var canSkip:Bool = false;
	
	/** How much time the skip button has been held (in seconds). */
	public var skipHold:Float = 0.0;
	
	/** How much time the skip button needs to be held to skip (in seconds). */
	public var skipNeed:Float = 1.0;
	
	/** The visual indicator for skipping. */
	public var pie:FlxPieDial;
	
	/** The maximum desync allowed (in milliseconds) before a forced seek occurs. */
	public var syncLeniency:Float = 500.0;

	public var initialConductTime:Float = 0;
	
	private var wasPlayingBeforeFocusLost:Bool = false;

	private var _isLooped:Bool = false;

	/**
	 * Creates a new video sprite.
	 * 
	 * @param x 			X coordinate
	 * @param y 			Y coordinate
	 * @param autoDestroy 	Automatically destroy the sprite when the video completes
	 */
	public function new(x:Float = 0, y:Float = 0, autoDestroy:Bool = true)
	{
		super(x, y);
		this.autoDestroyOnComplete = autoDestroy;
		
		if (autoDestroy) 
			bitmap.onEndReached.add(onVideoComplete, true, -10);

		pie = new FlxPieDial(0, 0, 40, FlxColor.WHITE);
		pie.amount = 0.0;
			
		setupEventListeners();
	}
	
	/**
	 * Loads and prepares video for playback.
	 * 
	 * @param videoPath 	Path to the video file
	 * @param args 			Additional VLC arguments
	 * @return 				Bool Success status of loading
	 */
	public function loadVideo(videoPath:String, ?args:Array<String>):Bool
	{
		if (videoPath == null || videoPath.length == 0) 
		{
			trace("Video path is empty!");
			return false;
		}
		
		try 
		{
			final loadArgs:Array<String> = args?.copy() ?? [];
			
			if (!loadArgs.contains(ARG_HW_ACCEL)) loadArgs.push(ARG_HW_ACCEL);
			if (!loadArgs.contains(ARG_DROP_LATE)) loadArgs.push(ARG_DROP_LATE);
			if (!loadArgs.contains(ARG_SKIP_FRAMES)) loadArgs.push(ARG_SKIP_FRAMES);

			_isLooped = args?.contains(ARG_LOOPING) ?? false;
			
			final success:Bool = load(videoPath, loadArgs);
			
			if (success && bitmap != null) 
			{
				#if FLX_PITCH
				if (FlxG.sound.music != null) 
					bitmap.rate = FlxG.sound.music.pitch;
				#end
			}
			
			return success;
		} 
		catch (e:Dynamic) 
		{
			trace('Exception loading video: $e | Path: $videoPath');
			return false;
		}
	}

	public function precacheVideo(videoPath:String, ?args:Array<String>):Bool
	{
		if (videoPath == null || videoPath.length == 0) 
		{
			return false;
		}
		
		try 
		{
			final loadArgs:Array<String> = args?.copy() ?? [];
			
			if (!loadArgs.contains(ARG_HW_ACCEL)) loadArgs.push(ARG_HW_ACCEL);
			if (!loadArgs.contains(ARG_DROP_LATE)) loadArgs.push(ARG_DROP_LATE);
			if (!loadArgs.contains(ARG_SKIP_FRAMES)) loadArgs.push(ARG_SKIP_FRAMES);
			
			return precache(videoPath, loadArgs);
		} 
		catch (e:Dynamic) 
		{
			return false;
		}
	}

	/**
	 * Starts playback with a specific delay.
	 * 
	 * @param delay Delay in seconds (0 = play immediately)
	 */
	public function playDelayed(delay:Float = 0):Void
	{
		if (delay <= 0) 
		{
			play();
		} 
		else 
		{
			new FlxTimer().start(delay, _ -> play());
		}
		
		#if FLX_PITCH 
		if (bitmap != null) 
		{
			bitmap.rate = PlayState.instance?.playbackRate ?? 1.0;
		}
		#end
	}

	override function play():Bool
	{
		initialConductTime = Conductor.songPosition;
		return super.play();
	}

	/**
	 * Chainable callback when video completes.
	 */
	public function onComplete(callback:Void->Void):FunkinVideoSprite
	{
		bitmap.onEndReached.add(callback, true);
		return this;
	}
	
	/**
	 * Chainable callback when video starts playing.
	 */
	public function onStart(callback:Void->Void):FunkinVideoSprite
	{
		bitmap.onOpening.add(callback, true);
		return this;
	}
	
	/**
	 * Chainable callback when video is formatted and ready.
	 */
	public function onFormat(callback:Void->Void):FunkinVideoSprite
	{
		bitmap.onFormatSetup.add(callback, true);
		return this;
	}
	
	/** Adds an event dispatched when the video reaches its end. */
	public function onEnd(func:Void->Void, once:Bool = false, priority:Int = 0):Void
	{
		bitmap.onEndReached.add(func, once, priority);
	}
	
	/** Adds an event dispatched when the video starts. */
	public function onStartEvent(func:Void->Void, once:Bool = false, priority:Int = 0):Void
	{
		bitmap.onOpening.add(func, once, priority);
	}
	
	/** Adds an event dispatched when the video formats itself. */
	public function onFormatEvent(func:Void->Void, once:Bool = false, priority:Int = 0):Void
	{
		bitmap.onFormatSetup.add(func, once, priority);
	}

	/**
	 * Sets the playback position of the video.
	 * @param time Time in milliseconds
	 */
	public function setTime(time:Float):Void
	{
		if (bitmap != null) 
		{
			bitmap.time = haxe.Int64.fromFloat(time);
		}
	}

	/**
	 * Gets the current playback position of the video.
	 * @return Current time in milliseconds
	 */
	public function getTime():Float
	{
		if (bitmap != null)
		{
			final time64 = bitmap.time;
			return (time64.high * 4294967296.0) + time64.low;
		}
		return 0;
	}

	/**
	 * Sets the video position as a percentage (0.0 to 1.0).
	 * @param percent Position as a percentage (0.0 = start, 1.0 = end)
	 */
	public function setVideoPercent(percent:Float):Void
	{
		if (bitmap != null) 
		{
			final newPos:Float = FlxMath.bound(percent, 0.0, 1.0);
			bitmap.position = newPos;
			
			if (!bitmap.isPlaying) play();
		}
	}

	/**
	 * Gets the current video position as a percentage (0.0 to 1.0).
	 * @return Current position as a percentage
	 */
	public function getVideoPercent():Float
	{
		return bitmap?.position ?? 0.0;
	}

	/**
	 * Seeks to a specific time in milliseconds safely based on duration.
	 * @param ms Time in milliseconds
	 */
	public function seekToMs(ms:Float):Void
	{
		if (bitmap == null) return;

		final durationMs = bitmap.length;

		if (haxe.Int64.compare(durationMs, haxe.Int64.ofInt(0)) <= 0)
		{
			setTime(ms);
			return;
		}

		final durFloat:Float = (durationMs.high * 4294967296.0) + durationMs.low;

		if (durFloat > 0)
			setVideoPercent(ms / durFloat);
	}

	/**
	 * Seeks to a specific time in seconds safely based on duration.
	 * @param seconds Time in seconds
	 */
	public function seekToSeconds(seconds:Float):Void
	{
		seekToMs(seconds * 1000.0);
	}

	/** Check if video is currently playing. */
	public function isPlaying():Bool
	{
		return bitmap?.isPlaying ?? false;
	}

	private function setupEventListeners():Void
	{
		if (bitmap != null && isStateAffected) 
		{
			FlxG.signals.focusGained.add(onFocusGained);
			FlxG.signals.focusLost.add(onFocusLost);
		}
	}
	
	private function onVideoComplete():Void
	{
		if (autoDestroyOnComplete) 
		{
			new FlxTimer().start(0.1, _ -> {
				if (this != null) destroy();
			});
		}
	}
	
	private function onFocusLost():Void
	{
		if (FlxG.autoPause)
		{
			wasPlayingBeforeFocusLost = isPlaying();
			if (wasPlayingBeforeFocusLost) bitmap?.pause();
		}
	}

	private function onFocusGained():Void
	{
		final isGamePaused:Bool = PlayState.instance?.paused ?? true;
		if (!isGamePaused && FlxG.autoPause && wasPlayingBeforeFocusLost)
		{
			bitmap?.resume();
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		final isGamePaused:Bool = PlayState.instance?.paused ?? true;
		if (isPlaying() && !isGamePaused && !_isLooped)
		{
			final targetTime:Float = Conductor.songPosition - initialConductTime - Conductor.offset;
			if (targetTime >= 0)
			{
				final drift:Float = Math.abs(getTime() - targetTime);
				if (drift > syncLeniency)
					setTime(targetTime);
			}
		}

		if (canSkip)
		{
			if (FlxG.keys.pressed.ENTER)
			{
				skipHold += elapsed;
				pie.amount = skipHold / skipNeed;

				if (skipHold >= skipNeed) 
				{
					destroy();
				}
			}
			else
			{
				skipHold = Math.max(0.0, skipHold - (elapsed * 2.0));
				pie.amount = skipHold / skipNeed;
			}
		}
	}
	
	override public function destroy():Void
	{
		if (bitmap != null) 
		{
			bitmap.onEndReached.removeAll();
			bitmap.onOpening.removeAll();
			bitmap.onFormatSetup.removeAll();
			
			if (isStateAffected) 
			{
				FlxG.signals.focusGained.remove(onFocusGained);
				FlxG.signals.focusLost.remove(onFocusLost);
			}
			
			stop();
		}
		
		super.destroy();
	}
}
#end