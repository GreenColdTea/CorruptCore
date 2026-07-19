package game.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import flixel.util.typeLimit.NextState;
import flixel.math.FlxMath;

import openfl.utils.Assets;
import openfl.utils.AssetType;
import openfl.media.Sound;

import lime.app.Promise;
import lime.app.Future;
import lime.system.ThreadPool;
import lime.system.WorkOutput;
import lime.system.WorkOutput.ThreadMode;

import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;

import haxe.Exception;
import haxe.io.Path;

import game.backend.StageData.StageFile;

enum LoadTaskType {
    FILE_IO;
    IMAGE_PROCESSING;
    AUDIO_PROCESSING;
    JSON_PROCESSING;
    MAIN_THREAD;
}

typedef LoadTask = {
    type:LoadTaskType,
    execute:Void->Void,
    ?description:String
}

class LoadingState extends MusicBeatState
{
    static final MIN_TIME = 1.0;

    var target:NextState;
    var stopMusic:Bool;
    var directory:String;
    var callbacks:MultiCallback;
    var targetShit:Float = 0;

    static var imageProcessingPool:ThreadPool;
    static var audioProcessingPool:ThreadPool;
    static var jsonProcessingPool:ThreadPool;

    var loadQueue:Array<LoadTask> = [];
    var queueIndex:Int = 0;
    var tasksPerFrame:Int = 2;

    var loadingStarted:Bool = false;
    var startTimer:FlxTimer;

    public final maxImageThreads:Int = lime.Native.getCPUThreadsCount() - 1;
    public final maxAudioThreads:Int = Std.int(Math.max(1, lime.Native.getCPUThreadsCount() - 2));
    public final maxJSONThreads:Int = Std.int(Math.max(1, lime.Native.getCPUThreadsCount() - 2));

    static var formatCache:Map<String, Dynamic> = new Map();

    public function new(target:NextState, stopMusic:Bool, directory:String)
    {
        super();
        this.target = target;
        this.stopMusic = stopMusic;
        this.directory = directory;

        initializeMultiChannelPools();
    }

    function initializeMultiChannelPools()
    {
        if (imageProcessingPool == null) {
            imageProcessingPool = new ThreadPool(0, maxImageThreads);
            imageProcessingPool.doWork.add(onPoolWork);
            imageProcessingPool.onComplete.add(onPoolComplete);
            imageProcessingPool.onError.add(onPoolError);
        }

        if (audioProcessingPool == null) {
            audioProcessingPool = new ThreadPool(0, maxAudioThreads);
            audioProcessingPool.doWork.add(onPoolWork);
            audioProcessingPool.onComplete.add(onPoolComplete);
            audioProcessingPool.onError.add(onPoolError);
        }

        if (jsonProcessingPool == null) {
            jsonProcessingPool = new ThreadPool(0, maxJSONThreads);
            jsonProcessingPool.doWork.add(onPoolWork);
            jsonProcessingPool.onComplete.add(onPoolComplete);
            jsonProcessingPool.onError.add(onPoolError);
        }
    }

    function onPoolWork(task:LoadTask) {
        try {
            task.execute();
        } catch(e:Dynamic) {
            trace("Background thread error: " + e);
        }
    }

    function onPoolComplete(msg:Dynamic) {
        if (msg?.mainThreadCallback != null)
            msg.mainThreadCallback();
    }

    function onPoolError(msg:Dynamic) {
        trace("ThreadPool error encountered!");
    }

    var funkay:FlxSprite;
    var loadBarBg:FlxSprite;
    var loadBar:FlxSprite;
    var percentText:FlxText;

    override function create()
    {
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory(false);

        FlxTransitionableState.skipNextTransIn = true;

        var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
        add(bg);

        funkay = new FlxSprite(0, 0).loadGraphic(Paths.image('funkay', null, true));
        funkay.setGraphicSize(FlxG.width, FlxG.height);
        funkay.updateHitbox();
        add(funkay);
        funkay.scrollFactor.set();
        funkay.screenCenter();

        loadBarBg = new FlxSprite(0, 660).makeGraphic(1, 1, FlxColor.BLACK);
        loadBarBg.scale.set(FlxG.width - 300, 25);
        loadBarBg.updateHitbox();
        loadBarBg.screenCenter(X);
        add(loadBarBg);

        loadBar = new FlxSprite(loadBarBg.x + 5, loadBarBg.y + 5).makeGraphic(1, 1, 0xffff16d2);
        loadBar.scale.set(0, 15);
        loadBar.origin.set(0, 0);
        add(loadBar);

        percentText = new FlxText(0, FlxG.height - 65, FlxG.width, "0%");
        percentText.setFormat(Paths.font("vcr.ttf"), 32, 0xFFFFFFFF, CENTER, OUTLINE, 0xFF000000);
        percentText.borderSize = 2;
        add(percentText);

        startTimer = new FlxTimer().start(MIN_TIME, (_) -> {
            loadingStarted = true;
            startLoading();
        });
    }

