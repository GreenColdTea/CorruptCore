package game.states;

import lime.app.Promise;
import lime.app.Future;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import flixel.util.typeLimit.NextState;
import flixel.math.FlxMath;

import openfl.utils.Assets;
import openfl.media.Sound;

import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;

import haxe.io.Path;

import sys.thread.FixedThreadPool;
import sys.thread.Thread;
import sys.thread.Mutex;

import game.backend.StageData.StageFile;

class LoadingState extends MusicBeatState
{
    static final MIN_TIME = 1.0;

    var target:NextState;
    var stopMusic:Bool;
    var directory:String;
    var callbacks:MultiCallback;
    var targetShit:Float = 0;

    static var threadPool:FixedThreadPool;
    
    #if sys
    static var loadMutex = new sys.thread.Mutex();
    #end

    var loadQueue:Array<Void->Void> = [];
    var queueIndex:Int = 0;
    var tasksPerFrame:Int = 3;
    var loadingStarted:Bool = false;
    var startTimer:FlxTimer;

    public var maxThreadPools:Int = 2;

    public function new(target:NextState, stopMusic:Bool, directory:String)
    {
        super();
        this.target = target;
        this.stopMusic = stopMusic;
        this.directory = directory;
        
        if (threadPool == null) {
            threadPool = new FixedThreadPool(maxThreadPools);
            trace('Thread pool initialized with $maxThreadPools threads');
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

        var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
        add(bg);
        
        funkay = new FlxSprite(0, 0).loadGraphic(Paths.getPath('images/funkay.png', IMAGE));
        funkay.setGraphicSize(0, FlxG.height);
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
        
        var fadeTime = 0.5;
        FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true);
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
                    loadQueue.push(() -> {
                        var callback = callbacks.add("character:" + char);
                        loadCharacterJson(char, () -> callback());
                    });
                }
            }

            loadQueue.push(() -> checkLoadSong(getSongPath()));
            if (PlayState.SONG.needsVoices)
                loadQueue.push(() -> checkLoadSong(getVocalPath()));

            var stage = PlayState.SONG.stage;
            stage ??= StageData.vanillaSongStage(PlayState.SONG.song);
            
            var stageFile:StageFile = StageData.getStageFile(stage);
            if (stageFile != null && stageFile.loadingImages != null)
            {
                for (image in stageFile.loadingImages)
                {
                    loadQueue.push(() -> {
                        var callback = callbacks.add("stageImage:" + image);
                        loadStageImage(image, () -> callback());
                    });
                }
            }
        }
        
        loadQueue.push(() -> checkLibrary("shared"));
        if(directory != null && directory.length > 0 && directory != 'shared') {
            loadQueue.push(() -> checkLibrary(directory));
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
                loadQueue[queueIndex]();
                queueIndex++;
                count++;
            }
        }
        
        funkay.setGraphicSize(Std.int(0.88 * FlxG.width + 0.9 * (funkay.width - 0.88 * FlxG.width)));
        funkay.updateHitbox();
        
        if(controls.ACCEPT)
        {
            funkay.setGraphicSize(Std.int(funkay.width + 60));
            funkay.updateHitbox();
        }

        if(callbacks != null) {
            var progress:Float = 1 - (callbacks.numRemaining / callbacks.length);
            targetShit = progress * Std.int(loadBarBg.width - 10);
            loadBar.scale.x = targetShit;
            
            var percent:Int = Math.round(progress * 100);
            percentText.text = '$percent%';
        }
    }
    
    function loadCharacterJson(character:String, onComplete:Void->Void)
    {
        var characterPath:String = 'characters/' + character + '.json';
        var path:String = Paths.getPath(characterPath, TEXT, null, true);
        
        #if MODS_ALLOWED
        if (sys.FileSystem.exists(path))
        {
            threadPool.run(function() {
                try {
                    var rawJson = sys.io.File.getContent(path);
                    var json:Dynamic = haxe.Json.parse(rawJson);
                    
                    haxe.Timer.delay(function() {
                        if (json.image != null) {
                            loadCharacterImage(json.image, onComplete);
                        } else {
                            loadCharacterImage('characters/' + character, onComplete);
                        }
                    }, 0);
                } catch (e:Dynamic) {
                    trace('Error loading character JSON: $character, error: $e');
                    haxe.Timer.delay(function() {
                        loadCharacterImage('characters/' + character, onComplete);
                    }, 0);
                }
            });
        }
        else
        #end
        if (Assets.exists(path))
        {
            threadPool.run(function() {
                try {
                    var rawJson = Assets.getText(path);
                    var json:Dynamic = haxe.Json.parse(rawJson);
                    
                    haxe.Timer.delay(function() {
                        if (json.image != null) {
                            loadCharacterImage(json.image, onComplete);
                        } else {
                            loadCharacterImage('characters/' + character, onComplete);
                        }
                    }, 0);
                } catch (e:Dynamic) {
                    trace('Error parsing character JSON: $character, error: $e');
                    haxe.Timer.delay(() -> loadCharacterImage('characters/' + character, onComplete), 0);
                }
            });
        }
        else
        {
            loadCharacterImage('characters/' + character, onComplete);
        }
    }
    
    function loadCharacterImage(image:String, onComplete:Void->Void)
    {
        var callback = callbacks.add("characterImage:" + image);

        #if flixel_animate
        var animatePath:String = Paths.getPath('images/$image/Animation.json', TEXT, null, true);

        if (#if MODS_ALLOWED sys.FileSystem.exists(animatePath) || #end Assets.exists(animatePath))
        {
            Paths.getAnimateAtlas(image);
            callback();
            onComplete();
            return;
        }
        #end
        
        var xmlPath = Paths.getPath('images/$image.xml', TEXT, null, true);
        if (Assets.exists(xmlPath) #if MODS_ALLOWED || sys.FileSystem.exists(xmlPath) #end)
        {
            Paths.getSparrowAtlas(image, null, true);
            callback();
            onComplete();
            return;
        }
        
        var jsonPath = Paths.getPath('images/$image.json', TEXT, null, true);
        if (Assets.exists(jsonPath) #if MODS_ALLOWED || sys.FileSystem.exists(jsonPath) #end)
        {
            Paths.getAsepriteAtlas(image, null, true);
            callback();
            onComplete();
            return;
        }
        
        var txtPath = Paths.getPath('images/$image.txt', TEXT, null, true);
        if (Assets.exists(txtPath) #if MODS_ALLOWED || sys.FileSystem.exists(txtPath) #end)
        {
            Paths.getPackerAtlas(image, null, true);
            callback();
            onComplete();
            return;
        }
        
        trace('WARNING: Character image not found: $image');
        callback();
        onComplete();
    }

    function loadStageImage(image:String, onComplete:Void->Void)
    {
        var callback = callbacks.add("stageImage:" + image);

        #if flixel_animate
        var animatePath:String = Paths.getPath('images/$image/Animation.json', TEXT, null, true);

        if (#if MODS_ALLOWED sys.FileSystem.exists(animatePath) || #end Assets.exists(animatePath))
        {
            Paths.getAnimateAtlas(image);
            callback();
            onComplete();
            return;
        }
        #end
        
        var xmlPath = Paths.getPath('images/$image.xml', TEXT, null, true);
        if (Assets.exists(xmlPath) #if MODS_ALLOWED || sys.FileSystem.exists(xmlPath) #end)
        {
            Paths.getSparrowAtlas(image, null, true);
            callback();
            onComplete();
            return;
        }
        
        var jsonPath = Paths.getPath('images/$image.json', TEXT, null, true);
        if (Assets.exists(jsonPath) #if MODS_ALLOWED || sys.FileSystem.exists(jsonPath) #end)
        {
            Paths.getAsepriteAtlas(image, null, true);
            callback();
            onComplete();
            return;
        }
        
        var txtPath = Paths.getPath('images/$image.txt', TEXT, null, true);
        if (Assets.exists(txtPath) #if MODS_ALLOWED || sys.FileSystem.exists(txtPath) #end)
        {
            Paths.getPackerAtlas(image, null, true);
            callback();
            onComplete();
            return;
        }
        
        var imagePath = Paths.getPath('images/$image.png', IMAGE, null, true);
        if (Assets.exists(imagePath) #if MODS_ALLOWED || sys.FileSystem.exists(imagePath) #end)
        {
            Paths.image(image);
            callback();
            onComplete();
            return;
        }
        
        trace('WARNING: Stage image not found: $image');
        callback();
        onComplete();
    }
    
    function checkLoadSong(path:String)
    {
        if (path.startsWith('contents/')) {
            var callback = callbacks.add("modSong:" + path);
            
            #if MODS_ALLOWED
            threadPool.run(function() {
                try {
                    var sound = Sound.fromFile(path);
                    haxe.Timer.delay(function() {
                        Paths.currentTrackedSounds.set(path, sound);
                        callback();
                    }, 0);
                } catch (e:Dynamic) {
                    trace('Error loading mod sound: $path, error: $e');
                    haxe.Timer.delay(function() {
                        callback();
                    }, 0);
                }
            });
            #else
            callback();
            #end
        } else {
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
        #if sys
        loadMutex.acquire();
        #end
        try {
            if (Assets.getLibrary(library) == null)
            {
                @:privateAccess
                if (!LimeAssets.libraryPaths.exists(library))
                {
                    trace('Library $library not found, but continuing anyway');
                    #if sys
                    loadMutex.release();
                    #end
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
            #if sys
            loadMutex.release();
            #end
            var callback = callbacks.add("error_library:" + library);
            callback();
        }
        #if sys
        loadMutex.release();
        #end
    }
    
    function onLoad()
    {
        trace('Loading complete! Loaded ${callbacks.getFired().length} items');
        trace('Fired callbacks: ${callbacks.getFired().join(", ")}');

        if (stopMusic)
            FlxG.sound?.music?.stop();
        
        FlxG.switchState(target);
    }
    
    static function getSongPath():String
    {
        #if MODS_ALLOWED
        var modPath = modsSongs('${Paths.formatToSongPath(PlayState.SONG.song)}/Inst');
        if (sys.FileSystem.exists(modPath)) {
            return modPath;
        }
        #end
        return instPath(PlayState.SONG.song);
    }

    static function getVocalPath():String
    {
        #if MODS_ALLOWED
        var modPath = modsSongs('${Paths.formatToSongPath(PlayState.SONG.song)}/Voices');
        if (sys.FileSystem.exists(modPath)) {
            return modPath;
        }
        #end
        return voicesPath(PlayState.SONG.song);
    }

    #if MODS_ALLOWED
    static function modsSongs(key:String)
    {
        return Paths.mods('songs/$key.${Paths.SOUND_EXT}');
    }
    #end

    static public function instPath(song:String):String
    {
        var songKey:String = '${Paths.formatToSongPath(song)}/Inst';
        #if MODS_ALLOWED
        var modPath = Paths.mods('songs/$songKey.${Paths.SOUND_EXT}');
        if (sys.FileSystem.exists(modPath)) {
            return modPath;
        }
        #end
        return Paths.getPath('$songKey.${Paths.SOUND_EXT}', SOUND, 'songs', true);
    }

    static public function voicesPath(song:String, postfix:String = null):String
    {
        var songKey:String = '${Paths.formatToSongPath(song)}/Voices';
        if (postfix != null) songKey += '-' + postfix;
        #if MODS_ALLOWED
        var modPath = Paths.mods('songs/$songKey.${Paths.SOUND_EXT}');
        if (sys.FileSystem.exists(modPath)) {
            return modPath;
        }
        #end
        return Paths.getPath('$songKey.${Paths.SOUND_EXT}', SOUND, 'songs', true);
    }
    
    public static function loadAndSwitchState(targetFactory:Void->NextState, stopMusic = false)
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
                    (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath())) && 
                    isLibraryLoaded("shared") && 
                    isLibraryLoaded(directory) &&
                    #if MODS_ALLOWED isModsLoaded() #else true #end &&
                    areCharactersLoaded();
        }
        
        if (!loaded && isPlayState)
        {
            FlxG.switchState(new LoadingState(targetState, stopMusic, directory));
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
        return Paths.getGlobalMods().length > 0;
    }
    #end
    
    static function isSoundLoaded(path:String):Bool
    {
        if (path.startsWith('contents/')) {
            #if MODS_ALLOWED
            return sys.FileSystem.exists(path);
            #else
            return false;
            #end
        }
        
        return Assets.cache.hasSound(path);
    }
    
    static function isLibraryLoaded(library:String):Bool
    {
        return Assets.getLibrary(library) != null;
    }
    
    override function destroy()
    {
        super.destroy();
        
        callbacks = null;
        percentText?.destroy();
        startTimer?.destroy();

        threadPool = null;
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