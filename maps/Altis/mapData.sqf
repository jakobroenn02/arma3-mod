// mapData.sqf — PER-MAP data for STCTI.Altis.
// The ONLY hand-edited files per map are this file + mission.sqm.
// All logic lives in framework/ and is stamped in by build.ps1. Loaded by init.sqf.
//
// Sectors are NOT listed here: towns are auto-detected from the engine's location index, and
// strategic sectors are authored in framework/description.ext > CfgSTCTISectors > Altis. This file
// only carries the per-map start-base options.

STCTI_START_BASES = [
    ["Central Airport (military)", [15250,17241,0],    0, [15242,17241,0], [15258,17241,0]],
    ["South-East Airport",         [20556.3,7277.93,0],0, [20548.3,7277.93,0], [20564.3,7277.93,0]],
    ["North-East Military Base",   [23536.7,21088.1,0],0, [23528.7,21088.1,0], [23544.7,21088.1,0]],
    ["North-West Airport",         [9156.62,21612.7,0],0, [9148.62,21612.7,0], [9164.62,21612.7,0]]
];
