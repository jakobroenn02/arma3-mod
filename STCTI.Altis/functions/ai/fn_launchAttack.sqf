// fn_launchAttack.sqf — [SERVER] picks a player sector, warns, then attacks it. See §F1.
// Phase 2 step 1: after the warning, the attack resolves one of two ways —
//   • sector OBSERVED (a player is near) -> spawn the assault as LIVE units, fought in person;
//   • sector UNOBSERVED                  -> resolve it abstractly through the combat resolver.
// Both paths use the same STCTI_ATTACK_ROSTER, so a staged defence you walk away from plays
// out at the same strength it would if you'd stayed. See abstract-combat-resolution-spec.md.
if (!isServer) exitWith {};

private _targets = (values (STCTI_state get "sectors")) select { (_x get "owner") isEqualTo "player" };
if (_targets isEqualTo []) exitWith {}; // nothing to attack yet

private _target = selectRandom _targets;
private _id     = _target get "id";
private _tpos   = _target get "pos";

// Warn the player NOW; resolve after the warning lead time.
[STCTI_EV_ATTACK_INBOUND, [_id]] call CBA_fnc_globalEvent;

[{
    params ["_id", "_tpos"];
    private _rec = (STCTI_state get "sectors") get _id;
    if (isNil "_rec") exitWith {};
    if !((_rec get "owner") isEqualTo "player") exitWith {};       // taken/lost during the warning
    if (_id in keys STCTI_engagements) exitWith {};                // already being fought over

    // Fresh attacker roster each time (the resolver mutates its force map).
    private _att = createHashMap;
    { _att set [_x select 0, _x select 1]; } forEach STCTI_ATTACK_ROSTER;

    if ([_id] call STCTI_fnc_isSectorObserved) then {
        // OBSERVED — spawn the assault live; the player fights it directly.
        private _spawn = _tpos getPos [1200, random 360];
        private _grp = [_spawn, STCTI_SIDE_ENEMY, ([_att] call STCTI_fnc_rosterToClasses)] call BIS_fnc_spawnGroup;
        private _wp = _grp addWaypoint [_tpos, 0];
        _wp setWaypointType "SAD";
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        diag_log format ["[STCTI] Live assault spawned on %1 (%2 attackers).", _id, count units _grp];
    } else {
        // UNOBSERVED — hand the fight to the abstract resolver. The defender is the sector's
        // virtual garrison; the resolver mutates it in place so losses persist, and checkBreak
        // flips ownership / fires STCTI_EV_ENGAGEMENT_RESOLVED when it breaks.
        private _def = _rec get "defenderForce";
        if (isNil "_def") then {
            _def = createHashMapFromArray [["rifleman", STCTI_PLAYER_GARRISON]];
            _rec set ["defenderForce", _def];
        };
        [_id, _att, _def, "enemy", "player"] call STCTI_fnc_beginEngagement;
    };
}, [_id, _tpos], STCTI_ATTACK_WARNING] call CBA_fnc_waitAndExecute;
