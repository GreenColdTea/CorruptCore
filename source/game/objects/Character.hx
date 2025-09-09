package game.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;

import game.stages.objects.TankmenBG;
import game.backend.Section.SwagSection;

using StringTools;

typedef CharacterFile =
{
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var vocals_file:String;
	var healthbar_colors:Array<Int>;
}

typedef AnimArray =
{
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var voicelining:Bool = false;

	//for double note ghosts anim
	public var mostRecentRow:Int = 0;
	public var ghostIdx:Int = 0;
	public var ghostAnim:String = '';
	public var animGhosts:Array<FlxSprite> = [];
	public var ghostTweens:Array<FlxTween> = [];

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var animTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var vocalsFile:String = '';
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static var DEFAULT_CHARACTER:String = 'bf'; // In case a character is missing, it will use BF on its place

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false, ?isChibiChar:Bool = false)
	{
		super(x, y);

		for(i in 0...4){
			var ghost = new FlxSprite();
			ghost.visible = false;
			ghost.antialiasing = ClientPrefs.globalAntialiasing;
			ghost.alpha = 0.6;
			animGhosts.push(ghost);
			ghostTweens.push(null);
		}

		#if (haxe >= "4.0.0")
		animOffsets = new Map();
		#else
		animOffsets = new Map<String, Array<Dynamic>>();
		#end
		curCharacter = character;
		this.isPlayer = isPlayer;
		antialiasing = ClientPrefs.globalAntialiasing;
		var library:String = null;

		var characterPath:String = 'characters/' + curCharacter + '.json';

		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path))
		{
			path = Paths.getPreloadPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getPreloadPath('characters/' + DEFAULT_CHARACTER +
				'.json'); // If a character couldn't be found, change him to BF just to prevent a crash
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end

		var json:CharacterFile = cast Json.parse(rawJson);
		var spriteType = "sparrow";
		// sparrow
		// packer
		// texture
		#if MODS_ALLOWED
		var modTxtToFind:String = Paths.modsTxt(json.image);
		var txtToFind:String = Paths.getPath('images/' + json.image + '.txt', TEXT);

		if (FileSystem.exists(modTxtToFind) || FileSystem.exists(txtToFind) || Assets.exists(txtToFind))
		#else
		if (Assets.exists(Paths.getPath('images/' + json.image + '.txt', TEXT)))
		#end
		{
			spriteType = "packer";
		}

		#if flixel_animate
		#if MODS_ALLOWED
		var modAnimToFind:String = Paths.modFolders('images/' + json.image + '/Animation.json');
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);

		isAnimateAtlas = false;
		if (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind))
		{
		#else
		if (Assets.exists(Paths.getPath('images/' + json.image + '/Animation.json', TEXT)))
		{
		#end
			spriteType = "texture";
			isAnimateAtlas = true;
		}
		#end

		switch (spriteType)
		{
			case "packer":
				frames = Paths.getPackerAtlas(json.image);

			case "sparrow":
				frames = Paths.getSparrowAtlas(json.image);

			#if flixel_animate
			case "texture":
				atlas = new FlxAnimate();
				try
				{
					atlas.frames = Paths.getAnimateAtlas(json.image);
				}
				catch (e:haxe.Exception)
				{
					FlxG.log.warn('Could not load atlas ${json.image}: $e');
					trace(e.stack);
				}
			#end
		}
		imageFile = json.image;

		if (json.scale != 1)
		{
			jsonScale = json.scale;
			setGraphicSize(Std.int(width * jsonScale));
			updateHitbox();
		}

		positionArray = json.position;
		cameraPosition = json.camera_position;

		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		flipX = !!json.flip_x; //bruhhh
		if (json.no_antialiasing)
		{
			antialiasing = false;
			noAntialiasing = true;
		}

		if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
			healthColorArray = json.healthbar_colors;

		antialiasing = !noAntialiasing;
		if (!ClientPrefs.globalAntialiasing)
			antialiasing = false;

		animationsArray = json.animations;
		if (animationsArray != null && animationsArray.length > 0)
		{
			for (anim in animationsArray)
			{
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop; // Bruh
				var animIndices:Array<Int> = anim.indices;

				if (!isAnimateAtlas)
				{
					if (animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
				#if flixel_animate
				else
				{
					if (animIndices != null && animIndices.length > 0)
						atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else if (atlas.library.getSymbol(animName) != null) // ? Allow us to use labels please
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					else // ? Allow us to use labels please
						atlas.anim.addByFrameLabel(animAnim, animName, animFps, animLoop);
				}
				#end

				if (anim.offsets != null && anim.offsets.length > 1)
				{
					addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				}
			}
		}
		else
		{
			quickAnimAdd('idle', 'BF idle dance');
		}
		
		if (isChibiChar) {
			scale.set(scale.x / 3, scale.y / 3);
			updateHitbox();
			origin.set();

			x -= width * .5;
			y -= height;

			for (anim in animOffsets.keys()) {
				animOffsets[anim][0] *= scale.x;
				animOffsets[anim][1] *= scale.y;
			}
		}

		#if flixel_animate
		if (isAnimateAtlas)
			copyAtlasValues();
		#end
		originalFlipX = flipX;

		if (hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss'))
			hasMissAnimations = true;
		recalculateDanceIdle();
		dance();

		if (isPlayer)flipX = !flipX;

		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
		}
	}

	override function update(elapsed:Float)
	{
		if (isAnimateAtlas)
			atlas.update(elapsed);

		if (debugMode
			|| (!isAnimateAtlas && animation.curAnim == null)
			|| (isAnimateAtlas && atlas.anim.curAnim == null))
		{
			super.update(elapsed);
			return;
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if(animTimer > 0) 
		{
			animTimer -= elapsed;
			if(animTimer <= 0){
				animTimer=0;
				dance();
			}
		}

		if (heyTimer > 0)
		{
			heyTimer -= elapsed * PlayState.instance.playbackRate;
			if (heyTimer <= 0)
			{
				if (specialAnim && getAnimationName() == 'hey' || getAnimationName() == 'cheer')
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if (specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if(isAnimationFinished() && hasAnimation('$name-loop'))
			playAnim('$name-loop');

		for (ghost in animGhosts)
			ghost.update(elapsed);

		super.update(elapsed);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	inline public function dance()
	{
		if (!debugMode && !skipDance && animTimer <= 0 && !specialAnim && !voicelining)
		{
			if (danceIdle)
			{
				danced = !danced;

				playAnim(danced ? 'danceRight' + idleSuffix : 'danceLeft' + idleSuffix);
			}
			else if (hasAnimation('idle' + idleSuffix))
			{
				playAnim('idle' + idleSuffix);
			}
		}
	}

	inline public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		if (!isAnimateAtlas)
		{
			animation?.play(AnimName, Force, Reversed, Frame);
		}
		else
		{
			atlas?.anim?.play(AnimName, Force, Reversed, Frame);
			atlas?.update(0);
		}

		_lastPlayedAnimation = AnimName;

		var daOffset = animOffsets.get(AnimName);
		if (hasAnimation(AnimName))
			offset.set(daOffset[0], daOffset[1]);
		else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
			{
				danced = true;
			}
			else if (AnimName == 'singRIGHT')
			{
				danced = false;
			}

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
			{
				danced = !danced;
			}
		}
	}

	inline public function playGhostAnim(GhostIdx = 0, AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0){
		if (GhostIdx < 0 || GhostIdx >= animGhosts.length) return;

		var ghost = animGhosts[GhostIdx];
		ghost.scale.set(scale.x, scale.y);
		ghost.updateHitbox();
		ghost.frames = frames;
		ghost.animation.copyFrom(animation);
		ghost.antialiasing = antialiasing;
		ghost.x = x;
		ghost.y = y;
		ghost.flipX = flipX;
		ghost.flipY = flipY;
		ghost.alpha = alpha * 0.6;
		ghost.visible = true;
		ghost.color = FlxColor.fromRGB(healthColorArray[0], healthColorArray[1], healthColorArray[2]);
		ghost.animation.play(AnimName, Force, Reversed, Frame);
		if (GhostIdx < ghostTweens.length && ghostTweens[GhostIdx] != null) {
			ghostTweens[GhostIdx].cancel();
		}

		if (GhostIdx < ghostTweens.length) {
			ghostTweens[GhostIdx] = FlxTween.tween(ghost, {alpha: 0}, 0.75, {
				ease: FlxEase.linear,
				onComplete: function(twn:FlxTween)
				{
					ghost.visible = false;
					ghostTweens[GhostIdx] = null;
				}
			});
		}

		var daOffset = animOffsets.get(AnimName);
		if (hasAnimation(AnimName))
			ghost.offset.set(daOffset[0], daOffset[1]);
		else
			ghost.offset.set(0, 0);
	}

	inline function loadMappedAnims():Void
	{
		try
		{
			var noteData:Array<SwagSection> = Song.loadFromJson('picospeaker', Paths.formatToSongPath(PlayState.SONG.song)).notes;
			for (section in noteData) {
				for (songNotes in section.sectionNotes) {
					animationNotes.push(songNotes);
				}
			}
			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	inline function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	inline public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	inline public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	inline public function hasAnimation(anim:String):Bool
	{
		return animOffsets.exists(anim);
	}

	inline public function isAnimationNull():Bool
	{
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curAnim == null);	
	}

	var _lastPlayedAnimation:String;

	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool
	{
		if (isAnimationNull())
			return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	inline public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.finish();
	}

	public var danceEveryNumBeats:Int = 2;

	private var settingCharacterUp:Bool = true;

	inline public function recalculateDanceIdle()
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if (settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if (lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if (danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	// Atlas support
	// special thanks ne_eo for the references, you're the goat!!
	public var isAnimateAtlas:Bool = false;
	#if flixel_animate
	public var atlas:FlxAnimate;
	#end

	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;

		#if flixel_animate
		if (isAnimateAtlas)
		{
			if (atlas.anim.curAnim != null)
			{
				copyAtlasValues();
				atlas.draw();
				alpha = lastAlpha;
				color = lastColor;
			}
			return;
		}
		#end

		for(ghost in animGhosts){
			if(ghost.visible)
				ghost.draw();
		}

		super.draw();
	}

	#if flixel_animate
	inline public function copyAtlasValues()
	{
		@:privateAccess
		{
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}

	public override function destroy()
	{
		destroyAtlas();
		super.destroy();
	}

	inline public function destroyAtlas()
	{
		if (atlas != null)
			atlas = FlxDestroyUtil.destroy(atlas);
	}
	#end
}