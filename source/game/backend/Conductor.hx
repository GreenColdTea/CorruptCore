package game.backend;

import game.backend.Song.SwagSong;
import game.objects.Note;

import flixel.addons.sound.FlxRhythmConductor;
import flixel.addons.sound.MusicTimeChangeEvent;

typedef BPMChangeEvent =
{
    var stepTime:Int;
    var songTime:Float;
    var bpm:Float;
    @:optional var stepCrochet:Float;
}

class Conductor
{
    public static var bpm(get, set):Float;
    static function get_bpm():Float return FlxRhythmConductor.instance.currentBpm;
    static function set_bpm(v:Float):Float 
    {
        if (v == FlxRhythmConductor.instance.currentBpm) return v;

        if (FlxRhythmConductor.instance.timeChanges.length <= 1 && songPosition <= 0) {
            FlxRhythmConductor.instance.setupTimeChanges([new MusicTimeChangeEvent(0, v)]);
        } else {
            final changes = FlxRhythmConductor.instance.timeChanges.copy();
            changes.push(new MusicTimeChangeEvent(songPosition, v));
            FlxRhythmConductor.instance.setupTimeChanges(changes);
        }
        return v;
    }

    public static var crochet(get, never):Float;
    static inline function get_crochet():Float return FlxRhythmConductor.instance.beatLengthMs;

    public static var stepCrochet(get, never):Float;
    static inline function get_stepCrochet():Float return FlxRhythmConductor.instance.stepLengthMs;

    public static var songPosition(default, set):Float = 0;
    static function set_songPosition(val:Float):Float 
    {
        songPosition = val;
        FlxRhythmConductor.instance.update(val);
        return val;
    }

    public static var offset:Float = ClientPrefs.noteOffset;

    public static final ROWS_PER_BEAT = 48; 
    public static final BEATS_PER_MEASURE = 4;
    public static final ROWS_PER_MEASURE = ROWS_PER_BEAT * BEATS_PER_MEASURE; 
    public static final MAX_NOTE_ROW = 1 << 30; 

    public inline static function beatToRow(beat:Float):Int
        return Math.round(beat * ROWS_PER_BEAT);

    public inline static function rowToBeat(row:Int):Float
        return row / ROWS_PER_BEAT;

    public inline static function secsToRow(sex:Float):Int
        return Math.round(getBeat(sex) * ROWS_PER_BEAT);

    public static var safeZoneOffset:Float = (ClientPrefs.safeFrames / 60) * 1000;

    public static function getCrotchetAtTime(time:Float):Float 
    {
        final currentBpm = FlxRhythmConductor.instance.getCurrentTimeChangeBPMAccurate(time);
        return (60 / currentBpm) * 1000;
    }

    public static function getBPMFromSeconds(time:Float):BPMChangeEvent 
    {
        final changes = FlxRhythmConductor.instance.timeChanges;

        var lastChange:BPMChangeEvent = {
            stepTime: 0,
            songTime: 0,
            bpm: bpm,
            stepCrochet: stepCrochet
        };
        
        for (i in 0...changes.length) {
            if (time >= changes[i].time) {
                lastChange = {
                    stepTime: Math.floor(FlxRhythmConductor.instance.getCumulativeSteps(changes[i].time)),
                    songTime: changes[i].time,
                    bpm: changes[i].bpm,
                    stepCrochet: calculateCrochet(changes[i].bpm) / 4
                };
            }
        }
        return lastChange;
    }

    public static function getBPMFromStep(step:Float):BPMChangeEvent 
    {
        final changes = FlxRhythmConductor.instance.timeChanges;

        var lastChange:BPMChangeEvent = {
            stepTime: 0,
            songTime: 0,
            bpm: bpm,
            stepCrochet: stepCrochet
        };
        
        for (i in 0...changes.length) 
        {
            final eventStep = FlxRhythmConductor.instance.getCumulativeSteps(changes[i].time);
            
            if (step >= eventStep) 
            {
                lastChange = {
                    stepTime: Math.floor(eventStep),
                    songTime: changes[i].time,
                    bpm: changes[i].bpm,
                    stepCrochet: calculateCrochet(changes[i].bpm) / 4
                };
            }
        }
        return lastChange;
    }

    public static function stepToSeconds(targetStep:Float):Float
    {
        final changes = FlxRhythmConductor.instance.timeChanges;
        if (changes.length == 0) return targetStep * FlxRhythmConductor.instance.stepLengthMs;

        var currentSteps:Float = 0;
        for (i in 0...changes.length) 
        {
            final event = changes[i];
            final nextEvent = changes[i + 1];
            final eventSteps = (nextEvent != null) ? FlxRhythmConductor.instance.getCumulativeSteps(nextEvent.time) : Math.POSITIVE_INFINITY;
            
            if (targetStep < eventSteps) 
            {
                final stepDiff = targetStep - currentSteps;
                final msPerStep = (60 / event.bpm) * 1000 / 4;
                return event.time + (stepDiff * msPerStep);
            }
            currentSteps = eventSteps;
        }
        return 0;
    }

    public inline static function beatToSeconds(targetBeat:Float):Float 
    {
        return stepToSeconds(targetBeat * 4);
    }
    
    public inline static function getStep(time:Float)
    {
        return FlxRhythmConductor.instance.getCumulativeSteps(time);
    }

    public inline static function getStepRounded(time:Float)
    {
        return Math.floor(getStep(time));
    }

    public inline static function getBeat(time:Float)
    {
        return getStep(time) / 4;
    }

    public inline static function getBeatRounded(time:Float):Int
    {
        return Math.floor(getBeat(time));
    }

    public static function mapBPMChanges(song:SwagSong)
    {
        var timeEvents:Array<MusicTimeChangeEvent> = [];
        var curBPM:Float = song.bpm;
        var totalSteps:Int = 0;
        var totalPos:Float = 0;
        
        timeEvents.push(new MusicTimeChangeEvent(0, song.bpm));
        
        for (i in 0...song.notes.length)
        {
            if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
            {
                curBPM = song.notes[i].bpm;
                timeEvents.push(new MusicTimeChangeEvent(totalPos, curBPM));
            }

            final deltaSteps:Int = Math.round((song.notes[i]?.sectionBeats ?? 4) * 4);
            totalSteps += deltaSteps;
            totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
        }
        
        FlxRhythmConductor.instance.setupTimeChanges(timeEvents);
    }

    static function getSectionBeats(song:SwagSong, section:Int)
    {
        var val:Null<Float> = null;
        if(song.notes[section] != null) val = song.notes[section].sectionBeats;
        return val ?? 4;
    }

    public inline static function calculateCrochet(bpm:Float)
    {
        return (60 / bpm) * 1000;
    }
}