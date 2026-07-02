// fn_startIntel.sqf — [SERVER] periodic enemy-garrison intel (roadmap Phase 12 / design §4 —
// the military-complex effect the design doc promised). While the players hold at least one
// MILITARY sector, every STCTI_INTEL_INTERVAL seconds the enemy sectors' map dots are annotated
// with the current garrison strength (live garrisons recounted, so the number is honest).
// Lose every military site and the annotations fade back to plain names on the next tick.
// Markers are global objects, so setMarkerText broadcasts to every client for free.
if (!isServer) exitWith {};
if (!isNil "STCTI_intelPFH") exitWith {};

STCTI_intelPFH = [{
    private _haveIntel = ((values (STCTI_state get "sectors")) findIf {
        (_x get "type") isEqualTo "military" && {(_x get "owner") isEqualTo "player"}
    }) > -1;

    {
        private _rec = _y;
        private _dot = "mk_" + _x + "_dot";
        if (_haveIntel && {(_rec get "owner") isEqualTo "enemy"}) then {
            // Live truth wins: recount a spawned garrison, else trust the virtual map.
            private _grp = _rec getOrDefault ["garrisonGroup", grpNull];
            private _df  = if ((_rec get "spawned") && {!isNull _grp}) then {
                [_grp] call STCTI_fnc_recountForce
            } else {
                _rec getOrDefault ["defenderForce", createHashMap]
            };
            private _n = 0;
            { _n = _n + _y; } forEach _df;
            _dot setMarkerText format ["%1  [str %2]", _x, _n];
        } else {
            _dot setMarkerText _x;
        };
    } forEach (STCTI_state get "sectors");
}, STCTI_INTEL_INTERVAL] call CBA_fnc_addPerFrameHandler;

diag_log format ["[STCTI] Intel manager started (scan every %1s while a military site is held).", STCTI_INTEL_INTERVAL];
