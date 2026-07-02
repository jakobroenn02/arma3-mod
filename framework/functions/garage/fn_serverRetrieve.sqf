// fn_serverRetrieve.sqf — [SERVER] params: [classname, spawnPos, spawnDir, requester]
// The authority side of "take vehicle out of the garage": the class must actually be in
// STCTI_state.storedVehicles (clients only see a broadcast copy), and the spot passes the same
// radius/water checks as a purchase. No cost — the vehicle was already paid for.
params ["_class", "_pos", "_dir", ["_reqIdx", -1], ["_requester", 0]];
if (!isServer) exitWith {};

private _stored = STCTI_state get "storedVehicles";
// Prefer the exact entry the client clicked (validated: same class at that index — the list
// may have changed since their menu opened); fall back to first-of-class.
private _idx = -1;
if (_reqIdx >= 0 && {(_stored param [_reqIdx, []]) param [0, ""] isEqualTo _class}) then {
    _idx = _reqIdx;
} else {
    _idx = _stored findIf { (_x select 0) isEqualTo _class };   // entries are [cls, hits, fuel]
};
if (_idx < 0) exitWith { ["That vehicle is not in the garage."] remoteExec ["hint", _requester]; };

if (!isNil "STCTI_garage" && {!isNull STCTI_garage} && {_pos distance2D getPosATL STCTI_garage > STCTI_GARAGE_RADIUS + 10}) exitWith {
    ["Placement is too far from the garage."] remoteExec ["hint", _requester];
};
if (surfaceIsWater _pos isNotEqualTo (_class isKindOf "Ship")) exitWith {
    [["Cannot place that in water.", "Boats have to be placed on water."] select (_class isKindOf "Ship")]
        remoteExec ["hint", _requester];
};

(_stored deleteAt _idx) params ["", "_hits", "_fuel"];

private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
_veh setDir _dir;
if (_class isKindOf "Ship") then {
    _veh setPos [_pos select 0, _pos select 1, 0];   // AGL — sea surface
} else {
    _veh setPosATL [_pos select 0, _pos select 1, 0];
};
_veh setVariable ["STCTI_owned", true, true];
// Restore the condition it was stored with (index-based, so unnamed hit points apply too).
_veh setFuel _fuel;
{ _veh setHitIndex [_forEachIndex, _x]; } forEach (_hits param [2, []]);

[STCTI_EV_GARAGE_CHANGED, [+_stored]] call CBA_fnc_globalEvent;
[format ["%1 taken out of the garage.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")]] remoteExec ["hint", _requester];
