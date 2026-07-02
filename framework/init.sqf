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
STCTI_EV_UNLOCKS_CHANGED     = "STCTI_UnlocksChanged";     // args: [unlocksArray, newlyUnlockedId]
STCTI_EV_GARAGE_CHANGED      = "STCTI_GarageChanged";      // args: [storedClassnamesArray]

// --- Progression: unlocks + garage catalog -------------------------------------
// STCTI_unlocks is the server-authoritative list of granted unlock ids, broadcast to clients
// (UNLOCKS_CHANGED) so the garage can gate on it. Capturing a sector grants its grantsUnlock.
STCTI_unlocks = [];
// Garage catalog TEMPLATE: [role, price, requiredUnlock ("" = always), fuelCost]. Roles resolve
// to the chosen faction's classes — the concrete STCTI_garageCatalog ([label, class, price,
// unlock, fuel]) is derived below once STCTI_FACTION_POOL exists, and re-derived by
// fn_applyFaction when the player picks a faction at campaign setup. Vehicles cost money + fuel
// (design §resources). NOTE: catalog name must NOT collide with the garage flag object
// STCTI_garage — SQF variable names are case-insensitive. Hence STCTI_garageCatalog.
STCTI_garageCatalogTemplate = [
    ["mrap",    500,  "",           50],
    ["ifv",     1500, "",           150],
    ["jet_cas", 6000, "fixed_wing", 400]
];
// How far from the garage flag a purchase may be placed. The placement ghost clamps to
// this on the client; the server enforces it (with slack) in fn_serverPurchase.
STCTI_GARAGE_RADIUS = 50;
// Client cache of the server's stored-vehicle list (GARAGE_CHANGED pushes; garage menu reads).
STCTI_lastStored = [];

// --- Tunables (slice values — tune by feel) ------------------------------------
STCTI_ECONOMY_INTERVAL = 60;    // economy tick seconds
STCTI_CAPTURE_INTERVAL = 2;     // sector presence check seconds
STCTI_CAPTURE_RATE     = 0.10;  // capture progress per check when uncontested
STCTI_ATTACK_MIN       = 600;   // min seconds between enemy attacks
STCTI_ATTACK_MAX       = 900;   // max seconds
STCTI_ATTACK_WARNING   = 60;    // warning lead time
// Reinforce garrison (design §sector-actions): money + manpower buys extra riflemen for the
// sector you are standing in (fn_serverReinforce).
STCTI_REINFORCE_COST   = [["money", 250], ["manpower", 5]];
STCTI_REINFORCE_SIZE   = 5;     // riflemen added per reinforcement
// Build static turret (design §sector-actions): money + ammo places a manned static where the
// player stands, remembered as a sector "hardening" slot (fn_serverPlaceStatic).
STCTI_STATIC_COST = createHashMapFromArray [
    ["static_he", [["money", 200], ["ammo", 50]]],
    ["static_at", [["money", 400], ["ammo", 100]]],
    ["static_aa", [["money", 400], ["ammo", 100]]]
];

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
// --- AI director (Phase 4) — design §8. Aggression is the single pacing scalar: it rises on
// player captures (fn_startManagers), decays on quiet director rolls (fn_directorTick), and is
// hard-capped for a passive-by-default feel. Each jittered roll: random 1 < aggression launches
// ONE operation, then a cooldown. The task force is the highest escalation tier at/below the
// current aggression — these are the dials the design doc says you'll tune the most.
STCTI_AGGRO_START       = 0.20;
STCTI_AGGRO_CAP         = 0.60;   // hard cap — the enemy stays passive by design
STCTI_AGGRO_FLOOR       = 0.10;   // never fully dormant
STCTI_AGGRO_PER_CAPTURE = 0.10;   // rise per player sector capture
STCTI_AGGRO_DECAY       = 0.02;   // decay per director roll (quiet time)
STCTI_OP_COOLDOWN       = 900;    // min seconds after an op before the next is even considered
STCTI_OP_TIMEOUT        = 2700;   // spawned op older than this culminates (attacker withdraws)

