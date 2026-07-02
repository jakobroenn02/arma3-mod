// fn_orderDefend.sqf — [SERVER] params: [_grp, _pos, _radius]
// Defend order backend (Phase 5). Deliberately VANILLA even when LAMBS is loaded:
// lambs_wp_fnc_taskGarrison misuse broke the CBA PFH pool once (see repo history 4e851df) and
// a GUARD waypoint gets defensive behaviour that is good enough — LAMBS's danger FSM still
// drives the actual fighting once contact happens.
params ["_grp", "_pos", ["_radius", 80]];
if (!isServer || {isNull _grp}) exitWith {};

for "_i" from count waypoints _grp - 1 to 0 step -1 do { deleteWaypoint [_grp, _i]; };
_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";

private _wp = _grp addWaypoint [_pos, _radius * 0.5];
_wp setWaypointType "GUARD";
