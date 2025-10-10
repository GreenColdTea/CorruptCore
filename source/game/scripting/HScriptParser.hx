package game.scripting;

import hscript.Expr;
import hscript.Parser.Token;

import rulescript.parsers.HxParser;

using StringTools;
using rulescript.Tools;

class HScriptParser extends HxParser
{
    public var strictMode:Bool = true;
    public var requireSemicolons:Bool = true;
    public var reportWarnings:Bool = true;
    
    private var errors:Array<String>;
    private var warnings:Array<String>;
    private var currentLine:Int = 1;
    private var currentColumn:Int = 1;
    
    private var skipMode:Bool = false;
    private var currentCondition:Bool = true;

    public var preprocessorValues:Map<String, Dynamic>;

    public function setPreprocessorValues(values:Map<String, Dynamic>):Void {
        this.preprocessorValues = values;
    }
    
    public function setDefines(values:Map<String, Dynamic>):Void {
        this.preprocessorValues = values;
    }
    
    public function new(?strictMode:Bool = true)
    {
        super();
        this.strictMode = strictMode;
        this.errors = [];
        this.warnings = [];
        this.preprocessorValues = new Map();
    }
    
    override public function parse(code:String):Expr
    {
        errors = [];
        warnings = [];
        currentLine = 1;
        currentColumn = 1;
        skipMode = false;
        currentCondition = true;
        
        try {
            var processedCode = preprocessCode(code);
            
            if (strictMode && !validateBasicSyntax(processedCode)) {
                throw new haxe.Exception("Basic syntax validation failed");
            }
            
            var result = super.parse(processedCode);
            
            result = transformFieldAssignments(result);
            
            if (reportWarnings && warnings.length > 0) {
                trace('Parser warnings:');
                for (warning in warnings) {
                    trace('  $warning');
                }
            }
            
            if (errors.length > 0) {
                throw new haxe.Exception("Parser errors detected: " + errors.join("; "));
            }
            
            return result;
        } catch (e:haxe.Exception) {
            var enhancedError = 'Error at line $currentLine, column $currentColumn: ${e.message}';
            if (errors.length > 0) {
                enhancedError += "\nAdditional errors: " + errors.join("; ");
            }
            throw new haxe.Exception(enhancedError);
        }
    }
    
