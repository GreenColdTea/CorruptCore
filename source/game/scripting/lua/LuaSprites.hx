package game.scripting.lua;

#if flixel_animate
import animate.internal.Timeline;
import animate.FlxAnimateJson.TimelineJson;
#end

import flixel.graphics.FlxGraphic;

import game.objects.Character;

class LuaSprites
{
    public static function init(script:FunkinLua)
    {
        var lua:cpp.RawPointer<Lua_State> = script.lua;
        
        LuaUtils.addFunction(lua, "makeLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);

			final leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image?.length > 0)
			{
				leSprite.loadGraphic(Paths.image(image));
			}
			PlayState.instance.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
		});

		LuaUtils.addFunction(lua, "makeLuaBackdrop", function(tag:String, image:String, x:Float, y:Float, repeatX:Bool = false, repeatY:Bool = false) {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
		
			final backdrop = new ModchartBackdrop(Paths.image(image), 1, 1, repeatX, repeatY);
			backdrop.setPosition(x, y);
		
			PlayState.instance.modchartBackdrops.set(tag, backdrop);
			backdrop.active = true;
		});	

		LuaUtils.addFunction(lua, "makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float, ?spriteType:String = "sparrow") {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);

			final leSprite:ModchartSprite = new ModchartSprite(x, y);
			loadFrames(leSprite, image, spriteType);
			PlayState.instance.modchartSprites.set(tag, leSprite);
		});

		LuaUtils.addFunction(lua, "makeGraphic", function(obj:String, width:Int, height:Int, color:String) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

			var spr:FlxSprite = PlayState.instance.getLuaObject(obj,false);
			if(spr!=null) {
				PlayState.instance.getLuaObject(obj,false).makeGraphic(width, height, colorNum);
				return;
			}

			var object:FlxSprite = Reflect.getProperty(FunkinLua.getInstance(), obj);
			if(object != null) {
				object.makeGraphic(width, height, colorNum);
			}
		});
		LuaUtils.addFunction(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(FunkinLua.getInstance(), obj);
			if(cock != null) {
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		LuaUtils.addFunction(lua, "addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			if(PlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(FunkinLua.getInstance(), obj);
			if(cock != null) {
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		LuaUtils.addFunction(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			return addAnimByIndices(obj, name, prefix, indices, framerate, false);
		});
		LuaUtils.addFunction(lua, "addAnimationByIndicesLoop", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			return addAnimByIndices(obj, name, prefix, indices, framerate, true);
		});
		

		LuaUtils.addFunction(lua, "playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			var obj:Dynamic = FunkinLua.getObjectDirectly(obj, false);
			if(obj.playAnim != null)
			{
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			}
			else
			{
				if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame); //FlxAnimate
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		LuaUtils.addFunction(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			if(PlayState.instance.modchartSprites.exists(obj)) {
				PlayState.instance.modchartSprites.get(obj).animOffsets.set(anim, [x, y]);
				return true;
			}

			var char:Character = Reflect.getProperty(FunkinLua.getInstance(), obj);
			if(char != null) {
				char.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		//FlxAnimate Funcs
		#if flixel_animate
		LuaUtils.addFunction(lua, "makeFlxAnimateSprite", function(tag:String, atlasFolder:String, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			var lastSprite = PlayState.instance.variables.get(tag);
			if(lastSprite != null)
			{
				lastSprite.kill();
				PlayState.instance.remove(lastSprite);
				lastSprite.destroy();
			}

			var mySprite:ModchartAnimateSprite = new ModchartAnimateSprite(x, y);
			mySprite.frames = Paths.getAnimateAtlas(atlasFolder);
			PlayState.instance.variables.set(tag, mySprite);
			mySprite.active = true;
		});
		
		LuaUtils.addFunction(lua, "addAnimationBySymbol", function(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false, ?flipX:Bool = false, ?flipY:Bool = false)
		{
			var obj:Dynamic = PlayState.instance.variables.get(tag);
			if(cast (obj, FlxAnimate) == null) return false;

			obj.anim.addBySymbol(name, symbol, framerate, loop, flipX, flipY);
			if(obj.anim.lastPlayedAnim == null)
			{
				if(obj.playAnim != null) obj.playAnim(name, true); //is ModchartAnimateSprite
				else obj.animation.play(name, true);
			}
			return true;
		});

		LuaUtils.addFunction(lua, "addAnimationBySymbolIndices", function(tag:String, name:String, symbol:String, ?indices:Any = null, ?framerate:Float = 24, ?loop:Bool = false, ?flipX:Bool = false, ?flipY:Bool = false)
		{
			var obj:Dynamic = PlayState.instance.variables.get(tag);
			if(cast (obj, FlxAnimate) == null) return false;

			if(indices == null)
				indices = [0];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
				indices = myIndices;
			}

			obj.anim.addBySymbolIndices(name, symbol, indices, framerate, loop, flipX, flipY);
			if(obj.anim.lastPlayedAnim == null)
			{
				if(obj.playAnim != null) obj.playAnim(name, true); //is ModchartAnimateSprite
				else obj.animation.play(name, true);
			}
			return true;
		});

		LuaUtils.addFunction(lua, "addAnimationByFrameLabel", function(tag:String, name:String, label:String, ?framerate:Float = 24, ?loop:Bool = false, ?flipX:Bool = false, ?flipY:Bool = false)
		{
			var obj:Dynamic = PlayState.instance.variables.get(tag);
			if(cast (obj, FlxAnimate) == null) return false;

			obj.anim.addByFrameLabel(name, label, framerate, loop, flipX, flipY);
			if(obj.anim.lastPlayedAnim == null)
			{
				if(obj.playAnim != null) obj.playAnim(name, true); //is ModchartAnimateSprite
				else obj.animation.play(name, true);
			}
			return true;
		});

		LuaUtils.addFunction(lua, "addAnimationByFrameLabelIndices", function(tag:String, name:String, label:String, ?indices:Any = null, ?framerate:Float = 24, ?loop:Bool = false, ?flipX:Bool = false, ?flipY:Bool = false)
		{
			var obj:Dynamic = PlayState.instance.variables.get(tag);
			if(cast (obj, FlxAnimate) == null) return false;

			if(indices == null)
				indices = [0];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
				indices = myIndices;
			}

			obj.anim.addByFrameLabelIndices(name, label, indices, framerate, loop, flipX, flipY);
			if(obj.anim.lastPlayedAnim == null)
			{
				if(obj.playAnim != null) obj.playAnim(name, true); //is ModchartAnimateSprite
				else obj.animation.play(name, true);
			}
			return true;
		});

		LuaUtils.addFunction(lua, "addByTimeline", function(tag:String, name:String, timelinePath:String, ?framerate:Float = 24, ?loop:Bool = true, ?flipX:Bool = false, ?flipY:Bool = false) {
			var obj:Dynamic = PlayState.instance.variables.get(tag);
			if(cast (obj, FlxAnimate) == null) return false;

			var timeline:Timeline = loadTimelineFromJson(timelinePath);
			if(timeline == null) {
				FunkinLua.luaTrace('addByTimeline: Timeline not found: $timelinePath', false, false, FlxColor.RED);
				return false;
			}

			obj.anim.addByTimeline(name, timeline, framerate, loop, flipX, flipY);
			return true;
		});

		LuaUtils.addFunction(lua, "addByTimelineIndices", function(tag:String, name:String, timelinePath:String, indices:Any = null, ?framerate:Float = 24, ?loop:Bool = true, ?flipX:Bool = false, ?flipY:Bool = false) {
			var obj:Dynamic = PlayState.instance.variables.get(tag);
			if(cast (obj, FlxAnimate) == null) return false;

			var timeline:Timeline = loadTimelineFromJson(timelinePath);
			if(timeline == null) {
				FunkinLua.luaTrace('addByTimelineIndices: Timeline not found: $timelinePath', false, false, FlxColor.RED);
				return false;
			}

			var idxArray:Array<Int> = [];
			if(Std.isOfType(indices, String)) {
				var strIndices = cast(indices, String).split(',');
				for(i in strIndices) idxArray.push(Std.parseInt(i.trim()));
			} else if(Std.isOfType(indices, Array)) {
				idxArray = cast indices;
			}

			obj.anim.addByTimelineIndices(name, timeline, idxArray, framerate, loop, flipX, flipY);
			return true;
		});
		#end

		LuaUtils.addFunction(lua, "addLuaSprite", function(tag:String, front:Bool = false) {
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				if(!shit.wasAdded) {
					if(front)
					{
						FunkinLua.getInstance().add(shit);
					}
					else
					{
						if(PlayState.instance.isDead)
						{
							GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), shit);
						}
						else
						{
							var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
							if(PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position) {
								position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
							} else if(PlayState.instance.members.indexOf(PlayState.instance.dadGroup) < position) {
								position = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
							}
							PlayState.instance.insert(position, shit);
						}
					}
					shit.wasAdded = true;
					//trace('added a thing: ' + tag);
				}
			}
		});

		LuaUtils.addFunction(lua, "addLuaBackdrop", function(tag:String, front:Bool = false) {
			if (!PlayState.instance.modchartBackdrops.exists(tag)) return;
		
			final backdrop = PlayState.instance.modchartBackdrops.get(tag);
			if (backdrop == null) return;
		
			if (!Reflect.hasField(backdrop, "wasAdded")) {
				Reflect.setProperty(backdrop, "wasAdded", false);
			}
		
			if (!Reflect.field(backdrop, "wasAdded")) {
				if (front) {
					FunkinLua.getInstance().add(backdrop);
				} else {
					if (PlayState.instance.isDead) {
						GameOverSubstate.instance.insert(
							GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend),
							backdrop
						);
					} else {
						var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gfGroup);
						if (PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup) < position)
							position = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
						if (PlayState.instance.members.indexOf(PlayState.instance.dadGroup) < position)
							position = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
						PlayState.instance.insert(position, backdrop);
					}
				}
				Reflect.setProperty(backdrop, "wasAdded", true);
			}
		});

		LuaUtils.addFunction(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true) {
			if(!PlayState.instance.modchartSprites.exists(tag)) {
				return;
			}

			var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
			if(destroy) {
				pee.kill();
			}

			if(pee.wasAdded) {
				FunkinLua.getInstance().remove(pee, true);
				pee.wasAdded = false;
			}

			if(destroy) {
				pee.destroy();
				PlayState.instance.modchartSprites.remove(tag);
			}
		});

		LuaUtils.addFunction(lua, "luaSpriteExists", function(tag:String) {
			return PlayState.instance.modchartSprites.exists(tag);
		});

        LuaUtils.addFunction(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var killMe:Array<String> = variable.split('.');
			var spr:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			var animated = gridX != 0 || gridY != 0;

			if(killMe.length > 1) {
				spr = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
			}
		});
		LuaUtils.addFunction(lua, "loadFrames", function(variable:String, image:String, spriteType:String = "sparrow") {
			var killMe:Array<String> = variable.split('.');
			var spr:FlxSprite = FunkinLua.getObjectDirectly(killMe[0]);
			if(killMe.length > 1) {
				spr = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				loadFrames(spr, image, spriteType);
			}
		});
    }

    static function resetSpriteTag(tag:String) {
		if(!PlayState.instance.modchartSprites.exists(tag)) {
			return;
		}

		var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			PlayState.instance.remove(pee, true);
		}
		pee.destroy();
		PlayState.instance.modchartSprites.remove(tag);
	}

    static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().trim())
		{
			/*case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);

			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);*/

			case 'aseprite', 'ase', 'json', 'jsoni8':
				spr.frames = Paths.getAsepriteAtlas(image);

			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);

			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false)
	{
		var strIndices:Array<String> = indices.trim().split(',');
		var die:Array<Int> = [];
		for (i in 0...strIndices.length) {
			die.push(Std.parseInt(strIndices[i]));
		}

		if(PlayState.instance.getLuaObject(obj, false)!=null) {
			var pussy:FlxSprite = PlayState.instance.getLuaObject(obj, false);
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) {
				pussy.animation.play(name, true);
			}
			return true;
		}

		var pussy:FlxSprite = Reflect.getProperty(FunkinLua.getInstance(), obj);
		if(pussy != null) {
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) {
				pussy.animation.play(name, true);
			}
			return true;
		}
		return false;
	}

	#if flixel_animate
	static function loadTimelineFromJson(path:String):Timeline {
		var rawJson:String = Paths.getTextFromFile(path);
		if(rawJson != null && rawJson.length > 0) {
			try {
				var json:TimelineJson = haxe.Json.parse(rawJson);
				// This ass pissed me off tbh
				var dummyGraphic = FlxGraphic.fromRectangle(1, 1, FlxColor.TRANSPARENT);
				var dummyParent = new FlxAnimateFrames(dummyGraphic);
				return new Timeline(json, dummyParent, path);
			} catch(e:Dynamic) {
				trace('Error parsing timeline JSON: $e');
			}
		}
		return null;
	}
	#end
}