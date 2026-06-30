// fn_startResolver.sqf — [SERVER] one global PFH ticking every unpaused engagement.
// Resolved engagements are collected and removed AFTER the iteration so the HashMap isn't
// mutated mid-forEach. Idempotent — safe to call more than once. See spec §9.
if (!isServer) exitWith {};
if (!isNil "STCTI_resolverPFH") exitWith {};

STCTI_resolverPFH = [{
    private _done = [];
    {
        if !(_y get "paused") then {
            _y call STCTI_fnc_resolveTick;
            if (_y get "done") then { _done pushBack _x; };
        };
    } forEach STCTI_engagements;
    { STCTI_engagements deleteAt _x; } forEach _done;
}, STCTI_RESOLVE_INTERVAL] call CBA_fnc_addPerFrameHandler;

diag_log "[STCTI] Abstract combat resolver started.";
