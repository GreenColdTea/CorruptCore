package game.objects;
import flixel.*;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import flixel.util.FlxDestroyUtil;

/**
 * ...
 * @author ShadowMario
 * @modified by GreenColdTea
 */
class Prompt extends MusicBeatSubstate
{
	var selected = 0;
	public var okc:Void->Void;
	public var cancelc:Void->Void;
	var buttons:FlxSprite = new FlxSprite(473.3, 450);
	var theText:String = '';
	var goAnyway:Bool = false;
	var panel:FlxSprite;
	var panelbg:FlxSprite;
	var buttonAccept:PsychUIButton;
	var buttonNo:PsychUIButton;
	var cornerSize:Int = 10;
	private var _option1:String;
    private var _option2:String;
	
	public var bg:FlxSprite;
	public var titleText:FlxText;
	public var onCreate:Prompt->Void;
	public var onUpdate:Prompt->Float->Void;

	private var _sizeX:Float = 0;
	private var _sizeY:Float = 0;
	private var _blockInput:Float = 0.1;
	private var _newStyle:Bool = true;

	public function new(promptText:String='', defaultSelected:Int = 0, okCallback:Void->Void, cancelCallback:Void->Void, acceptOnDefault:Bool=false, option1:String=null, option2:String=null, ?newStyle:Bool = true, ?sizeX:Float = 420, ?sizeY:Float = 160) 
	{
		selected = defaultSelected;
		okc = okCallback;
		cancelc = cancelCallback;
		theText = promptText;
		goAnyway = acceptOnDefault;
		_newStyle = newStyle;
		_sizeX = sizeX;
		_sizeY = sizeY;
			
		_option1 = option1;
		_option2 = option2;
			
		var op1 = 'OK';
		var op2 = 'CANCEL';
			
		if (option1 != null) op1 = option1;
		if (option2 != null) op2 = option2;
		buttonAccept = new PsychUIButton(473.3, 450, op1, () -> {
			if(okc != null) okc();
			close();
		});
		buttonNo = new PsychUIButton(633.3,450, op2, () -> {
			if(cancelc != null) cancelc();
			close();
		});

		super();  
	}
	
	// New constructor for simplified usage
	public static function simple(promptText:String, yesCallback:Void->Void, ?noCallback:Void->Void, ?yesText:String = "OK", ?noText:String = "Cancel"):Prompt
	{
		return new Prompt(promptText, 0, yesCallback, noCallback, false, yesText, noText, true);
	}
	
	override public function create():Void 
	{
		if (goAnyway)
		{
			if(okc != null) okc();
			close();
		} else {
			if (_newStyle) {
				// Psych new style implementation
				cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
				bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
				bg.alpha = 0.8;
				bg.scale.set(_sizeX, _sizeY);
				bg.updateHitbox();
				bg.screenCenter();
				bg.scrollFactor.set();
				bg.cameras = cameras;
				add(bg);
				
				titleText = new FlxText(0, bg.y + 30, 400, theText, 16);
				titleText.screenCenter(X);
				titleText.alignment = CENTER;
				titleText.scrollFactor.set();
				titleText.cameras = cameras;
				add(titleText);
				
				var btnY = 390;
				buttonAccept = new PsychUIButton(0, btnY, _option1 != null ? _option1 : "OK", function() {
					if(okc != null) okc();
					close();
				});
				buttonAccept.screenCenter(X);
				buttonAccept.scrollFactor.set();
				buttonAccept.cameras = cameras;
				add(buttonAccept);

				if (_option2 != null) {
					buttonAccept.x -= 100;
					
					buttonNo = new PsychUIButton(0, btnY, _option2, function() {
						if(cancelc != null) cancelc();
						close();
					});
					buttonNo.screenCenter(X);
					buttonNo.scrollFactor.set();
					buttonNo.x += 100;
					buttonNo.cameras = cameras;
					add(buttonNo);
				}
			} else {
				// Old style implementation
				panel = new FlxSprite(0, 0);
				panelbg = new FlxSprite(0, 0);
				makeSelectorGraphic(panel, 300, 150, 0xff999999);
				makeSelectorGraphic(panelbg, 302, 165, 0xff000000);
				panel.scrollFactor.set();
				panel.screenCenter();
				panelbg.scrollFactor.set();
				panelbg.screenCenter();
					
				add(panelbg);
				add(panel);
				add(buttonAccept);
				if (_option2 != null) add(buttonNo);
					
				var textField:FlxText = new FlxText(0, panel.y, 300, theText, 16);
				textField.alignment = 'center';
				textField.screenCenter();
				textField.y -= 10;
				add(textField);
					
				if (_option2 == null) {
					buttonAccept.x = panel.x + panel.width / 2 - buttonAccept.width / 2;
				} else {
					buttonAccept.screenCenter();
					buttonAccept.x -= buttonNo.width / 1.5;
					buttonNo.screenCenter();
					buttonNo.x += buttonNo.width / 1.5;
					buttonNo.y = panel.y + panel.height - 30;
				}
				buttonAccept.y = panel.y + panel.height - 30;
				textField.scrollFactor.set();
			}
			
			if (onCreate != null) onCreate(this);
		}
		super.create();
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		_blockInput = Math.max(0, _blockInput - elapsed);
		if(_blockInput <= 0 && FlxG.keys.justPressed.ESCAPE)
		{
			close();
			return;
		}

		if(onUpdate != null)
			onUpdate(this, elapsed);
	}
	
