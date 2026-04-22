package game.scripting;

import hscript.Expr;
import hscript.Parser.Token;

import rulescript.parsers.HxParser;

using StringTools;
using rulescript.Tools;

class RuleScriptParserEx extends HxParser
{
    private var warnedLines:Map<Int, Array<String>>;

    public var strictMode:Bool = true;
    public var reportWarnings:Bool = true;

    public var scriptPath:String = "";
    
    private var errors:Array<String>;
    private var warnings:Array<String>;
    private var currentLine:Int = 1;
    private var currentColumn:Int = 1;
    
    private var preprocStack:Array<{active:Bool, elseFound:Bool}>;
    private var currentActive:Bool = true;
    
    public function new(?strictMode:Bool = true)
    {
        super();
        this.strictMode = strictMode;
        this.errors = [];
        this.warnings = [];
        this.preprocStack = [];
        this.warnedLines = new Map();
    }
    
    override public function parse(code:String):Expr
    {
        errors = [];
        warnings = [];
        warnedLines.clear();
        currentLine = 1;
        currentColumn = 1;
        preprocStack = [];
        currentActive = true;
        
        try {
            var preprocessResult = preprocessCode(code);
            var processedCode = preprocessResult.code;
            var lineMap = preprocessResult.lineMap;
            
            if (strictMode && !validateBasicSyntax(processedCode)) {
                var errorMsg = errors.length > 0 ? errors.join("; ") : "Basic syntax validation failed";
                var pathPrefix = scriptPath != "" ? '[$scriptPath] ' : '';
                throw new haxe.Exception(pathPrefix + errorMsg);
            }
            
            var result = super.parse(processedCode);
            
            result = transformFieldAssignments(result);
            
            if (reportWarnings && warnings.length > 0) {
                var pathPrefix = scriptPath != "" ? '[$scriptPath] ' : '';
                trace('${pathPrefix}Parser warnings:');
                for (warning in warnings) {
                    trace('  ${pathPrefix}$warning');
                }
            }
            
            if (errors.length > 0) {
                var enhancedErrors = [];
                var pathPrefix = scriptPath != "" ? '[$scriptPath] ' : '';
                
                for (error in errors) {
                    var lineMatch = ~/Line (\d+), column (\d+): (.*)/;
                    if (lineMatch.match(error)) {
                        var processedLine = Std.parseInt(lineMatch.matched(1));
                        var column = Std.parseInt(lineMatch.matched(2));
                        var message = lineMatch.matched(3);
                        
                        var originalLine = if (processedLine <= lineMap.length) lineMap[processedLine - 1] else processedLine;
                        enhancedErrors.push('${pathPrefix}Line $originalLine, column $column: $message');
                    } else {
                        enhancedErrors.push(pathPrefix + error);
                    }
                }
                
                throw new haxe.Exception("Parser errors detected: " + enhancedErrors.join("; "));
            }
            
            return result;
        } catch (e:haxe.Exception) {
            var pathPrefix = scriptPath != "" ? '[$scriptPath] ' : '';
            var enhancedError = '${pathPrefix}Error at line $currentLine, column $currentColumn: ${e.message}';
            if (errors.length > 0) {
                enhancedError += "\n" + pathPrefix + "Additional errors: " + errors.join("; ");
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
    
    private function preprocessCode(code:String):{code:String, lineMap:Array<Int>}
    {
        var lines = code.split("\n");
        var output = [];
        var lineMap = [];
        preprocStack = [];
        currentActive = true;
        
        var inMultiLineComment = false;
        
        for (i in 0...lines.length) {
            var line = lines[i];
            currentLine = i + 1;
            
            var result = removeCommentsFromLine(line, inMultiLineComment);
            line = result.line;
            inMultiLineComment = result.inMultiLineComment;
            
            var trimmed = line.trim();
            
            if (trimmed.startsWith("#")) {
                if (trimmed.startsWith("#if ")) {
                    var condition = trimmed.substr(4).trim();
                    var conditionMet = evaluatePreprocessorCondition(condition);
                    
                    preprocStack.push({
                        active: currentActive,
                        elseFound: false
                    });
                    
                    currentActive = currentActive && conditionMet;
                    continue;
                }
                else if (trimmed.startsWith("#elseif ")) {
                    if (preprocStack.length == 0) {
                        addError("Unexpected #elseif without #if", i + 1, 1);
                        continue;
                    }
                    
                    var lastCondition = preprocStack[preprocStack.length - 1];
                    if (lastCondition.elseFound) {
                        addError("#elseif after #else", i + 1, 1);
                        currentActive = false;
                    } else {
                        var condition = trimmed.substr(8).trim();
                        var conditionMet = evaluatePreprocessorCondition(condition);
                        
                        if (currentActive) {
                            currentActive = false;
                        } else {
                            currentActive = lastCondition.active && conditionMet;
                        }
                        preprocStack[preprocStack.length - 1].elseFound = true;
                    }
                    continue;
                }
                else if (trimmed == "#else") {
                    if (preprocStack.length == 0) {
                        addError("Unexpected #else without #if", i + 1, 1);
                        continue;
                    }
                    
                    var lastCondition = preprocStack[preprocStack.length - 1];
                    if (lastCondition.elseFound) {
                        addError("#else after #else", i + 1, 1);
                        currentActive = false;
                    } else {
                        currentActive = lastCondition.active && !currentActive;
                        preprocStack[preprocStack.length - 1].elseFound = true;
                    }
                    continue;
                }
                else if (trimmed == "#end") {
                    if (preprocStack.length == 0) {
                        addError("Unexpected #end without #if", i + 1, 1);
                        continue;
                    }
                    
                    var lastCondition = preprocStack.pop();
                    currentActive = lastCondition.active;
                    continue;
                }
                else if (trimmed.startsWith("#error ")) {
                    var message = trimmed.substr(7).trim();
                    if (currentActive) {
                        addError("Preprocessor error: " + message, i + 1, 1);
                    }
                    continue;
                }
                else if (trimmed.startsWith("#warning ")) {
                    var message = trimmed.substr(9).trim();
                    if (currentActive) {
                        addWarning("Preprocessor warning: " + message, i + 1, 1);
                    }
                    continue;
                }
                else if (trimmed.startsWith("#set ")) {
                    var setExpr = trimmed.substr(5).trim();
                    if (currentActive) {
                        processSetDirective(setExpr, i + 1);
                    }
                    continue;
                }
            }
            
            if (currentActive) {
                output.push(line);
                lineMap.push(i + 1);
            }
        }
        
        if (preprocStack.length > 0) {
            addError("Unclosed #if directive", lines.length, 1);
        }
        
        return {code: output.join("\n"), lineMap: lineMap};
    }
    
    private function removeCommentsFromLine(line:String, inMultiLineComment:Bool):{line:String, inMultiLineComment:Bool}
    {
        var result = new StringBuf();
        var i = 0;
        var len = line.length;
        var inString = false;
        var stringChar:Int = 0;
        
        while (i < len) {
            var char = line.charAt(i);
            var nextChar = i + 1 < len ? line.charAt(i + 1) : "";
            
            if (!inString && !inMultiLineComment) {
                if (char == '"' || char == "'") {
                    inString = true;
                    stringChar = char.charCodeAt(0);
                    result.add(char);
                    i++;
                    continue;
                }
                
                if (char == "/" && nextChar == "/") {
                    result.add("  ");
                    i += 2;
                    while (i < len) {
                        result.add(" ");
                        i++;
                    }
                    break;
                }
                
                if (char == "/" && nextChar == "*") {
                    inMultiLineComment = true;
                    result.add("  ");
                    i += 2;
                    continue;
                }
                
                result.add(char);
                i++;
            } else if (inString) {
                if (char == "\\") {
                    result.add(char);
                    i++;
                    if (i < len) {
                        result.add(line.charAt(i));
                    }
                } else if (char.charCodeAt(0) == stringChar) {
                    inString = false;
                    result.add(char);
                } else {
                    result.add(char);
                }
                i++;
            } else if (inMultiLineComment) {
                if (char == "*" && nextChar == "/") {
                    inMultiLineComment = false;
                    result.add("  ");
                    i += 2;
                } else {
                    result.add(" ");
                    i++;
                }
            }
        }
        
        return {line: result.toString(), inMultiLineComment: inMultiLineComment};
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
            var subCondition = condition.substr(1).trim();
            return !evaluatePreprocessorCondition(subCondition);
        }
        
        var andIndex = condition.indexOf(" && ");
        if (andIndex != -1) {
            var left = condition.substring(0, andIndex).trim();
            var right = condition.substring(andIndex + 4).trim();
            return evaluatePreprocessorCondition(left) && evaluatePreprocessorCondition(right);
        }
        
        var orIndex = condition.indexOf(" || ");
        if (orIndex != -1) {
            var left = condition.substring(0, orIndex).trim();
            var right = condition.substring(orIndex + 4).trim();
            return evaluatePreprocessorCondition(left) || evaluatePreprocessorCondition(right);
        }
        
        var eqIndex = condition.indexOf(" == ");
        if (eqIndex != -1) {
            var left = condition.substring(0, eqIndex).trim();
            var right = condition.substring(eqIndex + 4).trim();
            return evaluatePreprocessorValue(left) == evaluatePreprocessorValue(right);
        }
        
        var neqIndex = condition.indexOf(" != ");
        if (neqIndex != -1) {
            var left = condition.substring(0, neqIndex).trim();
            var right = condition.substring(neqIndex + 4).trim();
            return evaluatePreprocessorValue(left) != evaluatePreprocessorValue(right);
        }
        
        return evaluatePreprocessorValue(condition) == true;
    }
    
    private function evaluatePreprocessorValue(value:String):Dynamic
    {
        value = value.trim();
        
        if (value == "true") return true;
        if (value == "false") return false;
        
        var intVal = Std.parseInt(value);
        if (intVal != null) return intVal != 0;
        
        var floatVal = Std.parseFloat(value);
        if (!Math.isNaN(floatVal)) return floatVal != 0;
        
        if (preprocessorValues.exists(value)) {
            var val = preprocessorValues.get(value);

            if (Std.isOfType(val, Bool)) return val;
            if (Std.isOfType(val, Int) || Std.isOfType(val, Float)) return val != 0;
            if (Std.isOfType(val, String)) {
                var str:String = val;
                return str != "" && str != "0" && str.toLowerCase() != "false";
            }
            return val != null;
        }
        
        if ((value.startsWith('"') && value.endsWith('"')) || 
            (value.startsWith("'") && value.endsWith("'"))) {
            var strVal = value.substring(1, value.length - 1);
            return strVal != "" && strVal != "0" && strVal.toLowerCase() != "false";
        }
        
        addWarning("Unknown preprocessor identifier: " + value, currentLine, currentColumn);
        return false;
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
    
    private function validateBasicSyntax(code:String):Bool
    {
        var lines = code.split("\n");
        var inComment:Bool = false;
        var inString:Bool = false;
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
            var lineLength = line.length;
            while (j < lineLength) {
                var char = line.charAt(j);
                var nextChar = j + 1 < lineLength ? line.charAt(j + 1) : "";
                
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
                addWarning('Unclosed string literal', i + 1, lineLength);
            }
            
            if (inComment && i == lines.length - 1) {
                addWarning('Unclosed multi-line comment', i + 1, lineLength);
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
    
    public function setParserParameters(params:{
        ?strictMode:Bool,
        ?reportWarnings:Bool
    }):Void
    {
        if (params.strictMode != null) strictMode = params.strictMode;
        if (params.reportWarnings != null) reportWarnings = params.reportWarnings;
    }
}