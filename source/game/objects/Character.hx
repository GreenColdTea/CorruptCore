package game.objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.animation.FlxBaseAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;
import flixel.util.FlxColor;

#if flixel_animate
import animate.FlxAnimate;
#end

#if MODS_ALLOWED
import sys.io.File;
#end

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;
import haxe.format.JsonParser;

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

typedef AnimArray = {
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
	public var singDuration:Float = 4;
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false;
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var vocalsFile:String = '';
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static final DEFAULT_CHARACTER:String = 'bf';

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false, ?isChibiChar:Bool = false)
	{
		super(x, y);

		#if (haxe >= "4.0.0")
		animOffsets = new Map();
		#else
		animOffsets = new Map<String, Array<Dynamic>>();
		#end

		curCharacter = character;
		this.isPlayer = isPlayer;
		antialiasing = ClientPrefs.globalAntialiasing;

		var library:String = null;
		var characterPath:String = 'data/characters/' + curCharacter + '.json';

		if (!Paths.fileExists(characterPath, TEXT))
		{
			characterPath = 'data/characters/' + DEFAULT_CHARACTER + '.json';
		}

		var json:CharacterFile = cast Json.parse(Paths.getTextFromFile(characterPath));
		var spriteType:String = "sparrow";

		if (Paths.fileExists('images/' + json.image + '.txt', TEXT))
		{
			spriteType = "packer";
		}

		#if flixel_animate
		isAnimateAtlas = false;
		if (Paths.fileExists('images/' + json.image + '/Animation.json', TEXT))
		{
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
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		positionArray = json.position;
		cameraPosition = json.camera_position;

		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		flipX = !!json.flip_x;
		if (json.no_antialiasing)
		{
			antialiasing = false;
			noAntialiasing = true;
		}

		if (json.healthbar_colors?.length > 2)
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
				var animLoop:Bool = !!anim.loop;
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
					else if (atlas.library.getSymbol(animName) != null)
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					else
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

		originalFlipX = flipX;

		if (hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss'))
			hasMissAnimations = true;
		recalculateDanceIdle();
		dance();

		if (isPlayer) flipX = !flipX;

		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
		}

		initGhosts();
	}

	private function initGhosts():Void
	{
		for (i in 0...4)
		{
			var ghost:FlxSprite;
			#if flixel_animate
			if (isAnimateAtlas)
			{
				var animateGhost = new FlxAnimate();
				try
				{
					animateGhost.frames = Paths.getAnimateAtlas(imageFile);
				}
				catch (e:Dynamic)
				{
					FlxG.log.warn('Could not load ghost atlas for $imageFile: $e');
				}
				
				for (anim in animationsArray)
				{
					var animAnim:String = '' + anim.anim;
					var animName:String = '' + anim.name;
					var animFps:Int = anim.fps;
					var animLoop:Bool = !!anim.loop;
					var animIndices:Array<Int> = anim.indices;

					if (animIndices != null && animIndices.length > 0)
						animateGhost.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else
						animateGhost.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				}
				ghost = animateGhost;
			}
			else
			#end
			{
				ghost = new FlxSprite();
			}

			ghost.visible = false;
			ghost.antialiasing = ClientPrefs.globalAntialiasing;
			ghost.alpha = 0.6;
			animGhosts.push(ghost);
			ghostTweens.push(null);
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
				animTimer = 0;
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
		
		#if flixel_animate
		if (isAnimateAtlas && Std.isOfType(ghost, FlxAnimate))
		{
			var animateGhost:FlxAnimate = cast ghost;
			
			animateGhost.scale.set(scale.x, scale.y);
			animateGhost.x = x;
			animateGhost.y = y;
			animateGhost.flipX = flipX;
			animateGhost.flipY = flipY;
			animateGhost.alpha = alpha * 0.6;
			animateGhost.visible = true;
			animateGhost.angle = angle;
			animateGhost.shader = shader;
			animateGhost.useRenderTexture = atlas.useRenderTexture;
			animateGhost.color = FlxColor.fromRGB(
				Std.int((healthColorArray[0]/255) * color.red),
				Std.int((healthColorArray[1]/255) * color.green),
				Std.int((healthColorArray[2]/255) * color.blue)
			);
			animateGhost.antialiasing = antialiasing;
			animateGhost.scrollFactor.copyFrom(scrollFactor);
			
			animateGhost.origin.copyFrom(origin);
			
			animateGhost.anim.play(AnimName, Force, Reversed, Frame);
			animateGhost.update(0);
			
			var daOffset = animOffsets.get(AnimName);
			if (daOffset != null)
				animateGhost.offset.set(daOffset[0], daOffset[1]);
			else
				animateGhost.offset.set(0, 0);
		}
		else
		#end
		{
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
			ghost.angle = angle;
			ghost.shader = shader;
			ghost.dirty = dirty;
			ghost.color = FlxColor.fromRGB(
				Std.int((healthColorArray[0]/255) * color.red),
				Std.int((healthColorArray[1]/255) * color.green),
				Std.int((healthColorArray[2]/255) * color.blue)
			);
			ghost.animation.play(AnimName, Force, Reversed, Frame);
			
			var daOffset = animOffsets.get(AnimName);
			if (daOffset != null)
				ghost.offset.set(daOffset[0], daOffset[1]);
			else
				ghost.offset.set(0, 0);
		}

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
			game.stages.objects.TankmenBG.animationNotes = animationNotes;
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

	public function isAnimationLooped():Bool
	{
		if (isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.looped : atlas.anim.curAnim.looped;
	}

	public function getTotalFrames():Int
	{
		if (isAnimationNull()) return 0;
		return !isAnimateAtlas ? animation.curAnim.numFrames : atlas.anim.curAnim.numFrames;
	}

	public function setCurrentFrameRate(fps:Float):Void
	{
		if (isAnimationNull()) return;
		
		if (!isAnimateAtlas) {
			animation.curAnim.frameRate = fps;
		} else {
			atlas.anim.curAnim.frameRate = fps;
		}
	}

	public function getCurrentFrameRate():Float
	{
		if (isAnimationNull()) return 0;
		return !isAnimateAtlas ? animation.curAnim.frameRate : atlas.anim.curAnim.frameRate;
	}

	public function setCurrentFrame(frame:Int):Void
	{
		if (isAnimationNull()) return;
		
		if (!isAnimateAtlas) {
			animation.curAnim.curFrame = frame;
		} else {
			atlas.anim.curAnim.curFrame = frame;
			atlas.update(0);
		}
	}

	public function getCurrentFrame():Int
	{
		if (isAnimationNull()) return 0;
		return !isAnimateAtlas ? animation.curAnim.curFrame : atlas.anim.curAnim.curFrame;
	}

	public function isPlaying(animName:String):Bool
	{
		if (isAnimationNull()) return false;
		return !isAnimateAtlas ? 
			(animation.curAnim != null && animation.curAnim.name == animName) : 
			(atlas.anim.curAnim != null && atlas.anim.curAnim.name == animName);
	}

	inline public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.finish();
	}

	public function stopAnimation():Void
	{
		if (!isAnimateAtlas) {
			animation.stop();
		} else {
			atlas.anim.stop();
		}
		_lastPlayedAnimation = '';
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
			danceEveryNumBeats = Math.round(Math.max(danceIdle ? danceEveryNumBeats * .5 : danceEveryNumBeats * 2, 1));
		}
		settingCharacterUp = false;
	}

	public var isAnimateAtlas:Bool = false;
	#if flixel_animate
	public var atlas:FlxAnimate;
	#end

	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;

		for (ghost in animGhosts)
		{
			if (ghost.visible)
				ghost.draw();
		}

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
		}
		else
		#end
		{
			super.draw();
		}
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
	#end

	public override function destroy()
	{
		for (ghost in animGhosts)
		{
			ghost?.destroy();
		}
		animGhosts = [];
		
		for (tween in ghostTweens)
		{
			tween?.cancel();
		}
		ghostTweens = [];

		#if flixel_animate
		destroyAtlas();
		#end
		super.destroy();
	}

	#if flixel_animate
	inline public function destroyAtlas()
	{
		if (atlas != null)
			atlas = FlxDestroyUtil.destroy(atlas);
	}
	#end
}