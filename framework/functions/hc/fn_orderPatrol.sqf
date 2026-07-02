// fn_orderPatrol.sqf — [SERVER] params: [_grp, _pos, _radius]
// Patrol order backend (Phase 5): LAMBS taskPatrol when lambs_wp is loaded (spawn — the lambs
// task functions are scheduled scripts, calling them raw is what broke the CBA PFH pool once),
// else a 4-point MOVE + CYCLE loop around the target. Existing waypoints are cleared first.
params ["_grp", "_pos", ["_radius", 150]];
if (!isServer || {isNull _grp}) exitWith {};

for "_i" from count waypoints _grp - 1 to 0 step -1 do { deleteWaypoint [_grp, _i]; };
_grp setBehaviour "SAFE";
_grp setCombatMode "YELLOW";

if (STCTI_HAS_LAMBS_WP) exitWith {
    [_grp, _pos, _radius] spawn lambs_wp_fnc_taskPatrol;
};

{
    private _wp = _grp addWaypoint [_pos getPos [_radius, _x], 30];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
} forEach [0, 90, 180, 270];
private _cycle = _grp addWaypoint [_pos, 30];
_cycle setWaypointType "CYCLE";
