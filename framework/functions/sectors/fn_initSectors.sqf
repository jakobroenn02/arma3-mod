// fn_initSectors.sqf — [SERVER] called once after initState. Registers the map's sectors
// from STCTI_SECTOR_TABLE (per-map data defined in mapData.sqf, loaded by init.sqf). See §C6.
if (!isServer) exitWith {};

// Order-safety fallback: if init.sqf hasn't populated the table yet, load it now.
if (isNil "STCTI_SECTOR_TABLE") then { call compile preprocessFileLineNumbers "mapData.sqf"; };
if (isNil "STCTI_SECTOR_TABLE") exitWith {
    diag_log "[STCTI] fn_initSectors: STCTI_SECTOR_TABLE undefined — is mapData.sqf present?";
};

{
    _x params ["_id", "_type", "_pos", "_radius", "_income"];
    [_id, _type, _pos, _radius, _income] call STCTI_fnc_registerSector;
    // Seed the enemy garrison as DATA only. It spawns lazily when a player observes the sector
    // (fn_startVirtualization) — Phase 1's always-on garrison spawn is gone.
    ((STCTI_state get "sectors") get _id) set ["defenderForce", createHashMapFromArray [["rifleman", STCTI_GARRISON_SIZE]]];
} forEach STCTI_SECTOR_TABLE;
