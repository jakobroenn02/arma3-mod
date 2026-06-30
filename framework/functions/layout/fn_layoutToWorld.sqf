// fn_layoutToWorld.sqf — [GLOBAL] params: [_centre, _heading, _layoutId] -> [[role, worldPos, worldDir], ...]
// Resolves a layout's polar slot offsets into world space, rotated by the sector's heading. The
// geometry primitive the garrison spawn (and later §6.1 hardening) build on. See sector-layout-spec §2.1.
params ["_centre", "_heading", "_layoutId"];
(STCTI_LAYOUTS getOrDefault [_layoutId, []]) apply {
    _x params ["_role", "_dist", "_bear", "_face"];
    [_role, [_centre, _dist, _heading + _bear] call BIS_fnc_relPos, _heading + _face]
}
