// fn_launchAttack.sqf — [SERVER] picks a player sector, warns, then assaults it. See §F1.
if (!isServer) exitWith {};

private _targets = (values (STCTI_state get "sectors")) select { (_x get "owner") isEqualTo "player" };
if (_targets isEqualTo []) exitWith {}; // nothing to attack yet

private _target = selectRandom _targets;
private _tpos   = _target get "pos";

// Warn the player NOW; spawn after the warning delay.
[STCTI_EV_ATTACK_INBOUND, [_target get "id"]] call CBA_fnc_globalEvent;

[{
    params ["_tpos"];
    private _spawn = _tpos getPos [1200, random 360];
    private _grp = [_spawn, STCTI_SIDE_ENEMY, (STCTI_FACTION_ENEMY get "riflemen")] call BIS_fnc_spawnGroup;
    private _wp = _grp addWaypoint [_tpos, 0];
    _wp setWaypointType "SAD";
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
}, [_tpos], STCTI_ATTACK_WARNING] call CBA_fnc_waitAndExecute;
