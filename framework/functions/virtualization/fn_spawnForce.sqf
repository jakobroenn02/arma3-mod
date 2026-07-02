// fn_spawnForce.sqf — [SERVER] params: [_force, _ownerKey, _centre, _scatter, _heading, _layoutId] -> Group
// Instantiates an abstract force (HashMap resolverType -> count) as live units of _ownerKey's side.
// If a non-empty _layoutId is given, the composition is placed into that layout's SLOTS (vehicles,
// statics, infantry posts at their authored positions/facings — sector-layout-spec §2.3), matching
// each slot's resolverType; anything left over (or with no layout, e.g. an assault force or a town's
// building garrison) scatters on land near _centre. Every spawned principal is tagged with
// STCTI_type and recorded in the group's STCTI_entities for recount/despawn. Caller owns lifecycle.
params ["_force", "_ownerKey", "_centre", ["_scatter", 30], ["_heading", 0], ["_layoutId", ""], ["_extraSlots", []]];
if (!isServer) exitWith { grpNull };

private _side = if (_ownerKey isEqualTo "player") then { STCTI_SIDE_PLAYER } else { STCTI_SIDE_ENEMY };
private _grp  = createGroup [_side, false];
private _ents = [];
private _work = +_force;   // mutable copy — never mutate the caller's defenderForce

// 1) Slot placement: the layout's authored slots (skip the empty town layout) plus any
// caller-supplied world-space extras (sector hardening — player-built statics).
private _slots = if (_layoutId != "" && {_layoutId != "town_light"}) then {
    [_centre, _heading, _layoutId] call STCTI_fnc_layoutToWorld
} else { [] };
{
    _x params ["_role", "_wpos", "_wdir"];
    (STCTI_ROLES getOrDefault [_role, ["infantry", ""]]) params ["_kind", "_rtype"];
    if (_rtype != "" && {(_work getOrDefault [_rtype, 0]) > 0}) then {
        private _e = [_rtype, _kind, _role, _wpos, _wdir, _grp, _ownerKey] call STCTI_fnc_spawnUnit;
        if (!isNull _e) then { _ents pushBack _e; };
        _work set [_rtype, (_work get _rtype) - 1];
    };
} forEach (_slots + _extraSlots);

// 2) Leftover composition (types with no matching slot, or no layout at all) -> scatter on land.
{
    private _rtype = _x;
    private _n     = _y;
    if (_n > 0) then {
        private _cat  = [_rtype, "category"] call STCTI_fnc_unitAttr;     // infantry | armor | air
        private _kind = if (_cat in ["armor", "air"]) then { "vehicle" } else { "infantry" };
        for "_i" from 1 to _n do {
            private _p = _centre;
            for "_try" from 1 to 12 do {
                private _c = _centre getPos [random (_scatter max 10), random 360];
                if !(surfaceIsWater _c) exitWith { _p = _c; };
            };
            private _e = [_rtype, _kind, "", _p, random 360, _grp, _ownerKey] call STCTI_fnc_spawnUnit;
            if (!isNull _e) then { _ents pushBack _e; };
        };
    };
} forEach _work;

_grp setVariable ["STCTI_entities", _ents];
_grp
