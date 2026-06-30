// fn_serverPurchase.sqf — [SERVER] params: [classname, spawnPos, requester]
// The authority side: looks the item up in STCTI_garageCatalog (price + required unlock are NOT
// trusted from the client), checks the unlock and affordability, then spawns. See §E1.
params ["_class", "_pos", "_requester"];
if (!isServer) exitWith {};

private _item = STCTI_garageCatalog select { (_x select 1) isEqualTo _class };
if (_item isEqualTo []) exitWith { ["Unknown garage item."] remoteExec ["hint", _requester]; };
(_item select 0) params ["_label", "_cls", "_price", "_unlock"];

if (_unlock != "" && {!(_unlock in STCTI_unlocks)}) exitWith {
    ["That requires an unlock you don't have yet."] remoteExec ["hint", _requester];
};
if !(["money", _price] call STCTI_fnc_spend) exitWith {
    ["Not enough money."] remoteExec ["hint", _requester];
};

private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
_veh setDir (random 360);
[format ["Purchased %1.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")]] remoteExec ["hint", _requester];
// TODO (Phase 3): register into storedVehicles.
