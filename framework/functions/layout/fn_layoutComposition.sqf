// fn_layoutComposition.sqf — [GLOBAL] params: [_layoutId] -> HashMap (resolverType -> count)
// THE single-source-of-truth derivation (sector-layout-spec §2.2): a layout's abstract resolver
// force is COUNTED from its slots, never hand-typed alongside it — so the live spawn and the
// abstract resolver can't silently disagree. Roles with resolverType "" are decoration and skipped.
params ["_layoutId"];
private _force = createHashMap;
{
    private _role = _x select 0;
    (STCTI_ROLES getOrDefault [_role, ["", ""]]) params ["_kind", "_rtype"];
    if (_rtype != "") then { _force set [_rtype, (_force getOrDefault [_rtype, 0]) + 1]; };
} forEach (STCTI_LAYOUTS getOrDefault [_layoutId, []]);
_force
