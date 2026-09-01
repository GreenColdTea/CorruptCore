// How to basically change hardcoded state to softcoded

import haxe.ds.StringMap;

/* 
 * Map to store which states are softcoded
 * Key: State class name as String
 * Value: Bool indicating if the state is softcoded
 */
var softcodedStates:StringMap<Bool> = new StringMap<Bool>();

/* 
 * Set whether a specific state should be softcoded
 * @param stateClassName The full class name of the state (e.g., "game.states.MainMenuState")
 * @param isSoftcoded Bool indicating if the state should be softcoded
 */
function setSoftcodedState(stateClassName:String, isSoftcoded:Bool):Void {
    softcodedStates.set(stateClassName, isSoftcoded);
}

/* 
 * Check if a specific state is marked as softcoded
 * @param stateClassName The full class name of the state to check
 * @return Bool indicating if the state is softcoded
 */
function isStateSoftcoded(stateClassName:String):Bool {
    return softcodedStates.exists(stateClassName) && softcodedStates.get(stateClassName);
}

/* 
 * Initialize default softcoded states
 * Add all states that should be softcoded by default here
 */
function initializeSoftcodedStates():Void {
    // Set MainMenuState as softcoded by default
    setSoftcodedState("game.states.MainMenuState", true);
    
    // Add more states here as needed:
    // setSoftcodedState("game.states.TitleState", true);
    // setSoftcodedState("game.states.StoryMenuState", true);
    // and etc. I'm lazy writing all of them lol
}

/* 
 * Called when the global script is created
 */
function onCreate()
{
    initializeSoftcodedStates();
}

/* 
 * Toggle the softcoded status of a state
 * @param stateClassName The full class name of the state to toggle
 * @return The new softcoded status of the state
 */
function toggleSoftcodedState(stateClassName:String):Bool 
{
    var currentState = isStateSoftcoded(stateClassName);
    setSoftcodedState(stateClassName, !currentState);
    return !currentState;
}

/* 
 * Get all states that are currently marked as softcoded
 * @return Array of state class names that are softcoded
 */
function getAllSoftcodedStates():Array<String> {
    var states:Array<String> = [];
    for (key in softcodedStates.keys()) {
        if (softcodedStates.get(key)) {
            states.push(key);
        }
    }
    return states;
}