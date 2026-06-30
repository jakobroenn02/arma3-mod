// fn_spawnGarrison.sqf — [SERVER] params: [_id]
// Instantiates a sector's virtual garrison (its defenderForce) as live units of the owner's
// side, in a loose defensive GUARD posture. Idempotent (skips if already spawned). Called by the
// virtualization manager when a player starts observing the sector. See design §9.
params ["_id"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
if (_rec get "spawned") exitWith {};

private _force = _rec getOrDefault ["defenderForce", createHashMap];
private _n = 0; { _n = _n + _y } forEach _force;

_rec set ["spawned", true];                 // mark spawned even when empty (nothing to place)
if (_n <= 0) exitWith {};

private _ownerKey = if ((_rec get "owner") isEqualTo "player") then { "player" } else { "enemy" };
private _pos      = _rec get "pos";
private _r        = _rec get "radius";

private _grp = [_force, _ownerKey, _pos, _r * 0.6] call STCTI_fnc_spawnForce;
private _wp  = _grp addWaypoint [_pos, _r * 0.4];
_wp setWaypointType "GUARD";
_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";
_rec set ["garrisonGroup", _grp];
