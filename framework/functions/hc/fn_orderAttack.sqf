// fn_orderAttack.sqf — [SERVER] params: [_grp, _pos, _radius]
// Staged-attack order backend (Phase 5): LAMBS taskAssault when lambs_wp is loaded (spawned —
// scheduled script), else MOVE + SAD at the objective. Capture itself needs no extra wiring:
// fn_updateSectorCapture counts any player-side unit standing in the sector, so a squad that
// wins the ground fight captures it by presence, exactly like the player on foot.
params ["_grp", "_pos", ["_radius", 100]];
if (!isServer || {isNull _grp}) exitWith {};

for "_i" from count waypoints _grp - 1 to 0 step -1 do { deleteWaypoint [_grp, _i]; };
_grp setBehaviour "AWARE";
_grp setCombatMode "RED";

if (STCTI_HAS_LAMBS_WP) exitWith {
    [_grp, _pos, _radius] spawn lambs_wp_fnc_taskAssault;
};

private _move = _grp addWaypoint [_pos, 50];
_move setWaypointType "MOVE";
private _sad = _grp addWaypoint [_pos, _radius];
_sad setWaypointType "SAD";
