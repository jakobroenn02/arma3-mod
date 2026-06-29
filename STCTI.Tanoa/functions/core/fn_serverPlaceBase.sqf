// fn_serverPlaceBase.sqf — [SERVER] params: [baseIndex, requester]
// Establishes the campaign base from STCTI_START_BASES (once): drops the Arsenal crate
// and the garage flag at their exact coordinates, then deploys the requester at the
// exact spawn point. No base building is created — these are just interaction points.
params ["_index", "_requester"];
if (!isServer) exitWith {};
if (_index < 0 || {_index >= count STCTI_START_BASES}) exitWith {};

(STCTI_START_BASES select _index) params ["_label", "_spawnPos", "_spawnDir", "_arsenalPos", "_garagePos"];

if (isNil "STCTI_baseEstablished") then {
    STCTI_baseEstablished = true;

    STCTI_BASE_POS = _spawnPos;
    STCTI_BASE_DIR = _spawnDir;
    publicVariable "STCTI_BASE_POS";
    publicVariable "STCTI_BASE_DIR";

    // Arsenal — a small equipment crate turned into a full Arsenal (Inventory action).
    private _ars = createVehicle ["Box_NATO_Equip_F", _arsenalPos, [], 0, "CAN_COLLIDE"];
    _ars setPosATL [_arsenalPos select 0, _arsenalPos select 1, 0];
    ["AmmoboxInit", [_ars, true]] remoteExec ["BIS_fnc_arsenal", 0, true];

    // Garage — a flag as the interaction point; clients attach the purchase menu (E3).
    STCTI_garage = createVehicle ["Flag_NATO_F", _garagePos, [], 0, "CAN_COLLIDE"];
    STCTI_garage setPosATL [_garagePos select 0, _garagePos select 1, 0];
    STCTI_garage setVariable ["STCTI_isGarage", true, true];
    publicVariable "STCTI_garage";

    diag_log format ["[STCTI] Base established: %1 at %2", _label, _spawnPos];
};

// Deploy the requesting player at the exact spawn point.
[STCTI_BASE_POS, STCTI_BASE_DIR] remoteExec ["STCTI_fnc_deployPlayer", _requester];
