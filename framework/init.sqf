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
STCTI_EV_HC_CHANGED          = "STCTI_HCChanged";          // args: [hcGroupsArray]

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
// Full combined-arms taxonomy (roadmap Phase 10): each row gates on its category unlock,
// reachable by capturing the matching military site OR procuring the category (fn_serverProcure).
STCTI_garageCatalogTemplate = [
    ["mrap",           500,  "",              50],
    ["truck",          400,  "cat_wheeled",   40],
    ["apc",            1500, "cat_apc",       150],
    ["ifv",            2200, "cat_apc",       180],
    ["mbt",            4500, "cat_armor",     300],
    ["mbt_heavy",      7000, "cat_armor_t2",  400],
    ["heli_transport", 3000, "cat_rotary",    200],
    ["heli_atk",       5500, "cat_rotary",    300],
    ["jet_cas",        8000, "cat_fixedwing", 500],
    ["uav_recon",      2500, "cat_uav",       120],
    ["uav_armed",      6000, "cat_uav",       350],
    ["boat",           900,  "cat_naval",     60]
];
// How far from the garage flag a purchase may be placed. The placement ghost clamps to
// this on the client; the server enforces it (with slack) in fn_serverPurchase.
STCTI_GARAGE_RADIUS = 50;
// Client cache of the server's stored-vehicle list (GARAGE_CHANGED pushes; garage menu reads).
STCTI_lastStored = [];
// Client cache of the recruited HC squads (HC_CHANGED pushes; HC menu + vanilla HC bar read).
STCTI_lastHC = [];

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

// --- High Command (Phase 5, design §5/§7) ----------------------------------------
// Recruited squads are registered into vanilla HC (Ctrl+Space) AND drivable from the map
// board's dialog (fn_hcMenu). Orders compile through STCTI_fnc_order* — LAMBS backend when
// lambs_wp is loaded, vanilla waypoints otherwise.
STCTI_RECRUIT_COST   = [["money", 300], ["manpower", 4]];
STCTI_RECRUIT_COMP   = [["rifleman", 3], ["at_team", 1]];   // squad composition (typeId, count)
STCTI_SUPPLY_COST    = [["money", 200]];                    // truck dispatch cost
STCTI_SUPPLY_REWARD  = [["ammo", 150], ["fuel", 150]];      // granted when the truck arrives
STCTI_AIRSTRIKE_COST = [["money", 500], ["fuel", 100], ["ammo", 150]];
STCTI_AIRSTRIKE_TIME = 180;   // seconds the CAS jet hunts over the target before leaving

// --- Unlock taxonomy (Phase 9+ roadmap §1.2) --------------------------------------
// Canonical unlock ids are "cat_<category>" (+ "_t<n>" tiers). Legacy ids from shipped map
// data (and old saves) normalize through this alias map inside fn_grantUnlock/loadCampaign,
// so grantsUnlock="fixed_wing" in CfgSTCTISectors keeps working.
STCTI_UNLOCK_ALIASES = createHashMapFromArray [
    ["fixed_wing", "cat_fixedwing"]
];

// Procurement (roadmap §1.3 / Phase 10): buy a hardware-category unlock with resources.
// The table IS the policy — unique-effect unlocks (intel sites etc.) are deliberately absent,
// so fn_serverProcure refuses them and capture stays the only path to those.
STCTI_PROCURE_COST = createHashMapFromArray [
    ["cat_wheeled",   [["money", 800],  ["ammo", 50]]],
    ["cat_apc",       [["money", 1800], ["ammo", 100]]],
    ["cat_armor",     [["money", 3500], ["ammo", 200]]],
    ["cat_armor_t2",  [["money", 6000], ["ammo", 400]]],
    ["cat_rotary",    [["money", 3000], ["ammo", 150]]],
    ["cat_fixedwing", [["money", 8000], ["ammo", 500]]],
    ["cat_uav",       [["money", 4000], ["ammo", 200]]],
    ["cat_naval",     [["money", 1500], ["ammo", 50]]]
];

// --- Strategic mobility (Phase 9) --------------------------------------------------
STCTI_TRAVEL_FUEL_COST       = 40;    // redeploy between owned travel nodes
STCTI_TRAVEL_INSERT_FUEL     = 120;   // airborne insertion (any sector, arrives under canopy)
STCTI_TRAVEL_COOLDOWN        = 120;   // per-player seconds between travels (keyed by UID)
STCTI_TRAVEL_BLOCK_IN_COMBAT = true;  // refuse when enemies are near the requester
STCTI_TRAVEL_COMBAT_RADIUS   = 300;   // "near" for the combat lockout

// --- Front line (Warlords-style adjacency, conventional-war pacing) ----------------
// Capture is only possible in sectors ADJACENT to friendly territory (k-nearest graph built
// at init) or near the HQ. Out-of-reach enemy markers render faded. Airborne INSERT (Phase 9)
// deliberately bypasses the front — paradrops behind the lines are conventional doctrine.
STCTI_FRONTLINE       = true;   // false = capture anywhere (pre-front behaviour)
STCTI_FRONT_K         = 3;      // neighbors per sector in the adjacency graph
STCTI_FRONT_HQ_RADIUS = 3000;   // sectors this close to the base are always attackable

