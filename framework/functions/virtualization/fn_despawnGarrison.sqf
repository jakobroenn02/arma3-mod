// fn_despawnGarrison.sqf — [SERVER] params: [_id]
// Recounts the sector's living garrison back into defenderForce (losses preserved), deletes the
// units, and marks the sector unspawned. Re-approaching respawns whatever survived. See design §9.
params ["_id"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
if !(_rec get "spawned") exitWith {};

private _grp = _rec getOrDefault ["garrisonGroup", grpNull];
if (!isNull _grp) then {
    _rec set ["defenderForce", [_grp] call STCTI_fnc_recountForce];
    { deleteVehicle _x } forEach units _grp;
    deleteGroup _grp;
};
_rec set ["garrisonGroup", grpNull];
_rec set ["spawned", false];
