// fn_startVirtualization.sqf — [SERVER] one PFH that proximity-caches active engagements and
// standing garrisons against the observer signal, under a global spawned-unit budget. See §9.
//
// Each tick:
//   1) DESPAWN/SYNC first — despawn anything no longer observed (frees budget), and resolve any
//      live-spawned fight whose loser was wiped. Doing this first means freed slots are reusable
//      the same tick.
//   2) GATHER candidates — engagements/garrisons that ARE observed but not yet spawned, each with
//      a priority (active fights outrank garrisons; nearer outranks farther) and a unit cost.
//   3) SPAWN in priority order until STCTI_SPAWN_BUDGET would be exceeded; the rest stay abstract
//      (engagements keep resolving as math; garrisons stay data) until budget frees.
// Hysteresis (STCTI_OBS_HYSTERESIS) on the despawn side prevents boundary thrash. Idempotent.
if (!isServer) exitWith {};
if (!isNil "STCTI_virtPFH") exitWith {};

STCTI_virtPFH = [{
    private _obs = call STCTI_fnc_observerPoints;

    // ---- 1) DESPAWN / SYNC (frees budget before we consider spawning) ----
    private _doneEng = [];
    {
        private _id  = _x;
        private _eng = _y;
        private _rec = (STCTI_state get "sectors") get _id;
        private _pos = _rec get "pos";
        private _r   = _rec get "radius";
        if (_eng get "spawned") then {
            // already live: despawn if the player has left (hysteresis), else check for a live win
            private _reach = false;
            { _x params ["_opos", "_orad"]; if ((_opos distance2D _pos) < (_r + _orad + STCTI_OBS_HYSTERESIS)) exitWith { _reach = true }; } forEach _obs;
            if (!_reach) then { _eng call STCTI_fnc_despawnEngagement } else { _eng call STCTI_fnc_syncEngagement };
        };
        if (_eng get "done") then { _doneEng pushBack _id; };
    } forEach STCTI_engagements;
    { STCTI_engagements deleteAt _x; } forEach _doneEng;

    {
        private _id = _x;
        if !(_id in keys STCTI_engagements) then {
            private _rec = (STCTI_state get "sectors") get _id;
            if (_rec get "spawned") then {
                private _pos = _rec get "pos";
                private _r   = _rec get "radius";
                private _reach = false;
                { _x params ["_opos", "_orad"]; if ((_opos distance2D _pos) < (_r + _orad + STCTI_OBS_HYSTERESIS)) exitWith { _reach = true }; } forEach _obs;
                if (!_reach) then { [_id] call STCTI_fnc_despawnGarrison; };
            };
        };
    } forEach (keys (STCTI_state get "sectors"));

    // ---- 2) GATHER observed-but-unspawned candidates ----
    // _cands element: [priority, cost, kind, ref]. Engagements get a large priority base so a
    // watched fight always outranks an idle garrison; within a kind, nearer (smaller dist) ranks higher.
    private _cands = [];
    {
        private _id  = _x;
        private _eng = _y;
        if !(_eng get "spawned") then {
            private _rec = (STCTI_state get "sectors") get _id;
            private _pos = _rec get "pos";
            private _r   = _rec get "radius";
            private _nd = 1e12; private _reach = false;
            { _x params ["_opos", "_orad"]; private _d = _opos distance2D _pos; if (_d < _nd) then { _nd = _d }; if (_d < (_r + _orad)) then { _reach = true }; } forEach _obs;
            if (_reach) then {
                private _cost = ([_eng get "attacker"] call STCTI_fnc_forceCount) + ([_eng get "defender"] call STCTI_fnc_forceCount);
                _cands pushBack [1e7 - _nd, _cost, "eng", _eng];
            };
        };
    } forEach STCTI_engagements;
    {
        private _id = _x;
        if !(_id in keys STCTI_engagements) then {
            private _rec = (STCTI_state get "sectors") get _id;
            if !(_rec get "spawned") then {
                private _pos = _rec get "pos";
                private _r   = _rec get "radius";
                private _nd = 1e12; private _reach = false;
                { _x params ["_opos", "_orad"]; private _d = _opos distance2D _pos; if (_d < _nd) then { _nd = _d }; if (_d < (_r + _orad)) then { _reach = true }; } forEach _obs;
                if (_reach) then {
                    private _cost = [_rec getOrDefault ["defenderForce", createHashMap]] call STCTI_fnc_forceCount;
                    _cands pushBack [0 - _nd, _cost, "gar", _id];
                };
            };
        };
    } forEach (keys (STCTI_state get "sectors"));

    // ---- 3) SPAWN in priority order within budget ----
    // Sort by priority desc via a [priority, index] key array (the candidate refs aren't sortable).
    private _order = [];
    { _order pushBack [_x select 0, _forEachIndex]; } forEach _cands;
    _order sort false;

    private _used = call STCTI_fnc_countSpawnedUnits;
    {
        private _cand = _cands select (_x select 1);
        _cand params ["_prio", "_cost", "_kind", "_ref"];
        if (_used + _cost <= STCTI_SPAWN_BUDGET) then {
            if (_kind isEqualTo "eng") then { _ref call STCTI_fnc_spawnEngagement; } else { [_ref] call STCTI_fnc_spawnGarrison; };
            _used = _used + _cost;
        };
    } forEach _order;
}, STCTI_VIRT_INTERVAL] call CBA_fnc_addPerFrameHandler;

diag_log "[STCTI] Virtualization manager started (budget + priority).";