	override function destroy()
	{
		for (member in members) FlxDestroyUtil.destroy(member);
		super.destroy();
	}
	
	function makeSelectorGraphic(panel:FlxSprite,w,h,color:FlxColor)
	{
		panel.makeGraphic(w, h, color);
		panel.pixels.fillRect(new Rectangle(0, 190, panel.width, 5), 0x0);
		
		// Why did i do this? Because i'm a lmao stupid, of course
		// also i wanted to understand better how fillRect works so i did this shit lol???
		panel.pixels.fillRect(new Rectangle(0, 0, cornerSize, cornerSize), 0x0);														 //top left
		drawCircleCornerOnSelector(panel,false, false,color);
		panel.pixels.fillRect(new Rectangle(panel.width - cornerSize, 0, cornerSize, cornerSize), 0x0);							 //top right
		drawCircleCornerOnSelector(panel,true, false,color);
		panel.pixels.fillRect(new Rectangle(0, panel.height - cornerSize, cornerSize, cornerSize), 0x0);							 //bottom left
		drawCircleCornerOnSelector(panel,false, true,color);
		panel.pixels.fillRect(new Rectangle(panel.width - cornerSize, panel.height - cornerSize, cornerSize, cornerSize), 0x0); //bottom right
		drawCircleCornerOnSelector(panel,true, true,color);
	}

	function drawCircleCornerOnSelector(panel:FlxSprite,flipX:Bool, flipY:Bool,color:FlxColor)
	{
		var antiX:Float = (panel.width - cornerSize);
		var antiY:Float = flipY ? (panel.height - 1) : 0;
		if(flipY) antiY -= 2;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 1), Std.int(Math.abs(antiY - 8)), 10, 3), color);
		if(flipY) antiY += 1;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 2), Std.int(Math.abs(antiY - 6)),  9, 2), color);
		if(flipY) antiY += 1;
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 3), Std.int(Math.abs(antiY - 5)),  8, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 4), Std.int(Math.abs(antiY - 4)),  7, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 5), Std.int(Math.abs(antiY - 3)),  6, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 6), Std.int(Math.abs(antiY - 2)),  5, 1), color);
		panel.pixels.fillRect(new Rectangle((flipX ? antiX : 8), Std.int(Math.abs(antiY - 1)),  3, 1), color);
	}
}

// Exit confirmation prompt used on all editors, for convenience
// Ass thing tbh lol
class ExitConfirmationPrompt extends Prompt
{
	public function new(?finishCallback:Void->Void)
	{
		var exitCallback = function()
		{
			FlxG.mouse.visible = false;
			FlxG.switchState(() -> new game.states.editors.MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			if(finishCallback != null) finishCallback();
		};
		
		super('There\'s unsaved progress,\nare you sure you want to exit?', 0, exitCallback, null, false, "Exit", null, true);
	}
}