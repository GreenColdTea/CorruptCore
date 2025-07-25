package game.stages;

import game.stages.objects.*;

class Mall extends BaseStage
{
	var upperBoppers:BGSprite;
	var bottomBoppers:MallCrowd;
	var santa:BGSprite;

	override function create()
	{
		var bg:BGSprite = new BGSprite('bgs/christmas/bgWalls', -1000, -500, 0.2, 0.2);
		bg.setGraphicSize(Std.int(bg.width * 0.8));
		bg.updateHitbox();
		add(bg);

		if(!ClientPrefs.lowQuality) {
			upperBoppers = new BGSprite('bgs/christmas/upperBop', -240, -90, 0.33, 0.33, ['Upper Crowd Bob']);
			upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
			upperBoppers.updateHitbox();
			add(upperBoppers);

			var bgEscalator:BGSprite = new BGSprite('bgs/christmas/bgEscalator', -1100, -600, 0.3, 0.3);
			bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
			bgEscalator.updateHitbox();
			add(bgEscalator);
		}

		var tree:BGSprite = new BGSprite('bgs/christmas/christmasTree', 370, -250, 0.40, 0.40);
		add(tree);

		bottomBoppers = new MallCrowd(-300, 140);
		add(bottomBoppers);

		var fgSnow:BGSprite = new BGSprite('bgs/christmas/fgSnow', -600, 700);
		add(fgSnow);

		santa = new BGSprite('bgs/christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
		add(santa);
		Paths.sound('Lights_Shut_off');
		setDefaultGF('gf-christmas');

		if(isStoryMode && !seenCutscene)
			setEndCallback(eggnogEndCutscene);
	}

	override function countdownTick(swagCounter:Int) everyoneDance();
	override function beatHit() everyoneDance();

	override function eventCalled(eventName:String, value1:String, value2:String)
	{
		switch(eventName)
		{
			case "Hey!":
				var time:Float = Std.parseFloat(value2);
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						return;
				}
				bottomBoppers.animation.play('hey', true);
				bottomBoppers.heyTimer = time;
		}
	}

	function everyoneDance()
	{
		if(!ClientPrefs.lowQuality)
			upperBoppers.dance(true);

		bottomBoppers.dance(true);
		santa.dance(true);
	}

	function eggnogEndCutscene()
	{
		if(PlayState.storyPlaylist[1] == null)
		{
			endSong();
			return;
		}

		var nextSong:String = Paths.formatToSongPath(PlayState.storyPlaylist[1]);
		if(nextSong == 'winter-horrorland')
		{
			FlxG.sound.play(Paths.sound('Lights_Shut_off'));

			var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
				-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			blackShit.scrollFactor.set();
			add(blackShit);
			camHUD.visible = false;

			inCutscene = true;
			canPause = false;

			new FlxTimer().start(1.5, function(tmr:FlxTimer) {
				endSong();
			});
		}
		else endSong();
	}
}