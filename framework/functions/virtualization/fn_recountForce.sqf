// fn_recountForce.sqf — [SERVER] params: [_group] -> HashMap typeId -> count (living only)
// Reads each living unit's STCTI_type tag (set by fn_spawnForce) back into an abstract force,
// so a spawned force can be virtualized again with its losses preserved.
params ["_grp"];
private _out = createHashMap;
if (isNull _grp) exitWith { _out };

{
    if (alive _x) then {
        private _t = _x getVariable ["STCTI_type", ""];
        if (_t != "") then { _out set [_t, (_out getOrDefault [_t, 0]) + 1]; };
    };
} forEach units _grp;

_out