    function startLoading()
    {
        callbacks = new MultiCallback(onLoad);
        final dummyCallback = callbacks.add("dummyDelay");
        new FlxTimer().start(0.1, (_) -> dummyCallback());

        buildLoadQueue();
    }

    function buildLoadQueue()
    {
        if (PlayState.SONG != null)
        {
            var characters = [PlayState.SONG.player1, PlayState.SONG.player2, PlayState.SONG.gfVersion];

            for (char in characters) {
                if (char != null) {
                    var cb = callbacks.add("character:" + char);
                    loadCharacter(char, cb);
                }
            }

            var cbSong = callbacks.add("song audio");
            checkLoadSong(getSongPath(), cbSong);

            if (PlayState.SONG.needsVoices) {
                for (vocalPath in getVocalPaths()) {
                    var cbVocal = callbacks.add("vocal audio: " + vocalPath);
                    checkLoadSong(vocalPath, cbVocal);
                }
            }

            var stage = PlayState.SONG.stage ?? StageData.vanillaSongStage(PlayState.SONG.song);
            var stageFile:StageFile = StageData.getStageFile(stage);

            if (stageFile != null && stageFile.loadingImages != null) {
                for (image in stageFile.loadingImages) {
                    var cbImage = callbacks.add("stageImage:" + image);
                    loadStageImage(image, cbImage);
                }
            }
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (loadingStarted)
        {
            var count = 0;
            while (queueIndex < loadQueue.length && count < tasksPerFrame)
            {
                var task = loadQueue[queueIndex];
                try {
                    task.execute();
                } catch(e:Dynamic) {
                    trace('Error executing task ${task.description}: $e');
                }
                queueIndex++;
                count++;
            }
        }

        if(callbacks != null) {
            var progress:Float = 0;
            if (callbacks.length > 0) progress = 1 - (callbacks.numRemaining / callbacks.length);
            if (callbacks.length == 0 || callbacks.numRemaining == 0) progress = 1;
            
            targetShit = progress * (loadBarBg.width - 10);
            if (Math.isNaN(targetShit)) targetShit = 0;

            loadBar.scale.x = targetShit;
            
            var percent:Int = Math.floor(progress * 100);
            percentText.text = '$percent%';
        }
    }

    function loadCharacter(character:String, onComplete:Void->Void)
    {
        jsonProcessingPool.queue({
            type: JSON_PROCESSING,
            description: 'Parse character JSON: $character',
            execute: function() {
                var characterPath:String = 'data/characters/' + character + '.json';
                var rawJson:String = Paths.getTextFromFile(characterPath);
                var imageToLoad = 'characters/' + character;
                
                if (rawJson != null) {
                    try {
                        var json:Dynamic = haxe.Json.parse(rawJson);
                        if (json?.image != null)
                            imageToLoad = json.image;
                    } catch (e:Dynamic) {
                        trace('Error parsing character JSON for $character: $e');
                    }
                }
                
                jsonProcessingPool.sendComplete({
                    mainThreadCallback: () -> loadStageImage(imageToLoad, onComplete)
                });
            }
        });
    }

    function loadStageImage(image:String, onComplete:Void->Void)
    {
        if (isGraphicCached(image)) {
            onComplete();
            return;
        }

        loadQueue.push({
            type: MAIN_THREAD,
            description: 'Load image: $image',
            execute: function() {
                var formats = checkImageFormats(image);

                if (formats.animate)
                    #if flixel_animate Paths.getAnimateAtlas(image); #end
                else if (formats.xml)
                    Paths.getSparrowAtlas(image, null, true);
                else if (formats.json)
                    Paths.getAsepriteAtlas(image, null, true);
                else if (formats.txt)
                    Paths.getPackerAtlas(image, null, true);
                else if (formats.png) {
                    var loaded = false;
                    for (ext in Paths.IMAGE_EXTS) {
                        if (Paths.fileExists('images/$image.$ext', IMAGE)) {
                            Paths.image(image, null, true);
                            loaded = true;
                            break;
                        }
                    }
                    if (!loaded) trace('WARNING: Image not found: $image');
                }
                else
                    trace('WARNING: Image not found: $image');
                
                onComplete();
            }
        });
    }

    @:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
    static function isGraphicCached(imageName:String):Bool {
        for (ext in Paths.IMAGE_EXTS) {
            var key = 'images/$imageName.$ext';
            if (FlxG.bitmap._cache.exists(key)) return true;
        }
        return false;
    }

    function checkImageFormats(image:String):Dynamic
    {
        if (formatCache.exists(image)) return formatCache.get(image);

        var hasImage = false;
        for (ext in Paths.IMAGE_EXTS) {
            if (Paths.fileExists('images/$image.$ext', IMAGE)) {
                hasImage = true;
                break;
            }
        }

        var result = {
            animate: #if flixel_animate Paths.fileExists('images/$image/Animation.json', TEXT) #else false #end,
            xml: Paths.fileExists('images/$image.xml', TEXT),
            json: Paths.fileExists('images/$image.json', TEXT),
            txt: Paths.fileExists('images/$image.txt', TEXT),
            png: hasImage
        };
        formatCache[image] = result;
        return result;
    }

    function checkLoadSong(path:String, onComplete:Void->Void)
    {
        if (path == null) {
            onComplete();
            return;
        }

        #if MODS_ALLOWED
        if (path.startsWith('${Mods.MODS_FOLDER}/')) {
            audioProcessingPool.queue({
                type: AUDIO_PROCESSING,
                description: 'Decode Mod Audio: $path',
                execute: function() {
                    final sound = loadSoundFromPath(path);
                    
                    audioProcessingPool.sendComplete({
                        mainThreadCallback: () -> {
                            if (sound != null) {
                                Paths.currentTrackedSounds.set(path, sound);
                            }
                            onComplete();
                        }
                    });
                }
            });
        } else #end {
            if (!Assets.cache.hasSound(path)) {
                Assets.loadSound(path).onComplete((_) -> onComplete()).onError((e) -> {
                    trace('Error loading sound: $path, error: $e');
                    onComplete();
                });
            } else {
                onComplete();
            }
        }
    }

