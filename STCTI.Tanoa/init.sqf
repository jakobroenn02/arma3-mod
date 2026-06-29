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
// Z is taken from terrain at runtime (setPosATL), so heights are 0 here.
// arsenal/garage are offset a few metres either side of the spawn — adjust to taste.
// Tanoa: the other airfields/bases are enemy sectors (see fn_initSectors).
STCTI_START_BASES = [
    ["Central Airport",          [7068.01,7411.45,0], 0, [7060.01,7411.45,0], [7076.01,7411.45,0]],
    ["Western Military Airbase", [2367.82,13316.8,0], 0, [2359.82,13316.8,0], [2375.82,13316.8,0]]
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
