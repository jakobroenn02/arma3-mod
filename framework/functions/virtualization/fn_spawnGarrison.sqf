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
private _heading  = _rec getOrDefault ["heading", 0];
private _layout   = _rec getOrDefault ["layout", "town_light"];

private _grp = [_force, _ownerKey, _pos, _r * 0.6, _heading, _layout, _rec getOrDefault ["hardening", []]] call STCTI_fnc_spawnForce;
_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";

// Hold the sector with a GUARD waypoint on its centre. (LAMBS's danger FSM still drives the
// AI's tactics automatically — cover, suppression, building use. Explicit LAMBS task orders like
// taskGarrison are deferred to the Phase 5 order layer, where the signatures are wrapped properly.)
private _wp = _grp addWaypoint [_pos, _r * 0.4];
_wp setWaypointType "GUARD";

_rec set ["garrisonGroup", _grp];
[_grp] call STCTI_fnc_offloadGroup;   // headless-client offload (no-op in SP)
