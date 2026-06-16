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
    
    public var strictMode:Bool = true;
    public var declaredVariables:Map<String, {type:Null<String>, value:Dynamic}> = new Map();
    public var declaredLocalVariables:Map<String, {type:Null<String>, value:Dynamic}> = new Map();
    
    public function new(?script:FunkinRuleScript) {
        this.script = script;
        super();
    }
    
    override function resetVariables():Void 
    {
        super.resetVariables();
        declaredVariables.clear();
        declaredLocalVariables.clear();
    }
    
    override function resolveType(path:String):Dynamic 
    {
        var resolved = script.resolveType(path);
        if (resolved != null) {
            resolveScriptState = {owner: this, mode: "resolve"};
            return resolved;
        }
        
        try {
            var cl = Type.resolveClass(path);
            if (cl != null) {
                return cl;
            }
        } catch (e:Dynamic) {}
        
        resolveScriptState = {owner: this, mode: "resolve"};
        return super.resolveType(path);
    }
    
   override function cnew(cl:String, args:Array<Dynamic>):Dynamic 
    {
        resolveScriptState = {owner: this, mode: "cnew", args: args};
        
        var resolvedClass:Dynamic = null;
        try {
            resolvedClass = resolveType(cl);
        } catch (e:Dynamic) {}
        
        if (resolvedClass != null && !isScriptedClass(resolvedClass)) {
            try {
                return Type.createInstance(resolvedClass, args);
            } catch (e:Dynamic) {
                trace('Failed to create instance with Type.createInstance for $cl: $e');
            }
        }
        
        return super.cnew(cl, args);
    }

    override function expr(expr:Expr):Dynamic {
        #if hscriptPos
        switch(expr.e) {
        #else
        switch(expr) {
        #end
            case EVar(name, typeExpr, e, global, _):
                var typeStr = typeExpr != null ? typeToString(typeExpr) : null;
                var result = super.expr(expr);
                if (global) {
                    declaredVariables.set(name, {type: typeStr, value: null});
                } else {
                    declaredLocalVariables.set(name, {type: typeStr, value: null});
                }
                return result;
            case EProp(name, getter, setter, typeExpr, e, global):
                var typeStr = typeExpr != null ? typeToString(typeExpr) : null;
                var result = super.expr(expr);
                if (global) {
                    declaredVariables.set(name, {type: typeStr, value: null});
                } else {
                    declaredLocalVariables.set(name, {type: typeStr, value: null});
                }
                return result;
            default:
                return super.expr(expr);
        }
    }
    
    private function typeToString(typeExpr:CType):String {
        return switch(typeExpr) {
            case CTPath(path, params):
                path.join(".");
            case CTNamed(name, t):
                typeToString(t);
            case CTOpt(t):
                typeToString(t) + "?";
            default:
                "Dynamic";
        }
    }
    
    private function checkType(varName:String, value:Dynamic, expectedType:Null<String>):Bool {
        if (value == null || expectedType == null || expectedType == "Dynamic") {
            return true;
        }
        
        switch(expectedType) {
            case "Int":
                return Std.isOfType(value, Int);
            case "Float":
                return Std.isOfType(value, Float) || Std.isOfType(value, Int);
            case "Bool":
                return Std.isOfType(value, Bool);
            case "String":
                return Std.isOfType(value, String);
            default:
                try {
                    var cls:Dynamic = resolveType(expectedType);
                    if (cls != null) {
                        return Std.isOfType(value, cls);
                    }
                } catch (e:Dynamic) {}
                
                return true;
        }
    }

    override function get(o:Dynamic, f:String):Dynamic 
    {
        if (strictMode && o != null && o != this && !Std.isOfType(o, ScriptClassRef)) {
            validateFieldAccess(o, f);
        }
        
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
                        return str.startsWith(substr);
                    };
                case "endsWith": 
                    return function(substr:String):Bool {
                        return str.endsWith(substr);
                    };
                case "length": return str.length;
                case "toUpperCase": return str.toUpperCase();
                case "toLowerCase": return str.toLowerCase();
                case "charAt": return function(index:Int):String {
                    return str.charAt(index);
                };
                case "charCodeAt": return function(index:Int):Int {
                    return str.charCodeAt(index);
                };
                case "indexOf": return function(substr:String, ?startIndex:Int):Int {
                    if (startIndex == null) return str.indexOf(substr);
                    return str.indexOf(substr, startIndex);
                };
                case "lastIndexOf": return function(substr:String, ?startIndex:Int):Int {
                    if (startIndex == null) return str.lastIndexOf(substr);
                    return str.lastIndexOf(substr, startIndex);
                };
                case "split": return function(delimiter:String):Array<String> {
                    return str.split(delimiter);
                };
                case "substr": return function(start:Int, ?len:Int):String {
                    if (len == null) return str.substr(start);
                    return str.substr(start, len);
                };
                case "substring": return function(start:Int, ?end:Int):String {
                    if (end == null) return str.substring(start);
                    return str.substring(start, end);
                };
                case "trim": return str.trim();
                case "ltrim": return StringTools.ltrim(str);
                case "rtrim": return StringTools.rtrim(str);
                case "replace": return function(sub:String, by:String):String {
                    return StringTools.replace(str, sub, by);
                };
                case "urlEncode": return StringTools.urlEncode(str);
                case "urlDecode": return StringTools.urlDecode(str);
                case "htmlEscape": return StringTools.htmlEscape(str);
                case "htmlUnescape": return StringTools.htmlUnescape(str);
                case "contains": return function(value:String):Bool {
                    return StringTools.contains(str, value);
                };
                case "isSpace": return function(pos:Int):Bool {
                    return StringTools.isSpace(str, pos);
                };
                case "lpad": return function(c:String, l:Int):String {
                    return StringTools.lpad(str, c, l);
                };
                case "rpad": return function(c:String, l:Int):String {
                    return StringTools.rpad(str, c, l);
                };
                case "hex": return function(?digits:Int):String {
                    var n = Std.parseInt(str);
                    if (n == null) return "0";
                    return StringTools.hex(n, digits);
                };
                case "iterator":
                    return StringTools.iterator(str);
                case "keyValueIterator":
                    return StringTools.keyValueIterator(str);
                case "fastCodeAt": return function(index:Int):Int {
                    return StringTools.fastCodeAt(str, index);
                };
                case "unsafeCodeAt": return function(index:Int):Int {
                    return StringTools.unsafeCodeAt(str, index);
                };
                case "isEof": return function(c:Int):Bool {
                    return StringTools.isEof(c);
                };
            }
        }

        if (Std.isOfType(o, Array)) {
            var arr:Array<Dynamic> = cast o;
            switch(f) {
                case "length": return arr.length;
                case "concat": return function(a:Array<Dynamic>):Array<Dynamic> {
                    return arr.concat(a);
                };
                case "join": return function(sep:String):String {
                    return arr.join(sep);
                };
                case "pop": return function():Dynamic {
                    return arr.pop();
                };
                case "push": return function(x:Dynamic):Int {
                    return arr.push(x);
                };
                case "reverse": return function():Void {
                    arr.reverse();
                };
                case "shift": return function():Dynamic {
                    return arr.shift();
                };
                case "slice": return function(pos:Int, ?end:Int):Array<Dynamic> {
                    return arr.slice(pos, end);
                };
                case "sort": return function(f:Dynamic->Dynamic->Int):Void {
                    arr.sort(f);
                };
                case "splice": return function(pos:Int, len:Int):Array<Dynamic> {
                    return arr.splice(pos, len);
                };
                case "toString": return function():String {
                    return arr.toString();
                };
                case "unshift": return function(x:Dynamic):Void {
                    arr.unshift(x);
                };
                case "insert": return function(pos:Int, x:Dynamic):Void {
                    arr.insert(pos, x);
                };
                case "remove": return function(x:Dynamic):Bool {
                    return arr.remove(x);
                };
                case "contains": return function(x:Dynamic):Bool {
                    return arr.contains(x);
                };
                case "indexOf": return function(x:Dynamic, ?fromIndex:Int):Int {
                    return arr.indexOf(x, fromIndex);
                };
                case "lastIndexOf": return function(x:Dynamic, ?fromIndex:Int):Int {
                    return arr.lastIndexOf(x, fromIndex);
                };
                case "copy": return function():Array<Dynamic> {
                    return arr.copy();
                };
                case "iterator":
                    return arr.iterator();
                case "keyValueIterator":
                    return arr.keyValueIterator();
                case "map":
                    return function(f:Dynamic->Dynamic):Array<Dynamic> {
                        return arr.map(f);
                    };
                case "filter":
                    return function(f:Dynamic->Bool):Array<Dynamic> {
                        return arr.filter(f);
                    };
                case "resize":
                    return function(len:Int):Void {
                        arr.resize(len);
                    };
            }
        }

        return super.get(o, f);
    }

    override function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
        if (strictMode && o != null && o != this) {
            validateFieldAccess(o, f);
        }

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
                if (l == null) {
                    if (strictMode) {
                        var isDeclared = declaredVariables.exists(id) || 
                                        (context != null && (context.staticVariables.exists(id) || context.publicVariables.exists(id))) ||
                                        (superInstance != null && superFields.contains(id));
                        
                        if (!isDeclared && !variables.exists(id)) {
                            throw new haxe.Exception('Undeclared variable: $id');
                        }
                    }
                    
                    if (strictMode && declaredVariables.exists(id)) {
                        var varInfo = declaredVariables.get(id);
                        if (!checkType(id, v, varInfo.type)) {
                            throw new haxe.Exception('Type mismatch for variable $id: expected ${varInfo.type}, got ${Type.typeof(v)}');
                        }
                    }
                    
                    setVar(id, v);
                } 
                else 
                {
                    if (strictMode && declaredLocalVariables.exists(id)) {
                        var varInfo = declaredLocalVariables.get(id);
                        if (!checkType(id, v, varInfo.type)) {
                            throw new haxe.Exception('Type mismatch for local variable $id: expected ${varInfo.type}, got ${Type.typeof(v)}');
                        }
                    }
                    
                    if (l.r != null && Type.getClassName(Type.getClass(l.r)) == "rulescript.types.Property")
                        cast(l.r, rulescript.types.Property).value = v;
                    else
                        l.r = v;
                }
                
            case EField(e, f):
                var obj = expr(e);
                obj ??= {};
                
                if (strictMode && obj != null && obj != this) {
                    validateFieldAccess(obj, f);
                }
                
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
                
                if (strictMode) {
                    validateFieldAccess(obj, field);
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

    override function setVar(name:String, v:Dynamic) {
        if (strictMode && declaredVariables.exists(name)) {
            var varInfo = declaredVariables.get(name);
            if (!checkType(name, v, varInfo.type)) {
                throw new haxe.Exception('Type mismatch for variable $name: expected ${varInfo.type}, got ${Type.typeof(v)}');
            }
        }
        
        if (superInstance != null && (superFields.contains(name) || superFields.contains('set_' + name)))
            Reflect.setProperty(superInstance, name, v);
        else if (context?.staticVariables.exists(name))
            context.staticVariables.set(name, v);
        else if (context?.publicVariables.exists(name))
            context.publicVariables.set(name, v);
        else
        {
            var lastValue = variables.get(name);

            if (lastValue is Property)
                cast(lastValue, Property).value = v;
            else
                variables.set(name, v);
        }
    }

    override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic 
    {
        if (o == Type && f == "createInstance") {
            if (args.length >= 1) {
                var cls = args[0];
                var constructorArgs = args.slice(1);
                
                if (!isScriptedClass(cls)) {
                    return Type.createInstance(cls, constructorArgs);
                }
            }
        }
        
        if (f == null) {
            var className = Type.getClassName(o);
            if (className != null && className != "Dynamic") {
                try {
                    var cls:Class<Dynamic> = cast o;
                    var instance = Type.createInstance(cls, args);
                    return instance;
                } catch (e:Dynamic) {}
            }
        }
        
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
    
    public function addVariableDeclaration(name:String, type:Null<String> = null):Void {
        declaredVariables.set(name, {type: type, value: null});
    }
    
    private function validateFieldAccess(obj:Dynamic, field:String, ?expr:Expr):Void {
        if (!strictMode || obj == null) return;

        if (Std.isOfType(obj, rulescript.scriptedClass.RuleScriptedClass) || 
			Type.getClassName(Type.getClass(obj)) == "rulescript.scriptedClass.ScriptedClass") 
		{
			return;
		}
        
        if (isMapType(obj)) return;
        
        var cls = Type.getClass(obj);
        if (cls == null) return;
        
        var className = Type.getClassName(cls);
        if (className == null) return;
        
        var skipClasses = [
            "String", "Array", "Int", "Float", "Bool", "Dynamic",
            "haxe.ds.StringMap", "haxe.ds.IntMap", "haxe.ds.ObjectMap",
            "haxe.ds.EnumValueMap", "Map", "haxe.ds.Map",
            "flixel.tweens.misc.VarTween", "flixel.tweens.FlxTween",
            "haxe.ds.GenericStack", "flixel.ui.FlxBar"
        ];
        
        if (skipClasses.contains(className)) return;
        
        function checkField(cls:Class<Dynamic>):Bool {
            if (cls == null) return false;
            
            if (Type.getClassFields(cls).indexOf(field) >= 0 || Type.getInstanceFields(cls).indexOf(field) >= 0) return true;
            if (Type.getInstanceFields(cls).indexOf('get_$field') >= 0 || Type.getInstanceFields(cls).indexOf('set_$field') >= 0) return true;
            
            var superClass = Type.getSuperClass(cls);
            return checkField(superClass);
        }
        
        if (!checkField(cls)) {
            throw new haxe.Exception('Field "$field" does not exist on $className');
        }
    }

    private function isMapType(obj:Dynamic):Bool 
    {
        if (obj == null) return false;

        var cls = Type.getClass(obj);
        if (cls == null) return false;

        var className = Type.getClassName(cls);
        if (className == null) return false;
        
        return className.indexOf("Map") != -1 || 
            className == "haxe.ds.StringMap" ||
            className == "haxe.ds.IntMap" ||
            className == "haxe.ds.ObjectMap" ||
            className == "haxe.ds.EnumValueMap" ||
            className == "haxe.ds.GenericStack";
    }

    private function isScriptedClass(cls:Class<Dynamic>):Bool {
        if (cls == null) return false;
        
        var className = Type.getClassName(cls);
        if (className == null) return false;
        
        var superClass = Type.getSuperClass(cls);
        while (superClass != null) {
            if (Type.getClassName(superClass) == "rulescript.scriptedClass.RuleScriptedClass") {
                return true;
            }
            superClass = Type.getSuperClass(superClass);
        }
        
        return false;
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