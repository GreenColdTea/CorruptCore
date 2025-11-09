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

    static var fileIOPool:ThreadPool;
    static var imageProcessingPool:ThreadPool;
    static var audioProcessingPool:ThreadPool;
    static var jsonProcessingPool:ThreadPool;

    var loadQueue:Array<LoadTask> = [];
    var queueIndex:Int = 0;
    var tasksPerFrame:Int = 2;
    var loadingStarted:Bool = false;
    var startTimer:FlxTimer;

    public final maxFileIOThreads:Int = 2;
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
        if (fileIOPool == null) {
            fileIOPool = new ThreadPool(0, maxFileIOThreads);
            fileIOPool.onComplete.add(onFileIOComplete);
            fileIOPool.onError.add(onFileIOError);
            #if (haxe_ver >= 4.1)
            fileIOPool.onUncaughtError.add(onFileIOUncaughtError);
            #end
        }

        if (imageProcessingPool == null) {
            imageProcessingPool = new ThreadPool(0, maxImageThreads);
            imageProcessingPool.onComplete.add(onImageProcessingComplete);
            imageProcessingPool.onError.add(onImageProcessingError);
            #if (haxe_ver >= 4.1)
            imageProcessingPool.onUncaughtError.add(onImageProcessingUncaughtError);
            #end
        }

        if (audioProcessingPool == null) {
            audioProcessingPool = new ThreadPool(0, maxAudioThreads);
            audioProcessingPool.onComplete.add(onAudioProcessingComplete);
            audioProcessingPool.onError.add(onAudioProcessingError);
            #if (haxe_ver >= 4.1)
            audioProcessingPool.onUncaughtError.add(onAudioProcessingUncaughtError);
            #end
        }

        if (jsonProcessingPool == null) {
            jsonProcessingPool = new ThreadPool(0, maxJSONThreads);
            jsonProcessingPool.onComplete.add(onJSONProcessingComplete);
            jsonProcessingPool.onError.add(onJSONProcessingError);
            #if (haxe_ver >= 4.1)
            jsonProcessingPool.onUncaughtError.add(onJSONProcessingUncaughtError);
            #end
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

        funkay = new FlxSprite(0, 0).loadGraphic(Paths.getPath('images/funkay.png', IMAGE));
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
        startTimer = new FlxTimer().start(CustomFadeTransition.lastDuration, (_) -> {
            loadingStarted = true;
            startLoading();
        });
    }

    function startLoading()
    {
        initSongsManifest().onComplete
        (
            function (lib)
            {
                callbacks = new MultiCallback(onLoad);
                var introComplete = callbacks.add("introComplete");

                buildLoadQueue();

                new FlxTimer().start(MIN_TIME, (_) -> introComplete());
            }
        ).onError(function(e) {
            trace('Error loading songs manifest: $e');
            callbacks = new MultiCallback(onLoad);
            var introComplete = callbacks.add("introComplete");
            introComplete();
        });
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
                        type: MAIN_THREAD, // JSON processing in main thread
                        execute: () -> {
                            var callback = callbacks.add("character:" + char);
                            loadCharacter(char, () -> callback());
                        },
                        description: 'Load character: $char'
                    });
                }
            }

            loadQueue.push({
                type: MAIN_THREAD, // Audio loading in main thread
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
                        type: MAIN_THREAD, // Image loading in main thread
                        execute: () -> {
                            var callback = callbacks.add("stageImage:" + image);
                            loadStageImage(image, () -> callback());
                        },
                        description: 'Load stage image: $image'
                    });
                }
            }
        }

        loadQueue.push({
            type: MAIN_THREAD, // Library operations in main thread
            execute: () -> checkLibrary("shared"),
            description: 'Check shared library'
        });

        if(directory != null && directory.length > 0 && directory != 'shared') {
            loadQueue.push({
                type: MAIN_THREAD, // Library operations in main thread
                execute: () -> checkLibrary(directory),
                description: 'Check directory library: $directory'
            });
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

    // for future stuff
    function onFileIOComplete(state:Dynamic) {}
    function onImageProcessingComplete(state:Dynamic) {}
    function onAudioProcessingComplete(state:Dynamic) {}
    function onJSONProcessingComplete(state:Dynamic) {}
    function handleTaskError(state:Dynamic) {}
    function onFileIOError(state:Dynamic) {}
    function onImageProcessingError(state:Dynamic) {}
    function onAudioProcessingError(state:Dynamic) {}
    function onJSONProcessingError(state:Dynamic) {}
    #if (haxe_ver >= 4.1)
    function onFileIOUncaughtError(exception:Exception) {}
    function onImageProcessingUncaughtError(exception:Exception) {}
    function onAudioProcessingUncaughtError(exception:Exception) {}
    function onJSONProcessingUncaughtError(exception:Exception) {}
    #end

    function loadCharacter(character:String, onComplete:Void->Void)
    {
        var characterPath:String = 'characters/' + character + '.json';
        var path:String = Paths.getPath(characterPath, TEXT, null, true);

        var rawJson:String = null;
        #if MODS_ALLOWED
        if (sys.FileSystem.exists(path))
            rawJson = sys.io.File.getContent(path);
        else #end if (Assets.exists(path))
            rawJson = Assets.getText(path);

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
            Paths.getAnimateAtlas(image);
        else if (formats.xml)
            Paths.getSparrowAtlas(image, null, true);
        else if (formats.json)
            Paths.getAsepriteAtlas(image, null, true);
        else if (formats.txt)
            Paths.getPackerAtlas(image, null, true);
        else if (formats.png)
            Paths.image(image);
        else
            trace('WARNING: Character image not found: $image');

        callback();
        onComplete();
    }

    function checkImageFormats(image:String):Dynamic
    {
        function assetExists(path:String, type:AssetType):Bool
        {
            #if MODS_ALLOWED
            var modsPath:String = Paths.getPath(path, type, null, true);
            if (sys.FileSystem.exists(modsPath))
                return true;
            #end

            return Assets.exists(Paths.getPath(path, type, null, false));
        }

        return {
            animate: #if flixel_animate assetExists('images/$image/Animation.json', TEXT) #else false #end,
            xml: assetExists('images/$image.xml', TEXT),
            json: assetExists('images/$image.json', TEXT),
            txt: assetExists('images/$image.txt', TEXT),
            png: assetExists('images/$image.png', IMAGE)
        };
    }

    function loadStageImage(image:String, onComplete:Void->Void)
    {
        var callback = callbacks.add("stageImage:" + image);

        var formats = checkImageFormats(image);

        if (formats.animate)
            Paths.getAnimateAtlas(image);
        else if (formats.xml)
            Paths.getSparrowAtlas(image, null, true);
        else if (formats.json)
            Paths.getAsepriteAtlas(image, null, true);
        else if (formats.txt)
            Paths.getPackerAtlas(image, null, true);
        else if (formats.png)
            Paths.image(image);
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
                var sound = Sound.fromFile(path);
                Paths.currentTrackedSounds.set(path, sound);
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

    function checkLibrary(library:String) {
        try {
            if (Assets.getLibrary(library) == null)
            {
                @:privateAccess
                if (!LimeAssets.libraryPaths.exists(library))
                {
                    trace('Library $library not found, but continuing anyway');
                    var callback = callbacks.add("missing_library:" + library);
                    callback();
                    return;
                }

                var callback = callbacks.add("library:" + library);
                Assets.loadLibrary(library).onComplete((_) -> callback()).onError(function(e) {
                    trace('Error loading library: $library, error: $e');
                    callback();
                });
            }
            else
            {
                var callback = callbacks.add("already_loaded_library:" + library);
                callback();
            }
        } catch (e) {
            trace('Exception in checkLibrary: $e');
            var callback = callbacks.add("error_library:" + library);
            callback();
        }
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
        return instPath(PlayState.SONG.song);
    }

    static function getVocalPaths():Array<String>
    {
        var paths:Array<String> = [];

        var vocalsPath:String = voicesPath(PlayState.SONG.song);
        if (vocalsPath != null) paths.push(vocalsPath);

        var playerPostfix:String = getCharVocalsPostfix(PlayState.SONG.player1);
        var opponentPostfix:String = getCharVocalsPostfix(PlayState.SONG.player2);

        if (playerPostfix != null) {
            var playerVocals:String = voicesPath(PlayState.SONG.song, playerPostfix);
            if (playerVocals != null) paths.push(playerVocals);
        }

        if (opponentPostfix != null) {
            var opponentVocals:String = voicesPath(PlayState.SONG.song, opponentPostfix);
            if (opponentVocals != null) paths.push(opponentVocals);
        }

        return paths;
    }

    static function instPath(song:String):String
    {
        var songKey:String = '${Paths.formatToSongPath(song)}/inst';

        var path = getSoundFilePath(null, songKey, 'songs');
        if (path == null) {
            songKey = '${Paths.formatToSongPath(song)}/Inst';
            path = getSoundFilePath(null, songKey, 'songs');
        }

        return path;
    }

    static function voicesPath(song:String, postfix:String = null):String
    {
        var songKey:String = '${Paths.formatToSongPath(song)}/voices';
        if (postfix != null) songKey += '-' + postfix;

        var path = getSoundFilePath(null, songKey, 'songs');
        if (path == null) {
            songKey = '${Paths.formatToSongPath(song)}/Voices';
            if (postfix != null) songKey += '-' + postfix;
            path = getSoundFilePath(null, songKey, 'songs');
        }
        return path;
    }

    @:noCompletion
    private static function getSoundFilePath(path:Null<String>, key:String, ?library:String):String
    {
        #if MODS_ALLOWED
        var modLibPath:String = '';
        if (library != null) modLibPath = '$library/';
        if (path != null) modLibPath += '$path/';

        for (ext in Paths.SOUND_EXTS) {
            var file:String = Mods.modsSounds(modLibPath, key, ext);
            if(FileSystem.exists(file)) {
                return file;
            }
        }
        #end

        var fullKey = (path != null ? '$path/' : '') + key;

        for (ext in Paths.SOUND_EXTS) {
            var soundPath:String = Paths.getPath('$fullKey.$ext', SOUND, library);
            if(Assets.exists(soundPath, SOUND)) {
                return soundPath;
            }
        }

        return null;
    }

    static function getCharVocalsPostfix(character:String):String
    {
        if (character == null) return null;

        try {
            var characterPath:String = 'characters/' + character + '.json';
            var path:String = Paths.getPath(characterPath, TEXT, null, true);

            var rawJson:String = null;
            #if MODS_ALLOWED
            if (sys.FileSystem.exists(path))
                rawJson = sys.io.File.getContent(path);
            else #end if (Assets.exists(path))
                rawJson = Assets.getText(path);

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
                return "Player";
            else if (character == PlayState.SONG.player2)
                return "Opponent";
        }

        return null;
    }

    public static function loadAndSwitchState(targetFactory:Void->FlxState, stopMusic = false)
    {
        var targetState = targetFactory();
        var isPlayState = Std.isOfType(targetState, PlayState);

        var directory:String = 'shared';
        var weekDir:String = StageData.forceNextDirectory;
        StageData.forceNextDirectory = null;

        Paths.setCurrentLevel(directory);
        trace('Setting asset folder to ' + directory);

        var loaded:Bool = true;
        if (PlayState.SONG != null) {
            loaded = isSoundLoaded(getSongPath()) &&
                    (!PlayState.SONG.needsVoices || areVocalsLoaded()) &&
                    isLibraryLoaded("shared") &&
                    isLibraryLoaded(directory) &&
                    #if MODS_ALLOWED isModsLoaded() #else true #end &&
                    areCharactersLoaded();
        }

        if (!loaded && isPlayState)
        {
            FlxG.switchState(() -> new LoadingState(targetState, stopMusic, directory));
            return;
        }

        if (stopMusic) FlxG.sound?.music?.stop();

        FlxG.switchState(() -> targetState);
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
            Paths.getPath('characters/$character.json', TEXT, null, true),
            Paths.getPath('images/characters/$character.png', IMAGE, null, true),
            Paths.getPath('images/characters/$character.xml', TEXT, null, true),
            Paths.getPath('images/characters/$character.json', TEXT, null, true),
            Paths.getPath('images/characters/$character.txt', TEXT, null, true)
        ];

        for (path in pathsToCheck)
        {
            #if MODS_ALLOWED
            if (sys.FileSystem.exists(path)) return true;
            #end
            if (Assets.exists(path)) return true;
        }

        return false;
    }

    static function isStageImageLoaded(image:String):Bool
    {
        var pathsToCheck = [
            Paths.getPath('images/$image.png', IMAGE, null, true),
            Paths.getPath('images/$image.xml', TEXT, null, true),
            Paths.getPath('images/$image.json', TEXT, null, true),
            Paths.getPath('images/$image.txt', TEXT, null, true)
        ];

        for (path in pathsToCheck)
        {
            #if MODS_ALLOWED
            if (sys.FileSystem.exists(path)) return true;
            #end
            if (Assets.exists(path)) return true;
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
        if (path.startsWith('${Mods.MODS_FOLDER}/')) return sys.FileSystem.exists(path);
        #end

        return Assets.cache.hasSound(path);
    }

    static function isLibraryLoaded(library:String):Bool
    {
        return Assets.getLibrary(library) != null;
    }

    override function destroy()
    {
        if (fileIOPool != null) {
            fileIOPool.cancel();
            fileIOPool = null;
        }

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