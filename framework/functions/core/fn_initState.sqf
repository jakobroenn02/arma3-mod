// fn_initState.sqf — [SERVER] call once. Builds the single world-state spine.
// Sets global STCTI_state. See §A2.
if (!isServer) exitWith {};

STCTI_state = createHashMapFromArray [
    ["resources", createHashMapFromArray [
        ["money", 5000], ["manpower", 50], ["fuel", 2000], ["ammo", 2000]
    ]],
    ["sectors", createHashMap],      // sectorId -> sector record
    ["storedVehicles", []],          // player vehicles parked in the garage: [class, hitPoints, fuel]
    ["aggression", STCTI_AGGRO_START], // AI director pacing scalar 0..1 (Phase 4, design §8)
    ["opCooldownUntil", 0],          // mission time before which the director may not launch again
    ["hcGroups", []]                 // recruited High Command squads (group refs; pruned on read)
];

// Active abstract-combat engagements: sectorId -> engagement record (resolver §2).
STCTI_engagements = createHashMap;
