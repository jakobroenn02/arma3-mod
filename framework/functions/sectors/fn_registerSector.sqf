// fn_registerSector.sqf — [SERVER] params: [id, type, pos, radius, income, heading, layoutId]
// Creates the sector record + a global map marker, stores it in state. The enemy garrison's
// defenderForce is DERIVED from the layout (sector-layout-spec §2.4) — never hand-typed — so the
// live spawn and the resolver can't disagree. Towns (empty layout) fall back to a rifleman baseline.
// _heading / _layoutId default so older callers don't break. See §C1.
params ["_id", "_type", "_pos", "_radius", ["_income", []], ["_heading", 0], ["_layoutId", "town_light"], ["_grantsUnlock", ""], ["_travelNode", -1]];
if (!isServer) exitWith {};

// Travel-node default (roadmap §1.1): towns + military are nodes, bare resource depots are
// not; -1 means "derive from type", 0/1 are explicit config overrides.
if (_travelNode < 0) then { _travelNode = parseNumber (_type in ["town", "military"]); };

// Authored positions may be PLACEHOLDER coordinates (towns come from the engine and are
// always fine) — never register a sector in the water; snap to the nearest land instead.
if (_type isNotEqualTo "town" && {surfaceIsWater _pos}) then {
    private _s = [_pos, 0, 600, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (count _s >= 2) then {
        diag_log format ["[STCTI] Sector %1 position was in water — snapped %2 -> %3.", _id, _pos, _s];
        _pos = [_s select 0, _s select 1, 0];
    };
};

private _comp = [_layoutId] call STCTI_fnc_layoutComposition;
if (count _comp == 0) then { _comp = createHashMapFromArray [["rifleman", STCTI_GARRISON_SIZE]]; };

private _rec = createHashMapFromArray [
    ["id", _id], ["type", _type], ["pos", _pos], ["radius", _radius],
    ["owner", "enemy"], ["captureProgress", 0],
    ["income", createHashMapFromArray _income],
    ["heading", _heading], ["layout", _layoutId], ["grantsUnlock", _grantsUnlock],
    ["travelNode", _travelNode > 0],
    ["defenderForce", _comp],
    ["hardening", []],   // player-built static slots [role, worldPos, dir] — see fn_serverPlaceStatic
    ["garrison", []], ["garrisonGroup", grpNull], ["spawned", false]
];
(STCTI_state get "sectors") set [_id, _rec];

// Global marker (createMarker broadcasts) — an ellipse area + a labelled dot.
private _mName = "mk_" + _id;
private _m = createMarker [_mName, _pos];
_m setMarkerShape "ELLIPSE";
_m setMarkerSize [_radius, _radius];
_m setMarkerBrush "Border";
_m setMarkerAlpha 0.6;

private _dot = createMarker [_mName + "_dot", _pos];
_dot setMarkerType "mil_dot";
_dot setMarkerText _id;

[_id] call STCTI_fnc_updateSectorMarker;
