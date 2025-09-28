package game.scripting;

import flixel.FlxG;

import rulescript.*;
import rulescript.scriptedClass.*;
import rulescript.types.ScriptedTypeUtil;

import hscript.Expr;
import hscript.Parser;

import game.scripting.HScriptParser as HxParser;

#if sys
import sys.io.File;
#end

import game.scripting.FunkinRScript.RuleScriptInterpEx;

import haxe.ds.StringMap;

using StringTools;

class HScriptClassManager {
    public static final SCRIPTABLE_CLASSES:Map<String, Class<Dynamic>> = {
        var map = new Map<String, Class<Dynamic>>();
        map.set(Type.getClassName(TempClass), ScriptedTempClass);
        map;
    };

    public static var classes:Map<String, ScriptClassRef> = new Map();

    public static function init():Void {
        ScriptedTypeUtil.resolveScript = __resolveScript;
        RuleScriptedClassUtil.buildBridge = __buildRuleScript;
        reloadScriptedClasses();
    }

    public static function reloadScriptedClasses():Void {
        classes.clear();
        
        var sourceFiles = new Map<String, String>();
        
        #if sys
        for (file in CoolUtil.readRecursive("source")) {
            if (file.endsWith(".hx")) {
                try {
                    sourceFiles.set(file, File.getContent(Paths.getPath(file)));
                } catch (e:haxe.Exception) {
                    trace('Failed to read file: $file - ${e.message}');
                }
            }
        }
        #else
        var resourceNames = haxe.Resource.listNames();
        for (name in resourceNames) {
            if (name.startsWith("source_") && name.endsWith("_hx")) {
                try {
                    var originalPath = name.substring(7, name.length - 3).replace("_", "/") + ".hx";
                    var content = haxe.Resource.getString(name);
                    sourceFiles.set(originalPath, content);
                } catch (e:haxe.Exception) {
                    trace('Failed to read resource: $name - ${e.message}');
                }
            }
        }
        #end
        
        for (file => content in sourceFiles) {
            processScriptFile(file, content);
        }
    }

    private static function processScriptFile(file:String, content:String):Void {
        try {
            var parser = new HxParser();
            parser.allowAll();
            parser.mode = MODULE;
            parser.preprocesorValues = FunkinHScript.getHScriptPreprocessors();
            
            var expr = parser.parse(content);
            var ogParser = new Parser();
            var ogExpr = ogParser.parseModule(content);
            
            var parentCls:Class<Dynamic> = ScriptedTempClass;
            var baseCls:Null<Class<Dynamic>> = null;
            var imports = new Map<String, String>();
            
            for (e in ogExpr) {
                processDeclaration(e, imports, file, expr, parentCls, baseCls);
            }
        } catch (e:haxe.Exception) {
            trace('Failed to process script file: $file - ${e.message}');
        }
    }

    private static function processDeclaration(
        e:hscript.Expr.ModuleDecl,
        imports:Map<String, String>, 
        file:String, 
        expr:Expr, 
        parentCls:Class<Dynamic>, 
        baseCls:Null<Class<Dynamic>>
    ):Void {
        switch (e) {
            case DImport(path, everything):
                var name = path[path.length - 1];
                imports.set(name, path.join("."));
                
            case DClass(c):
                if (c.extend != null) {
                    processClassExtend(c.extend, imports, parentCls, baseCls);
                }
                
                var ref = createScriptClassRef(file, parentCls, baseCls, expr, c);
                if (ref != null) {
                    processStaticFields(ref, c, expr);
                    classes.set(ref.path, ref);
                }
                
            default:
                // nothing...
        }
    }

    private static function processClassExtend(
        extend:hscript.Expr.CType, 
        imports:Map<String, String>, 
        parentCls:Class<Dynamic>, 
        baseCls:Null<Class<Dynamic>>
    ):Void {
        switch (extend) {
            case CTPath(path, params):
                var p = path.join(".");
                if (imports.exists(p)) p = imports.get(p);
                
                baseCls = Type.resolveClass(p);
                if (baseCls != null) {
                    var className = Type.getClassName(baseCls);
                    if (className != null && SCRIPTABLE_CLASSES.exists(className)) {
                        parentCls = SCRIPTABLE_CLASSES.get(className);
                    } else {
                        trace('[WARN] Class $p is not scriptable or not found!');
                    }
                }
            default:
        }
    }

