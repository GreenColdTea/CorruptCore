package game.modchart;

import game.modchart.events.ModEvent;
import game.modchart.events.BaseEvent;

/**
 * Manages and executes mod events in chronological order
 * Handles both modifier-specific events and general timeline events
 */
class EventTimeline {
    // Storage for events organized by modifier name
    public var modEvents:Map<String, Array<ModEvent>> = [];
    
    // Storage for general timeline events
    public var events:Array<BaseEvent> = [];
    
    public function new() {}

    /**
     * Initializes storage for a new modifier's events
     */
    public function addMod(modName:String) {
        modEvents.set(modName, []);
    }

    /**
     * Adds an event to the timeline and maintains execution order
     */
    public function addEvent(event:BaseEvent) {
        if (Std.isOfType(event, ModEvent)) {
            addModEvent(cast event);
        } else if (!events.contains(event)) {
            addGeneralEvent(event);
        }
    }

    /**
     * Handles adding modifier-specific events
     */
    private function addModEvent(modEvent:ModEvent) {
        var modName = modEvent.modName;
        
        // Ensure modifier has event storage
        if (!modEvents.exists(modName)) {
            addMod(modName);
        }
        
        var eventList = modEvents.get(modName);
        if (!eventList.contains(modEvent)) {
            eventList.push(modEvent);
            sortModEventsByStep(eventList);
        }
    }

    /**
     * Handles adding general timeline events
     */
    private function addGeneralEvent(event:BaseEvent) {
        events.push(event);
        sortBaseEventsByStep(events);
    }

    /**
     * Sorts modifier events by their execution step for proper timeline order
     */
    private function sortModEventsByStep(eventArray:Array<ModEvent>) {
        eventArray.sort((a, b) -> Std.int(a.executionStep - b.executionStep));
    }

    /**
     * Sorts base events by their execution step for proper timeline order
     */
    private function sortBaseEventsByStep(eventArray:Array<BaseEvent>) {
        eventArray.sort((a, b) -> Std.int(a.executionStep - b.executionStep));
    }

    /**
     * Updates and executes all events that are due at the current step
     */
    public function update(currentStep:Float) {
        executeModEvents(currentStep);
        executeGeneralEvents(currentStep);
    }

    /**
     * Executes all modifier-specific events
     */
    private function executeModEvents(currentStep:Float) {
        for (modName in modEvents.keys()) {
            executeModEventList(modEvents.get(modName), currentStep);
        }
    }

    /**
     * Executes events for a specific modifier
     */
    private function executeModEventList(eventList:Array<ModEvent>, currentStep:Float) {
        var completedEvents:Array<ModEvent> = [];
        
        for (event in eventList) {
            if (shouldSkipEvent(event)) continue;
            
            if (currentStep >= event.executionStep) {
                event.run(currentStep);
            } else {
                // Events are sorted, so we can stop checking once we find one that's not ready
                break;
            }
            
            if (event.finished) {
                completedEvents.push(event);
            }
        }
        
        cleanupCompletedModEvents(eventList, completedEvents);
    }

    /**
     * Executes all general timeline events
     */
    private function executeGeneralEvents(currentStep:Float) {
        var completedEvents:Array<BaseEvent> = [];
        
        for (event in events) {
            if (shouldSkipEvent(event)) continue;
            
            if (currentStep >= event.executionStep) {
                event.run(currentStep);
            } else {
                // Events are sorted, so we can stop checking once we find one that's not ready
                break;
            }
            
            if (event.finished) {
                completedEvents.push(event);
            }
        }
        
        cleanupCompletedBaseEvents(events, completedEvents);
    }

    /**
     * Checks if an event should be skipped during execution
     */
    private inline function shouldSkipEvent(event:BaseEvent):Bool {
        return event.ignoreExecution || event.finished;
    }

    /**
     * Removes completed modifier events from the event list
     */
    private function cleanupCompletedModEvents(eventList:Array<ModEvent>, completedEvents:Array<ModEvent>) {
        for (completedEvent in completedEvents) {
            eventList.remove(completedEvent);
        }
    }

    /**
     * Removes completed base events from the event list
     */
    private function cleanupCompletedBaseEvents(eventList:Array<BaseEvent>, completedEvents:Array<BaseEvent>) {
        for (completedEvent in completedEvents) {
            eventList.remove(completedEvent);
        }
    }
}