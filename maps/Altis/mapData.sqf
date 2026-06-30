// mapData.sqf — PER-MAP data for STCTI.Altis.
// The ONLY hand-edited files per map are this file + mission.sqm.
// All logic lives in framework/ and is stamped in by build.ps1. Loaded by init.sqf.

STCTI_START_BASES = [
    ["Central Airport (military)", [15250,17241,0],    0, [15242,17241,0], [15258,17241,0]],
    ["South-East Airport",         [20556.3,7277.93,0],0, [20548.3,7277.93,0], [20564.3,7277.93,0]],
    ["North-East Military Base",   [23536.7,21088.1,0],0, [23528.7,21088.1,0], [23544.7,21088.1,0]],
    ["North-West Airport",         [9156.62,21612.7,0],0, [9148.62,21612.7,0], [9164.62,21612.7,0]]
];

// Sectors: ["id", "type", pos, captureRadius, incomeArray]
STCTI_SECTOR_TABLE = [
    // id, type, position, captureRadius, income
    ["kavala",    "town",          [3500,13200,0], 200, [["money",50],["manpower",2]]],
    ["airfield",  "military",      [23100,18800,0],300, [["money",30]]],
    ["fueldepot", "resource_fuel", [9200,15500,0], 200, [["fuel",40]]]
];
