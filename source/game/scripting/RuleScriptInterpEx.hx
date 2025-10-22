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
    var mode:String; // resolve or cnew
    var ?args:Array<Dynamic>;
}