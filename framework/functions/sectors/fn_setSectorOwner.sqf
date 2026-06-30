// fn_setSectorOwner.sqf — [SERVER] params: [id, newOwner]
// The single mutation point for ownership. Flips owner, recolours, fires event. See §C3.
params ["_id", "_owner"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
if ((_rec get "owner") isEqualTo _owner) exitWith {};

_rec set ["owner", _owner];
_rec set ["captureProgress", if (_owner isEqualTo "player") then {1} else {0}];

// Ownership changed: drop the previous owner's live garrison so the virtualization manager
// re-spawns the NEW owner's garrison (from defenderForce) on its next tick.
private _g = _rec getOrDefault ["garrisonGroup", grpNull];
if (!isNull _g) then { { deleteVehicle _x } forEach units _g; deleteGroup _g; };
_rec set ["garrisonGroup", grpNull];
_rec set ["spawned", false];

// On player capture, seed a baseline virtual garrison so an unobserved enemy attack has
// something to fight (rather than instantly flipping). Tune via STCTI_PLAYER_GARRISON.
// (When an abstract fight resolves, checkBreak overwrites this with the survivors.)
if (_owner isEqualTo "player") then {
    _rec set ["defenderForce", createHashMapFromArray [["rifleman", STCTI_PLAYER_GARRISON]]];
};

[_id] call STCTI_fnc_updateSectorMarker;

// globalEvent so clients (economy HUD feedback, notifications) react everywhere.
[STCTI_EV_SECTOR_CAPTURED, [_id, _owner]] call CBA_fnc_globalEvent;
