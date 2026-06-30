// mapData.sqf — PER-MAP data for STCTI.Tanoa.
// The ONLY hand-edited files per map are this file + mission.sqm.
// All logic lives in framework/ and is stamped in by build.ps1. Loaded by init.sqf.

STCTI_START_BASES = [
    ["Central Airport",          [7068.01,7411.45,0], 0, [7060.01,7411.45,0], [7076.01,7411.45,0]],
    ["Western Military Airbase", [2367.82,13316.8,0], 0, [2359.82,13316.8,0], [2375.82,13316.8,0]]
];

// Sectors: ["id", "type", pos, captureRadius, incomeArray, heading, layoutId]
STCTI_SECTOR_TABLE = [
    // id, type, position, captureRadius, income, heading, layout   (Tanoa)
    ["north_air",  "town",          [11677.1,13115.5,0], 250, [["money",50],["manpower",2]],   0, "town_light"],
    ["north_mil",  "military",      [10086.8,11772.5,0], 300, [["money",30]],                 0, "military_small"],
    ["se_air",     "resource_fuel", [11690.4,3070.36,0], 250, [["fuel",40]],                  0, "fuel_depot"]
];
