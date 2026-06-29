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
STCTI_EV_ENGAGEMENT_RESOLVED = "STCTI_EngagementResolved"; // args: [sectorId, routedSide, attackerForce, defenderForce, startA, startD, attackerOwner, defenderOwner]

// --- Tunables (slice values — tune by feel) ------------------------------------
STCTI_ECONOMY_INTERVAL = 60;    // economy tick seconds
STCTI_CAPTURE_INTERVAL = 2;     // sector presence check seconds
STCTI_CAPTURE_RATE     = 0.10;  // capture progress per check when uncontested
STCTI_ATTACK_MIN       = 600;   // min seconds between enemy attacks
STCTI_ATTACK_MAX       = 900;   // max seconds
STCTI_ATTACK_WARNING   = 60;    // warning lead time

// --- Abstract combat resolver (Phase 2) — see abstract-combat-resolution-spec.md §8.
// Master pace dial is K; calibrate it against live fights before tuning anything else.
STCTI_K                = 0.03;  // per-tick lethality (master pace)
STCTI_RESOLVE_INTERVAL = 10;    // real seconds between resolver ticks
STCTI_JITTER           = 0.25;  // per-tick randomness (±)
STCTI_CA_STEP          = 0.05;  // combined-arms bonus per extra capability category
STCTI_CA_MAX           = 1.20;  // combined-arms multiplier cap
STCTI_CA_AT_MIN        = 0.5;   // infantry antiArmor at/above this counts as an "AT" capability
STCTI_CA_AA_MIN        = 0.5;   // infantry antiAir   at/above this counts as an "AA" capability
STCTI_P_ARMOR          = 0.5;   // offense penalty for unanswered enemy armor
STCTI_P_AIR            = 0.5;   // offense penalty for unanswered enemy air
STCTI_BREAK_THRESHOLD  = 0.30;  // raw-strength fraction at which a force routs
STCTI_MAX_TICKS        = 240;   // stalemate safeguard (~40 min @10s)
STCTI_PURSUIT_LOSS     = 0.05;  // attacker attrition (fraction of start Sraw) on a capture
STCTI_BASEVULN = createHashMapFromArray [
    ["soft", 1.0], ["light", 0.6], ["armored", 0.35], ["heavy", 0.20], ["air", 0.30]
];
STCTI_DEFBONUS = createHashMapFromArray [
    ["town", 0.15], ["resource_fuel", 0.20], ["resource_ammo", 0.20], ["military", 0.35]
];

// --- Director ↔ resolver wiring (Phase 2 step 1) -------------------------------
// An attack on a sector NObody is watching resolves as math; one being watched spawns live.
STCTI_OBSERVE_RANGE   = 1500;   // [PLACEHOLDER] player within (sectorRadius + this) => observed.
                                // Phase 2 step 2 replaces this with altitude/sensor-scaled
                                // observer points that follow the UAV camera.
STCTI_PLAYER_GARRISON = 4;      // baseline virtual hold force (riflemen) a sector gains on player capture
STCTI_ATTACK_ROSTER   = [["rifleman", 8]];  // attacker composition (typeId -> count); same for live & abstract

// Abstract typeId -> real classname (faction-abstraction seam; Phase 3 expands per faction/role).
STCTI_TYPE_CLASS = createHashMapFromArray [
    ["rifleman", "O_Soldier_F"]
];

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
STCTI_START_BASES = [
    ["Central Airport (military)", [15250,17241,0],    0, [15242,17241,0], [15258,17241,0]],
    ["South-East Airport",         [20556.3,7277.93,0],0, [20548.3,7277.93,0], [20564.3,7277.93,0]],
    ["North-East Military Base",   [23536.7,21088.1,0],0, [23528.7,21088.1,0], [23544.7,21088.1,0]],
    ["North-West Airport",         [9156.62,21612.7,0],0, [9148.62,21612.7,0], [9164.62,21612.7,0]]
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