// --- Persistence (Phase 6, design §10) ------------------------------------------
// The campaign spine autosaves to the server profile, keyed by world. Wipe for a fresh
// campaign from the debug console: `call STCTI_fnc_wipeSave` (then restart the mission).
STCTI_PERSISTENCE       = true;   // false = never save or restore
STCTI_AUTOSAVE_INTERVAL = 300;    // seconds between autosaves (also saves on every capture)
STCTI_SAVE_VERSION      = 1;      // bump when the save layout changes; mismatched saves are ignored
// Escalation tiers: [minAggression, roster (typeId->count pairs)]. Tier 1 infantry + light
// vehicles; tier 2 adds an armor element; tier 3 adds air. Same roster live & abstract.
STCTI_ESCALATION = [
    [0.00, [["rifleman", 8],  ["at_team", 1], ["mrap", 1]]],
    [0.35, [["rifleman", 10], ["at_team", 2], ["mrap", 1], ["ifv", 1]]],
    [0.55, [["rifleman", 12], ["at_team", 2], ["aa_team", 1], ["mrap", 2], ["ifv", 1], ["mbt", 1], ["heli_atk", 1]]]
];
STCTI_GARRISON_SIZE   = 6;      // default enemy garrison (riflemen) seeded per sector at campaign start
STCTI_VIRT_INTERVAL   = 5;      // seconds between garrison spawn/despawn (proximity-cache) checks
STCTI_SPAWN_BUDGET    = 60;     // max framework-spawned AI units alive at once (the FPS ceiling).
                                // Observed forces beyond this stay abstract/data until budget frees,
                                // spawned in priority order (active fights first, then nearest garrisons).

// Faction pool (Phase 3, design §faction-abstraction): every native faction as one datum —
// role->class unit map (keyed by CfgSTCTIUnitTypes ids, so a layout slot's resolverType resolves
// straight to a class), role->class statics map, garage flag, and its default opponent. The
// campaign-setup faction pick (fn_applyFaction) populates STCTI_FACTION / STCTI_STATIC_CLASS /
// STCTI_garageCatalog from this. DELIBERATE spec deviation: engine sides stay fixed
// (player=west, enemy=east) regardless of faction — the mission.sqm player unit is WEST, and
// units joined into framework groups take the group's side anyway, so swapping CLASSES alone
// gives faction selection without any side-relation surgery.
STCTI_FACTION_POOL = createHashMapFromArray [
    ["NATO", createHashMapFromArray [
        ["enemy", "CSAT"], ["flag", "Flag_NATO_F"],
        ["units", createHashMapFromArray [
            ["rifleman", "B_Soldier_F"], ["at_team", "B_soldier_AT_F"], ["aa_team", "B_soldier_AA_F"],
            ["mrap", "B_MRAP_01_hmg_F"], ["ifv", "B_APC_Wheeled_01_cannon_F"], ["mbt", "B_MBT_01_cannon_F"],
            ["uav_armed", "B_UAV_02_dynamicLoadout_F"], ["heli_atk", "B_Heli_Attack_01_dynamicLoadout_F"], ["jet_cas", "B_Plane_CAS_01_dynamicLoadout_F"]
        ]],
        ["statics", createHashMapFromArray [["static_he", "B_HMG_01_high_F"], ["static_at", "B_static_AT_F"], ["static_aa", "B_static_AA_F"]]],
        // Arsenal tiers: unlockId ("" = from the start) -> unit classes whose config gear gets
        // whitelisted into the base arsenal (fn_updateArsenal).
        ["arsenalUnits", createHashMapFromArray [
            ["",           ["B_Soldier_F", "B_soldier_AR_F", "B_medic_F", "B_soldier_AT_F", "B_soldier_AA_F"]],
            ["fixed_wing", ["B_Pilot_F", "B_Heli_Pilot_F"]]
        ]]
    ]],
    ["CSAT", createHashMapFromArray [
        ["enemy", "NATO"], ["flag", "Flag_CSAT_F"],
        ["units", createHashMapFromArray [
            ["rifleman", "O_Soldier_F"], ["at_team", "O_Soldier_AT_F"], ["aa_team", "O_Soldier_AA_F"],
            ["mrap", "O_MRAP_02_hmg_F"], ["ifv", "O_APC_Wheeled_02_rcws_v2_F"], ["mbt", "O_MBT_02_cannon_F"],
            ["uav_armed", "O_UAV_02_dynamicLoadout_F"], ["heli_atk", "O_Heli_Attack_02_dynamicLoadout_F"], ["jet_cas", "O_Plane_CAS_02_dynamicLoadout_F"]
        ]],
        ["statics", createHashMapFromArray [["static_he", "O_HMG_01_high_F"], ["static_at", "O_static_AT_F"], ["static_aa", "O_static_AA_F"]]],
        ["arsenalUnits", createHashMapFromArray [
            ["",           ["O_Soldier_F", "O_Soldier_AR_F", "O_medic_F", "O_Soldier_AT_F", "O_Soldier_AA_F"]],
            ["fixed_wing", ["O_Pilot_F", "O_helipilot_F"]]
        ]]
    ]],
    ["AAF", createHashMapFromArray [
        ["enemy", "CSAT"], ["flag", "Flag_AAF_F"],
        ["units", createHashMapFromArray [
            ["rifleman", "I_Soldier_F"], ["at_team", "I_Soldier_AT_F"], ["aa_team", "I_Soldier_AA_F"],
            ["mrap", "I_MRAP_03_hmg_F"], ["ifv", "I_APC_Wheeled_03_cannon_F"], ["mbt", "I_MBT_03_cannon_F"],
            // AAF has no attack helicopter — armed Hellcat is its closest native equivalent (v1
            // native-factions-only rule, design §1).
            ["uav_armed", "I_UAV_02_dynamicLoadout_F"], ["heli_atk", "I_Heli_light_03_dynamicLoadout_F"], ["jet_cas", "I_Plane_Fighter_03_dynamicLoadout_F"]
        ]],
        ["statics", createHashMapFromArray [["static_he", "I_HMG_01_high_F"], ["static_at", "I_static_AT_F"], ["static_aa", "I_static_AA_F"]]],
        ["arsenalUnits", createHashMapFromArray [
            ["",           ["I_soldier_F", "I_Soldier_AR_F", "I_medic_F", "I_Soldier_AT_F", "I_Soldier_AA_F"]],
            ["fixed_wing", ["I_pilot_F", "I_helipilot_F"]]
        ]]
    ]]
];

