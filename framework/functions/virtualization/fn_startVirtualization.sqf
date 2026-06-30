// fn_startVirtualization.sqf — [SERVER] one PFH that proximity-caches sector garrisons:
// spawn a sector's garrison when a player observes it, despawn (and recount survivors back to
// data) when nobody does. Sectors with an active abstract engagement are skipped — those belong
// to the resolver / engagement handoff (#2-iii), not the standing-garrison manager. Idempotent.
// See design §9 (virtualization). Hysteresis (via the _spawned arg) prevents boundary thrash.
if (!isServer) exitWith {};
if (!isNil "STCTI_virtPFH") exitWith {};

STCTI_virtPFH = [{
    {
        private _id = _x;
        if !(_id in keys STCTI_engagements) then {
            private _rec      = (STCTI_state get "sectors") get _id;
            private _spawned  = _rec get "spawned";
            private _observed = [_id, _spawned] call STCTI_fnc_isSectorObserved;
            if (_observed && {!_spawned}) then { [_id] call STCTI_fnc_spawnGarrison; };
            if (!_observed && {_spawned}) then { [_id] call STCTI_fnc_despawnGarrison; };
        };
    } forEach (keys (STCTI_state get "sectors"));
}, STCTI_VIRT_INTERVAL] call CBA_fnc_addPerFrameHandler;

diag_log "[STCTI] Garrison virtualization manager started.";