// --- Respawn (conventional reinforcement) ------------------------------------------
STCTI_RESPAWN_MANPOWER = 2;     // manpower debited per player respawn (see description.ext)

// --- Enemy build-up (slow-war pressure) --------------------------------------------
// Unobserved, unengaged enemy garrisons entrench over time: waiting has a price.
STCTI_ENEMY_BUILDUP_INTERVAL = 300;  // seconds between growth ticks
STCTI_ENEMY_GARRISON_CAP     = 14;   // total units an enemy garrison can grow to

// --- Artillery fire mission (HC order) ---------------------------------------------
STCTI_FIREMISSION_COST   = [["money", 300], ["ammo", 250]];
STCTI_FIREMISSION_SHELLS = 8;    // 155mm impacts spread over ~35s
STCTI_FIREMISSION_AGGRO  = 0.03; // provocation: each fire mission nudges the director

// --- Supply lines (map-physical logistics) ------------------------------------------
// A player sector only pays income while CONNECTED to the HQ beachhead through owned,
// adjacent sectors (the front-line graph). Cut the chain and everything beyond it starves —
// and the same applies to you when the enemy retakes a link. Cut-off sectors render dimmer.
STCTI_SUPPLY_RULE = true;

// --- Enemy convoys (ambushable logistics) --------------------------------------------
// When players are near the front, the enemy runs supply convoys between adjacent enemy
// sectors. Destroy one: loot + the destination garrison weakens. Intact trucks can be driven
// home and captured into garage stock. One convoy at a time; leftovers clean up after a while.
STCTI_CONVOY_INTERVAL      = 240;   // min seconds between convoy dispatches
STCTI_CONVOY_SPAWNRANGE    = 1800;  // a player this close to an endpoint makes a route eligible
STCTI_CONVOY_LOOT          = [["ammo", 100], ["fuel", 100]];   // credited when a convoy is stopped
STCTI_CONVOY_GARRISON_LOSS = 2;     // riflemen the destination garrison loses (missed supplies)

// --- Logistics & sustainment (Phase 12 slice) --------------------------------------
STCTI_INTEL_INTERVAL = 300;   // seconds between enemy-garrison scans (needs an owned military site)
STCTI_SERVICE_COST   = [["money", 100], ["fuel", 30], ["ammo", 50]];   // full repair/refuel/rearm

