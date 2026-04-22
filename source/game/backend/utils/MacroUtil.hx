package game.backend.utils;

#if macro
import sys.FileSystem;
import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
#end

using StringTools;

final class MacroUtil {
    public static var defines(get, null):Map<String, Dynamic>;
	private static inline function get_defines() return __getDefines();
	private static macro function __getDefines() {
		#if display
		return macro $v{[]};
		#else
		var definesMap = Context.getDefines();
		var processedDefines = new Map<String, Dynamic>();
		
		for (key => value in definesMap) {
			processedDefines.set(key, parseDefineValueMacro(value));
		}
		
		return macro $v{processedDefines};
		#end
	}

	#if macro
	private static function parseDefineValueMacro(value:String):Dynamic {
		if (value == "1") return true;
		if (value == "0") return false;
		if (value == "true") return true;
		if (value == "false") return false;
		
		var floatVal = Std.parseFloat(value);
		if (!Math.isNaN(floatVal)) return floatVal;
		
		var intVal = Std.parseInt(value);
		if (intVal != null) return intVal;
	   
		return value;
	}
	#end
	
	// Taken from cne
	macro public static function generateReflectionLike(totalArguments:Int, funcName:String, argsName:String) {
		#if macro
		totalArguments++;

		var funcCalls = [];
		for(i in 0...totalArguments) {
			var args = [
				for(d in 0...i) macro $i{argsName}[$v{d}]
			];

			funcCalls.push(macro $i{funcName}($a{args}));
		}

		var expr = {
			pos: Context.currentPos(),
			expr: ESwitch(
				macro ($i{argsName}.length),
				[
					for(i in 0...totalArguments) {
						values: [macro $v{i}],
						expr: funcCalls[i],
						guard: null,
					}
				],
				macro throw "Too many arguments"
			)
		}

		return expr;
		#end
	}
}