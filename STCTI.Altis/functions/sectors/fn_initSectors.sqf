// fn_initSectors.sqf — [SERVER] called once after initState. Hand-places slice sectors. See §C6.
if (!isServer) exitWith {};

{
    _x params ["_id", "_type", "_pos", "_radius", "_income"];
    [_id, _type, _pos, _radius, _income] call STCTI_fnc_registerSector;
    [_id] call STCTI_fnc_spawnSectorGarrison;
} forEach [
    // id, type, position, captureRadius, income
    ["kavala",    "town",          [3500,13200,0], 200, [["money",50],["manpower",2]]],
    ["airfield",  "military",      [23100,18800,0],300, [["money",30]]],
    ["fueldepot", "resource_fuel", [9200,15500,0], 200, [["fuel",40]]]
];
