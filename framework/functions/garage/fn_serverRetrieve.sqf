// fn_serverRetrieve.sqf — [SERVER] params: [classname, spawnPos, spawnDir, requester]
// The authority side of "take vehicle out of the garage": the class must actually be in
// STCTI_state.storedVehicles (clients only see a broadcast copy), and the spot passes the same
// radius/water checks as a purchase. No cost — the vehicle was already paid for.
params ["_class", "_pos", "_dir", "_requester"];
if (!isServer) exitWith {};

private _stored = STCTI_state get "storedVehicles";
private _idx = _stored findIf { (_x select 0) isEqualTo _class };   // first of that class; entries are [cls, hits, fuel]
if (_idx < 0) exitWith { ["That vehicle is not in the garage."] remoteExec ["hint", _requester]; };

if (!isNil "STCTI_garage" && {!isNull STCTI_garage} && {_pos distance2D getPosATL STCTI_garage > STCTI_GARAGE_RADIUS + 10}) exitWith {
    ["Placement is too far from the garage."] remoteExec ["hint", _requester];
};
if (surfaceIsWater _pos) exitWith {
    ["Cannot place that in water."] remoteExec ["hint", _requester];
};

(_stored deleteAt _idx) params ["", "_hits", "_fuel"];

private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
_veh setDir _dir;
_veh setPosATL [_pos select 0, _pos select 1, 0];
_veh setVariable ["STCTI_owned", true, true];
// Restore the condition it was stored with (index-based, so unnamed hit points apply too).
_veh setFuel _fuel;
{ _veh setHitIndex [_forEachIndex, _x]; } forEach (_hits param [2, []]);

[STCTI_EV_GARAGE_CHANGED, [+_stored]] call CBA_fnc_globalEvent;
[format ["%1 taken out of the garage.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")]] remoteExec ["hint", _requester];
