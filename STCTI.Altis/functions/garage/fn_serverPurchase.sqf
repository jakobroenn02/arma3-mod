// fn_serverPurchase.sqf — [SERVER] params: [classname, price, spawnPos, requester]
// Validates the spend, then spawns. The authority side. See §E1.
params ["_class", "_price", "_pos", "_requester"];
if (!isServer) exitWith {};

if !(["money", _price] call STCTI_fnc_spend) exitWith {
    ["Not enough money."] remoteExec ["hint", _requester];
};

private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
_veh setDir (random 360);
[format ["Purchased %1.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")]] remoteExec ["hint", _requester];
// TODO (Phase 3): register into storedVehicles.
