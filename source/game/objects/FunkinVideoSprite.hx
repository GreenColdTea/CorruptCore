package game.objects;

#if VIDEOS_ALLOWED
import hxvlc.flixel.FlxVideoSprite;
import hxvlc.util.Handle;

class FunkinVideoSprite extends FlxVideoSprite
{
	@:unreflective
    public static final ARG_LOOPING:String = ':input-repeat=65535';

	@:unreflective
    public static final ARG_MUTED:String = ':no-audio';

	@:unreflective
    public static final ARG_HW_ACCEL:String = ':avcodec-hw=any';
    
    public var isStateAffected:Bool = true;
    public var autoDestroyOnComplete:Bool = true;

    /**
     * Creates a new video sprite
     * @param x X coordinate
     * @param y Y coordinate
     * @param autoDestroy Automatically destroy when video completes
     */
    public function new(x:Float = 0, y:Float = 0, autoDestroy:Bool = true)
    {
        super(x, y);
        this.autoDestroyOnComplete = autoDestroy;
        
        if (autoDestroy) 
            bitmap.onEndReached.add(onVideoComplete, true, -10);
            
        setupEventListeners();
    }
    
    /**
     * Loads and prepares video for playback
     * @param videoPath Path to video file
     * @param args Additional VLC arguments
     * @return Bool Success status of loading
     */
    public function loadVideo(videoPath:String, ?args:Array<String>):Bool
    {
        if (videoPath == null || videoPath == "") {
            trace("Video path is empty!");
            return false;
        }
        
        try {
            var loadArgs:Array<String> = args != null ? args.copy() : [];
            
            if (!loadArgs.contains(ARG_HW_ACCEL))
                loadArgs.push(ARG_HW_ACCEL);
            
            var success = load(videoPath, loadArgs);
            
            if (success) {
                #if FLX_PITCH
                if (bitmap != null && FlxG.sound.music != null) {
                    bitmap.rate = FlxG.sound.music.pitch;
                }
                #end
            }
            
            return success;
        } catch (e:Dynamic) {
            trace('Exception loading video: $e | Path: $videoPath');
            return false;
        }
    }
    
    /**
     * Starts playback with delay
     * @param delay Delay in seconds (0 = next frame)
     */
    public function playDelayed(delay:Float = 0):Void
    {
        if (delay <= 0) {
            play();
        } else {
            new FlxTimer().start(delay, _ -> play());
        }
        
        #if FLX_PITCH 
        if (bitmap != null) {
            bitmap.rate = PlayState.instance != null ? PlayState.instance.playbackRate : 1.0;
        }
        #end
    }
    
    /**
     * Callback when video completes
     */
    public function onComplete(callback:Void->Void):FunkinVideoSprite
    {
        bitmap.onEndReached.add(callback, true);
        return this;
    }
    
    /**
     * Callback when video starts playing
     */
    public function onStart(callback:Void->Void):FunkinVideoSprite
    {
        bitmap.onOpening.add(callback, true);
        return this;
    }
    
    /**
     * Callback when video is formatted and ready
     */
    public function onFormat(callback:Void->Void):FunkinVideoSprite
    {
        bitmap.onFormatSetup.add(callback, true);
        return this;
    }
    
    /**
     * Adds a event to be dispatched when the video reaches its end
     */
    public function onEnd(func:Void->Void, once:Bool = false, priority:Int = 0)
    {
        bitmap.onEndReached.add(func, once, priority);
    }
    
    /**
     * Adds a event to be dispatched when the video starts
     */
    public function onStartEvent(func:Void->Void, once:Bool = false, priority:Int = 0)
    {
        bitmap.onOpening.add(func, once, priority);
    }
    
    /**
     * Adds a event to be dispatched when the video has formatted itself
     */
    public function onFormatEvent(func:Void->Void, once:Bool = false, priority:Int = 0)
    {
        bitmap.onFormatSetup.add(func, once, priority);
    }

    /**
     * Sets the playback position of the video
     * @param time Time in milliseconds
     */
    public function setTime(time:Float):Void
    {
        if (bitmap != null) {
            var microSeconds:Float = time * 1000;
            bitmap.time = haxe.Int64.fromFloat(microSeconds);
        }
    }

    /**
     * Gets the current playback position of the video
     * @return Current time in milliseconds
     */
    public function getTime():Float
    {
        if (bitmap != null) {
            var time64 = bitmap.time;
            var microSeconds:Float = (time64.high * 4294967296.0) + time64.low;

            return microSeconds / 1000;
        }
        return 0;
    }

    /**
     * Check if video is currently playing
     */
    public function isPlaying():Bool
    {
        return bitmap != null && bitmap.isPlaying;
    }
    
    private function setupEventListeners():Void
    {
        if (bitmap != null && isStateAffected) {
            FlxG.signals.focusGained.add(onFocusGained);
            FlxG.signals.focusLost.add(onFocusLost);
        }
    }
    
    private function onVideoComplete():Void
    {
        if (autoDestroyOnComplete) {
            new FlxTimer().start(0.1, function(_) {
                if (this != null) {
                    destroy();
                }
            });
        }
    }
    
    private function onFocusGained():Void
    {
        bitmap?.resume();
    }
    
    private function onFocusLost():Void
    {
        bitmap?.pause();
    }
    
    override public function destroy():Void
    {
        if (bitmap != null) {
            bitmap.onEndReached.removeAll();
            bitmap.onOpening.removeAll();
            bitmap.onFormatSetup.removeAll();
            
            if (isStateAffected) {
                FlxG.signals.focusGained.remove(onFocusGained);
                FlxG.signals.focusLost.remove(onFocusLost);
            }
            
            bitmap.stop();
        }
        
        super.destroy();
    }
}
#end