// fn_spawnSectorGarrison.sqf — [SERVER] params: [id, count]
// Spawns a dumb enemy infantry garrison (always-on in the slice). See §C4.
params ["_id", ["_count", 6]];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
if (_rec get "spawned") exitWith {};

private _pos  = _rec get "pos";
private _r    = _rec get "radius";
private _pool = STCTI_FACTION_ENEMY get "riflemen";
private _grp  = createGroup [STCTI_SIDE_ENEMY, true];

for "_i" from 1 to _count do {
    private _spawn = _pos getPos [random _r, random 360];
    (selectRandom _pool) createUnit [_spawn, _grp, "", 1, "PRIVATE"];
};

// Light defensive guard around the sector centre.
private _wp = _grp addWaypoint [_pos, _r * 0.5];
_wp setWaypointType "GUARD";
_grp setBehaviour "SAFE";
_grp setCombatMode "YELLOW";

_rec set ["garrison", units _grp];
_rec set ["spawned", true];
