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

#if hxopus
import hxopus.Opus;
#end

#if hxflac
import hxflac.FLACHelper;
#end

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

    public final maxImageThreads:Int = 2;
    public final maxAudioThreads:Int = 1;
    public final maxJSONThreads:Int = 2;

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
            imageProcessingPool.onComplete.add(onImageProcessingComplete);
            imageProcessingPool.onError.add(onImageProcessingError);
            imageProcessingPool.onUncaughtError.add(onImageProcessingUncaughtError);
        }

        if (audioProcessingPool == null) {
            audioProcessingPool = new ThreadPool(0, maxAudioThreads);
            audioProcessingPool.onComplete.add(onAudioProcessingComplete);
            audioProcessingPool.onError.add(onAudioProcessingError);
            audioProcessingPool.onUncaughtError.add(onAudioProcessingUncaughtError);
        }

        if (jsonProcessingPool == null) {
            jsonProcessingPool = new ThreadPool(0, maxJSONThreads);
            jsonProcessingPool.onComplete.add(onJSONProcessingComplete);
            jsonProcessingPool.onError.add(onJSONProcessingError);
            jsonProcessingPool.onUncaughtError.add(onJSONProcessingUncaughtError);
        }
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
        FlxTransitionableState.skipNextTransOut = true;

        var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
        add(bg);

        funkay = new FlxSprite(0, 0).loadGraphic(Paths.image('funkay', null, true));
        funkay.setGraphicSize(FlxG.width, FlxG.height);
        funkay.updateHitbox();
        funkay.antialiasing = ClientPrefs.globalAntialiasing;
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

        @:privateAccess
        startTimer = new FlxTimer().start(MIN_TIME, (_) -> {
            loadingStarted = true;
            startLoading();
        });
    }

    function startLoading()
    {
        callbacks = new MultiCallback(onLoad);
        var introComplete = callbacks.add("introComplete");

        buildLoadQueue();

        new FlxTimer().start(MIN_TIME, (_) -> introComplete());
    }

    function buildLoadQueue()
    {
        if (PlayState.SONG != null)
        {
            var characters = [
                PlayState.SONG.player1,
                PlayState.SONG.player2,
                PlayState.SONG.gfVersion
            ];

            for (char in characters)
            {
                if (char != null)
                {
                    loadQueue.push({
                        type: MAIN_THREAD,
                        execute: () -> {
                            var callback = callbacks.add("character:" + char);
                            loadCharacter(char, () -> callback());
                        },
                        description: 'Load character: $char'
                    });
                }
            }

            loadQueue.push({
                type: MAIN_THREAD,
                execute: () -> checkLoadSong(getSongPath()),
                description: 'Load song audio'
            });

            if (PlayState.SONG.needsVoices)
            {
                var vocalPaths = getVocalPaths();
                for (vocalPath in vocalPaths)
                {
                    loadQueue.push({
                        type: MAIN_THREAD,
                        execute: () -> checkLoadSong(vocalPath),
                        description: 'Load vocal audio: $vocalPath'
                    });
                }
            }

            var stage = PlayState.SONG.stage;
            stage ??= StageData.vanillaSongStage(PlayState.SONG.song);

            var stageFile:StageFile = StageData.getStageFile(stage);
            if (stageFile != null && stageFile.loadingImages != null)
            {
                for (image in stageFile.loadingImages)
                {
                    loadQueue.push({
                        type: MAIN_THREAD,
                        execute: () -> {
                            var callback = callbacks.add("stageImage:" + image);
                            loadStageImage(image, () -> callback());
                        },
                        description: 'Load stage image: $image'
                    });
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
                executeTask(task);
                queueIndex++;
                count++;
            }
        }

        if(callbacks != null) {
            var progress:Float = 1 - (callbacks.numRemaining / callbacks.length);
            targetShit = progress * Std.int(loadBarBg.width - 10);
            loadBar.scale.x = targetShit;

            var percent:Int = Math.round(progress * 100);
            percentText.text = '$percent%';
        }
    }

    function executeTask(task:LoadTask)
    {
        trace('Executing task: ${task.description}');

        try {
            task.execute();
        } catch (e:Dynamic) {
            trace('Error executing task ${task.description}: $e');
        }
    }

    function onFileIOComplete(state:Dynamic) {}
    function onImageProcessingComplete(state:Dynamic) {}
    function onAudioProcessingComplete(state:Dynamic) {}
    function onJSONProcessingComplete(state:Dynamic) {}
    function onFileIOError(state:Dynamic) {}
    function onImageProcessingError(state:Dynamic) {}
    function onAudioProcessingError(state:Dynamic) {}
    function onJSONProcessingError(state:Dynamic) {}
    function onFileIOUncaughtError(exception:Exception) {}
    function onImageProcessingUncaughtError(exception:Exception) {}
    function onAudioProcessingUncaughtError(exception:Exception) {}
    function onJSONProcessingUncaughtError(exception:Exception) {}

    function loadCharacter(character:String, onComplete:Void->Void)
    {
        var characterPath:String = 'data/characters/' + character + '.json';
        var rawJson:String = Paths.getTextFromFile(characterPath);

        if (rawJson != null) {
            try {
                var json:Dynamic = haxe.Json.parse(rawJson);
                if (json != null && json.image != null) {
                    loadCharacterImage(json.image, onComplete);
                    return;
                }
            } catch (e:Dynamic) {
                trace('Error parsing character JSON for $character: $e');
            }
        }

        // fallback to default image path
        loadCharacterImage('characters/' + character, onComplete);
    }

    function loadCharacterImage(image:String, onComplete:Void->Void)
    {
        var callback = callbacks.add("characterImage:" + image);

        var formats = checkImageFormats(image);

        if (formats.animate)
            #if flixel_animate Paths.getAnimateAtlas(image); #end
        else if (formats.xml)
            Paths.getSparrowAtlas(image, null, true);
        else if (formats.json)
            Paths.getAsepriteAtlas(image, null, true);
        else if (formats.txt)
            Paths.getPackerAtlas(image, null, true);
        else if (formats.png)
            Paths.image(image, null, true);
        else
            trace('WARNING: Character image not found: $image');

        callback();
        onComplete();
    }

    function checkImageFormats(image:String):Dynamic
    {
        return {
            animate: #if flixel_animate Paths.fileExists('images/$image/Animation.json', TEXT) #else false #end,
            xml: Paths.fileExists('images/$image.xml', TEXT),
            json: Paths.fileExists('images/$image.json', TEXT),
            txt: Paths.fileExists('images/$image.txt', TEXT),
            png: Paths.fileExists('images/$image.png', IMAGE)
        };
    }

    function loadStageImage(image:String, onComplete:Void->Void)
    {
        var callback = callbacks.add("stageImage:" + image);

        var formats = checkImageFormats(image);

        if (formats.animate)
            #if flixel_animate Paths.getAnimateAtlas(image); #end
        else if (formats.xml)
            Paths.getSparrowAtlas(image, null, true);
        else if (formats.json)
            Paths.getAsepriteAtlas(image, null, true);
        else if (formats.txt)
            Paths.getPackerAtlas(image, null, true);
        else if (formats.png)
            Paths.image(image, null, true);
        else
            trace('WARNING: Stage image not found: $image');

        callback();
        onComplete();
    }

    function checkLoadSong(path:String)
    {
        if (path == null) {
            var callback = callbacks.add("null_song_path");
            callback();
            return;
        }

        #if MODS_ALLOWED
        if (path.startsWith('${Mods.MODS_FOLDER}/')) {
            var callback = callbacks.add("modSong:" + path);

            try {
                var sound = loadSoundFromPath(path);
                if (sound != null) {
                    Paths.currentTrackedSounds.set(path, sound);
                }
                callback();
            } catch (e:Dynamic) {
                trace('Error loading mod sound: $path, error: $e');
                callback();
            }
        } else #end {
            if (!Assets.cache.hasSound(path))
            {
                var callback = callbacks.add("song:" + path);
                Assets.loadSound(path).onComplete((_) -> callback()).onError((e) -> {
                    trace('Error loading sound: $path, error: $e');
                    callback();
                });
            }
            else
            {
                var callback = callbacks.add("already_loaded_song:" + path);
                callback();
            }
        }
    }

    function loadSoundFromPath(path:String):Sound
    {
        #if sys
        if (!FileSystem.exists(path)) {
            return null;
        }
        
        var extension = Path.extension(path).toLowerCase();
        
        try {
            switch(extension) {
                #if hxopus
                case "opus":
                    var bytes = File.getBytes(path);
                    return Opus.toOpenFL(bytes);
                #end
                
                #if hxflac
                case "flac":
                    var bytes = File.getBytes(path);
                    return FLACHelper.toOpenFL(bytes);
                #end
                
                case "wav":
                    return CoolUtil.loadHighBitrateWav(path, path);
                    
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

        if (stopMusic)
            FlxG.sound?.music?.stop();

        FlxG.switchState(target);
    }

    static function getSongPath():String
    {
        return getSoundPath(PlayState.SONG.song, 'inst');
    }

    static function getVocalPaths():Array<String>
    {
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

    static function getSoundPath(song:String, type:String):String
    {
        var songKey:String = '${Paths.formatToSongPath(song)}/$type';
        var extensions:Array<String> = Paths.SOUND_EXTS;
        
        #if MODS_ALLOWED
        for (ext in extensions) {
            var file:String = Mods.modsSounds('songs', songKey, ext);
            if (FileSystem.exists(file)) {
                return file;
            }
        }
        #end

        for (ext in extensions) {
            var soundPath:String = Paths.getPath('songs/$songKey.$ext', SOUND, 'songs');
            if (Assets.exists(soundPath)) {
                return soundPath;
            }
        }

        var capitalType = type.charAt(0).toUpperCase() + type.substr(1);
        var songKeyCapital:String = '${Paths.formatToSongPath(song)}/$capitalType';

        #if MODS_ALLOWED
        for (ext in extensions) {
            var file:String = Mods.modsSounds('songs', songKeyCapital, ext);
            if (FileSystem.exists(file)) {
                return file;
            }
        }
        #end

        for (ext in extensions) {
            var soundPath:String = Paths.getPath('songs/$songKeyCapital.$ext', SOUND, 'songs');
            if (Assets.exists(soundPath)) {
                return soundPath;
            }
        }

        return null;
    }

    static function getCharVocalsPostfix(character:String):String
    {
        if (character == null) return null;

        try {
            var characterPath:String = 'data/characters/' + character + '.json';
            var rawJson:String = Paths.getTextFromFile(characterPath);

            if (rawJson != null) {
                var json:Dynamic = haxe.Json.parse(rawJson);
                if (json?.vocals_file != null)
                    return json.vocals_file;
            }
        } catch (e:Dynamic) {
            trace('Error getting vocals postfix for character $character: $e');
        }

        if (PlayState.SONG != null) {
            if (character == PlayState.SONG.player1)
                return "";
            else if (character == PlayState.SONG.player2)
                return "Opponent";
        }

        return null;
    }

    public static function loadAndSwitchState(targetFactory:Void->NextState, stopMusic = false)
    {
        var targetState = targetFactory();
        var isPlayState = Std.isOfType(targetState, PlayState);

        var directory:String = StageData.forceNextDirectory;
        StageData.forceNextDirectory = null;

        if (directory == null || directory.length == 0)
            directory = 'shared';

        Paths.setCurrentLevel(directory);
        trace('Setting asset folder to ' + directory);

        var loaded:Bool = true;
        if (PlayState.SONG != null) {
            loaded = isSoundLoaded(getSongPath()) &&
                    (!PlayState.SONG.needsVoices || areVocalsLoaded()) &&
                    #if MODS_ALLOWED isModsLoaded() #else true #end &&
                    areCharactersLoaded();
        }

        if (!loaded && isPlayState)
        {
            FlxG.switchState(() -> new LoadingState(targetState, stopMusic, directory));
            return;
        }

        if (stopMusic) FlxG.sound?.music?.stop();

        FlxG.switchState(targetState);
    }

    static function areCharactersLoaded():Bool
    {
        if (PlayState.SONG != null)
        {
            var characters = [
                PlayState.SONG.player1,
                PlayState.SONG.player2,
                PlayState.SONG.gfVersion
            ];

            for (char in characters)
            {
                if (char != null && !isCharacterLoaded(char))
                    return false;
            }

            var stage = PlayState.SONG.stage;
            stage ??= StageData.vanillaSongStage(PlayState.SONG.song);

            var stageFile:StageFile = StageData.getStageFile(stage);
            if (stageFile != null && stageFile.loadingImages != null)
            {
                for (image in stageFile.loadingImages)
                {
                    if (!isStageImageLoaded(image))
                        return false;
                }
            }
        }
        return true;
    }

    static function isCharacterLoaded(character:String):Bool
    {
        var pathsToCheck = [
            'data/characters/$character.json',
            'images/characters/$character.png',
            'images/characters/$character.xml',
            'images/characters/$character.json',
            'images/characters/$character.txt'
        ];

        for (path in pathsToCheck)
        {
            var assetType:AssetType = path.endsWith('.png') ? IMAGE : TEXT;
            if (Paths.fileExists(path, assetType, true))
                return true;
        }

        return false;
    }

    static function isStageImageLoaded(image:String):Bool
    {
        var pathsToCheck = [
            'images/$image.png',
            'images/$image.xml',
            'images/$image.json',
            'images/$image.txt'
        ];

        for (path in pathsToCheck)
        {
            var assetType:AssetType = path.endsWith('.png') ? IMAGE : TEXT;
            if (Paths.fileExists(path, assetType, true))
                return true;
        }

        return false;
    }

    #if MODS_ALLOWED
    static function isModsLoaded():Bool
    {
        return Mods.getGlobalMods().length > 0;
    }
    #end

    static function areVocalsLoaded():Bool
    {
        var vocalPaths = getVocalPaths();
        for (path in vocalPaths)
        {
            if (!isSoundLoaded(path))
                return false;
        }
        return true;
    }

    static function isSoundLoaded(path:String):Bool
    {
        #if MODS_ALLOWED
        if (path?.startsWith('${Mods.MODS_FOLDER}/')) {
            return FileSystem.exists(path);
        }
        #end

        if (Assets.cache.hasSound(path)) {
            return true;
        }
        
        for (ext in Paths.SOUND_EXTS) {
            var testPath = Path.withoutExtension(path) + "." + ext;
            if (Assets.exists(testPath)) {
                return true;
            }
        }
        
        return false;
    }

    override function destroy()
    {
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

        callbacks = null;
        percentText?.destroy();
        startTimer?.destroy();

        super.destroy();
    }

    static function initSongsManifest()
    {
        var id = "songs";
        var promise = new Promise<AssetLibrary>();

        var library = LimeAssets.getLibrary(id);

        if (library != null)
        {
            return Future.withValue(library);
        }

        var path = id;
        var rootPath = null;

        @:privateAccess
        var libraryPaths = LimeAssets.libraryPaths;
        if (libraryPaths.exists(id))
        {
            path = libraryPaths[id];
            rootPath = Path.directory(path);
        }
        else
        {
            if (StringTools.endsWith(path, ".bundle"))
            {
                rootPath = path;
                path += "/library.json";
            }
            else
            {
                rootPath = Path.directory(path);
            }
            @:privateAccess
            path = LimeAssets.__cacheBreak(path);
        }

        AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
        {
            if (manifest == null)
            {
                promise.error("Cannot parse asset manifest for library \"" + id + "\"");
                return;
            }

            var library = AssetLibrary.fromManifest(manifest);

            if (library == null)
            {
                promise.error("Cannot open library \"" + id + "\"");
            }
            else
            {
                @:privateAccess
                LimeAssets.libraries.set(id, library);
                library.onChange.add(LimeAssets.onChange.dispatch);
                promise.completeWith(Future.withValue(library));
            }
        }).onError((_) ->
        {
            promise.error("There is no asset library with an ID of \"" + id + "\"");
        });

        return promise.future;
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

    public function new (callback:Void->Void, logId:String = null)
    {
        this.callback = callback;
        this.logId = logId;
    }

    public function add(id = "untitled")
    {
        id = '$length:$id';
        length++;
        numRemaining++;
        var func:Void->Void = null;
        func = function ()
        {
            if (unfired.exists(id))
            {
                unfired.remove(id);
                fired.push(id);
                numRemaining--;

                if (logId != null)
                    log('fired $id, $numRemaining remaining');

                if (numRemaining == 0)
                {
                    if (logId != null)
                        log('all callbacks fired');
                    callback();
                }
            }
            else
                log('already fired $id');
        }
        unfired[id] = func;
        return func;
    }

    inline function log(msg):Void
    {
        if (logId != null)
            trace('$logId: $msg');
    }

    public function getFired() return fired.copy();
    public function getUnfired() return [for (id in unfired.keys()) id];
}