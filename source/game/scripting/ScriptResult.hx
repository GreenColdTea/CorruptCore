package game.scripting;

enum abstract ScriptResult(Int) {
    final Function_Continue = 0;
    final Function_Stop = 1;
    final Function_Stop_Lua = 2;

    @:from public static function fromInt(value:Int):ScriptResult {
        return switch value {
            case 0: Function_Continue;
            case 1: Function_Stop;
            case 2: Function_Stop_Lua;
            default: throw "Invalid ScriptResult value: " + value;
        }
    }
    
    @:to public function toInt():Int {
        return this;
    }
}