package game.states.editors;

#if DISCORD_ALLOWED
import api.Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSave;

import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

import haxe.Json;
import haxe.ui.containers.Box;
import haxe.ui.containers.HBox;
import haxe.ui.containers.Panel;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.TabView;
import haxe.ui.containers.VBox;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.menus.MenuBar;
import haxe.ui.containers.menus.MenuCheckBox;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.containers.windows.Window;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.core.Component;
import haxe.ui.components.Button;
import haxe.ui.components.CheckBox;
import haxe.ui.components.ColorPicker;
import haxe.ui.components.DropDown;
import haxe.ui.components.HorizontalSlider;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.TextField;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.layouts.AbsoluteLayout;

import game.objects.Character;
import game.objects.HealthIcon;

using StringTools;

typedef HistoryStuff = {
	var animations:Array<AnimArray>;
	var position:Array<Float>;
	var scale:Float;
	var cameraPosition:Array<Float>;
	var healthColor:Array<Int>;
	var curAnim:Int;
	var imageFile:String;
	var healthIcon:String;
	var vocalsFile:Null<String>;
	var noAntialiasing:Bool;
	var isPlayer:Bool;
	var originalFlipX:Bool;
}

@:bitmap("psych-ui/images/cursorCross.png")
class GraphicCursorCross extends openfl.display.BitmapData {}

@:build(haxe.ui.ComponentBuilder.build("assets/embed/ui/charEditorToolBar.xml"))
class ToolBar extends MenuBar {}

class EditorUI extends Component
{
	public var mainToolbar:ToolBar;

	public var propWindow:Window;
	public var editorWindow:Window;
	public var animWindow:Window;

	public var mainTabView:TabView;
	public var rightTabView:TabView;

	public var ghostOpacitySlider:HorizontalSlider;
	public var highlightGhostCheck:CheckBox;
	public var makeGhostButton:Button;

	public var charDropDown:DropDown;
	public var playableCheck:CheckBox;
	public var templateCharButton:Button;

	public var imageInput:TextField;
	public var healthIconInput:TextField;
	public var vocalsInput:TextField;
	public var singDurationStepper:NumberStepper;
	public var scaleStepper:NumberStepper;
	public var posXStepper:NumberStepper;
	public var posYStepper:NumberStepper;
	public var camXStepper:NumberStepper;
	public var camYStepper:NumberStepper;
	public var healthColorButton:Button;

	public var animDropDown:DropDown;
	public var animNameInput:TextField;
	public var animPrefixInput:TextField;
	public var animIndicesInput:TextField;
	public var animFramerateStepper:NumberStepper;
	public var animLoopCheck:CheckBox;
	public var addUpdateAnimButton:Button;
	public var removeAnimButton:Button;

	public var animListContainer:VBox;
	public var animOffsetLabel:Label;

	public function new()
	{
		super();
		percentWidth = 100;
		percentHeight = 100;
		layout = new AbsoluteLayout();
		build();
	}

	function build()
	{
		mainToolbar = new ToolBar();
		mainToolbar.width = FlxG.width - 20;
		mainToolbar.height = 40;
		addComponent(mainToolbar);

		propWindow = new Window();
		propWindow.title = "Properties";
		propWindow.width = 250;
		propWindow.height = 225;
		propWindow.left = FlxG.width - propWindow.width - 10;
		propWindow.top = 10;
		propWindow.draggable = true;
		propWindow.minimizable = false;
		propWindow.maximizable = false;
		propWindow.closable = false;

		mainTabView = new TabView();
		mainTabView.percentWidth = 100;
		mainTabView.percentHeight = 100;
		mainTabView.addClass("editor-tabs");
		propWindow.addComponent(mainTabView);

		var ghostTab = new VBox();
		ghostTab.text = "Ghost";
		ghostTab.percentWidth = 100;
		ghostTab.percentHeight = 100;
		ghostTab.styleNames = "padding: 8px;";
		mainTabView.addComponent(ghostTab);

		makeGhostButton = new Button();
		makeGhostButton.text = "Make Ghost";
		makeGhostButton.width = 120;
		ghostTab.addComponent(makeGhostButton);

		highlightGhostCheck = new CheckBox();
		highlightGhostCheck.text = "Highlight Ghost";
		ghostTab.addComponent(highlightGhostCheck);

		var opacityText = new Label();
		opacityText.text = "Opacity:";
		ghostTab.addComponent(opacityText);

		ghostOpacitySlider = new HorizontalSlider();
		ghostOpacitySlider.min = 0;
		ghostOpacitySlider.max = 1;
		ghostOpacitySlider.pos = 0.6;
		ghostTab.addComponent(ghostOpacitySlider);

		var settingsTab = new VBox();
		settingsTab.text = "Settings";
		settingsTab.percentWidth = 100;
		settingsTab.percentHeight = 100;
		settingsTab.styleNames = "padding: 8px;";
		mainTabView.addComponent(settingsTab);

		playableCheck = new CheckBox();
		playableCheck.text = "Playable Character";
		settingsTab.addComponent(playableCheck);

		var charLabel = new Label();
		charLabel.text = "Character:";
		settingsTab.addComponent(charLabel);

		charDropDown = new DropDown();
		charDropDown.width = 200;
		settingsTab.addComponent(charDropDown);

		templateCharButton = new Button();
		templateCharButton.text = "Load Template";
		templateCharButton.addClass("danger-button");
		settingsTab.addComponent(templateCharButton);

		editorWindow = new Window();
		editorWindow.title = "Editor";
		editorWindow.width = 375;
		editorWindow.height = 390;
		editorWindow.left = propWindow.left - 125;
		editorWindow.top = propWindow.top + propWindow.height - 5;
		editorWindow.draggable = true;
		editorWindow.minimizable = false;
		editorWindow.maximizable = false;
		editorWindow.closable = false;

		rightTabView = new TabView();
		rightTabView.percentWidth = 100;
		rightTabView.percentHeight = 100;
		rightTabView.addClass("editor-tabs");
		editorWindow.addComponent(rightTabView);

		var charTab = new VBox();
		charTab.text = "Character";
		charTab.percentWidth = 100;
		charTab.percentHeight = 100;
		charTab.styleNames = "padding: 8px;";
		rightTabView.addComponent(charTab);

		var imgLabel = new Label();
		imgLabel.text = "Image file name:";
		charTab.addComponent(imgLabel);

		imageInput = new TextField();
		imageInput.width = 200;
		charTab.addComponent(imageInput);

		var healthLabel = new Label();
		healthLabel.text = "Health icon name:";
		charTab.addComponent(healthLabel);

		healthIconInput = new TextField();
		healthIconInput.width = 120;
		charTab.addComponent(healthIconInput);

		var vocalsLabel = new Label();
		vocalsLabel.text = "Vocals File Postfix:";
		charTab.addComponent(vocalsLabel);

		vocalsInput = new TextField();
		vocalsInput.width = 120;
		charTab.addComponent(vocalsInput);

		var mainRow = new HBox();
		mainRow.percentWidth = 100;
		mainRow.styleNames = "spacing: 40px;";
		charTab.addComponent(mainRow);

		var leftCol = new VBox();
		leftCol.styleNames = "spacing: 10px;";
		mainRow.addComponent(leftCol);

		var singLabel = new Label();
		singLabel.text = "Sing Animation length:";
		leftCol.addComponent(singLabel);

		singDurationStepper = new NumberStepper();
		singDurationStepper.min = 0;
		singDurationStepper.max = 999;
		singDurationStepper.step = 0.1;
		singDurationStepper.value = 4;
		leftCol.addComponent(singDurationStepper);

		var scaleLabel = new Label();
		scaleLabel.text = "Scale:";
		leftCol.addComponent(scaleLabel);

		scaleStepper = new NumberStepper();
		scaleStepper.min = 0.05;
		scaleStepper.max = 10;
		scaleStepper.step = 0.1;
		scaleStepper.value = 1;
		leftCol.addComponent(scaleStepper);

		var rightCol = new VBox();
		rightCol.styleNames = "spacing: 14px;";
		mainRow.addComponent(rightCol);

		var posBox = new VBox();
		posBox.styleNames = "spacing: 4px;";
		rightCol.addComponent(posBox);

		var posLabel = new Label();
		posLabel.text = "Character X/Y:";
		posBox.addComponent(posLabel);

		var posRow = new HBox();
		posRow.styleNames = "spacing: 16px;";
		posBox.addComponent(posRow);

		var posXBox = new VBox();
		posXBox.styleNames = "spacing: 2px;";
		posRow.addComponent(posXBox);

		posXStepper = new NumberStepper();
		posXStepper.step = 10;
		posXBox.addComponent(posXStepper);

		var posYBox = new VBox();
		posYBox.styleNames = "spacing: 2px;";
		posRow.addComponent(posYBox);

		posYStepper = new NumberStepper();
		posYStepper.step = 10;
		posYBox.addComponent(posYStepper);

		var camBox = new VBox();
		camBox.styleNames = "spacing: 4px;";
		rightCol.addComponent(camBox);

		var camLabel = new Label();
		camLabel.text = "Camera X/Y:";
		camBox.addComponent(camLabel);

		var camRow = new HBox();
		camRow.styleNames = "spacing: 16px;";
		camBox.addComponent(camRow);

		var camXBox = new VBox();
		camXBox.styleNames = "spacing: 2px;";
		camRow.addComponent(camXBox);

		camXStepper = new NumberStepper();
		camXStepper.step = 10;
		camXBox.addComponent(camXStepper);

		var camYBox = new VBox();
		camYBox.styleNames = "spacing: 2px;";
		camRow.addComponent(camYBox);

		camYStepper = new NumberStepper();
		camYStepper.step = 10;
		camYBox.addComponent(camYStepper);

		healthColorButton = new Button();
		healthColorButton.text = "Health Bar Color";
		healthColorButton.styleNames = "primary";
		charTab.addComponent(healthColorButton);

		var animTab = new VBox();
		animTab.text = "Animations";
		animTab.percentWidth = 100;
		animTab.percentHeight = 100;
		animTab.styleNames = "padding: 8px;";
		rightTabView.addComponent(animTab);

		var animLabel = new Label();
		animLabel.text = "Animations:";
		animTab.addComponent(animLabel);

		animDropDown = new DropDown();
		animDropDown.width = 200;
		animTab.addComponent(animDropDown);

		var animNameLabel = new Label();
		animNameLabel.text = "Animation name:";
		animTab.addComponent(animNameLabel);

		animNameInput = new TextField();
		animTab.addComponent(animNameInput);

		var prefixLabel = new Label();
		prefixLabel.text = "Animation on .XML/.TXT file:";
		animTab.addComponent(prefixLabel);

		animPrefixInput = new TextField();
		animTab.addComponent(animPrefixInput);

		var indicesLabel = new Label();
		indicesLabel.text = "ADVANCED - Animation Indices:";
		animTab.addComponent(indicesLabel);

		animIndicesInput = new TextField();
		animTab.addComponent(animIndicesInput);

		var fpsLabel = new Label();
		fpsLabel.text = "Framerate:";
		animTab.addComponent(fpsLabel);

		animFramerateStepper = new NumberStepper();
		animFramerateStepper.min = 0;
		animFramerateStepper.max = 240;
		animFramerateStepper.step = 1;
		animFramerateStepper.value = 24;
		animTab.addComponent(animFramerateStepper);

		animLoopCheck = new CheckBox();
		animLoopCheck.text = "Should it Loop?";
		animTab.addComponent(animLoopCheck);

		var animButtonsRow = new HBox();
		animTab.addComponent(animButtonsRow);

		addUpdateAnimButton = new Button();
		addUpdateAnimButton.text = "Add/Update";
		animButtonsRow.addComponent(addUpdateAnimButton);

		removeAnimButton = new Button();
		removeAnimButton.text = "Remove";
		removeAnimButton.addClass("danger-button");
		animButtonsRow.addComponent(removeAnimButton);

		animWindow = new Window();
		animWindow.title = "Animations List";
		animWindow.width = 260;
		animWindow.height = 300;
		animWindow.left = 20;
		animWindow.top = 40;
		animWindow.draggable = true;
		animWindow.minimizable = false;
		animWindow.maximizable = false;
		animWindow.closable = false;

		var mainContainer = new VBox();
		mainContainer.percentWidth = 100;
		mainContainer.percentHeight = 100;
		mainContainer.styleNames = "padding: 8px;";
		animWindow.addComponent(mainContainer);

		var scrollView = new ScrollView();
		scrollView.width = 236;
		scrollView.height = 220;
		scrollView.left = 8;
		mainContainer.addComponent(scrollView);

		animListContainer = new VBox();
		animListContainer.width = 220;
		scrollView.addComponent(animListContainer);

		animOffsetLabel = new Label();
		animOffsetLabel.percentWidth = 100;
		animOffsetLabel.styleNames = "padding: 4px; background-color: #2a2a2a; border-radius: 4px;";
		animOffsetLabel.text = "Offsets: X = 0, Y = 0";
		mainContainer.addComponent(animOffsetLabel);
	}
}

