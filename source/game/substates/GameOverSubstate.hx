package game.substates;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

import game.objects.Character;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;

	var camFollow:FlxObject;

	var stagesuffix:String = "";

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var instance:GameOverSubstate;

	public static function resetVariables() {
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
	}

	public function new(?playStateBoyfriend:Character = null)
	{
		if(playStateBoyfriend?.curCharacter == characterName) //Avoids spawning a second boyfriend cuz animate atlas is laggy
			this.boyfriend = playStateBoyfriend;

		super();
	}

	override function create()
	{
		parentState.persistentUpdate = parentState.persistentDraw = false;

		camera = PlayState.instance.camGame;

		instance = this;
		
		Conductor.songPosition = 0;

		if(boyfriend == null)
		{
			boyfriend = new Character(PlayState.instance.boyfriend.getScreenPosition().x, PlayState.instance.boyfriend.getScreenPosition().y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0] - PlayState.instance.boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - PlayState.instance.boyfriend.positionArray[1];
		}
		boyfriend.skipDance = true;
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		Conductor.changeBPM(100);
		
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0], boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]);
		FlxG.camera.focusOn(new FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2)));
		FlxG.camera.follow(camFollow, LOCKON, 0.025);
		add(camFollow);

		PlayState.instance.setOnScripts('inGameOver', true);
		PlayState.instance.callOnScripts('onGameOverStart', []);

		FlxG.sound.music.loadEmbedded(Paths.music(loopSoundName), true);

		super.create();
	}

	public var startedDeath:Bool = false;
	override function update(elapsed:Float)
	{
		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (!boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished())
		{
			boyfriend.playAnim('deathLoop');
			justPlayedLoop = true;
		}

		if (controls.ACCEPT) {
			endBullshit();
		} else if (controls.BACK) {
			FlxG.sound.music.stop();
			FlxG.sound.music = null;
			
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;
			PlayState.chartingMode = false;

			WeekData.loadTheFirstEnabledMod();
			if (PlayState.isStoryMode)
				FlxG.switchState(() -> new StoryMenuState());
			else
				FlxG.switchState(() -> new FreeplayState());

			PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
		} else if (justPlayedLoop) {
			switch(PlayState.SONG.stage)
			{
				case 'tank':
					coolStartDeath(0.2);
					
					var exclude:Array<Int> = [];
					//if(!ClientPrefs.cursing) exclude = [1, 3, 8, 13, 17, 21];

					FlxG.sound.play(Paths.sound('jeffGameover/jeffGameover-' + FlxG.random.int(1, 25, exclude)), 1, false, null, true, function() {
						if(!isEnding)
							FlxG.sound.music.fadeIn(0.2, 1, 4);
					});

				default:
					coolStartDeath();
			}
		}

		if (FlxG.sound?.music?.playing)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}

		super.update(elapsed);

		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	override function beatHit()
	{
		super.beatHit();

		//FlxG.log.add('beat');
	}

	var isEnding:Bool = false;

	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;

		PlayState.instance.callOnScripts('deathAnimStart', [volume]);
	}

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;

			if(boyfriend.hasAnimation('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			else if(boyfriend.hasAnimation('deathLoop'))
				boyfriend.playAnim('deathLoop', true);
			
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					FlxG.resetState();
				});
			});
			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}