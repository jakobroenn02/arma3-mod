// fn_startConvoys.sqf — [SERVER] enemy supply convoys (map-physical logistics, roadmap §5).
// When a player is near the front, the enemy occasionally runs a convoy (escort MRAP + two
// trucks) between two ADJACENT enemy sectors. Stop it (kill or immobilize every vehicle) and
// the destination garrison loses riflemen for the missed supplies, plus a resource loot
// credit; surviving trucks are ordinary un-owned vehicles — drive one home and capture it into
// garage stock. One convoy at a time; convoys spawn only near players (no ghost traffic
// grinding the sim), and stragglers clean themselves up. Double-start guarded.
if (!isServer) exitWith {};
if (!isNil "STCTI_convoyPFH") exitWith {};

STCTI_activeConvoy = [];
STCTI_nextConvoyAt = time + STCTI_CONVOY_INTERVAL;

STCTI_convoyPFH = [{
    // 1) Watch the running convoy: arrival despawns it quietly; a stop pays out.
    if !(STCTI_activeConvoy isEqualTo []) then {
        STCTI_activeConvoy params ["_vehs", "_destId", "_grp"];
        private _destRec = (STCTI_state get "sectors") get _destId;
        private _alive = _vehs select { alive _x && {canMove _x} && {({alive _x} count crew _x) > 0} };
        private _arrived = !isNil "_destRec"
            && {(_vehs findIf { alive _x && {_x distance2D (_destRec get "pos") < 120} }) > -1};
        if (_arrived) then {
            { { deleteVehicle _x } forEach (crew _x); deleteVehicle _x; } forEach (_vehs select { alive _x });
            { deleteVehicle _x } forEach (units _grp);   // crew that bailed from lost trucks
            deleteGroup _grp;
            STCTI_activeConvoy = [];
        };
        if (!_arrived && {_alive isEqualTo []}) then {
            // Stopped. Loot + starve the destination garrison (if it's still enemy-held).
            { [_x select 0, _x select 1] call STCTI_fnc_addRes; } forEach STCTI_CONVOY_LOOT;
            if (!isNil "_destRec" && {(_destRec get "owner") isEqualTo "enemy"}) then {
                private _df = _destRec getOrDefault ["defenderForce", createHashMap];
                _df set ["rifleman", ((_df getOrDefault ["rifleman", 0]) - STCTI_CONVOY_GARRISON_LOSS) max 0];
            };
            ["STCTI_Info", [format ["Enemy convoy stopped — %1's garrison goes without.", _destId]]]
                remoteExec ["BIS_fnc_showNotification", 0];
            diag_log format ["[STCTI] Enemy convoy to %1 destroyed by players.", _destId];
            // Leave the survivors/wrecks to be looted or captured; sweep them later.
            [{
                params ["_vehs"];
                {
                    private _veh = _x;
                    if (!isNull _veh && {!(_veh getVariable ["STCTI_owned", false])}
                        && {({ alive _x && {(_x distance2D _veh) < 500} } count allPlayers) == 0}) then {
                        { deleteVehicle _x } forEach (crew _veh);
                        deleteVehicle _veh;
                    };
                } forEach _vehs;
            }, [_vehs], 600] call CBA_fnc_waitAndExecute;
            deleteGroup _grp;
            STCTI_activeConvoy = [];
        };
    };

    // 2) Maybe dispatch a new one.
    if !(STCTI_activeConvoy isEqualTo []) exitWith {};
    if (time < STCTI_nextConvoyAt) exitWith {};

    // Route: two adjacent enemy sectors with a player near an endpoint (someone to see it).
    private _sectors = STCTI_state get "sectors";
    private _routes = [];
    {
        private _rec = _y;
        if ((_rec get "owner") isEqualTo "enemy") then {
            private _p = _rec get "pos";
            if (({ alive _x && {(_x distance2D _p) < STCTI_CONVOY_SPAWNRANGE} } count allPlayers) > 0) then {
                {
                    private _o = _sectors get _x;
                    if (!isNil "_o" && {(_o get "owner") isEqualTo "enemy"}) then {
                        _routes pushBack [_rec get "id", _x];
                    };
                } forEach (_rec getOrDefault ["adjacent", []]);
            };
        };
    } forEach _sectors;
    if (_routes isEqualTo []) exitWith {};

    (selectRandom _routes) params ["_fromId", "_toId"];
    private _from = (_sectors get _fromId) get "pos";
    private _to   = (_sectors get _toId)   get "pos";
    private _ef   = STCTI_FACTION_POOL get ((STCTI_FACTION_POOL get STCTI_PLAYER_FACTION) get "enemy");
    private _grp  = createGroup [STCTI_SIDE_ENEMY, false];
    private _vehs = [];
    {
        _x params ["_cls", "_back"];
        private _p   = _from getPos [_back, (_from getDir _to) + 180];
        private _veh = createVehicle [_cls, _p, [], 0, "NONE"];
        _veh setDir (_from getDir _to);
        private _crewG = createVehicleCrew _veh;
        { [_x] joinSilent _grp; } forEach units _crewG;
        deleteGroup _crewG;
        _vehs pushBack _veh;
    } forEach [
        [(_ef get "units") getOrDefault ["mrap", "O_MRAP_02_hmg_F"], 0],
        [(_ef get "units") getOrDefault ["truck", "O_Truck_03_transport_F"], 25],
        [(_ef get "units") getOrDefault ["truck", "O_Truck_03_transport_F"], 45]
    ];
    _grp setBehaviour "SAFE";
    _grp setSpeedMode "LIMITED";
    _grp setFormation "COLUMN";
    private _wp = _grp addWaypoint [_to, 30];
    _wp setWaypointType "MOVE";

    STCTI_activeConvoy = [_vehs, _toId, _grp];
    STCTI_nextConvoyAt = time + STCTI_CONVOY_INTERVAL;
    diag_log format ["[STCTI] Enemy convoy dispatched: %1 -> %2.", _fromId, _toId];
}, 20] call CBA_fnc_addPerFrameHandler;

diag_log "[STCTI] Convoy manager started.";
