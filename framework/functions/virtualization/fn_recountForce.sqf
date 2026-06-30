// fn_recountForce.sqf — [SERVER] params: [_group] -> HashMap resolverType -> count (living only)
// Counts the living tagged principals of a spawned force (infantry, vehicles, statics) back into an
// abstract force, so it can be virtualized again with losses preserved. Reads STCTI_entities (set by
// fn_spawnForce) so vehicles/statics — which are NOT in `units group` — are counted; falls back to
// `units group` for plain infantry groups.
params ["_grp"];
private _out = createHashMap;
if (isNull _grp) exitWith { _out };

{
    if (alive _x) then {
        private _t = _x getVariable ["STCTI_type", ""];
        if (_t != "") then { _out set [_t, (_out getOrDefault [_t, 0]) + 1]; };
    };
} forEach (_grp getVariable ["STCTI_entities", units _grp]);

_out
