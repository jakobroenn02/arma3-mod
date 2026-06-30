// fn_launchAttack.sqf — [SERVER] picks a player sector, warns, then attacks it. See §F1.
// Phase 2: the attack always becomes an ENGAGEMENT. Observation then decides how it plays out,
// uniformly — beginEngagement spawns it live at once if a player is watching, otherwise the
// resolver fights it as math until a player flies over and the virtualization manager hands it
// off (and back). One code path, same STCTI_ATTACK_ROSTER either way.
if (!isServer) exitWith {};

private _targets = (values (STCTI_state get "sectors")) select { (_x get "owner") isEqualTo "player" };
if (_targets isEqualTo []) exitWith {}; // nothing to attack yet

private _target = selectRandom _targets;
private _id     = _target get "id";

// Warn the player NOW; commit the attack after the warning lead time.
[STCTI_EV_ATTACK_INBOUND, [_id]] call CBA_fnc_globalEvent;

[{
    params ["_id"];
    private _rec = (STCTI_state get "sectors") get _id;
    if (isNil "_rec") exitWith {};
    if !((_rec get "owner") isEqualTo "player") exitWith {};       // taken/lost during the warning
    if (_id in keys STCTI_engagements) exitWith {};                // already being fought over

    // Fresh attacker roster each time (the resolver/spawn mutate the force map).
    private _att = createHashMap;
    { _att set [_x select 0, _x select 1]; } forEach STCTI_ATTACK_ROSTER;

    // Defender is the sector's virtual garrison (baseline seeded on capture).
    private _def = _rec get "defenderForce";
    if (isNil "_def") then {
        _def = createHashMapFromArray [["rifleman", STCTI_PLAYER_GARRISON]];
        _rec set ["defenderForce", _def];
    };

    [_id, _att, _def, "enemy", "player"] call STCTI_fnc_beginEngagement;
}, [_id], STCTI_ATTACK_WARNING] call CBA_fnc_waitAndExecute;