    private function transformFieldAssignments(expr:Expr):Expr {
        #if hscriptPos
        return switch(expr.e) {
            case EBinop("=", e1, e2):
                switch(e1.e) {
                    case EField(obj, field):
                        var transformedObj = transformFieldAssignments(obj);
                        var transformedValue = transformFieldAssignments(e2);
                        {
                            e: ECall(
                                {
                                    e: EField(
                                        {
                                            e: EIdent("Reflect"),
                                            pmin: expr.pmin,
                                            pmax: expr.pmax,
                                            origin: expr.origin,
                                            line: expr.line
                                        },
                                        "setProperty"
                                    ),
                                    pmin: expr.pmin,
                                    pmax: expr.pmax,
                                    origin: expr.origin,
                                    line: expr.line
                                },
                                [
                                    transformedObj, 
                                    {
                                        e: EConst(CString(field)),
                                        pmin: expr.pmin,
                                        pmax: expr.pmax,
                                        origin: expr.origin,
                                        line: expr.line
                                    }, 
                                    transformedValue
                                ]
                            ),
                            pmin: expr.pmin,
                            pmax: expr.pmax,
                            origin: expr.origin,
                            line: expr.line
                        };
                    default:
                        {
                            e: EBinop("=", transformFieldAssignments(e1), transformFieldAssignments(e2)),
                            pmin: expr.pmin,
                            pmax: expr.pmax,
                            origin: expr.origin,
                            line: expr.line
                        };
                }
                
            case EBinop(op, e1, e2):
                {
                    e: EBinop(op, transformFieldAssignments(e1), transformFieldAssignments(e2)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EUnop(op, postFix, e):
                {
                    e: EUnop(op, postFix, transformFieldAssignments(e)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EField(e, field):
                {
                    e: EField(transformFieldAssignments(e), field),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case ECall(e, params):
                {
                    e: ECall(transformFieldAssignments(e), [for (p in params) transformFieldAssignments(p)]),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EArray(e, index):
                {
                    e: EArray(transformFieldAssignments(e), transformFieldAssignments(index)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EBlock(exprs):
                {
                    e: EBlock([for (e in exprs) transformFieldAssignments(e)]),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EIf(cond, e1, e2):
                {
                    e: EIf(transformFieldAssignments(cond), transformFieldAssignments(e1), 
                        e2 == null ? null : transformFieldAssignments(e2)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EWhile(cond, e):
                {
                    e: EWhile(transformFieldAssignments(cond), transformFieldAssignments(e)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EFor(v, it, e):
                {
                    e: EFor(v, transformFieldAssignments(it), transformFieldAssignments(e)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case ESwitch(e, cases, def):
                {
                    e: ESwitch(transformFieldAssignments(e), 
                            [for (c in cases) { 
                                values: [for (v in c.values) transformFieldAssignments(v)], 
                                expr: transformFieldAssignments(c.expr) 
                            }],
                            def == null ? null : transformFieldAssignments(def)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case ETry(e, v, t, ecatch):
                {
                    e: ETry(transformFieldAssignments(e), v, t, transformFieldAssignments(ecatch)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EFunction(args, e, name, ret):
                {
                    e: EFunction(args, transformFieldAssignments(e), name, ret),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EReturn(e):
                {
                    e: EReturn(e == null ? null : transformFieldAssignments(e)),
                    pmin: expr.pmin,
                    pmax: expr.pmax,
                    origin: expr.origin,
                    line: expr.line
                };
                
            case EBreak | EContinue | ETernary(_, _, _):
                expr;
                
            default:
                expr;
        }
        #else
        return switch(expr) {
            case EBinop("=", e1, e2):
                switch(e1) {
                    case EField(obj, field):
                        ECall(
                            EField(EIdent("Reflect"), "setProperty"),
                            [transformFieldAssignments(obj), EConst(CString(field)), transformFieldAssignments(e2)]
                        );
                    default:
                        EBinop("=", transformFieldAssignments(e1), transformFieldAssignments(e2));
                }
                
            case EBinop(op, e1, e2):
                EBinop(op, transformFieldAssignments(e1), transformFieldAssignments(e2));
                
            case EUnop(op, postFix, e):
                EUnop(op, postFix, transformFieldAssignments(e));
                
            case EField(e, field):
                EField(transformFieldAssignments(e), field);
                
            case ECall(e, params):
                ECall(transformFieldAssignments(e), [for (p in params) transformFieldAssignments(p)]);
                
            case EArray(e, index):
                EArray(transformFieldAssignments(e), transformFieldAssignments(index));
                
            case EBlock(exprs):
                EBlock([for (e in exprs) transformFieldAssignments(e)]);
                
            case EIf(cond, e1, e2):
                EIf(transformFieldAssignments(cond), transformFieldAssignments(e1), 
                    e2 == null ? null : transformFieldAssignments(e2));
                
            case EWhile(cond, e):
                EWhile(transformFieldAssignments(cond), transformFieldAssignments(e));
                
            case EFor(v, it, e):
                EFor(v, transformFieldAssignments(it), transformFieldAssignments(e));
                
            case ESwitch(e, cases, def):
                ESwitch(transformFieldAssignments(e), 
                    [for (c in cases) { 
                        values: [for (v in c.values) transformFieldAssignments(v)], 
                        expr: transformFieldAssignments(c.expr) 
                    }],
                    def == null ? null : transformFieldAssignments(def));
                
            case ETry(e, v, t, ecatch):
                ETry(transformFieldAssignments(e), v, t, transformFieldAssignments(ecatch));
                
            case EFunction(args, e, name, ret):
                EFunction(args, transformFieldAssignments(e), name, ret);
                
            case EReturn(e):
                EReturn(e == null ? null : transformFieldAssignments(e));
                
            case EBreak | EContinue | ETernary(_, _, _):
                expr;
                
            default:
                expr;
        }
        #end
    }
    
    private function preprocessCode(code:String):String
    {
        var lines = code.split("\n");
        var output = [];
        var conditionStack:Array<{condition:Bool, active:Bool, elseFound:Bool}> = [];
        var currentActive = true;
        var skipBlock = false;
        
        for (i in 0...lines.length) {
            var line = lines[i];
            var trimmed = line.trim();
            currentLine = i + 1;
            
            if (trimmed.startsWith("#")) {
                if (trimmed.startsWith("#if ")) {
                    var condition = trimmed.substr(4).trim();
                    var conditionMet = evaluatePreprocessorCondition(condition);
                    
                    conditionStack.push({
                        condition: conditionMet, 
                        active: currentActive,
                        elseFound: false
                    });
                    
                    currentActive = conditionMet && currentActive;
                    skipBlock = !currentActive;
                    
                    output.push(line);
                    continue;
                }
                else if (trimmed.startsWith("#elseif ")) {
                    if (conditionStack.length == 0) {
                        addError("Unexpected #elseif without #if", i + 1, 1);
                        output.push(line);
                        continue;
                    }
                    
                    var lastCondition = conditionStack[conditionStack.length - 1];
                    var condition = trimmed.substr(8).trim();
                    var conditionMet = evaluatePreprocessorCondition(condition);
                    
                    if (lastCondition.condition) {
                        currentActive = false;
                    } else {
                        currentActive = conditionMet && lastCondition.active;
                    }
                    
                    conditionStack[conditionStack.length - 1] = {
                        condition: conditionMet || lastCondition.condition,
                        active: lastCondition.active,
                        elseFound: false
                    };
                    
                    skipBlock = !currentActive;
                    output.push(line);
                    continue;
                }
                else if (trimmed == "#else") {
                    if (conditionStack.length == 0) {
                        addError("Unexpected #else without #if", i + 1, 1);
                        output.push(line);
                        continue;
                    }
                    
                    var lastCondition = conditionStack[conditionStack.length - 1];
                    
                    currentActive = !lastCondition.condition && lastCondition.active;
                    skipBlock = !currentActive;
                    
                    conditionStack[conditionStack.length - 1] = {
                        condition: true,
                        active: lastCondition.active,
                        elseFound: true
                    };
                    
                    output.push(line);
                    continue;
                }
                else if (trimmed == "#end") {
                    if (conditionStack.length == 0) {
                        addError("Unexpected #end without #if", i + 1, 1);
                        output.push(line);
                        continue;
                    }
                    
                    var lastCondition = conditionStack.pop();
                    currentActive = conditionStack.length > 0 ? 
                        conditionStack[conditionStack.length - 1].active : true;
                    skipBlock = !currentActive;
                    
                    output.push(line);
                    continue;
                }
                else if (trimmed.startsWith("#error ")) {
                    var message = trimmed.substr(7).trim();
                    if (currentActive) {
                        addError("Preprocessor error: " + message, i + 1, 1);
                    }
                    output.push(line);
                    continue;
                }
                else if (trimmed.startsWith("#warning ")) {
                    var message = trimmed.substr(9).trim();
                    if (currentActive) {
                        addWarning("Preprocessor warning: " + message, i + 1, 1);
                    }
                    output.push(line);
                    continue;
                }
                else if (trimmed.startsWith("#set ")) {
                    var setExpr = trimmed.substr(5).trim();
                    processSetDirective(setExpr, i + 1);
                    output.push(line);
                    continue;
                }
            }
            
            if (!skipBlock) {
                output.push(line);
            } else {
                output.push("");
            }
        }
        
        if (conditionStack.length > 0) {
            for (condition in conditionStack) {
                addError("Unclosed #if directive", lines.length, 1);
            }
        }
        
        return output.join("\n");
    }
    
    private function processSetDirective(expr:String, line:Int):Void
    {
        var parts = expr.split("=");
        if (parts.length != 2) {
            addError("Invalid #set directive syntax. Use: #set flag = value", line, 1);
            return;
        }
        
        var flag = parts[0].trim();
        var valueStr = parts[1].trim();
        
        var value:Dynamic = null;
        
        if (valueStr == "true") {
            value = true;
        } else if (valueStr == "false") {
            value = false;
        } else {
            var num = Std.parseFloat(valueStr);
            if (!Math.isNaN(num)) {
                value = num;
            } else {
                if ((valueStr.startsWith('"') && valueStr.endsWith('"')) || 
                    (valueStr.startsWith("'") && valueStr.endsWith("'"))) {
                    value = valueStr.substring(1, valueStr.length - 1);
                } else {
                    addError('Invalid value for #set: $valueStr', line, 1);
                    return;
                }
            }
        }
        
        preprocessorValues.set(flag, value);
    }
    
    private function evaluatePreprocessorCondition(condition:String):Bool
    {
        condition = condition.trim();
        
        while (condition.startsWith("(") && condition.endsWith(")")) {
            condition = condition.substring(1, condition.length - 1).trim();
        }
        
        if (condition == "true") return true;
        if (condition == "false") return false;
        
        if (condition.startsWith("!")) {
            var flag = condition.substr(1).trim();
            return !evaluatePreprocessorCondition(flag);
        }
        
        if (condition.indexOf(" && ") != -1) {
            var parts = condition.split(" && ");
            var result = true;
            for (part in parts) {
                result = result && evaluatePreprocessorCondition(part.trim());
                if (!result) break;
            }
            return result;
        }
        
        if (condition.indexOf(" || ") != -1) {
            var parts = condition.split(" || ");
            var result = false;
            for (part in parts) {
                result = result || evaluatePreprocessorCondition(part.trim());
                if (result) break;
            }
            return result;
        }
        
        if (condition.indexOf(" == ") != -1) {
            var parts = condition.split(" == ");
            if (parts.length == 2) {
                return evaluatePreprocessorCondition(parts[0].trim()) == evaluatePreprocessorCondition(parts[1].trim());
            }
        }
        
        if (condition.indexOf(" != ") != -1) {
            var parts = condition.split(" != ");
            if (parts.length == 2) {
                return evaluatePreprocessorCondition(parts[0].trim()) != evaluatePreprocessorCondition(parts[1].trim());
            }
        }
        
        if (preprocessorValues.exists(condition)) {
            var value = preprocessorValues.get(condition);
            if (Std.isOfType(value, Bool)) {
                return value;
            } else if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) {
                return value != 0;
            } else if (Std.isOfType(value, String)) {
                return value != "" && value != "0" && value.toLowerCase() != "false";
            }
            return value != null;
        }
        
        addWarning("Unknown preprocessor condition: " + condition, currentLine, currentColumn);
        return false;
    }
    
    private function validateBasicSyntax(code:String):Bool
    {
        var lines = code.split("\n");
        var inComment = false;
        var inString = false;
        var stringChar:Int = 0;
        var braceStack:Array<String> = [];
        var bracketStack:Array<String> = [];
        var parenStack:Array<String> = [];
        
        for (i in 0...lines.length) {
            var line = lines[i];
            var trimmed = line.trim();
            currentLine = i + 1;
            
            if (trimmed == "") {
                continue;
            }
            
            if (trimmed.startsWith("//")) {
                continue;
            }
            
            if (inComment) {
                if (trimmed.indexOf("*/") != -1) {
                    inComment = false;
                    line = line.substring(line.indexOf("*/") + 2);
                } else {
                    continue;
                }
            }
            
            var j = 0;
            while (j < line.length) {
                var char = line.charAt(j);
                var nextChar = j + 1 < line.length ? line.charAt(j + 1) : "";
                
                if (!inString && !inComment) {
                    if (char == "/" && nextChar == "*") {
                        inComment = true;
                        j += 2;
                        continue;
                    }
                    
                    if (char == '"' || char == "'") {
                        inString = true;
                        stringChar = char.charCodeAt(0);
                        j++;
                        continue;
                    }
                    
                    switch (char) {
                        case "{": braceStack.push("{");
                        case "}": 
                            if (braceStack.length == 0 || braceStack.pop() != "{") {
                                addError('Unmatched closing brace: }', i + 1, j + 1);
                            }
                        case "[": bracketStack.push("[");
                        case "]": 
                            if (bracketStack.length == 0 || bracketStack.pop() != "[") {
                                addError('Unmatched closing bracket: ]', i + 1, j + 1);
                            }
                        case "(": parenStack.push("(");
                        case ")": 
                            if (parenStack.length == 0 || parenStack.pop() != "(") {
                                addError('Unmatched closing parenthesis: )', i + 1, j + 1);
                            }
                    }
                    
                    if (requireSemicolons && strictMode) {
                        checkSemicolonRequirement(line, i + 1, j);
                    }
                } else if (inString) {
                    if (char == "\\") {
                        j++;
                    } else if (char.charCodeAt(0) == stringChar) {
                        inString = false;
                    }
                }
                
                j++;
            }
            
            if (inString) {
                addWarning('Unclosed string literal', i + 1, line.length);
            }
            
            if (inComment && i == lines.length - 1) {
                addWarning('Unclosed multi-line comment', i + 1, line.length);
            }
        }
        
        if (braceStack.length > 0) {
            for (brace in braceStack) {
                addError('Unclosed brace: $brace', lines.length, 1);
            }
        }
        
        if (bracketStack.length > 0) {
            for (bracket in bracketStack) {
                addError('Unclosed bracket: $bracket', lines.length, 1);
            }
        }
        
        if (parenStack.length > 0) {
            for (paren in parenStack) {
                addError('Unclosed parenthesis: $paren', lines.length, 1);
            }
        }
        
        return errors.length == 0;
    }
    
    private function checkSemicolonRequirement(line:String, lineNum:Int, pos:Int):Void
    {
        var trimmed = line.trim();
        if (trimmed == "" || trimmed.startsWith("//")) return;
        
        var noSemicolonEndings = [
            "{", "}", 
            "function", "class", "enum", "typedef", "interface",
            "if", "for", "while", "switch", "do",
            "try", "catch", "finally"
        ];
        
        for (ending in noSemicolonEndings) {
            if (trimmed.endsWith(ending) || trimmed.endsWith(ending + " ")) {
                return;
            }
        }
        
        if (!trimmed.endsWith(";") && !trimmed.endsWith("{") && !trimmed.endsWith("}")) {
            addWarning('Missing semicolon', lineNum, trimmed.length);
        }
    }
    
    private function addError(message:String, line:Int, column:Int):Void
    {
        errors.push('Line $line, column $column: $message');
    }
    
    private function addWarning(message:String, line:Int, column:Int):Void
    {
        if (reportWarnings) {
            warnings.push('Line $line, column $column: $message');
        }
    }
    
    private function tokenString(tk:Token):String
    {
        return switch (tk) {
            case TEof: "<eof>";
            case TConst(c): constString(c);
            case TId(s): s;
            case TOp(s): s;
            case TPOpen: "(";
            case TPClose: ")";
            case TBrOpen: "{";
            case TBrClose: "}";
            case TDot: ".";
            case TQuestionDot: "?.";
            case TComma: ",";
            case TSemicolon: ";";
            case TBkOpen: "[";
            case TBkClose: "]";
            case TQuestion: "?";
            case TDoubleDot: ":";
            case TMeta(id): "@" + id;
            case TPrepro(id): "#" + id;
            case TApostr: "'";
        }
    }
    
    private function constString(c:Const):String
    {
        return switch (c) {
            case CInt(v): Std.string(v);
            case CFloat(f): Std.string(f);
            case CString(s): '"$s"';
        }
    }
    
    public function getErrors():Array<String>
    {
        return errors.copy();
    }
    
    public function getWarnings():Array<String>
    {
        return warnings.copy();
    }
    
    public function hasErrors():Bool
    {
        return errors.length > 0;
    }
    
    public function hasWarnings():Bool
    {
        return warnings.length > 0;
    }
    
    public function clearErrors():Void
    {
        errors = [];
        warnings = [];
    }
    
    public function setStrictMode(enabled:Bool):Void
    {
        strictMode = enabled;
        requireSemicolons = enabled;
    }
    
    public function setParserParameters(params:{
        ?strictMode:Bool,
        ?requireSemicolons:Bool,
        ?reportWarnings:Bool
    }):Void
    {
        if (params.strictMode != null) strictMode = params.strictMode;
        if (params.requireSemicolons != null) requireSemicolons = params.requireSemicolons;
        if (params.reportWarnings != null) reportWarnings = params.reportWarnings;
    }
}