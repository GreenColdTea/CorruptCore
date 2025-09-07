package game.backend;

import game.shaders.flixel.FlxShader;
import flixel.FlxG;
import flixel.addons.display.FlxRuntimeShader;

import lime.graphics.opengl.GLProgram;

#if sl_windows_api
import winapi.WindowsAPI.MessageBoxIcon;
import winapi.WindowsAPI.MessageBoxType;
import winapi.WindowsAPI;
#end

using StringTools;

class ErrorShader extends FlxShader implements IErrorHandler {
	public var shaderName:String = '';
	public dynamic function onError(error:Dynamic):Void {}

	public function new(?shaderName:String) {
		this.shaderName = shaderName;
		super();
	}

	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram {
		try {
			return super.__createGLProgram(vertexSource, fragmentSource);
		} catch (error) {
			ErrorShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
	
	public static function crashSave(shaderName:String, error:Dynamic, onError:Dynamic) {
		shaderName = (shaderName == null ? 'unnamed' : shaderName);

		CoolUtil.showPopUp(
			'There has been an error compiling this shader!', 
			'Error on shader "${shaderName}"!'
		);
		final dateNow = Date.now().toString().replace(" ", "_").replace(":", "'");
		if (!sys.FileSystem.exists('./crash/')) sys.FileSystem.createDirectory('./crash/');

		final crashLogPath = './crash/shader_${shaderName}_${dateNow}.txt';
		sys.io.File.saveContent(crashLogPath, error);
		trace('Shader Crashlog saved at "$crashLogPath"');

		onError(error);
	}
}

class ErrorRuntimeShader extends FlxRuntimeShader implements IErrorHandler {
	public var shaderName:String = '';
	public dynamic function onError(error:Dynamic):Void {}

	public function new(?shaderName:String, ?fragmentSource:String, ?vertexSource:String) {
		this.shaderName = shaderName;
		super(fragmentSource, vertexSource);
	}

	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram {
		try {
			return super.__createGLProgram(vertexSource, fragmentSource);
		} catch (error) {
			ErrorShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
}

interface IErrorHandler {
	public var shaderName:String;
	public dynamic function onError(error:Dynamic):Void;
}