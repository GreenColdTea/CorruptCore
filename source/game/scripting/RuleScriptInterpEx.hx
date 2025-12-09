package game.scripting;

import rulescript.interps.RuleScriptInterp;
import rulescript.interps.bytecode.Command;
import rulescript.RuleScript.IInterp;
import rulescript.scriptedClass.RuleScriptedClass;
import rulescript.types.Property;
import rulescript.types.ScriptedTypeUtil;
import hscript.Expr;

class RuleScriptInterpEx extends RuleScriptInterp 
{
    public static var resolveScriptState:ResolveScriptState;
    public var ref:ScriptClassRef;
    public var script:FunkinRuleScript;
    
    public function new(?script:FunkinRuleScript) {
        this.script = script;
        super();
    }
    
    override function resolveType(path:String):Dynamic {
        var resolved = script.resolveType(path);
        if (resolved != null) {
            resolveScriptState = {owner: this, mode: "resolve"};
            return resolved;
        }
        
        resolveScriptState = {owner: this, mode: "resolve"};
        return super.resolveType(path);
    }
    
    override function cnew(cl:String, args:Array<Dynamic>):Dynamic {
        resolveScriptState = {owner: this, mode: "cnew", args: args};
        return super.cnew(cl, args);
    }

    override function get(o:Dynamic, f:String):Dynamic {
        if (o == this) {
            if (this.ref != null && this.ref.staticFields.exists(f))
                return this.ref.staticFields.get(f);
        }

        if (Std.isOfType(o, ScriptClassRef)) {
            var cls:ScriptClassRef = cast o;
            if (cls.staticFields.exists(f))
                return cls.staticFields.get(f);
        }

        if (o == null) return null;

        var value = null;
        try {
            value = Reflect.getProperty(o, f);
        } catch (e:Dynamic) {}

        if (value == null) {
            try {
                value = Reflect.field(o, f);
            } catch (e:Dynamic) {}
        }

        if (value != null) return value;

        if (Std.isOfType(o, String)) {
            var str:String = cast o;
            switch(f) {
                case "startsWith": 
                    return function(substr:String):Bool {
                        return StringTools.startsWith(str, substr);
                    };
                case "endsWith": 
                    return function(substr:String):Bool {
                        return StringTools.endsWith(str, substr);
                    };
                case "length": return str.length;
                case "toUpperCase": return str.toUpperCase();
                case "toLowerCase": return str.toLowerCase();
                case "charAt": return function(index:Int):String {
                    return str.charAt(index);
                };
                case "indexOf": return function(substr:String, ?startIndex:Int):Int {
                    if (startIndex == null) return str.indexOf(substr);
                    return str.indexOf(substr, startIndex);
                };
                case "substr": return function(start:Int, ?len:Int):String {
                    if (len == null) return str.substr(start);
                    return str.substr(start, len);
                };
                case "split": return function(delimiter:String):Array<String> {
                    return str.split(delimiter);
                };
                case "trim": return str.trim();
                case "substring": return function(start:Int, ?end:Int):String {
                    if (end == null) return str.substring(start);
                    return str.substring(start, end);
                };
            }
        }

        if (Std.isOfType(o, Array)) {
            var arr:Array<Dynamic> = cast o;
            switch(f) {
                case "length": return arr.length;
                case "push": return function(item:Dynamic):Void {
                    arr.push(item);
                };
                case "pop": return function():Dynamic {
                    return arr.pop();
                };
                case "concat": return function(other:Array<Dynamic>):Array<Dynamic> {
                    return arr.concat(other);
                };
                case "join": return function(separator:String):String {
                    return arr.join(separator);
                };
                case "shift": return function():Dynamic {
                    return arr.shift();
                };
                case "unshift": return function(item:Dynamic):Void {
                    arr.unshift(item);
                };
                case "slice": return function(start:Int, ?end:Int):Array<Dynamic> {
                    if (end == null) return arr.slice(start);
                    return arr.slice(start, end);
                };
            }
        }

        return super.get(o, f);
    }

    override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
        if (o == this) {
            if (this.ref != null && this.ref.staticFields.exists(f)) {
                this.ref.staticFields.set(f, v);
                return v;
            }
        }

        if (Std.isOfType(o, ScriptClassRef)) {
            var cls:ScriptClassRef = cast o;
            if (cls.staticFields.exists(f)) {
                cls.staticFields.set(f, v);
                return v;
            }
        }

        return super.set(o, f, v);
    }

    override function assign(e1:Expr, e2:Expr):Dynamic 
    {
        var v = expr(e2);
        #if hscriptPos
        switch(e1.e) {
        #else
        switch(e1) {
        #end
            case EIdent(id):
                var l = locals.get(id);
                if (l == null)
                    setVar(id, v);
                else 
                {
                    if (l.r != null && Type.getClassName(Type.getClass(l.r)) == "rulescript.types.Property")
                        cast(l.r, rulescript.types.Property).value = v;
                    else
                        l.r = v;
                }
            case EField(e, f):
                var obj = expr(e);
                obj ??= {};
                
                try {
                    Reflect.setProperty(obj, f, v);
                } catch (e:Dynamic) {
                    Reflect.setField(obj, f, v);
                }
                return v;
            case EArray(e, index):
                var arr:Dynamic = expr(e);
                var index:Dynamic = expr(index);
                if (isMap(arr)) {
                    setMapValue(arr, index, v);
                } else {
                    arr[index] = v;
                }
            case ETypeVarPath(path):
                if (path.length < 2) {
                    throw new haxe.Exception("Invalid ETypeVarPath for assignment: " + path.join("."));
                }
                
                var field = path[path.length - 1];
                var objPath = path.slice(0, -1);
                
                var obj:Dynamic = null;
                
                var first = objPath[0];
                if (locals.exists(first) || variables.exists(first)) {
                    obj = resolve(first);
                    for (i in 1...objPath.length) {
                        obj = get(obj, objPath[i]);
                    }
                } else {
                    var typePath = objPath.join(".");
                    obj = resolveType(typePath);
                }
                
                if (obj == null) {
                    throw new haxe.Exception('Cannot resolve object for assignment: ${objPath.join(".")}');
                }
                
                try {
                    Reflect.setProperty(obj, field, v);
                } catch (e:Dynamic) {
                    Reflect.setField(obj, field, v);
                }
                return v;
            default:
                #if hscriptPos
                var exprStr = Std.string(e1.e);
                #else
                var exprStr = Std.string(e1);
                #end
                throw new haxe.Exception('Invalid assignment target: $exprStr');
        }
        return v;
    }

    override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
        if (Reflect.isFunction(o) && f == null) {
            try {
                return Reflect.callMethod(null, o, args);
            } catch (e:Dynamic) {
                if (args.length == 1) {
                    return o(args[0]);
                } else {
                    return o(args);
                }
            }
        }

        return super.call(o, f, args);
    }
}

@:structInit class ScriptClassRef {
    public var path:String;
    public var extend:Null<Class<Dynamic>>;
    public var scriptedClass:Class<Dynamic>;
    public var expr:Expr;
    public var staticFields:haxe.ds.Map<String, Dynamic>;
}

typedef ResolveScriptState = {
    var owner:RuleScriptInterpEx;
    var mode:String;
    var ?args:Array<Dynamic>;
}