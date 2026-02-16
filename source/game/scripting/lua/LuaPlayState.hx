package game.scripting.lua;

import game.objects.DialogueBoxPsych;
import game.objects.DialogueBoxPsych.DialogueFile;

class LuaPlayState
{
    public static function init(script:FunkinLua)
    {
        var lua:cpp.RawPointer<Lua_State> = script.lua;
        
        LuaUtils.addFunction(lua, "addScore", function(value:Int = 0) {
			PlayState.instance.songScore += value;
			PlayState.instance.RecalculateRating();
		});
		LuaUtils.addFunction(lua, "addMisses", function(value:Int = 0) {
			PlayState.instance.songMisses += value;
			PlayState.instance.RecalculateRating();
		});
		LuaUtils.addFunction(lua, "addHits", function(value:Int = 0) {
			PlayState.instance.songHits += value;
			PlayState.instance.RecalculateRating();
		});
		LuaUtils.addFunction(lua, "setScore", function(value:Int = 0) {
			PlayState.instance.songScore = value;
			PlayState.instance.RecalculateRating();
		});
		LuaUtils.addFunction(lua, "setMisses", function(value:Int = 0) {
			PlayState.instance.songMisses = value;
			PlayState.instance.RecalculateRating();
		});
		LuaUtils.addFunction(lua, "setHits", function(value:Int = 0) {
			PlayState.instance.songHits = value;
			PlayState.instance.RecalculateRating();
		});
		LuaUtils.addFunction(lua, "getScore", function() {
			return PlayState.instance.songScore;
		});
		LuaUtils.addFunction(lua, "getMisses", function() {
			return PlayState.instance.songMisses;
		});
		LuaUtils.addFunction(lua, "getHits", function() {
			return PlayState.instance.songHits;
		});

		LuaUtils.addFunction(lua, "setHealth", function(value:Float = 0) {
			PlayState.instance.health = value;
		});
		LuaUtils.addFunction(lua, "addHealth", function(value:Float = 0) {
			PlayState.instance.health += value;
		});
		LuaUtils.addFunction(lua, "getHealth", function() {
			return PlayState.instance.health;
		});

        LuaUtils.addFunction(lua, "addCharacterToList", function(name:String, type:String) {
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			PlayState.instance.addCharacterToList(name, charType);
		});
		LuaUtils.addFunction(lua, "precacheImage", function(name:String, ?allowGPU:Bool = true) {
			Paths.image(name, allowGPU);
		});
		LuaUtils.addFunction(lua, "precacheSound", function(name:String) {
			CoolUtil.precacheSound(name);
		});
		LuaUtils.addFunction(lua, "precacheMusic", function(name:String) {
			CoolUtil.precacheMusic(name);
		});
		LuaUtils.addFunction(lua, "triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic) {
			var value1:String = arg1;
			var value2:String = arg2;
			PlayState.instance.triggerEventNote(name, value1, value2);
			//trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
			return true;
		});