    function loadSoundFromPath(path:String):Sound
    {
        #if sys
        if (!FileSystem.exists(path)) return null;
        
        var extension = Path.extension(path).toLowerCase();
        try {
            switch(extension) {
                default:
                    return Sound.fromFile(path);
            }
        } catch(e:Dynamic) {
            trace('Error loading sound file $path: $e');
            return null;
        }
        #else
        return null;
        #end
    }

    function onLoad()
    {
        trace('Loading complete! Loaded ${callbacks.getFired().length} items');
        if (stopMusic) FlxG.sound?.music?.stop();

        FlxG.switchState(target);
    }

    static function getSongPath():String {
        return getSoundPath(PlayState.SONG.song, 'inst');
    }

    static function getVocalPaths():Array<String> {
        var paths:Array<String> = [];
        var vocalsPath:String = getSoundPath(PlayState.SONG.song, 'voices');
        if (vocalsPath != null) paths.push(vocalsPath);

        var playerPostfix:String = getCharVocalsPostfix(PlayState.SONG.player1);
        var opponentPostfix:String = getCharVocalsPostfix(PlayState.SONG.player2);
        
        if (playerPostfix != null) {
            var playerVocals:String = getSoundPath(PlayState.SONG.song, 'voices-$playerPostfix');
            if (playerVocals != null) paths.push(playerVocals);
        }

        if (opponentPostfix != null) {
            var opponentVocals:String = getSoundPath(PlayState.SONG.song, 'voices-$opponentPostfix');
            if (opponentVocals != null) paths.push(opponentVocals);
        }

        return paths;
    }

    static function getSoundPath(song:String, type:String):String {
        var songKey:String = '${Paths.formatToSongPath(song)}/$type';
        
        #if MODS_ALLOWED
        for (ext in Paths.SOUND_EXTS) {
            var file:String = Mods.modsSounds('songs', songKey, ext);
            if (FileSystem.exists(file)) return file;
        }
        #end

        for (ext in Paths.SOUND_EXTS) {
            var soundPath:String = Paths.getPath('songs/$songKey.$ext', SOUND, 'songs');
            if (Assets.exists(soundPath)) return soundPath;
        }

        var capitalType = type.charAt(0).toUpperCase() + type.substr(1);
        var songKeyCapital:String = '${Paths.formatToSongPath(song)}/$capitalType';

        #if MODS_ALLOWED
        for (ext in Paths.SOUND_EXTS) {
            var file:String = Mods.modsSounds('songs', songKeyCapital, ext);
            if (FileSystem.exists(file)) return file;
        }
        #end

        for (ext in Paths.SOUND_EXTS) {
            var soundPath:String = Paths.getPath('songs/$songKeyCapital.$ext', SOUND, 'songs');
            if (Assets.exists(soundPath)) return soundPath;
        }

        return null;
    }