class CharacterEditorState extends haxe.ui.backend.flixel.UIState
{
	static inline final AUTO_SAVE_INTERVAL:Float = 60;

	var char:Character;
	var ghostChar:Character;
	var bgLayer:FlxTypedGroup<FlxSprite>;
	var charLayer:FlxTypedGroup<Character>;
	var curAnim:Int = 0;
	var daAnim:String = 'spooky';
	var goToPlayState:Bool = true;

	private var camEditor:FlxCamera;
	private var camUI:FlxCamera;

	var errorAnimText:FlxText;
	var grid:FlxBackdrop;
	var gridVisible:Bool = false;
	var copiedOffsets:Array<Int> = [0, 0];
	var undos:Array<Dynamic> = [];
	var redos:Array<Dynamic> = [];
	var maxHistorySteps:Int = 75;

	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];
	var cameraFollowPointer:FlxSprite;
	var healthBarBG:FlxSprite;
	var draggingCamera:Bool = false;
	var cameraSmoothness:Float = 0.2;
	var cameraDragSensitivity:Float = 0.5;
	var cameraScrollTarget:FlxPoint = FlxPoint.get(0, 0);
	var lastAutoSaveTime:Float = 0;
	var hasUnsavedChanges:Bool = false;

	var ghostAnim:String = '';
	var ghostAlpha:Float = 0.6;
	var ghostSingleAnimMode:Bool = false;

	var currentSavePath:String = null;

	var ui:EditorUI;

	var OFFSET_X:Float = 300;

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var arrowKeysPressed:Array<Bool> = [false, false, false, false];
	var arrowKeysJustPressed:Array<Bool> = [false, false, false, false];

	public function new(daAnim:String = 'spooky', goToPlayState:Bool = true)
	{
		super();
		this.daAnim = daAnim;
		this.goToPlayState = goToPlayState;
	}

	var characterEditorSave:FlxSave;
	override function create()
	{
		super.create();

		characterEditorSave = new FlxSave();
		characterEditorSave.bind('character_editor_data', CoolUtil.getSavePath());

		camEditor = initFunkinCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		bgLayer = new FlxTypedGroup<FlxSprite>();
		add(bgLayer);

		grid = new FlxBackdrop(FlxGridOverlay.createGrid(15, 15, FlxG.width, FlxG.height, true, 0xffe7e6e6, 0xffd9d5d5));
		grid.visible = gridVisible;
		grid.screenCenter();
		add(grid);

		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);

		var pointer:FlxGraphic = FlxGraphic.fromClass(GraphicCursorCross);
		cameraFollowPointer = new FlxSprite().loadGraphic(pointer);
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		add(cameraFollowPointer);

		root.layout = new AbsoluteLayout();
		root.width = FlxG.width;
		root.height = FlxG.height;
		root.cameras = [camUI];

		ui = new EditorUI();
		root.addComponent(ui);

		WindowManager.instance.container = root;

		WindowManager.instance.addWindow(ui.propWindow);
		WindowManager.instance.addWindow(ui.editorWindow);
		WindowManager.instance.addWindow(ui.animWindow);

		loadWindowPositions();

		bindUI();

		errorAnimText = new FlxText(300, 16, "ERROR ON LOADING ANIMATION");
		errorAnimText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		errorAnimText.scrollFactor.set();
		errorAnimText.borderSize = 1;
		errorAnimText.cameras = [camUI];
		errorAnimText.visible = false;
		add(errorAnimText);

		healthBarBG = new FlxSprite(30, FlxG.height - 75).loadGraphic(Paths.image('healthBar'));
		healthBarBG.scrollFactor.set();
		healthBarBG.cameras = [camUI];
		add(healthBarBG);

		leHealthIcon = new HealthIcon("face", false);
		leHealthIcon.y = FlxG.height - 150;
		leHealthIcon.cameras = [camUI];
		add(leHealthIcon);

		loadChar(!daAnim.startsWith('bf'), false);

		FlxG.camera.zoom = 1;
		FlxG.mouse.visible = true;
		cameraScrollTarget.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);

		reloadCharacterDropDown();
		reloadCharacterOptions();
		refreshAnimationList();
	}

	function loadWindowPositions()
	{
		if (ui == null) return;

		if (characterEditorSave.data.charEditorPropWindowX != null) ui.propWindow.left = characterEditorSave.data.charEditorPropWindowX;
		if (characterEditorSave.data.charEditorPropWindowY != null) ui.propWindow.top = characterEditorSave.data.charEditorPropWindowY;

		if (characterEditorSave.data.charEditorEditorWindowX != null) ui.editorWindow.left = characterEditorSave.data.charEditorEditorWindowX;
		if (characterEditorSave.data.charEditorEditorWindowY != null) ui.editorWindow.top = characterEditorSave.data.charEditorEditorWindowY;

		if (characterEditorSave.data.charEditorAnimWindowX != null) ui.animWindow.left = characterEditorSave.data.charEditorAnimWindowX;
		if (characterEditorSave.data.charEditorAnimWindowY != null) ui.animWindow.top = characterEditorSave.data.charEditorAnimWindowY;
	}

	function saveWindowPositions()
	{
		if (ui == null) return;

		characterEditorSave.data.charEditorPropWindowX = ui.propWindow.left;
		characterEditorSave.data.charEditorPropWindowY = ui.propWindow.top;

		characterEditorSave.data.charEditorEditorWindowX = ui.editorWindow.left;
		characterEditorSave.data.charEditorEditorWindowY = ui.editorWindow.top;

		characterEditorSave.data.charEditorAnimWindowX = ui.animWindow.left;
		characterEditorSave.data.charEditorAnimWindowY = ui.animWindow.top;
	}

	var syncingFlipXMenu:Bool = false;
	var syncingNoAA:Bool = false;
	var syncingGridMenu:Bool = false;
	function bindUI()
	{
		final undoBtn:MenuItem = ui.mainToolbar.findComponent("undoBtn", MenuItem, true);
		if (undoBtn != null) undoBtn.onClick = (_) -> undo();

		final redoBtn:MenuItem = ui.mainToolbar.findComponent("redoBtn", MenuItem, true);
		if (redoBtn != null) redoBtn.onClick = (_) -> redo();

		final copyBtn:MenuItem = ui.mainToolbar.findComponent("copyOffsetsBtn", MenuItem, true);
		if (copyBtn != null) copyBtn.onClick = (_) -> copyOffsets();

		final pasteBtn:MenuItem = ui.mainToolbar.findComponent("pasteOffsetsBtn", MenuItem, true);
		if (pasteBtn != null) pasteBtn.onClick = (_) -> pasteOffsets();

		final gridBtn:MenuCheckBox = ui.mainToolbar.findComponent("toggleGridBtn", MenuCheckBox, true);
		if (gridBtn != null) {
			gridBtn.onChange = (_) -> {
				if (syncingGridMenu) return;
				gridVisible = gridBtn.selected;
				grid.visible = gridVisible;
			};
		}

		final resetZoomBtn:MenuItem = ui.mainToolbar.findComponent("resetZoomBtn", MenuItem, true);
		if (resetZoomBtn != null) resetZoomBtn.onClick = (_) -> FlxG.camera.zoom = 1;

		final flipXBtn:MenuCheckBox = ui.mainToolbar.findComponent("flipXBtn", MenuCheckBox, true);
		if (flipXBtn != null) {
			flipXBtn.onChange = (_) -> {
				if (syncingFlipXMenu || char == null) return;

				char.originalFlipX = flipXBtn.selected;
				char.flipX = char.originalFlipX;
				if (char.isPlayer) char.flipX = !char.flipX;

				ghostChar.flipX = char.flipX;
				updatePointerPos(false);
				saveHistoryStuff();
			};
		}

		final noAntialiasBtn:MenuCheckBox = ui.mainToolbar.findComponent("noAntialiasBtn", MenuCheckBox, true);
		if (noAntialiasBtn != null) {
			noAntialiasBtn.onChange = (_) -> {
				if (syncingNoAA || char == null) return;

				char.noAntialiasing = noAntialiasBtn.selected;
				char.antialiasing = !char.noAntialiasing && ClientPrefs.globalAntialiasing;

				ghostChar.antialiasing = char.antialiasing;
				saveHistoryStuff();
			};
		}

		final saveBtn:MenuItem = ui.mainToolbar.findComponent("saveCharBtn", MenuItem, true);
		if (saveBtn != null) saveBtn.onClick = (_) -> quickSaveCharacter();

		final saveAsBtn:MenuItem = ui.mainToolbar.findComponent("saveCharAsBtn", MenuItem, true);
		if (saveAsBtn != null) saveAsBtn.onClick = (_) -> saveCharacter();

		final reloadBtn:MenuItem = ui.mainToolbar.findComponent("reloadCharBtn", MenuItem, true);
		if (reloadBtn != null) reloadBtn.onClick = (_) -> {
			loadChar(!ui.playableCheck.selected);
			reloadCharacterDropDown();
		};

		final reloadImgBtn:MenuItem = ui.mainToolbar.findComponent("reloadCharImageBtn", MenuItem, true);
		if (reloadImgBtn != null) reloadImgBtn.onClick = (_) -> reloadCharacterImage();

		final helpBtn:MenuItem = ui.mainToolbar.findComponent("helpBtn", MenuItem, true);
		if (helpBtn != null) helpBtn.onClick = (_) -> openSubState(new CharacterEditorTipsSubstate());

		ui.makeGhostButton.onClick = (_) -> {
			ghostChar.visible = !ghostChar.visible;
			ui.makeGhostButton.text = ghostChar.visible ? "Hide Ghost" : "Make Ghost";
			if (ghostChar.visible) {
				ghostAnim = (!char.isAnimateAtlas) ? char.animation.curAnim.name : char.atlas.anim.curAnim.name;
				ghostSingleAnimMode = true;
			}
			reloadGhost();
		};

		ui.highlightGhostCheck.onChange = (_) -> {
			final value = ui.highlightGhostCheck.selected ? 125 : 0;
			ghostChar.colorTransform.redOffset = value;
			ghostChar.colorTransform.greenOffset = value;
			ghostChar.colorTransform.blueOffset = value;
		};

		ui.ghostOpacitySlider.onChange = (_) -> {
			ghostAlpha = ui.ghostOpacitySlider.pos;
			ghostChar.alpha = ghostAlpha;
		};

		ui.playableCheck.onChange = (_) -> {
			char.isPlayer = ui.playableCheck.selected;
			char.flipX = char.originalFlipX;

			if (char.isPlayer)
				char.flipX = !char.flipX;

			updatePointerPos(false);
			loadBG();
			ghostChar.flipX = char.flipX;
		};

		ui.charDropDown.onChange = (_) -> {
			var intended = ui.charDropDown.text;
			if (intended == null || intended.length < 1) return;

			var characterPath:String = 'data/characters/$intended.json';
			if (Paths.fileExists(characterPath, TEXT)) {
				daAnim = intended;
				ui.playableCheck.selected = daAnim.startsWith('bf');
				loadChar(!ui.playableCheck.selected);
				reloadCharacterOptions();
				reloadCharacterDropDown();
				updatePointerPos();
			} else {
				reloadCharacterDropDown();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		};

		ui.templateCharButton.onClick = (_) -> {
			var parsedJson:CharacterFile = cast Json.parse(TemplateCharacter);
			var characters:Array<Character> = [char, ghostChar];

			for (character in characters) {
				character.animOffsets.clear();
				character.animationsArray = parsedJson.animations;
				for (anim in character.animationsArray) {
					character.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				}
				if (character.animationsArray[0] != null) {
					character.playAnim(character.animationsArray[0].anim, true);
				}
				character.singDuration = parsedJson.sing_duration;
				character.positionArray = parsedJson.position;
				character.cameraPosition = parsedJson.camera_position;
				character.imageFile = parsedJson.image;
				character.jsonScale = parsedJson.scale;
				character.noAntialiasing = parsedJson.no_antialiasing;
				character.originalFlipX = parsedJson.flip_x;
				character.healthIcon = parsedJson.healthicon;
				character.healthColorArray = parsedJson.healthbar_colors;
				character.setPosition(character.positionArray[0] + OFFSET_X + 100, character.positionArray[1]);
			}

			reloadCharacterImage();
			reloadCharacterDropDown();
			reloadCharacterOptions();
			updateAnimListOffsetDisplay();
			updatePointerPos();
			saveHistoryStuff();
		};

		ui.imageInput.onChange = (_) -> {
			char.imageFile = ui.imageInput.text;
			saveHistoryStuff();
		};

		ui.healthIconInput.onChange = (_) -> {
			leHealthIcon.changeIcon(ui.healthIconInput.text, false);
			char.healthIcon = ui.healthIconInput.text;
			updatePresence();
			saveHistoryStuff();
		};

		ui.vocalsInput.onChange = (_) -> {
			char.vocalsFile = ui.vocalsInput.text;
			saveHistoryStuff();
		};

		ui.singDurationStepper.onChange = (_) -> {
			char.singDuration = ui.singDurationStepper.value;
			saveHistoryStuff();
		};

		ui.scaleStepper.onChange = (_) -> {
			reloadCharacterImage();
			char.jsonScale = ui.scaleStepper.value;
			char.scale.set(char.jsonScale, char.jsonScale);
			char.updateHitbox();
			ghostChar.scale.set(char.jsonScale, char.jsonScale);
			ghostChar.updateHitbox();
			reloadGhost();
			updatePointerPos(false);

			if (!char.isAnimationNull()) {
				char.playAnim(char.getAnimationName(), true);
			}
			saveHistoryStuff();
		};

		ui.posXStepper.onChange = (_) -> {
			char.positionArray[0] = ui.posXStepper.value;
			char.x = char.positionArray[0] + OFFSET_X + 100;
			updatePointerPos();
			saveHistoryStuff();
		};

		ui.posYStepper.onChange = (_) -> {
			char.positionArray[1] = ui.posYStepper.value;
			char.y = char.positionArray[1];
			updatePointerPos();
			saveHistoryStuff();
		};

		ui.camXStepper.onChange = (_) -> {
			char.cameraPosition[0] = ui.camXStepper.value;
			updatePointerPos();
			saveHistoryStuff();
		};

		ui.camYStepper.onChange = (_) -> {
			char.cameraPosition[1] = ui.camYStepper.value;
			updatePointerPos();
			saveHistoryStuff();
		};

		ui.healthColorButton.onClick = (_) -> {
			ColorPickerWindow.showPicker(
				FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]),
				function(newColor:FlxColor) {
					char.healthColorArray[0] = newColor.red;
					char.healthColorArray[1] = newColor.green;
					char.healthColorArray[2] = newColor.blue;
					healthBarBG.color = newColor;
					saveHistoryStuff();
				},
				function():FlxColor {
					return FlxColor.fromInt(CoolUtil.dominantColor(leHealthIcon));
				}
			);
		};

		ui.animDropDown.onChange = (_) -> {
			var selectedAnim = ui.animDropDown.text;
			for (i in 0...char.animationsArray.length) {
				if (char.animationsArray[i].anim == selectedAnim) {
					curAnim = i;
					break;
				}
			}

			var anim:AnimArray = char.animationsArray[curAnim];
			ui.animNameInput.text = anim.anim ?? "";
			ui.animPrefixInput.text = anim.name ?? "";
			ui.animLoopCheck.selected = anim.loop;
			ui.animFramerateStepper.value = anim.fps;
			ui.animIndicesInput.text = anim.indices?.length > 0 ? anim.indices.join(",") : '';

			char.playAnim(anim.anim, true);
			if (ghostChar.visible) ghostChar.playAnim(anim.anim, true);

			syncCurrentAnimUI();
		};

		ui.addUpdateAnimButton.onClick = (_) -> {
			var indices:Array<Int> = [];
			var indicesStr:Array<String> = ui.animIndicesInput.text.trim().split(',');

			if (indicesStr.length > 1) {
				for (s in indicesStr) {
					var idx = Std.parseInt(s);
					if (s != null && s != '' && !Math.isNaN(idx) && idx > -1) indices.push(idx);
				}
			}

			var lastAnim:String = (char.animationsArray[curAnim] != null) ? char.animationsArray[curAnim].anim : "";
			var lastOffsets:Array<Int> = [0, 0];

			for (anim in char.animationsArray) {
				if (ui.animNameInput.text == anim.anim) {
					lastOffsets = anim.offsets;
					if (char.hasAnimation(ui.animNameInput.text)) {
						if (!char.isAnimateAtlas) char.animation.remove(ui.animNameInput.text);
						else char.atlas.anim.remove(ui.animNameInput.text);
					}
					char.animationsArray.remove(anim);
					break;
				}
			}

			var newAnim:AnimArray = {
				anim: ui.animNameInput.text,
				name: ui.animPrefixInput.text,
				fps: Math.round(ui.animFramerateStepper.value),
				loop: ui.animLoopCheck.selected,
				indices: indices,
				offsets: lastOffsets
			};

			if (char.isAnimateAtlas) {
				#if flixel_animate
				if (indices.length > 0)
					char.atlas.anim.addBySymbolIndices(newAnim.anim, newAnim.name, newAnim.indices, newAnim.fps, newAnim.loop);
				else
					char.atlas.anim.addBySymbol(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
				#end
			} else {
				if (indices.length > 0)
					char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, "", newAnim.fps, newAnim.loop);
				else
					char.animation.addByPrefix(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
			}

			if (!char.hasAnimation(newAnim.anim)) char.addOffset(newAnim.anim, 0, 0);
			char.animationsArray.push(newAnim);

			if (lastAnim == newAnim.anim) {
				char.playAnim(lastAnim, true);
			} else {
				for (i in 0...char.animationsArray.length) {
					if (char.animationsArray[i] != null) {
						char.playAnim(char.animationsArray[i].anim, true);
						curAnim = i;
						break;
					}
				}
			}

			curAnim = char.animationsArray.length - 1;
			refreshAnimationList();
			char.playAnim(ui.animNameInput.text, true);
			if (ghostChar.visible) ghostChar.playAnim(ui.animNameInput.text, true);
			saveHistoryStuff();
		};

		ui.removeAnimButton.onClick = (_) -> {
			for (anim in char.animationsArray) {
				if (ui.animNameInput.text == anim.anim) {
					var resetAnim = (anim.anim == char.getAnimationName());
					if (char.hasAnimation(anim.anim)) {
						if (!char.isAnimateAtlas) char.animation.remove(anim.anim);
						else char.atlas.anim.remove(anim.anim);
						char.animOffsets.remove(anim.anim);
						char.animationsArray.remove(anim);
					}

					if (resetAnim && char.animationsArray.length > 0) {
						char.playAnim(char.animationsArray[0].anim, true);
						curAnim = 0;
						if (ghostChar.visible) ghostChar.playAnim(char.animationsArray[0].anim, true);
					}

					refreshAnimationList();
					updateAnimListOffsetDisplay();
					saveHistoryStuff();
					break;
				}
			}
		};
	}

	function loadBG()
	{
		var i:Int = bgLayer.members.length - 1;
		while (i >= 0) {
			var memb:FlxSprite = bgLayer.members[i];
			if (memb != null) {
				memb.kill();
				bgLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		bgLayer.clear();

		var playerXDifference = !char.isPlayer ? 0 : 670;
		var bg:BGSprite = new BGSprite('stageback', -600 + OFFSET_X - playerXDifference, -300, 0.9, 0.9);
		bgLayer.add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650 + OFFSET_X - playerXDifference, 500, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		bgLayer.add(stageFront);
	}

	function reloadCharacterImage()
	{
		var lastAnim:String = char.getAnimationName() ?? '';

		char.atlas = FlxDestroyUtil.destroy(char.atlas);
		char.isAnimateAtlas = false;
		ghostChar.atlas = FlxDestroyUtil.destroy(ghostChar.atlas);
		ghostChar.isAnimateAtlas = false;

		if (Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			#if flixel_animate
			char.isAnimateAtlas = true;
			ghostChar.isAnimateAtlas = true;
			char.atlas = new FlxAnimate();
			char.atlas.frames = Paths.getAnimateAtlas(char.imageFile);
			ghostChar.atlas = new FlxAnimate();
			ghostChar.atlas.frames = Paths.getAnimateAtlas(char.imageFile);
			#end
		} else {
			if (Paths.fileExists('images/' + char.imageFile + '.txt', TEXT)) {
				char.frames = Paths.getPackerAtlas(char.imageFile);
				ghostChar.frames = Paths.getPackerAtlas(char.imageFile);
			} else if (Paths.fileExists('images/' + char.imageFile + '.json', TEXT)) {
				char.frames = Paths.getAsepriteAtlas(char.imageFile);
				ghostChar.frames = Paths.getAsepriteAtlas(char.imageFile);
			} else {
				char.frames = Paths.getSparrowAtlas(char.imageFile);
				ghostChar.frames = Paths.getSparrowAtlas(char.imageFile);
			}
		}

		if (char.animationsArray != null && char.animationsArray.length > 0) {
			for (anim in char.animationsArray) {
				var animAnim = anim.anim;
				var animName = anim.name;
				var animFps = anim.fps;
				var animLoop = anim.loop;
				var animIndices = anim.indices;

				if (char.isAnimateAtlas) {
					#if flixel_animate
					if (animIndices?.length > 0) {
						char.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
						ghostChar.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					} else {
						char.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
						ghostChar.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
					}
					#end
				} else {
					if (animIndices?.length > 0) {
						char.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						ghostChar.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					} else {
						char.animation.addByPrefix(animAnim, animName, animFps, animLoop);
						ghostChar.animation.addByPrefix(animAnim, animName, animFps, animLoop);
					}
				}

				if (!char.hasAnimation(animAnim)) char.addOffset(animAnim, 0, 0);
				if (!ghostChar.hasAnimation(animAnim)) ghostChar.addOffset(animAnim, 0, 0);
			}
		}

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);
		ghostChar.setPosition(char.x, char.y);

		if (char.animationsArray.length > 1) {
			if (lastAnim != '' && char.hasAnimation(lastAnim)) {
				char.playAnim(lastAnim, true);
				if (ghostChar.visible) ghostChar.playAnim(lastAnim, true);
			} else if (char.animationsArray.length > 0) {
				char.playAnim(char.animationsArray[0].anim, true);
				if (ghostChar.visible) ghostChar.playAnim(char.animationsArray[0].anim, true);
			}
		}

		ghostChar.isAnimateAtlas = char.isAnimateAtlas;
		reloadGhost();
		updatePointerPos(false);

		if (!char.isAnimationNull()) {
			char.playAnim(char.getAnimationName(), true);
		}

		refreshAnimationList();
	}

	function loadChar(isDad:Bool, blahBlahBlah:Bool = true)
	{
		var i:Int = charLayer.members.length - 1;
		while (i >= 0) {
			var memb:Character = charLayer.members[i];
			if (memb != null) {
				memb.kill();
				charLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		charLayer.clear();

		ghostChar = new Character(0, 0, daAnim, !isDad);
		ghostChar.debugMode = true;
		ghostChar.alpha = 0.6;
		ghostChar.visible = false;

		char = new Character(0, 0, daAnim, !isDad);
		if (char.animationsArray[0] != null) {
			char.playAnim(char.animationsArray[0].anim, true);
		}
		char.debugMode = true;
		ghostChar.isAnimateAtlas = char.isAnimateAtlas;

		charLayer.add(ghostChar);
		charLayer.add(char);

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);

		undos = [];
		redos = [];
		curAnim = 0;

		if (blahBlahBlah) {
			saveHistoryStuff(false);
			updateAnimListOffsetDisplay();
			refreshAnimationList();
		}

		loadBG();
		reloadCharacterOptions();
		updatePointerPos();

		hasUnsavedChanges = false;
	}

	function updatePointerPos(?snap:Bool = true)
	{
		if (char == null || cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;

		if (!char.isPlayer) {
			offX = char.getMidpoint().x + 100 + char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		} else {
			offX = char.getMidpoint().x - 150 - char.cameraPosition[0];
			offY = char.getMidpoint().y - 100 + char.cameraPosition[1];
		}

		cameraFollowPointer.setPosition(offX, offY);

		if (snap) {
			FlxG.camera.scroll.x = cameraFollowPointer.getMidpoint().x - FlxG.width / 2;
			FlxG.camera.scroll.y = cameraFollowPointer.getMidpoint().y - FlxG.height / 2;
			cameraScrollTarget.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
		}
	}

	function reloadCharacterOptions()
	{
		if (ui == null || ui.imageInput == null || char == null) return;

		ui.imageInput.text = char.imageFile;
		ui.healthIconInput.text = char.healthIcon;
		ui.vocalsInput.text = char.vocalsFile ?? '';
		ui.singDurationStepper.value = char.singDuration;
		ui.posXStepper.value = char.positionArray[0];
		ui.posYStepper.value = char.positionArray[1];
		ui.camXStepper.value = char.cameraPosition[0];
		ui.camYStepper.value = char.cameraPosition[1];
		ui.scaleStepper.value = char.jsonScale;
		ui.playableCheck.selected = char.isPlayer;
		leHealthIcon?.changeIcon(ui.healthIconInput.text, false);

		final flipXBtn:MenuCheckBox = ui.mainToolbar.findComponent("flipXBtn", MenuCheckBox, true);
		if (flipXBtn != null) {
			syncingFlipXMenu = true;
			flipXBtn.selected = char.originalFlipX;
			syncingFlipXMenu = false;
		}

		final noAntialiasBtn:MenuCheckBox = ui.mainToolbar.findComponent("noAntialiasBtn", MenuCheckBox, true);
		if (noAntialiasBtn != null) {
			syncingNoAA = true;
			noAntialiasBtn.selected = char.noAntialiasing;
			syncingNoAA = false;
		}

		final gridBtn:MenuCheckBox = ui.mainToolbar.findComponent("toggleGridBtn", MenuCheckBox, true);
		if (gridBtn != null) {
			syncingGridMenu = true;
			gridBtn.selected = gridVisible;
			syncingGridMenu = false;
		}

		if (healthBarBG != null)
			healthBarBG.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);

		refreshAnimationList();
		updatePresence();
	}

	function refreshAnimationList()
	{
		if (ui == null || ui.animListContainer == null || char == null) return;

		var animList:Array<String> = [];
		for (anim in char.animationsArray) animList.push(anim.anim);
		if (animList.length < 1) animList.push('NO ANIMATIONS');

		ui.animDropDown.dataSource = null;
		ui.animDropDown.dataSource = ArrayDataSource.fromArray(animList);
		if (animList.length > 0 && curAnim >= 0 && curAnim < animList.length)
			ui.animDropDown.text = animList[curAnim];
		else if (animList.length > 0)
			ui.animDropDown.text = animList[0];

		while (ui.animListContainer.numComponents > 0) {
			final child = ui.animListContainer.getComponentAt(0);
			ui.animListContainer.removeComponent(child);
			child.destroy();
		}

		for (i in 0...char.animationsArray.length) {
			final anim = char.animationsArray[i];
			final animName = anim?.anim ?? "<null>";

			final btn = new Button();
			final ir = btn.findComponent(haxe.ui.core.ItemRenderer);
			if (ir != null) btn.removeComponent(ir);

			btn.text = animName;
			btn.percentWidth = 100;
			btn.height = 32;

			if (i == curAnim) btn.addClass("anim-btn-selected");

			btn.onClick = (_) -> {
				curAnim = i;
				if (char.animationsArray[curAnim] != null) {
					char.playAnim(char.animationsArray[curAnim].anim, true);
					if (ghostChar.visible) ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
				}
				syncCurrentAnimUI();
				updatePointerPos();
			};

			ui.animListContainer.addComponent(btn);
		}

		updateAnimListSelection();
		updateAnimListOffsetDisplay();
	}

	function updateAnimListOffsetDisplay()
	{
		if (ui == null || ui.animOffsetLabel == null || char == null) return;

		if (char.animationsArray[curAnim] != null) {
			var off = char.animationsArray[curAnim].offsets;
			ui.animOffsetLabel.text = 'Offsets: X = ${off[0]}, Y = ${off[1]}';
		} else {
			ui.animOffsetLabel.text = "Offsets: X = 0, Y = 0";
		}
	}

	function updateAnimListSelection()
	{
		if (ui == null || ui.animListContainer == null) return;

		for (i in 0...ui.animListContainer.numComponents) {
			var btn:Button = cast ui.animListContainer.getComponentAt(i);

			btn.removeClass("anim-btn-selected");
			btn.removeClass("primary");

			if (i == curAnim)
				btn.addClass("anim-btn-selected");
		}
	}

	function reloadGhost()
	{
		var wasVisible = ghostChar.visible;
		var alpha = ghostChar.alpha;

		ghostChar.animOffsets.clear();

		if (ghostChar.isAnimateAtlas) {
			#if flixel_animate
			if (ghostChar.atlas != null) ghostChar.atlas.anim.destroyAnimations();
			#end
		} else {
			ghostChar.animation.destroyAnimations();
		}

		for (anim in char.animationsArray) {
			var animAnim = anim.anim;
			var animName = anim.name;
			var animFps = anim.fps;
			var animLoop = anim.loop;
			var animIndices = anim.indices;

			if (ghostChar.isAnimateAtlas) {
				#if flixel_animate
				if (animIndices?.length > 0)
					ghostChar.atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
				else
					ghostChar.atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				#end
			} else {
				if (animIndices?.length > 0)
					ghostChar.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
				else
					ghostChar.animation.addByPrefix(animAnim, animName, animFps, animLoop);
			}

			ghostChar.addOffset(animAnim, anim.offsets[0], anim.offsets[1]);
		}

		ghostChar.alpha = alpha;
		ghostChar.visible = wasVisible;
		ghostChar.antialiasing = char.antialiasing;
		ghostChar.flipX = char.flipX;

		if (ghostChar.visible && !char.isAnimationNull()) {
			var currentAnim = char.getAnimationName();
			if (ghostChar.hasAnimation(currentAnim)) ghostChar.playAnim(currentAnim, true);
		}
	}

	function reloadCharacterDropDown()
	{
		var charsLoaded:Map<String, Bool> = new Map();

		#if sys
		characterList = [];
		var directories:Array<String> = [
			#if MODS_ALLOWED
			Mods.getModPath('data/characters/'),
			Mods.getModPath(Mods.currentModDirectory + '/data/characters/'),
			#end
			Paths.getPreloadPath('data/characters/')
		];

		#if MODS_ALLOWED
		for (mod in Mods.getGlobalMods()) directories.push(Mods.getModPath(mod + '/data/characters/'));
		#end

		for (dir in directories) {
			if (FileSystem.exists(dir)) {
				for (file in FileSystem.readDirectory(dir)) {
					var path = haxe.io.Path.join([dir, file]);
					if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json')) {
						try {
							var charToCheck = file.substr(0, file.length - 5);
							var rawJson = sys.io.File.getContent(path);
							if (rawJson != null && rawJson.length > 0 && !charsLoaded.exists(charToCheck)) {
								var json = haxe.Json.parse(rawJson);
								if (json != null && Reflect.hasField(json, "animations") && Reflect.hasField(json, "image")) {
									characterList.push(charToCheck);
									charsLoaded.set(charToCheck, true);
								}
							}
						} catch (e) {}
					}
				}
			}
		}
		#else
		characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));
		#end

		if (characterList.length < 1) characterList.push('');
		ui.charDropDown.dataSource = ArrayDataSource.fromArray(characterList);
		ui.charDropDown.text = daAnim;
	}

	function updatePresence()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Character Editor", "Character: " + daAnim, leHealthIcon.getCharacter());
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.state.subState != null) return;

		var blockInput = (FocusManager.instance.focus != null && Std.isOfType(FocusManager.instance.focus, TextField));

		handleAutoSave(elapsed);
		handleAnimationValidityCheck();

		if (!blockInput) {
			ClientPrefs.toggleVolumeKeys();
			handleHotkeys();
			handleGridToggle();
			handleCopyPasteUndoRedo();
			handleExit();
			handleCameraZoom(elapsed);
			handleCameraDrag();
			handleAnimationNavigation();
			handleOffsetReset();
			handleArrowKeyMovement(elapsed);
		} else {
			ClientPrefs.toggleVolumeKeys(false);
		}

		updateVisuals();
	}

	function handleAutoSave(elapsed:Float)
	{
		lastAutoSaveTime += elapsed;
		if (lastAutoSaveTime >= AUTO_SAVE_INTERVAL) {
			lastAutoSaveTime = 0;
			saveBackup();
		}
	}

	function handleAnimationValidityCheck()
	{
		if (char.animationsArray[curAnim] != null) {
			var animName = char.animationsArray[curAnim].anim;
			var validAnim = false;

			if (char.isAnimateAtlas) {
				validAnim = char.atlas.anim.getByName(animName) != null;
			} else {
				var anim = char.animation.getByName(animName);
				validAnim = (anim != null && anim.frames.length > 0);
			}

			errorAnimText.visible = !validAnim;
		} else {
			errorAnimText.visible = false;
		}
	}

	function handleHotkeys()
	{
		if (FlxG.keys.justPressed.F1) openSubState(new CharacterEditorTipsSubstate());
	}

	function handleGridToggle()
	{
		if (FlxG.keys.justPressed.G) toggleGrid();
	}

	function handleCopyPasteUndoRedo()
	{
		var changedOffset = false;

		if (FlxG.keys.pressed.CONTROL) {
			if (FlxG.keys.justPressed.C) {
				copiedOffsets = char.animationsArray[curAnim].offsets.copy();
				changedOffset = true;
			}
			if (FlxG.keys.justPressed.V) {
				char.animationsArray[curAnim].offsets = copiedOffsets.copy();
				char.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
				ghostChar.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
				char.playAnim(char.animationsArray[curAnim].anim, false);
				saveHistoryStuff();
				changedOffset = true;
			}
			if (FlxG.keys.justPressed.Z) undo();
			if (FlxG.keys.justPressed.Y) redo();

			if (FlxG.keys.justPressed.S) {
				quickSaveCharacter();
				return;
			}

			if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.I) {
				loadChar(!ui.playableCheck.selected);
				reloadCharacterDropDown();
				return;
			}

			if (FlxG.keys.pressed.I && FlxG.keys.justPressed.R) {
				reloadCharacterImage();
				return;
			}
		}

		if (changedOffset) saveOffsetChanges();
	}

	function handleExit()
	{
		if (FlxG.keys.justPressed.ESCAPE) {
			if (hasUnsavedChanges) {
				HaxeUIUtil.showConfirm(
					"You have unsaved changes. Are you sure you want to exit?",
					"Confirmation",
					(btn:DialogButton) -> {
						if (btn == DialogButton.YES)
							doExit();
					}
				);
			} else {
				doExit();
			}
		}
	}

	function doExit()
	{
		if (goToPlayState) 
			FlxG.switchState(() -> new PlayState());
		else {
			FlxG.switchState(() -> new game.states.editors.MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
		FlxG.mouse.visible = false;
	}

	function handleCameraZoom(elapsed:Float)
	{
		var shiftMult = 1.0;
		var ctrlMult = 1.0;

		if (FlxG.keys.pressed.SHIFT) shiftMult = 4;
		if (FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) {
			FlxG.camera.zoom = 1;
		} else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if (FlxG.camera.zoom >= 3) FlxG.camera.zoom = 3;
		} else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if (FlxG.camera.zoom <= 0.1) FlxG.camera.zoom = 0.1;
		}
	}

	function isMouseOverComponent(c:Component):Bool
	{
		if (c == null || c.hidden) return false;

		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;

		var left = c.screenLeft;
		var top = c.screenTop;
		var width = c.width;
		var height = c.height;

		return mx >= left && mx <= left + width
			&& my >= top && my <= top + height;
	}

	function handleCameraDrag()
	{
		if (HaxeUIUtil.isCursorOverUI || FocusManager.instance.focus != null)
			return;

		if (FlxG.mouse.justPressed) {
			draggingCamera = true;
			cameraScrollTarget.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
		}

		if (draggingCamera && FlxG.mouse.pressed) {
			var deltaX = FlxG.mouse.deltaViewX * cameraDragSensitivity;
			var deltaY = FlxG.mouse.deltaViewY * cameraDragSensitivity;

			cameraScrollTarget.x -= deltaX;
			cameraScrollTarget.y -= deltaY;

			FlxG.camera.scroll.x += (cameraScrollTarget.x - FlxG.camera.scroll.x) * cameraSmoothness;
			FlxG.camera.scroll.y += (cameraScrollTarget.y - FlxG.camera.scroll.y) * cameraSmoothness;
		}
	}

	function handleAnimationNavigation()
	{
		if (char.animationsArray.length > 0) {
			var changed = false;

			if (FlxG.keys.justPressed.W) {
				curAnim--;
				changed = true;
			}
			if (FlxG.keys.justPressed.S && !FlxG.keys.pressed.CONTROL) {
				curAnim++;
				changed = true;
			}

			if (curAnim < 0) curAnim = char.animationsArray.length - 1;
			if (curAnim >= char.animationsArray.length) curAnim = 0;

			if (changed || FlxG.keys.justPressed.SPACE) {
				char.playAnim(char.animationsArray[curAnim].anim, true);

				if (!ghostSingleAnimMode && ghostChar.visible) {
					ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
				}

				syncCurrentAnimUI();
			}
		}
	}

	function handleOffsetReset()
	{
		if (FlxG.keys.justPressed.T && char.animationsArray.length > 0) {
			char.animationsArray[curAnim].offsets = [0, 0];
			char.addOffset(char.animationsArray[curAnim].anim, 0, 0);
			ghostChar.addOffset(char.animationsArray[curAnim].anim, 0, 0);
			char.playAnim(char.animationsArray[curAnim].anim, true);
			ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
			updateAnimListOffsetDisplay();
			saveHistoryStuff();
		}
	}

	function handleArrowKeyMovement(elapsed:Float)
	{
		if (char.animationsArray.length == 0) return;

		updateArrowKeyStates();

		var shiftMultBig = FlxG.keys.pressed.SHIFT ? 10 : 1;
		var offsetChanged = false;

		if (arrowKeysJustPressed.contains(true)) {
			final dx = ((arrowKeysJustPressed[0] ? 1 : 0) - (arrowKeysJustPressed[1] ? 1 : 0)) * shiftMultBig;
			final dy = ((arrowKeysJustPressed[2] ? 1 : 0) - (arrowKeysJustPressed[3] ? 1 : 0)) * shiftMultBig;

			if (char.isAnimateAtlas) {
				char.atlas.offset.x += dx;
				char.atlas.offset.y += dy;
			} else {
				char.offset.x += dx;
				char.offset.y += dy;
			}
			offsetChanged = true;
		}

		if (arrowKeysPressed.contains(true)) {
			holdingArrowsTime += elapsed;
			if (holdingArrowsTime > 0.6) {
				holdingArrowsElapsed += elapsed;
				while (holdingArrowsElapsed > (1 / 60)) {
					final dx = ((arrowKeysPressed[0] ? 1 : 0) - (arrowKeysPressed[1] ? 1 : 0)) * shiftMultBig;
					final dy = ((arrowKeysPressed[2] ? 1 : 0) - (arrowKeysPressed[3] ? 1 : 0)) * shiftMultBig;

					if (char.isAnimateAtlas) {
						char.atlas.offset.x += dx;
						char.atlas.offset.y += dy;
					} else {
						char.offset.x += dx;
						char.offset.y += dy;
					}

					holdingArrowsElapsed -= (1 / 60);
					offsetChanged = true;
				}
			}
		} else {
			holdingArrowsTime = 0;
		}

		if (offsetChanged) saveOffsetChanges();
	}

	function updateArrowKeyStates()
	{
		arrowKeysPressed[0] = FlxG.keys.pressed.LEFT;
		arrowKeysPressed[1] = FlxG.keys.pressed.RIGHT;
		arrowKeysPressed[2] = FlxG.keys.pressed.UP;
		arrowKeysPressed[3] = FlxG.keys.pressed.DOWN;

		arrowKeysJustPressed[0] = FlxG.keys.justPressed.LEFT;
		arrowKeysJustPressed[1] = FlxG.keys.justPressed.RIGHT;
		arrowKeysJustPressed[2] = FlxG.keys.justPressed.UP;
		arrowKeysJustPressed[3] = FlxG.keys.justPressed.DOWN;
	}

	function syncCurrentAnimUI()
	{
		if (char == null || char.animationsArray == null || char.animationsArray.length == 0) return;
		if (curAnim < 0 || curAnim >= char.animationsArray.length) return;

		final anim:AnimArray = char.animationsArray[curAnim];
		if (anim == null) return;

		ui.animDropDown.text = anim.anim ?? "";
		ui.animNameInput.text = anim.anim ?? "";
		ui.animPrefixInput.text = anim.name ?? "";
		ui.animLoopCheck.selected = anim.loop;
		ui.animFramerateStepper.value = anim.fps;

		if (anim.indices?.length > 0)
			ui.animIndicesInput.text = anim.indices.join(",");
		else
			ui.animIndicesInput.text = "";

		updateAnimListSelection();
		updateAnimListOffsetDisplay();
	}

	function saveOffsetChanges()
	{
		if (char.animationsArray[curAnim] != null) {
			final curX = char.isAnimateAtlas ? char.atlas.offset.x : char.offset.x;
			final curY = char.isAnimateAtlas ? char.atlas.offset.y : char.offset.y;

			final animName = char.animationsArray[curAnim].anim;
			char.animOffsets.set(animName, [curX, curY]);

			for (anim in char.animationsArray) {
				if (anim.anim == animName) {
					anim.offsets = [Std.int(curX), Std.int(curY)];
					break;
				}
			}

			if (ghostChar.visible && !ghostChar.isAnimationNull() && ghostChar.getAnimationName() == animName) {
				ghostChar.animOffsets.set(animName, [curX, curY]);
				ghostChar.offset.set(curX, curY);
			}

			saveHistoryStuff();
			updateAnimListOffsetDisplay();
		}
	}

	function updateVisuals()
	{
		ghostChar.setPosition(char.x, char.y);
	}

	var _file:FileReference;
	function onSaveComplete(_):Void
	{
		_file = null;
		HaxeUIUtil.showNotification("Character Editor", "File saved successfully", Success);
		hasUnsavedChanges = false;
	}
	function onSaveCancel(_):Void
	{
		_file = null;
		HaxeUIUtil.showNotification("Character Editor", "Save cancelled");
	}

	function onSaveError(_):Void
	{
		_file = null;
		HaxeUIUtil.showNotification("Character Editor", "Save failed", Error);
	}

	function saveBackup()
	{
		try {
			#if sys
			final backupDir = 'backups/characters/';
			if (!sys.FileSystem.exists(backupDir)) sys.FileSystem.createDirectory(backupDir);

			final path = backupDir + daAnim + '_backup.json';
			final data = Json.stringify(buildCharacterJson(), "\t");
			sys.io.File.saveContent(path, data);

			HaxeUIUtil.showNotification("Character Editor", 'Backup saved:\n${Paths.getRelativePath(path)}', Success);
			#end
		} catch (e) {
			HaxeUIUtil.showNotification("Character Editor", 'Backup save failed!\nError: $e', Error);
		}
	}

	function buildCharacterJson():CharacterFile
	{
		return {
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.jsonScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,
			"position": char.positionArray,
			"camera_position": char.cameraPosition,
			"flip_x": char.originalFlipX,
			"no_antialiasing": char.noAntialiasing,
			"vocals_file": char.vocalsFile,
			"healthbar_colors": char.healthColorArray
		};
	}

	function saveCharacter()
	{
		if (_file != null) return;

		try {
			var data = Json.stringify(buildCharacterJson(), "\t");
			if (data.length > 0) {
				_file = new FileReference();
				_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
				_file.addEventListener(Event.CANCEL, onSaveCancel);
				_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
				_file.save(data, daAnim + ".json");
			}
		} catch (e) {}
	}

	function quickSaveCharacter()
	{
		try {
			#if sys
			var path:String = currentSavePath;

			if (path == null || path.length == 0)
			{
				final resolved:String = Paths.json(daAnim);

				if (sys.FileSystem.exists(resolved))
					path = resolved;
				else
				{
					if (Mods.currentModDirectory?.length > 0)
						path = Mods.getModPath(Mods.currentModDirectory + '/data/characters/' + daAnim + '.json');
					else
						path = Paths.getPreloadPath('data/characters/' + daAnim + '.json');
				}

				currentSavePath = path;
			}

			final dir = haxe.io.Path.directory(path);
			if (!sys.FileSystem.exists(dir))
				sys.FileSystem.createDirectory(dir);

			final data = Json.stringify(buildCharacterJson(), "\t");
			sys.io.File.saveContent(path, data);

			HaxeUIUtil.showNotification("Character Editor", 'Saved successfully:\n${Paths.getRelativePath(path)}', Success);
			hasUnsavedChanges = false;
			#end
		} catch (e) {
			HaxeUIUtil.showNotification("Character Editor", 'Quick save failed!\nError: $e', Error);
		}
	}

	function saveHistoryStuff(markUnsaved:Bool = true)
	{
		var state:HistoryStuff = {
			animations: [for (anim in char.animationsArray) {
				anim: anim.anim,
				name: anim.name,
				fps: anim.fps,
				loop: anim.loop,
				indices: anim.indices.copy(),
				offsets: anim.offsets.copy()
			}],
			position: char.positionArray.copy(),
			scale: char.jsonScale,
			cameraPosition: char.cameraPosition.copy(),
			healthColor: char.healthColorArray.copy(),
			curAnim: curAnim,
			imageFile: char.imageFile,
			healthIcon: char.healthIcon,
			vocalsFile: char.vocalsFile,
			noAntialiasing: char.noAntialiasing,
			isPlayer: char.isPlayer,
			originalFlipX: char.originalFlipX
		};

		undos.push(state);
		if (undos.length > maxHistorySteps) undos.shift();
		redos = [];

		if (markUnsaved)
			hasUnsavedChanges = true;
	}

	function undo()
	{
		if (undos.length <= 1) return;

		redos.push(undos.pop());
		restoreState(undos[undos.length - 1]);
	}

	function redo()
	{
		if (redos.length == 0) return;

		var state = redos.pop();
		undos.push(state);
		restoreState(state);
	}

	function getCurrentState():HistoryStuff
	{
		return {
			animations: [for (anim in char.animationsArray) {
				anim: anim.anim,
				name: anim.name,
				fps: anim.fps,
				loop: anim.loop,
				indices: anim.indices.copy(),
				offsets: anim.offsets.copy()
			}],
			position: char.positionArray.copy(),
			scale: char.jsonScale,
			cameraPosition: char.cameraPosition.copy(),
			healthColor: char.healthColorArray.copy(),
			curAnim: curAnim,
			imageFile: char.imageFile,
			healthIcon: char.healthIcon,
			vocalsFile: char.vocalsFile,
			noAntialiasing: char.noAntialiasing,
			isPlayer: char.isPlayer,
			originalFlipX: char.originalFlipX
		};
	}

	function restoreState(state:HistoryStuff)
	{
		char.imageFile = state.imageFile;
		char.healthIcon = state.healthIcon;
		char.vocalsFile = state.vocalsFile;
		char.noAntialiasing = state.noAntialiasing;
		char.isPlayer = state.isPlayer;
		char.originalFlipX = state.originalFlipX;

		char.animationsArray = [for (anim in state.animations) {
			anim: anim.anim,
			name: anim.name,
			fps: anim.fps,
			loop: anim.loop,
			indices: anim.indices.copy(),
			offsets: anim.offsets.copy()
		}];

		ghostChar.animationsArray = [for (anim in state.animations) {
			anim: anim.anim,
			name: anim.name,
			fps: anim.fps,
			loop: anim.loop,
			indices: anim.indices.copy(),
			offsets: anim.offsets.copy()
		}];

		char.animOffsets.clear();
		ghostChar.animOffsets.clear();

		for (anim in char.animationsArray) {
			char.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			ghostChar.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
		}

		char.positionArray = state.position.copy();
		char.cameraPosition = state.cameraPosition.copy();
		char.jsonScale = state.scale;
		char.healthColorArray = state.healthColor.copy();
		curAnim = state.curAnim;

		if (curAnim < 0) curAnim = 0;
		if (curAnim >= char.animationsArray.length) curAnim = char.animationsArray.length - 1;

		reloadCharacterImage();

		char.antialiasing = !char.noAntialiasing && ClientPrefs.globalAntialiasing;
		ghostChar.antialiasing = char.antialiasing;

		char.flipX = char.originalFlipX;
		if (char.isPlayer) char.flipX = !char.flipX;
		ghostChar.flipX = char.flipX;

		refreshAnimationList();
		refreshAnimationList();
		reloadCharacterOptions();
		reloadGhost();
		loadBG();

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);
		ghostChar.setPosition(char.x, char.y);
		updatePointerPos();
		updateAnimListOffsetDisplay();

		if (char.animationsArray.length > 0) {
			char.playAnim(char.animationsArray[curAnim].anim, true);
			if (ghostChar.visible) ghostChar.playAnim(char.animationsArray[curAnim].anim, true);
		}
	}

	public function copyOffsets()
	{
		if (char.animationsArray.length > 0) {
			copiedOffsets = char.animationsArray[curAnim].offsets.copy();
		}
	}

	public function pasteOffsets()
	{
		if (char.animationsArray.length > 0) {
			char.animationsArray[curAnim].offsets = copiedOffsets.copy();
			char.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
			ghostChar.addOffset(char.animationsArray[curAnim].anim, copiedOffsets[0], copiedOffsets[1]);
			char.playAnim(char.animationsArray[curAnim].anim, false);
			saveHistoryStuff();
		}
	}

	public function toggleGrid()
	{
		gridVisible = !gridVisible;
		grid.visible = gridVisible;

		final gridBtn:MenuCheckBox = ui.mainToolbar.findComponent("toggleGridBtn", MenuCheckBox, true);
		if (gridBtn != null) {
			syncingGridMenu = true;
			gridBtn.selected = gridVisible;
			syncingGridMenu = false;
		}
	}

	public function toggleFlipX()
	{
		char.originalFlipX = !char.originalFlipX;
		char.flipX = char.originalFlipX;
		if (char.isPlayer) char.flipX = !char.flipX;
		ghostChar.flipX = char.flipX;
		saveHistoryStuff();
	}

	override function destroy()
	{
		if (cameraScrollTarget != null) {
			cameraScrollTarget.put();
			cameraScrollTarget = null;
		}

		saveWindowPositions();

		super.destroy();
	}

	static inline var TemplateCharacter:String = '{
		"animations": [
			{"loop": false,"offsets": [0,0],"fps": 24,"anim": "idle","indices": [],"name": "Dad idle dance"},
			{"offsets": [0,0],"indices": [],"fps": 24,"anim": "singLEFT","loop": false,"name": "Dad Sing Note LEFT"},
			{"offsets": [0,0],"indices": [],"fps": 24,"anim": "singDOWN","loop": false,"name": "Dad Sing Note DOWN"},
			{"offsets": [0,0],"indices": [],"fps": 24,"anim": "singUP","loop": false,"name": "Dad Sing Note UP"},
			{"offsets": [0,0],"indices": [],"fps": 24,"anim": "singRIGHT","loop": false,"name": "Dad Sing Note RIGHT"}
		],
		"no_antialiasing": false,"image": "characters/daddy/DADDY_DEAREST","position": [0,0],"healthicon": "face","flip_x": false,
		"healthbar_colors": [161,161,161],"camera_position": [0,0],"sing_duration": 6.1,"vocals_file": null,"scale": 1
	}';
}

