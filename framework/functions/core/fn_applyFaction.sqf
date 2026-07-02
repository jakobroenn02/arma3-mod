// fn_applyFaction.sqf — [SERVER] params: [factionName]  ("NATO" | "CSAT" | "AAF")
// Applies the campaign-setup faction pick (design §Phase-3): populates STCTI_FACTION,
// STCTI_STATIC_CLASS, STCTI_PLAYER_FLAG and rebuilds STCTI_garageCatalog from the template,
// all from STCTI_FACTION_POOL, then broadcasts so clients' garage menus match. The opponent is
// the pool's per-faction default. Engine sides are NOT touched — see the deliberate deviation
// note on STCTI_FACTION_POOL (classes swap, west/east stay). Call BEFORE anything spawns for a
// clean campaign; already-spawned units keep their old classes until they despawn.
params [["_name", "NATO"]];
if (!isServer) exitWith {};
if !(_name in STCTI_FACTION_POOL) then {
    diag_log format ["[STCTI] applyFaction: unknown faction %1 — defaulting to NATO.", _name];
    _name = "NATO";
};

private _pf = STCTI_FACTION_POOL get _name;
private _ef = STCTI_FACTION_POOL get (_pf get "enemy");

STCTI_PLAYER_FACTION = _name;
STCTI_PLAYER_FLAG    = _pf get "flag";
STCTI_FACTION      = createHashMapFromArray [["player", _pf get "units"], ["enemy", _ef get "units"]];
STCTI_STATIC_CLASS = createHashMapFromArray [["player", _pf get "statics"], ["enemy", _ef get "statics"]];
STCTI_garageCatalog = STCTI_garageCatalogTemplate apply {
    _x params ["_role", "_price", "_unlock", "_fuel"];
    private _cls = (_pf get "units") get _role;
    [format ["Buy %1 — $%2 + %3 fuel", getText (configFile >> "CfgVehicles" >> _cls >> "displayName"), _price, _fuel],
     _cls, _price, _unlock, _fuel]
};

publicVariable "STCTI_PLAYER_FACTION";
publicVariable "STCTI_FACTION";
publicVariable "STCTI_STATIC_CLASS";
publicVariable "STCTI_garageCatalog";

diag_log format ["[STCTI] Faction applied: player=%1, enemy=%2.", _name, _pf get "enemy"];
