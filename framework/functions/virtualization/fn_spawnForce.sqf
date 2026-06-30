// fn_spawnForce.sqf — [SERVER] params: [_force, _ownerKey, _center, _scatter] -> Group
// Instantiates an abstract force (HashMap typeId -> count) as live units, scattered within
// _scatter m of _center, each tagged with its STCTI_type so fn_recountForce can read survivors
// back. _ownerKey ("player"|"enemy") selects BOTH the group's side and the faction's classnames
// (STCTI_FACTION) — so a side never spawns wearing the other faction's uniform. Caller owns the
// returned group's lifecycle (createGroup deleteWhenEmpty=false).
params ["_force", "_ownerKey", "_center", ["_scatter", 30]];
if (!isServer) exitWith { grpNull };

private _side    = if (_ownerKey isEqualTo "player") then { STCTI_SIDE_PLAYER } else { STCTI_SIDE_ENEMY };
private _classes = STCTI_FACTION getOrDefault [_ownerKey, STCTI_FACTION get "enemy"];

private _grp = createGroup [_side, false];
{
    private _type = _x;
    private _cls  = _classes getOrDefault [_type, "O_Soldier_F"];
    private _init = format ["this setVariable ['STCTI_type', '%1', false];", _type];
    for "_i" from 1 to _y do {
        // Sample a LAND position near _center — coastal sectors (Kavala etc.) were spawning units
        // in the sea. Fall back to _center if every sample is water (won't happen near a land sector).
        private _p = _center;
        for "_try" from 1 to 12 do {
            private _cand = _center getPos [random (_scatter max 10), random 360];
            if !(surfaceIsWater _cand) exitWith { _p = _cand; };
        };
        _cls createUnit [_p, _grp, _init, 0.6, "PRIVATE"];
    };
} forEach _force;

_grp
