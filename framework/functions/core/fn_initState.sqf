// fn_initState.sqf — [SERVER] call once. Builds the single world-state spine.
// Sets global STCTI_state. See §A2.
if (!isServer) exitWith {};

STCTI_state = createHashMapFromArray [
    ["resources", createHashMapFromArray [
        ["money", 5000], ["manpower", 50], ["fuel", 2000], ["ammo", 2000]
    ]],
    ["sectors", createHashMap]   // sectorId -> sector record
];

// Active abstract-combat engagements: sectorId -> engagement record (resolver §2).
STCTI_engagements = createHashMap;
