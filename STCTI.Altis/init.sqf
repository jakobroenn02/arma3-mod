// init.sqf — runs on every machine, first. Shared constants only, no function calls.
// See phase-1-vertical-slice-tasks.md §A1.

STCTI_TAG = "STCTI";

// --- Hard dependency guard: CBA must be loaded as a mod -------------------------
if (isNil "CBA_fnc_addPerFrameHandler") then {
    private _msg = "STCTI requires CBA_A3. Load @CBA_A3 and restart.";
    diag_log text ("[STCTI] FATAL: " + _msg);
    if (hasInterface) then { systemChat _msg; };
};

// --- Event names (CBA events) --------------------------------------------------
STCTI_EV_SECTOR_CAPTURED   = "STCTI_SectorCaptured";    // args: [sectorId, newOwner]
STCTI_EV_RESOURCES_CHANGED = "STCTI_ResourcesChanged";  // args: [resourcesHashMap]
STCTI_EV_ATTACK_INBOUND    = "STCTI_AttackInbound";     // args: [sectorId]

// --- Tunables (slice values — tune by feel) ------------------------------------
STCTI_ECONOMY_INTERVAL = 60;    // economy tick seconds
STCTI_CAPTURE_INTERVAL = 2;     // sector presence check seconds
STCTI_CAPTURE_RATE     = 0.10;  // capture progress per check when uncontested
STCTI_ATTACK_MIN       = 600;   // min seconds between enemy attacks
STCTI_ATTACK_MAX       = 900;   // max seconds
STCTI_ATTACK_WARNING   = 60;    // warning lead time

// --- Starting bases -------------------------------------------------------------
// EDIT THIS TABLE. Each row is one selectable starting base:
//   [ "label", spawnPos, spawnDir, arsenalPos, garagePos ]
//     spawnPos    — where the player teleports in (exact; sits on the ground)
//     spawnDir    — facing in degrees (0 = north)
//     arsenalPos  — where the Arsenal crate is placed
//     garagePos   — where the vehicle-garage flag is placed
//
// To get a coordinate in-game: stand on the spot, open the debug console (Esc ->
// Debug Console), run:  copyToClipboard str (getPosATL player)  — then paste here.
// The example coords below are approximate placeholders — replace with real bases.
STCTI_START_BASES = [
    ["Air Station Mike-26 (NE airfield)", [23390,18900,0],  45, [23383,18893,0], [23397,18907,0]],
    ["Pyrgos (central)",                  [16800,12600,0],   0, [16793,12605,0], [16807,12595,0]],
    ["Syrta (west)",                      [8700,18800,0],   90, [8693,18805,0],  [8707,18795,0]],
    ["Zaros (south)",                     [9250,15900,0],  180, [9243,15905,0],  [9257,15895,0]]
];

// Set at campaign start from the chosen base (see fn_serverPlaceBase). Declared here
// so other code can reference it; values are overwritten on selection.
STCTI_BASE_POS = [0,0,0];
STCTI_BASE_DIR = 0;

// --- Minimal faction map (slice: riflemen only) --------------------------------
STCTI_FACTION_ENEMY = createHashMapFromArray [
    ["riflemen", ["O_Soldier_F", "O_Soldier_GL_F", "O_Soldier_AR_F"]]
];
STCTI_SIDE_ENEMY  = east;
STCTI_SIDE_PLAYER = west;
