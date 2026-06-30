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
STCTI_SPAWN_BUDGET    = 60;     // max framework-spawned AI units alive at once (the FPS ceiling).
                                // Observed forces beyond this stay abstract/data until budget frees,
                                // spawned in priority order (active fights first, then nearest garrisons).

// Faction map: owner ("player"/"enemy") -> (resolverType -> real classname). Side-aware so a force
// never spawns wearing the other faction's uniform, and keyed by the same CfgSTCTIUnitTypes ids the
// resolver uses, so a layout slot's resolverType resolves straight to a class. Phase 3 expands to
// AAF / per-faction selection (sector-layout-spec §1.3).
STCTI_FACTION = createHashMapFromArray [
    ["player", createHashMapFromArray [   // NATO
        ["rifleman", "B_Soldier_F"], ["at_team", "B_soldier_AT_F"], ["aa_team", "B_soldier_AA_F"],
        ["mrap", "B_MRAP_01_hmg_F"], ["ifv", "B_APC_Wheeled_01_cannon_F"], ["mbt", "B_MBT_01_cannon_F"],
        ["uav_armed", "B_UAV_02_dynamicLoadout_F"], ["heli_atk", "B_Heli_Attack_01_dynamicLoadout_F"], ["jet_cas", "B_Plane_CAS_01_dynamicLoadout_F"]
    ]],
    ["enemy", createHashMapFromArray [    // CSAT
        ["rifleman", "O_Soldier_F"], ["at_team", "O_Soldier_AT_F"], ["aa_team", "O_Soldier_AA_F"],
        ["mrap", "O_MRAP_02_hmg_F"], ["ifv", "O_APC_Wheeled_02_rcws_v2_F"], ["mbt", "O_MBT_02_cannon_F"],
        ["uav_armed", "O_UAV_02_dynamicLoadout_F"], ["heli_atk", "O_Heli_Attack_02_dynamicLoadout_F"], ["jet_cas", "O_Plane_CAS_02_dynamicLoadout_F"]
    ]]
];

// Side-aware static-weapon classes (a static is an object, not a man, so it needs its own map).
// Keyed by role (sector-layout-spec §1.3). Phase 3 expands per faction.
STCTI_STATIC_CLASS = createHashMapFromArray [
    ["player", createHashMapFromArray [["static_he", "B_HMG_01_high_F"], ["static_at", "B_static_AT_F"], ["static_aa", "B_static_AA_F"]]],
    ["enemy",  createHashMapFromArray [["static_he", "O_HMG_01_high_F"], ["static_at", "O_static_AT_F"], ["static_aa", "O_static_AA_F"]]]
];

// --- Sector layouts (sector-layout-spec) ---------------------------------------
// Role -> [spawnKind, resolverType]. spawnKind: "infantry"|"vehicle"|"static". resolverType is the
// CfgSTCTIUnitTypes id the slot contributes to abstract strength ("" = decoration, not counted).
STCTI_ROLES = createHashMapFromArray [
    ["inf_post",  ["infantry", "rifleman"]],
    ["at_post",   ["infantry", "at_team"]],
    ["aa_post",   ["infantry", "aa_team"]],
    ["mrap",      ["vehicle",  "mrap"]],
    ["ifv",       ["vehicle",  "ifv"]],
    ["mbt",       ["vehicle",  "mbt"]],
    ["static_he", ["static",   "rifleman"]],
    ["static_at", ["static",   "at_team"]],
    ["static_aa", ["static",   "aa_team"]]
];

// Layout archetypes: ordered slot lists keyed by id. A slot is polar from the sector centre and
// rotates with the sector's heading: [role, distFromCentre, bearingFromCentre, facingOffset].
// Author once, reuse on many sectors. Towns use the empty layout (garrison goes into buildings).
STCTI_LAYOUTS = createHashMapFromArray [
    ["military_small", [
        ["mbt",       18, 200,   0],
        ["static_he", 22,  40,  40],
        ["static_at", 24, 150, 150],
        ["inf_post",  15,  90,  90],
        ["inf_post",  15, 270, 270],
        ["inf_post",  20,   0,   0]
    ]],
    ["fuel_depot", [
        ["static_he", 16,  60,  60],
        ["inf_post",  12, 180, 180],
        ["inf_post",  12,   0,   0]
    ]],
    ["town_light", []]
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

// --- Sides ---------------------------------------------------------------------
STCTI_SIDE_ENEMY  = east;
STCTI_SIDE_PLAYER = west;