    private static function createScriptClassRef(
        file:String, 
        parentCls:Class<Dynamic>, 
        baseCls:Null<Class<Dynamic>>, 
        expr:Expr, 
        c:hscript.Expr.ClassDecl
    ):Null<ScriptClassRef> {
        var path = file.split("/source/")[1].replace(".hx", "").replace("/", ".");
        
        return {
            path: path,
            scriptedClass: parentCls,
            extend: baseCls,
            expr: expr,
            staticFields: new Map()
        };
    }

    private static function processStaticFields(ref:ScriptClassRef, c:hscript.Expr.ClassDecl, expr:Expr):Void {
        var staticFieldNames = new Array<String>();
        
        for (field in c.fields) {
            if (field.access.contains(AStatic)) {
                staticFieldNames.push(field.name);
            }
        }
        
        if (staticFieldNames.length > 0) {
            executeStaticFields(ref, staticFieldNames);
            removeStaticFieldsFromExpr(expr, staticFieldNames);
        }
    }

    private static function executeStaticFields(ref:ScriptClassRef, staticFieldNames:Array<String>):Void {
        try {
            var rulescript = new RuleScript(new RuleScriptInterpEx(), new HxParser());
            cast(rulescript.interp, RuleScriptInterpEx).ref = ref;
            rulescript.execute(ref.expr);
            
            for (key => data in rulescript.variables) {
                if (staticFieldNames.contains(key)) {
                    ref.staticFields.set(key, data);
                }
            }
        } catch (e:haxe.Exception) {
            trace('Failed to execute static fields for ${ref.path}: ${e.message}');
        }
    }

    private static function removeStaticFieldsFromExpr(expr:Expr, staticFieldNames:Array<String>):Void {
        switch (expr.e) {
            case EBlock(fields):
                var i = fields.length;
                while (i-- > 0) {
                    var field = fields[i];
                    switch (field.e) {
                        case EFunction(_, _, name, _) | EVar(name, _, _):
                            if (staticFieldNames.contains(name)) {
                                fields.splice(i, 1);
                            }
                        default:
                    }
                }
            default:
				//doing nothing
        }
    }

    static function __buildRuleScript(typeName:String, superInstance:Dynamic):RuleScript {
        if (!classes.exists(typeName))
            throw 'Script class $typeName not found';
        
        var ref = classes.get(typeName);
        var interp = new FunkinRScript.RuleScriptInterpEx();
        interp.ref = ref;
        
        var rulescript = new RuleScript(interp, new HxParser());
        rulescript.superInstance = superInstance;
        
        try {
            rulescript.execute(ref.expr);
        } catch (e:haxe.Exception) {
            trace('Failed to build rule script for $typeName: ${e.message}');
        }
        
        return rulescript;
    }

    static function __resolveScript(path:String):Dynamic {
        var state = RuleScriptInterpEx.resolveScriptState;
        if (state == null) return null;
        
        var clsName = path.split(".").pop();
        
        return switch (state.mode) {
            case "resolve": classes.get(path);
            case "cnew": 
                if (classes.exists(path)) {
                    createInstance(path, state.args);
                } else if (state.owner.variables.exists(clsName)) {
                    var ref = state.owner.variables.get(clsName);
                    if (ref != null && ref.expr != null) {
                        createInstance(ref.path, state.args);
                    } else {
                        null;
                    }
                } else {
                    null;
                }
            default: null;
        }
    }

    public static function createInstance(path:String, ?args:Array<Dynamic>):Dynamic {
        if (!classes.exists(path)) return null;
        
        var ref = classes.get(path);
        if (args == null) args = [];
        
        try {
            return Type.createInstance(ref.scriptedClass, [path, args]);
        } catch (e:haxe.Exception) {
            trace('Failed to create instance of $path: ${e.message}');
            return null;
        }
    }

    public static function listScriptClassesExtends(cls:Class<Dynamic>):Array<String> {
        var result = new Array<String>();
        
        for (key => scriptClass in classes) {
            if (scriptClass.extend == cls) {
                result.push(key);
            }
        }
        
        return result;
    }
}

@:structInit class ScriptClassRef {
    public var path:String;
    public var extend:Null<Class<Dynamic>>;
    public var scriptedClass:Class<Dynamic>;
    public var expr:Expr;
    public var staticFields:Map<String, Dynamic>;
}

class TempClass {
    public function new() {}
}

class ScriptedTempClass implements rulescript.scriptedClass.RuleScriptedClass extends TempClass {}