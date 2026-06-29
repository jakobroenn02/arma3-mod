// fn_initSectors.sqf — [SERVER] called once after initState. Hand-places slice sectors. See §C6.
if (!isServer) exitWith {};

{
    _x params ["_id", "_type", "_pos", "_radius", "_income"];
    [_id, _type, _pos, _radius, _income] call STCTI_fnc_registerSector;
    [_id] call STCTI_fnc_spawnSectorGarrison;
} forEach [
    // id, type, position, captureRadius, income     (Tanoa)
    ["north_air",  "town",          [11677.1,13115.5,0], 250, [["money",50],["manpower",2]]],
    ["north_mil",  "military",      [10086.8,11772.5,0], 300, [["money",30]]],
    ["se_air",     "resource_fuel", [11690.4,3070.36,0], 250, [["fuel",40]]]
];
