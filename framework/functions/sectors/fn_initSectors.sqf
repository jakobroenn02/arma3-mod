// fn_initSectors.sqf — [SERVER] called once after initState. Registers ALL sectors through the one
// merge point (fn_registerSector), from two sources (sector-layout-spec §2.5):
//   1) towns  — AUTO-DETECTED from the engine's location index (exact positions, every map free);
//   2) strategic sectors — AUTHORED in CfgSTCTISectors >> worldName (few, high-value, designer-placed).
// Downstream code never knows or cares which tier a sector came from.
if (!isServer) exitWith {};

// 1) Auto-detect towns.
private _center = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
{
    private _name = text _x;
    if (_name isEqualTo "") then { _name = format ["town_%1", _forEachIndex]; };
    private _sz = size _x;                                   // [a, b] location half-extents
    private _radius = ((_sz select 0) max (_sz select 1) max 150) min 400;
    [_name, "town", locationPosition _x, _radius, [["money", 50], ["manpower", 2]], 0, "town_light", ""]
        call STCTI_fnc_registerSector;
} forEach (nearestLocations [_center, ["NameCityCapital", "NameCity", "NameVillage"], 1e6]);

// 2) Authored strategic sectors from CfgSTCTISectors >> <worldName> (empty/absent on unsupported maps).
private _root = missionConfigFile >> "CfgSTCTISectors" >> worldName;
{
    private _c = _x;
    [   configName _c,
        getText   (_c >> "type"),
        getArray  (_c >> "position"),
        getNumber (_c >> "captureRadius"),
        getArray  (_c >> "income"),
        getNumber (_c >> "heading"),
        getText   (_c >> "layout"),
        getText   (_c >> "grantsUnlock")
    ] call STCTI_fnc_registerSector;
} forEach (configProperties [_root, "isClass _x", true]);

diag_log format ["[STCTI] Sectors registered: %1 total (auto towns + authored strategic).",
    count (keys (STCTI_state get "sectors"))];
