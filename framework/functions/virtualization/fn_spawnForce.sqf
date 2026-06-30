// fn_spawnForce.sqf — [SERVER] params: [_force, _side, _center, _scatter] -> Group
// Instantiates an abstract force (HashMap typeId -> count) as live units of _side, scattered
// within _scatter m of _center, each tagged with its STCTI_type so fn_recountForce can read the
// survivors back. The inverse of fn_recountForce; shared by garrison caching and (later) the
// engagement handoff. Caller owns the returned group's lifecycle (createGroup deleteWhenEmpty=false).
params ["_force", "_side", "_center", ["_scatter", 30]];
if (!isServer) exitWith { grpNull };

private _grp = createGroup [_side, false];
{
    private _type = _x;
    private _cls  = STCTI_TYPE_CLASS getOrDefault [_type, "O_Soldier_F"];
    private _init = format ["this setVariable ['STCTI_type', '%1', false];", _type];
    for "_i" from 1 to _y do {
        private _p = _center getPos [random _scatter, random 360];
        _cls createUnit [_p, _grp, _init, 0.6, "PRIVATE"];
    };
} forEach _force;

_grp