class ColorPickerWindow extends Window
{
	var colorPicker:ColorPicker;
	var onColorSelected:FlxColor->Void;
	var getIconColorCallback:Void->FlxColor;

	public function new(defaultColor:FlxColor, onColorSelected:FlxColor->Void, ?getIconColorCallback:Void->FlxColor)
	{
		super();
		this.onColorSelected = onColorSelected;
		this.getIconColorCallback = getIconColorCallback;

		this.title = "Select Color";
		this.width = 300;
		this.height = 360;
		this.percentWidth = 100;
		this.percentHeight = 100;
		this.closable = true;

		var content = new VBox();
		content.percentWidth = 100;
		content.percentHeight = 100;
		content.styleNames = "padding: 12px; spacing: 8px;";
		this.addComponent(content);

		colorPicker = new ColorPicker();
		colorPicker.width = 250;
		colorPicker.height = 250;
		content.addComponent(colorPicker);

		colorPicker.registerEvent(UIEvent.READY, (e) -> colorPicker.value = defaultColor.to24Bit());

		var buttonsRow = new HBox();
		buttonsRow.percentWidth = 100;
		buttonsRow.styleNames = "horizontal-align: center; spacing: 10px;";
		content.addComponent(buttonsRow);

		var okButton = new Button();
		okButton.text = "OK";
		okButton.width = 80;
		okButton.onClick = (_) -> {
			if (this.onColorSelected != null) {
				var col = FlxColor.fromRGB(
					(colorPicker.value >> 16) & 0xFF,
					(colorPicker.value >> 8) & 0xFF,
					colorPicker.value & 0xFF
				);
				this.onColorSelected(col);
			}
			WindowManager.instance.closeWindow(this);
		};
		buttonsRow.addComponent(okButton);

		if (getIconColorCallback != null) {
			var getIconColorButton = new Button();
			getIconColorButton.text = "Get Icon Color";
			getIconColorButton.width = 120;
			getIconColorButton.onClick = (_) -> {
				var iconColor = this.getIconColorCallback();
				colorPicker.value = iconColor.to24Bit();
			};
			buttonsRow.addComponent(getIconColorButton);
		}

		var cancelButton = new Button();
		cancelButton.text = "Cancel";
		cancelButton.width = 80;
		cancelButton.onClick = (_) -> WindowManager.instance.closeWindow(this);
		buttonsRow.addComponent(cancelButton);
	}

