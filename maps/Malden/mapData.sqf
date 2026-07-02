// mapData.sqf — PER-MAP data for STCTI.Malden (Phase 7).
// The ONLY hand-edited files per map are this file + mission.sqm.
// All logic lives in framework/ and is stamped in by build.ps1. Loaded by init.sqf.
//
// Sectors are NOT listed here: towns are auto-detected from the engine's location index, and
// strategic sectors are authored in framework/description.ext > CfgSTCTISectors > Malden. This
// file only carries the per-map start-base options.
//
// PLACEHOLDER coordinates — eyeballed, not editor-exported (spec §5 export still to do).
// fn_serverPlaceBase land-snaps anything that lands on water, so they are safe to play,
// but snap them to the real spots in the editor when convenient.

STCTI_START_BASES = [
    ["Northeastern Airfield", [8050, 11700, 0], 0, [8042, 11700, 0], [8058, 11700, 0]],
    ["Southern Peninsula",    [4600, 3800, 0],  0, [4592, 3800, 0],  [4608, 3800, 0]]
];
