// fn_startVirtualization.sqf — [SERVER] one PFH that proximity-caches both active engagements
// and standing sector garrisons against the observer signal. See design §9 (virtualization).
//   1) Engagements: observer arrives -> spawn both sides live (resolver pauses); observer leaves
//      -> despawn + recount (resolver resumes); a side wiped live -> resolve at that outcome.
//   2) Standing garrisons (sectors with no active engagement): spawn when observed, despawn +
//      recount survivors when not.
// Hysteresis (via the _spawned arg to isSectorObserved) prevents boundary thrash. Idempotent.
if (!isServer) exitWith {};
if (!isNil "STCTI_virtPFH") exitWith {};

STCTI_virtPFH = [{
    // 1) Active engagements — abstract <-> live handoff.
    private _doneEng = [];
    {
        private _id  = _x;
        private _eng = _y;
        private _spawned  = _eng get "spawned";
        private _observed = [_id, _spawned] call STCTI_fnc_isSectorObserved;
        if (_observed && {!_spawned}) then { _eng call STCTI_fnc_spawnEngagement; };
        if (!_observed && {_spawned}) then { _eng call STCTI_fnc_despawnEngagement; };
        if (_eng get "spawned") then { _eng call STCTI_fnc_syncEngagement; };  // live-win check
        if (_eng get "done") then { _doneEng pushBack _id; };
    } forEach STCTI_engagements;
    { STCTI_engagements deleteAt _x; } forEach _doneEng;

    // 2) Standing garrisons — skip sectors owned by an active engagement (handled above).
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

diag_log "[STCTI] Virtualization manager started (engagements + garrisons).";
