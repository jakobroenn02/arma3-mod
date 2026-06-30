// mapData.sqf — PER-MAP data for STCTI.Tanoa.
// The ONLY hand-edited files per map are this file + mission.sqm.
// All logic lives in framework/ and is stamped in by build.ps1. Loaded by init.sqf.
//
// Sectors are NOT listed here: towns are auto-detected from the engine's location index, and
// strategic sectors are authored in framework/description.ext > CfgSTCTISectors > Tanoa. This file
// only carries the per-map start-base options.

STCTI_START_BASES = [
    ["Central Airport",          [7068.01,7411.45,0], 0, [7060.01,7411.45,0], [7076.01,7411.45,0]],
    ["Western Military Airbase", [2367.82,13316.8,0], 0, [2359.82,13316.8,0], [2375.82,13316.8,0]]
];