	public static function showPicker(defaultColor:FlxColor, onColorSelected:FlxColor->Void, ?getIconColorCallback:Void->FlxColor):ColorPickerWindow
	{
		var picker = new ColorPickerWindow(defaultColor, onColorSelected, getIconColorCallback);
		
		WindowManager.instance.addWindow(picker);
		
		picker.left = Std.int((FlxG.width - picker.width) / 2);
		picker.top = Std.int((FlxG.height - picker.height) / 2);
		
		return picker;
	}
}

class CharacterEditorTipsSubstate extends haxe.ui.backend.flixel.UISubState
{
	var tipsWindow:Window;

	override function create() {
		super.create();

		camera = FlxG.cameras.list[FlxG.cameras.list.length - 1];

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.8;
		add(bg);

		root.layout = new AbsoluteLayout();
		root.width = FlxG.width;
		root.height = FlxG.height;

		WindowManager.instance.container = root;

		tipsWindow = new Window();
		tipsWindow.title = "Character Editor Tips";
		tipsWindow.width = 450;
		tipsWindow.height = 360;
		tipsWindow.minimizable = false;
		tipsWindow.maximizable = false;
		tipsWindow.closable = true;

		tipsWindow.registerEvent(UIEvent.CLOSE, (e) -> close());

		var textLabel = new Label();
		textLabel.text = "E/Q - Zoom In/Out\n" +
						 "R - Reset Zoom\n" +
						 "Drag Mouse - Move Camera\n" +
						 "W/S - Previous/Next Animation\n" +
						 "Space - Play Animation\n" +
						 "Arrow Keys - Move Offset\n" +
						 "T - Reset Current Offset\n" +
						 "Shift + Arrows - Move 10x Faster\n" +
						 "G - Toggle Grid\n" +
						 "CTRL + C - Copy Offsets\n" +
						 "CTRL + V - Paste Offsets\n" +
						 "CTRL + Z - Undo\n" +
						 "CTRL + Y - Redo";
						 
		textLabel.percentWidth = 100;
		textLabel.percentHeight = 100;
		textLabel.styleNames = "padding: 15px; font-size: 16px;";
		tipsWindow.addComponent(textLabel);

		WindowManager.instance.addWindow(tipsWindow);

		tipsWindow.left = (FlxG.width - tipsWindow.width) / 2;
		tipsWindow.top = (FlxG.height - tipsWindow.height) / 2;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE) close();
	}
}