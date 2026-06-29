// fn_setSectorOwner.sqf — [SERVER] params: [id, newOwner]
// The single mutation point for ownership. Flips owner, recolours, fires event. See §C3.
params ["_id", "_owner"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
if ((_rec get "owner") isEqualTo _owner) exitWith {};

_rec set ["owner", _owner];
_rec set ["captureProgress", if (_owner isEqualTo "player") then {1} else {0}];
[_id] call STCTI_fnc_updateSectorMarker;

// globalEvent so clients (economy HUD feedback, notifications) react everywhere.
[STCTI_EV_SECTOR_CAPTURED, [_id, _owner]] call CBA_fnc_globalEvent;
