// fn_serverPlaceBase.sqf — [SERVER] params: [baseIndex, factionName, requester]
// Establishes the campaign base from STCTI_START_BASES (once): applies the chosen faction
// (fn_applyFaction), drops the Arsenal crate and the garage flag at their exact coordinates,
// then deploys the requester at the exact spawn point. No base building is created — these
// are just interaction points.
params ["_index", ["_faction", "NATO"], ["_requester", objNull]];
if (!isServer) exitWith {};
if (_index < 0 || {_index >= count STCTI_START_BASES}) exitWith {};

(STCTI_START_BASES select _index) params ["_label", "_spawnPos", "_spawnDir", "_arsenalPos", "_garagePos"];

if (isNil "STCTI_baseEstablished") then {
    STCTI_baseEstablished = true;

    // Faction first, so every spawn from here on (garrisons, garage, flag) uses the pick.
    [_faction] call STCTI_fnc_applyFaction;

    STCTI_BASE_POS = _spawnPos;
    STCTI_BASE_DIR = _spawnDir;
    publicVariable "STCTI_BASE_POS";
    publicVariable "STCTI_BASE_DIR";

    // Arsenal — an equipment crate with a WHITELISTED arsenal (not the full catalogue):
    // fn_updateArsenal fills it from the faction's arsenal tiers vs current unlocks, and
    // re-runs on every unlock grant (fn_startProgression).
    STCTI_arsenalBox = createVehicle ["Box_NATO_Equip_F", _arsenalPos, [], 0, "CAN_COLLIDE"];
    STCTI_arsenalBox setPosATL [_arsenalPos select 0, _arsenalPos select 1, 0];
    ["AmmoboxInit", [STCTI_arsenalBox, false]] remoteExec ["BIS_fnc_arsenal", 0, true];
    call STCTI_fnc_updateArsenal;

    // Garage — the faction's flag as the interaction point; clients attach the purchase menu (E3).
    STCTI_garage = createVehicle [STCTI_PLAYER_FLAG, _garagePos, [], 0, "CAN_COLLIDE"];
    STCTI_garage setPosATL [_garagePos select 0, _garagePos select 1, 0];
    STCTI_garage setVariable ["STCTI_isGarage", true, true];
    publicVariable "STCTI_garage";

    diag_log format ["[STCTI] Base established: %1 at %2", _label, _spawnPos];
};

// Deploy the requesting player at the exact spawn point.
[STCTI_BASE_POS, STCTI_BASE_DIR] remoteExec ["STCTI_fnc_deployPlayer", _requester];