    static function getCharVocalsPostfix(character:String):String {
        if (character == null) return null;
        try {
            var characterPath:String = 'data/characters/' + character + '.json';
            var rawJson:String = Paths.getTextFromFile(characterPath);

            if (rawJson != null) {
                var json:Dynamic = haxe.Json.parse(rawJson);
                if (json?.vocals_file != null) return json.vocals_file;
            }
        } catch (e:Dynamic) {}

        if (PlayState.SONG != null) {
            if (character == PlayState.SONG.player1) return "";
            else if (character == PlayState.SONG.player2) return "Opponent";
        }
        return null;
    }

    public static function loadAndSwitchState(targetFactory:Void->NextState, stopMusic = false) {
        var targetState = targetFactory();
        var isPlayState = Std.isOfType(targetState, PlayState);

        var directory:String = StageData.forceNextDirectory;
        StageData.forceNextDirectory = null;
        if (directory == null || directory.length == 0) directory = 'shared';
        Paths.setCurrentLevel(directory);

        var loaded:Bool = true;
        if (PlayState.SONG != null) {
            loaded = isSoundLoaded(getSongPath()) &&
                    (!PlayState.SONG.needsVoices || areVocalsLoaded()) &&
                    #if MODS_ALLOWED isModsLoaded() #else true #end &&
                    areCharactersLoaded();
        }

        if (!loaded && isPlayState) {
            FlxG.switchState(() -> new LoadingState(targetState, stopMusic, directory));
            return;
        }

        if (stopMusic) FlxG.sound?.music?.stop();
        FlxG.switchState(targetState);
    }

    static function areCharactersLoaded():Bool {
        if (PlayState.SONG != null) {
            var characters = [PlayState.SONG.player1, PlayState.SONG.player2, PlayState.SONG.gfVersion];
            for (char in characters) {
                if (char != null && !isCharacterLoaded(char)) return false;
            }

            var stage = PlayState.SONG.stage ?? StageData.vanillaSongStage(PlayState.SONG.song);
            var stageFile:StageFile = StageData.getStageFile(stage);
            
            if (stageFile != null && stageFile.loadingImages != null) {
                for (image in stageFile.loadingImages) {
                    if (!isStageImageLoaded(image)) return false;
                }
            }
        }
        return true;
    }

    static function isCharacterLoaded(character:String):Bool {
        if (isGraphicCached('characters/$character')) return true;
        return Paths.fileExists('data/characters/$character.json', TEXT);
    }

    static function isStageImageLoaded(image:String):Bool {
        return isGraphicCached(image);
    }

    #if MODS_ALLOWED
    static function isModsLoaded():Bool {
        return Mods.getGlobalMods().length > 0;
    }
    #end

    static function areVocalsLoaded():Bool {
        var vocalPaths = getVocalPaths();
        for (path in vocalPaths) {
            if (!isSoundLoaded(path)) return false;
        }
        return true;
    }

    static function isSoundLoaded(path:String):Bool {
        #if MODS_ALLOWED
        if (path?.startsWith('${Mods.MODS_FOLDER}/')) {
            return FileSystem.exists(path);
        }
        #end

        if (Assets.cache.hasSound(path)) return true;
        
        for (ext in Paths.SOUND_EXTS) {
            var testPath = Path.withoutExtension(path) + "." + ext;
            if (Assets.exists(testPath)) return true;
        }
        
        return false;
    }

    override function destroy() {
        if (imageProcessingPool != null) {
            imageProcessingPool.cancel();
            imageProcessingPool = null;
        }
        if (audioProcessingPool != null) {
            audioProcessingPool.cancel();
            audioProcessingPool = null;
        }
        if (jsonProcessingPool != null) {
            jsonProcessingPool.cancel();
            jsonProcessingPool = null;
        }

        formatCache.clear();

        callbacks = null;
        percentText?.destroy();
        startTimer?.destroy();

        super.destroy();
    }
}

class MultiCallback
{
    public var callback:Void->Void;
    public var logId:String = null;
    public var length(default, null) = 0;
    public var numRemaining(default, null) = 0;

    var unfired = new Map<String, Void->Void>();
    var fired = new Array<String>();

    public function new (callback:Void->Void, logId:String = null) {
        this.callback = callback;
        this.logId = logId;
    }

    public function add(id = "untitled") {
        id = '$length:$id';
        length++;
        numRemaining++;
        var func:Void->Void = null;
        func = function () {
            if (unfired.exists(id)) {
                unfired.remove(id);
                fired.push(id);
                numRemaining--;

                if (logId != null) log('fired $id, $numRemaining remaining');

                if (numRemaining == 0) {
                    if (logId != null) log('all callbacks fired');
                    callback();
                }
            } else {
                log('already fired $id');
            }
        }
        unfired[id] = func;
        return func;
    }

    inline function log(msg):Void {
        if (logId != null) trace('$logId: $msg');
    }

    public function getFired() return fired.copy();
    public function getUnfired() return [for (id in unfired.keys()) id];
}