// Faction defaults (NATO vs CSAT) so everything works before the campaign-setup pick lands;
// fn_applyFaction re-derives exactly these (and broadcasts) from the chosen faction.
private _pf = STCTI_FACTION_POOL get "NATO";
private _ef = STCTI_FACTION_POOL get "CSAT";
STCTI_PLAYER_FACTION = "NATO";
STCTI_PLAYER_FLAG    = _pf get "flag";
STCTI_FACTION      = createHashMapFromArray [["player", _pf get "units"], ["enemy", _ef get "units"]];
STCTI_STATIC_CLASS = createHashMapFromArray [["player", _pf get "statics"], ["enemy", _ef get "statics"]];
STCTI_garageCatalog = STCTI_garageCatalogTemplate apply {
    _x params ["_role", "_price", "_unlock", "_fuel"];
    private _cls = (_pf get "units") get _role;
    [format ["Buy %1 — $%2 + %3 fuel", getText (configFile >> "CfgVehicles" >> _cls >> "displayName"), _price, _fuel],
     _cls, _price, _unlock, _fuel]
};

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

// --- Per-map data (start bases) ------------------------------------------------
// THE code/data seam (design doc §14): framework logic is shared across all maps; the only per-map
// SQF data is STCTI_START_BASES, in each mission's mapData.sqf (stamped in next to this file by
// build.ps1). Sectors aren't here — towns are auto-detected and strategic sectors are authored in
// CfgSTCTISectors. Loaded synchronously, on every machine, before initServer/initPlayerLocal run.
call compile preprocessFileLineNumbers "mapData.sqf";

// Set at campaign start from the chosen base (see fn_serverPlaceBase). Declared here
// so other code can reference it; values are overwritten on selection.
STCTI_BASE_POS = [0,0,0];
STCTI_BASE_DIR = 0;

// --- Sides ---------------------------------------------------------------------
STCTI_SIDE_ENEMY  = east;
STCTI_SIDE_PLAYER = west;
