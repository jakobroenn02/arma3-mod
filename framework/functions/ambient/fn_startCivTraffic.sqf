// fn_startCivTraffic.sqf — [SERVER] ambient civilian traffic (Phase 8, design §6.2).
// Purely atmospheric: a few civilian cars wander roads near towns that a player is actually
// close to. No gameplay effect, hard-capped (STCTI_CIV_CAP), proximity-virtualized — cars
// despawn when no player is within STCTI_CIV_DESPAWN or when they die. Double-start guarded.
if (!isServer) exitWith {};
if (!STCTI_CIVILIANS) exitWith { diag_log "[STCTI] Civilian traffic disabled (STCTI_CIVILIANS)."; };
if (!isNil "STCTI_civPFH") exitWith {};

STCTI_civVehicles = [];
STCTI_civPFH = [{
    // Prune: dead or abandoned-by-players cars are removed (crew first — deleteVehicle on a
    // crewed vehicle leaves the men standing on the road).
    STCTI_civVehicles = STCTI_civVehicles select {
        _x params ["_veh", "_grp"];
        private _keep = alive _veh
            && {({ alive _x && {(_x distance2D _veh) < STCTI_CIV_DESPAWN} } count allPlayers) > 0};
        if (!_keep) then {
            { deleteVehicle _x } forEach (crew _veh);
            deleteVehicle _veh;
            if (!isNull _grp) then { deleteGroup _grp; };
        };
        _keep
    };
    if (count STCTI_civVehicles >= STCTI_CIV_CAP) exitWith {};

    // Spawn where it matters: a town sector with a player nearby.
    private _towns = (values (STCTI_state get "sectors")) select {
        (_x get "type") isEqualTo "town"
        && {private _p = _x get "pos";
            ({ alive _x && {(_x distance2D _p) < STCTI_CIV_SPAWNRANGE} } count allPlayers) > 0}
    };
    if (_towns isEqualTo []) exitWith {};
    private _town  = selectRandom _towns;
    private _tPos  = _town get "pos";
    private _roads = _tPos nearRoads 500;
    if (_roads isEqualTo []) exitWith {};   // roadless hamlet — try again next tick
    private _pos = getPos (selectRandom _roads);

    private _veh = createVehicle [selectRandom STCTI_CIV_CARS, _pos, [], 5, "NONE"];
    private _grp = createGroup [civilian, true];
    private _drv = _grp createUnit [selectRandom STCTI_CIV_MEN, _pos, [], 0, "NONE"];
    _drv moveInDriver _veh;
    _grp setBehaviour "CARELESS";
    _grp setSpeedMode "LIMITED";

    // Wander loop between two road points around the town.
    private _far = getPos (selectRandom (_tPos nearRoads 800));
    private _wp1 = _grp addWaypoint [_far, 20];
    _wp1 setWaypointType "MOVE";
    private _wp2 = _grp addWaypoint [_pos, 20];
    _wp2 setWaypointType "CYCLE";

    STCTI_civVehicles pushBack [_veh, _grp];
}, STCTI_CIV_INTERVAL] call CBA_fnc_addPerFrameHandler;

diag_log format ["[STCTI] Civilian traffic started (cap %1).", STCTI_CIV_CAP];
