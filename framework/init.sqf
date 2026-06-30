// init.sqf — runs on every machine, first. Shared constants only, no function calls.
// See phase-1-vertical-slice-tasks.md §A1.

STCTI_TAG = "STCTI";

// --- Hard dependency guard: CBA must be loaded as a mod -------------------------
if (isNil "CBA_fnc_addPerFrameHandler") then {
    private _msg = "STCTI requires CBA_A3. Load @CBA_A3 and restart.";
    diag_log text ("[STCTI] FATAL: " + _msg);
    if (hasInterface) then { systemChat _msg; };
};

// --- Optional dependency: LAMBS Danger (advisory, never fatal) ------------------
// LAMBS Danger (GPLv2; runtime-dependency only — we call it, we don't bundle it) is an
// OPTIONAL enhancement, treated like ACE per design doc §12. If present it upgrades all AI
// tactics (cover, suppression, building-clearing, flanking) automatically with no code from
// us, and its lambs_wp_fnc_task* orders are the intended Phase 5 execution backend (wrapped
// behind STCTI_fnc_order* with a vanilla fallback — not built yet). If absent, STCTI runs on
// vanilla AI + vanilla waypoints. These flags let later code branch without re-querying config.
STCTI_HAS_LAMBS_AI = isClass (configFile >> "CfgPatches" >> "lambs_danger");  // behaviour FSM
STCTI_HAS_LAMBS_WP = isClass (configFile >> "CfgPatches" >> "lambs_wp");      // task/order functions
diag_log text (format [
    "[STCTI] LAMBS Danger: AI tactics %1, order backend %2.",
    ["absent (vanilla AI)", "active"] select STCTI_HAS_LAMBS_AI,
    ["absent (vanilla waypoints)", "available"] select STCTI_HAS_LAMBS_WP
]);

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

// --- Director ↔ resolver wiring + observation (Phase 2) ------------------------
// An attack on a sector nobody is watching resolves as math; one being watched spawns live.
// "Observed" = an observer point within (sectorRadius + observerRadius). Observer points are
// altitude-scaled (a jet/UAV up high sees and reaches far) and projected downrange along the
// vehicle's facing (your attention is ahead, not under your feet). See fn_observerPoints.
STCTI_OBS_GROUND_R    = 1500;   // observer radius on foot / in a ground vehicle (m)
STCTI_OBS_ALT_FACTOR  = 2.0;    // observer radius grows this many m per m of altitude
STCTI_OBS_MAX_R       = 5000;   // cap on observer radius (m)
STCTI_OBS_LOOKAHEAD   = 1.5;    // aircraft/UAV observer point projects this × altitude downrange
STCTI_OBS_HYSTERESIS  = 1000;   // once spawned, stay spawned until this much further out (anti-thrash)
STCTI_PLAYER_GARRISON = 4;      // baseline virtual hold force (riflemen) a sector gains on player capture
STCTI_ATTACK_ROSTER   = [["rifleman", 8]];  // attacker composition (typeId -> count); same for live & abstract
STCTI_GARRISON_SIZE   = 6;      // default enemy garrison (riflemen) seeded per sector at campaign start
STCTI_VIRT_INTERVAL   = 5;      // seconds between garrison spawn/despawn (proximity-cache) checks

// Abstract typeId -> real classname (faction-abstraction seam; Phase 3 expands per faction/role).
STCTI_TYPE_CLASS = createHashMapFromArray [
    ["rifleman", "O_Soldier_F"]
];

// --- Per-map data (start bases + sector table) ---------------------------------
// THE code/data seam (design doc §14): framework logic is shared across all maps; the only
// per-map data — STCTI_START_BASES and STCTI_SECTOR_TABLE — lives in each mission's
// mapData.sqf, stamped in next to this file by build.ps1. Loaded synchronously here, on
// every machine, before initServer.sqf / initPlayerLocal.sqf run (same as the faction map
// below, which the existing sector-spawn chain already depends on at this point).
call compile preprocessFileLineNumbers "mapData.sqf";

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