// --- Ambient civilians (Phase 8, design §6.2) — atmosphere only, no gameplay effect.
STCTI_CIVILIANS      = true;
STCTI_CIV_CAP        = 3;      // max wandering cars at once
STCTI_CIV_INTERVAL   = 30;     // seconds between spawn/prune checks
STCTI_CIV_SPAWNRANGE = 1200;   // a player this close to a town makes it eligible
STCTI_CIV_DESPAWN    = 2000;   // no player within this of a car -> despawn
STCTI_CIV_CARS = ["C_Offroad_01_F", "C_Hatchback_01_F", "C_SUV_01_F", "C_Van_01_transport_F"];
STCTI_CIV_MEN  = ["C_man_1", "C_man_polo_1_F", "C_man_shorts_1_F"];

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
            ["mrap", "B_MRAP_01_hmg_F"], ["truck", "B_Truck_01_transport_F"],
            ["apc", "B_APC_Tracked_01_rcws_F"], ["ifv", "B_APC_Wheeled_01_cannon_F"],
            ["mbt", "B_MBT_01_cannon_F"], ["mbt_heavy", "B_MBT_01_TUSK_F"],
            ["heli_transport", "B_Heli_Transport_01_F"], ["heli_atk", "B_Heli_Attack_01_dynamicLoadout_F"],
            ["jet_cas", "B_Plane_CAS_01_dynamicLoadout_F"],
            ["uav_recon", "B_UAV_01_F"], ["uav_armed", "B_UAV_02_dynamicLoadout_F"],
            ["boat", "B_Boat_Armed_01_minigun_F"]
        ]],
        ["statics", createHashMapFromArray [["static_he", "B_HMG_01_high_F"], ["static_at", "B_static_AT_F"], ["static_aa", "B_static_AA_F"]]],
        // Arsenal tiers: unlockId ("" = from the start) -> unit classes whose config gear gets
        // whitelisted into the base arsenal (fn_updateArsenal). Keyed by the same category
        // taxonomy the garage gates on (roadmap §1.2) — weapons ride the unlocks for free.
        ["arsenalUnits", createHashMapFromArray [
            ["",              ["B_Soldier_F", "B_soldier_AR_F", "B_medic_F", "B_soldier_AT_F", "B_soldier_AA_F"]],
            ["cat_armor",     ["B_crew_F"]],
            ["cat_rotary",    ["B_helicrew_F"]],
            ["cat_uav",       ["B_soldier_UAV_F"]],
            ["cat_fixedwing", ["B_Pilot_F", "B_Heli_Pilot_F"]]
        ]]
    ]],
    ["CSAT", createHashMapFromArray [
        ["enemy", "NATO"], ["flag", "Flag_CSAT_F"],
        ["units", createHashMapFromArray [
            ["rifleman", "O_Soldier_F"], ["at_team", "O_Soldier_AT_F"], ["aa_team", "O_Soldier_AA_F"],
            ["mrap", "O_MRAP_02_hmg_F"], ["truck", "O_Truck_03_transport_F"],
            ["apc", "O_APC_Tracked_02_cannon_F"], ["ifv", "O_APC_Wheeled_02_rcws_v2_F"],
            ["mbt", "O_MBT_02_cannon_F"], ["mbt_heavy", "O_MBT_04_cannon_F"],
            ["heli_transport", "O_Heli_Light_02_unarmed_F"], ["heli_atk", "O_Heli_Attack_02_dynamicLoadout_F"],
            ["jet_cas", "O_Plane_CAS_02_dynamicLoadout_F"],
            ["uav_recon", "O_UAV_01_F"], ["uav_armed", "O_UAV_02_dynamicLoadout_F"],
            ["boat", "O_Boat_Armed_01_hmg_F"]
        ]],
        ["statics", createHashMapFromArray [["static_he", "O_HMG_01_high_F"], ["static_at", "O_static_AT_F"], ["static_aa", "O_static_AA_F"]]],
        ["arsenalUnits", createHashMapFromArray [
            ["",              ["O_Soldier_F", "O_Soldier_AR_F", "O_medic_F", "O_Soldier_AT_F", "O_Soldier_AA_F"]],
            ["cat_armor",     ["O_crew_F"]],
            ["cat_rotary",    ["O_helicrew_F"]],
            ["cat_uav",       ["O_soldier_UAV_F"]],
            ["cat_fixedwing", ["O_Pilot_F", "O_helipilot_F"]]
        ]]
    ]],
    ["AAF", createHashMapFromArray [
        ["enemy", "CSAT"], ["flag", "Flag_AAF_F"],
        ["units", createHashMapFromArray [
            ["rifleman", "I_Soldier_F"], ["at_team", "I_Soldier_AT_F"], ["aa_team", "I_Soldier_AA_F"],
            ["mrap", "I_MRAP_03_hmg_F"], ["truck", "I_Truck_02_transport_F"],
            ["apc", "I_APC_tracked_03_cannon_F"], ["ifv", "I_APC_Wheeled_03_cannon_F"],
            // AAF has no heavy MBT or attack helicopter — Kuma doubles as heavy, the armed
            // Hellcat is the closest native equivalent (v1 native-factions-only rule, design §1).
            ["mbt", "I_MBT_03_cannon_F"], ["mbt_heavy", "I_MBT_03_cannon_F"],
            ["heli_transport", "I_Heli_Transport_02_F"], ["heli_atk", "I_Heli_light_03_dynamicLoadout_F"],
            ["jet_cas", "I_Plane_Fighter_03_dynamicLoadout_F"],
            ["uav_recon", "I_UAV_01_F"], ["uav_armed", "I_UAV_02_dynamicLoadout_F"],
            ["boat", "I_Boat_Armed_01_minigun_F"]
        ]],
        ["statics", createHashMapFromArray [["static_he", "I_HMG_01_high_F"], ["static_at", "I_static_AT_F"], ["static_aa", "I_static_AA_F"]]],
        ["arsenalUnits", createHashMapFromArray [
            ["",              ["I_soldier_F", "I_Soldier_AR_F", "I_medic_F", "I_Soldier_AT_F", "I_Soldier_AA_F"]],
            ["cat_armor",     ["I_crew_F"]],
            ["cat_rotary",    ["I_helicrew_F"]],
            ["cat_uav",       ["I_soldier_UAV_F"]],
            ["cat_fixedwing", ["I_pilot_F", "I_helipilot_F"]]
        ]]
    ]]
];

// DLC detection (roadmap Phase 11, Tier A/B split). First-party DLC hardware is usable by
// everyone (engine store-nags unowned players), so it lives directly in the pools above.
// CDLC (Tier B) requires ownership by every MP player and ships as opt-in extension packs —
// deliberately NOT loaded in v1 (native-factions non-goal); the detection table is the hook.
STCTI_DLC = createHashMapFromArray [
    ["apex", isClass (configFile >> "CfgPatches" >> "A3_Characters_F_Tanoa")],
    ["gm",   isClass (configFile >> "CfgPatches" >> "gm_core")],
    ["vn",   isClass (configFile >> "CfgPatches" >> "vn_main")],
    ["ws",   isClass (configFile >> "CfgPatches" >> "WS_core")],
    ["spe",  isClass (configFile >> "CfgPatches" >> "SPE_core")]
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