		LuaUtils.addFunction(lua, "startCountdown", function() {
			PlayState.instance.startCountdown();
			return true;
		});
		LuaUtils.addFunction(lua, "endSong", function() {
			PlayState.instance.KillNotes();
			PlayState.instance.endSong();
			return true;
		});
		LuaUtils.addFunction(lua, "restartSong", function(?skipTransition:Bool = false) {
			PlayState.instance.persistentUpdate = false;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		LuaUtils.addFunction(lua, "exitSong", function(?skipTransition:Bool = false) {
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.cancelMusicFadeTween();

			if(PlayState.isStoryMode)
				FlxG.switchState(() -> new StoryMenuState());
			else
				FlxG.switchState(() -> new FreeplayState());

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			PlayState.instance.transitioning = true;
			WeekData.loadTheFirstEnabledMod();
			return true;
		});
		LuaUtils.addFunction(lua, "getSongPosition", function() {
			return Conductor.songPosition;
		});

		LuaUtils.addFunction(lua, "getCharacterX", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});
		LuaUtils.addFunction(lua, "setCharacterX", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});
		LuaUtils.addFunction(lua, "getCharacterY", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});
		LuaUtils.addFunction(lua, "setCharacterY", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});
		LuaUtils.addFunction(lua, "cameraSetTarget", function(target:String) {
			var isDad:Bool = false;
			if(target == 'dad') {
				isDad = true;
			}
			PlayState.instance.moveCamera(isDad);
			return isDad;
		});
		LuaUtils.addFunction(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float) {
			FunkinLua.cameraFromString(camera).shake(intensity, duration);
		});
		LuaUtils.addFunction(lua, "cameraFlash", function(camera:String, color:String, duration:Float,forced:Bool) {
			if (!ClientPrefs.flashing) return;

			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			FunkinLua.cameraFromString(camera).flash(colorNum, duration,null,forced);
		});
		LuaUtils.addFunction(lua, "cameraFade", function(camera:String, color:String, duration:Float,forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			FunkinLua.cameraFromString(camera).fade(colorNum, duration,false,null,forced);
		});
		LuaUtils.addFunction(lua, "setRatingPercent", function(value:Float) {
			PlayState.instance.ratingPercent = value;
		});
		LuaUtils.addFunction(lua, "setRatingName", function(value:String) {
			PlayState.instance.ratingName = value;
		});
		LuaUtils.addFunction(lua, "setRatingFC", function(value:String) {
			PlayState.instance.ratingFC = value;
		});
		LuaUtils.addFunction(lua, "getMouseX", function(camera:String) {
			var cam:FlxCamera = FunkinLua.cameraFromString(camera);
			return FlxG.mouse.getViewPosition(cam).x;
		});
		LuaUtils.addFunction(lua, "getMouseY", function(camera:String) {
			var cam:FlxCamera = FunkinLua.cameraFromString(camera);
			return FlxG.mouse.getViewPosition(cam).y;
		});

		LuaUtils.addFunction(lua, "getMidpointX", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getMidpoint().x;

			return 0;
		});
		LuaUtils.addFunction(lua, "getMidpointY", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getMidpoint().y;

			return 0;
		});
		LuaUtils.addFunction(lua, "getGraphicMidpointX", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		LuaUtils.addFunction(lua, "getGraphicMidpointY", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		LuaUtils.addFunction(lua, "getScreenPositionX", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getScreenPosition().x;

			return 0;
		});
		LuaUtils.addFunction(lua, "getScreenPositionY", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			var obj:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				obj = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}
			if(obj != null) return obj.getScreenPosition().y;

			return 0;
		});
		LuaUtils.addFunction(lua, "characterDance", function(character:String) {
			switch(character.toLowerCase()) {
				case 'dad': PlayState.instance?.dad?.dance();
				case 'gf' | 'girlfriend': PlayState.instance?.gf?.dance();
				default: PlayState.instance.boyfriend.dance();
			}
		});

        LuaUtils.addFunction(lua, "loadSong", function(?name:String = null, ?difficultyNum:Int = -1) {
			if(name == null || name.length < 1)
				name = PlayState.SONG.song;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var poop = Highscore.formatSong(name, difficultyNum);
			PlayState.SONG = Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;
			PlayState.instance.persistentUpdate = false;
			LoadingState.loadAndSwitchState(() -> new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			if(PlayState.instance.vocals != null)
			{
				PlayState.instance.vocals.pause();
				PlayState.instance.vocals.volume = 0;
			}
		});

		LuaUtils.addFunction(lua, "startDialogue", function(dialogueFile:String, music:String = null) {
			var path:String = Paths.json("songs/" + Paths.formatToSongPath(PlayState.SONG.song) + '/' + dialogueFile);
			FunkinLua.luaTrace('startDialogue: Trying to load dialogue: ' + path);

			if(#if sys FileSystem.exists(path) || #end openfl.utils.Assets.exists(path))
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0) {
					PlayState.instance.startDialogue(shit, music);
					FunkinLua.luaTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				} else {
					FunkinLua.luaTrace('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
				}
			} else {
				FunkinLua.luaTrace('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
				if(PlayState.instance.endingSong) {
					PlayState.instance.endSong();
				} else {
					PlayState.instance.startCountdown();
				}
			}
			return false;
		});
		LuaUtils.addFunction(lua, "playVideo", function(videoFile:String, ?isNotMidPartSong:Bool = false) {
			#if VIDEOS_ALLOWED
			if(FileSystem.exists(Paths.video(videoFile))) {
				PlayState.instance.playVideo(videoFile, isNotMidPartSong);
				return true;
			} else {
				FunkinLua.luaTrace('playVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
			}
			return false;

			#else
			return true;
			#end
		});
    }
}