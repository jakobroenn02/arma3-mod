// fn_registerSector.sqf — [SERVER] params: [id, type, pos, radius, incomeArray]
// Creates the sector record + a global map marker, stores it in state. See §C1.
params ["_id", "_type", "_pos", "_radius", ["_income", []]];
if (!isServer) exitWith {};

private _rec = createHashMapFromArray [
    ["id", _id], ["type", _type], ["pos", _pos], ["radius", _radius],
    ["owner", "enemy"], ["captureProgress", 0],
    ["income", createHashMapFromArray _income],
    ["garrison", []], ["spawned", false]
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
