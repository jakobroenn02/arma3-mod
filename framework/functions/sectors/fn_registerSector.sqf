// fn_registerSector.sqf — [SERVER] params: [id, type, pos, radius, income, heading, layoutId]
// Creates the sector record + a global map marker, stores it in state. The enemy garrison's
// defenderForce is DERIVED from the layout (sector-layout-spec §2.4) — never hand-typed — so the
// live spawn and the resolver can't disagree. Towns (empty layout) fall back to a rifleman baseline.
// _heading / _layoutId default so older callers don't break. See §C1.
params ["_id", "_type", "_pos", "_radius", ["_income", []], ["_heading", 0], ["_layoutId", "town_light"], ["_grantsUnlock", ""]];
if (!isServer) exitWith {};

private _comp = [_layoutId] call STCTI_fnc_layoutComposition;
if (count _comp == 0) then { _comp = createHashMapFromArray [["rifleman", STCTI_GARRISON_SIZE]]; };

private _rec = createHashMapFromArray [
    ["id", _id], ["type", _type], ["pos", _pos], ["radius", _radius],
    ["owner", "enemy"], ["captureProgress", 0],
    ["income", createHashMapFromArray _income],
    ["heading", _heading], ["layout", _layoutId], ["grantsUnlock", _grantsUnlock],
    ["defenderForce", _comp],
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
