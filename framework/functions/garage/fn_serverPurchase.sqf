// fn_serverPurchase.sqf — [SERVER] params: [classname, spawnPos, spawnDir, requester]
// The authority side: looks the item up in STCTI_garageCatalog (price + required unlock are NOT
// trusted from the client), checks the unlock and affordability, then spawns at the player's
// chosen placement transform. See §E1.
params ["_class", "_pos", "_dir", "_requester"];
if (!isServer) exitWith {};

private _item = STCTI_garageCatalog select { (_x select 1) isEqualTo _class };
if (_item isEqualTo []) exitWith { ["Unknown garage item."] remoteExec ["hint", _requester]; };
(_item select 0) params ["_label", "_cls", "_price", "_unlock", ["_fuelCost", 0]];

if (_unlock != "" && {!(_unlock in STCTI_unlocks)}) exitWith {
    ["That requires an unlock you don't have yet."] remoteExec ["hint", _requester];
};
// Position is not trusted either: must be near the garage flag. Slack over the client's
// clamp radius absorbs the ghost-to-surface snap and any float drift.
if (!isNil "STCTI_garage" && {!isNull STCTI_garage} && {_pos distance2D getPosATL STCTI_garage > STCTI_GARAGE_RADIUS + 10}) exitWith {
    ["Placement is too far from the garage."] remoteExec ["hint", _requester];
};
if (surfaceIsWater _pos) exitWith {
    ["Cannot place that in water."] remoteExec ["hint", _requester];
};
if !([["money", _price], ["fuel", _fuelCost]] call STCTI_fnc_spendMulti) exitWith {
    [format ["Not enough resources (needs %1 money + %2 fuel).", _price, _fuelCost]] remoteExec ["hint", _requester];
};

private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
_veh setDir _dir;
_veh setPosATL [_pos select 0, _pos select 1, 0];
// Owned marks it as the player's until it explodes: storable (fn_serverStore) and
// retrievable (fn_serverRetrieve) from then on. Public so clients can find storables.
_veh setVariable ["STCTI_owned", true, true];
[format ["Purchased %1.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")]] remoteExec ["hint", _requester];
