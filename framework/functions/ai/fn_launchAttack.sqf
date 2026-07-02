// fn_launchAttack.sqf — [SERVER] params: [rosterPairs] -> Bool (true if an op was committed)
// One director operation (Phase 4, design §8): pick a FRONTIER target (a player sector among
// the 3 nearest to enemy territory — no attacks teleporting deep behind a stable front), fire
// the warning (notification + a shared "defend" task), then commit the attack as an ENGAGEMENT
// after the lead time. Observation decides live vs abstract, uniformly — beginEngagement spawns
// it live at once if a player is watching, otherwise the resolver fights it as math until the
// virtualization manager hands it off (Phase 2, one code path). Travel is abstracted into the
// warning lead time; physical approach convoys belong to the later order layer (Phase 5).
params [["_roster", []]];
if (!isServer) exitWith { false };
if (_roster isEqualTo []) exitWith { false };

private _sectors = values (STCTI_state get "sectors");
private _mine    = _sectors select { (_x get "owner") isEqualTo "player" };
private _theirs  = _sectors select { (_x get "owner") isEqualTo "enemy" };
if (_mine isEqualTo []) exitWith { false }; // nothing to attack yet

private _target = if (_theirs isEqualTo []) then {
    selectRandom _mine   // endgame: no enemy territory left to stage from — anything goes
} else {
    // Score each player sector by distance to the nearest enemy sector ([dist, index] pairs so
    // sort never has to compare hashmaps), take the closest 3 as candidates.
    private _scored = [];
    {
        private _p = _x get "pos";
        private _d = 1e9;
        { _d = _d min (_p distance2D (_x get "pos")); } forEach _theirs;
        _scored pushBack [_d, _forEachIndex];
    } forEach _mine;
    _scored sort true;
    selectRandom ((_scored select [0, 3]) apply { _mine select (_x select 1) })
};
private _id = _target get "id";

// Warn NOW: the F2 notification (initPlayerLocal) plus a shared defend task on the map. The
// task is closed by the ENGAGEMENT_RESOLVED handler in fn_startManagers.
[STCTI_EV_ATTACK_INBOUND, [_id]] call CBA_fnc_globalEvent;
[true, format ["STCTI_op_%1", _id],
    [format ["Enemy forces are moving on %1. Hold the sector.", _id], format ["Defend %1", _id], ""],
    _target get "pos", "CREATED", 5, false, "defend"] call BIS_fnc_taskCreate;

// Commit after the warning lead time.
[{
    params ["_id", "_roster"];
    private _rec = (STCTI_state get "sectors") get _id;
    if (isNil "_rec") exitWith {};
    // Lost/contested during the warning: the op stands down and the task is withdrawn.
    if (!((_rec get "owner") isEqualTo "player") || {_id in keys STCTI_engagements}) exitWith {
        [format ["STCTI_op_%1", _id], "CANCELED"] call BIS_fnc_taskSetState;
    };

    // Fresh attacker roster each time (the resolver/spawn mutate the force map).
    private _att = createHashMap;
    { _att set [_x select 0, _x select 1]; } forEach _roster;

    // Defender is the sector's virtual garrison (baseline seeded on capture).
    private _def = _rec get "defenderForce";
    if (isNil "_def") then {
        _def = createHashMapFromArray [["rifleman", STCTI_PLAYER_GARRISON]];
        _rec set ["defenderForce", _def];
    };
    // If the garrison is LIVE its virtual map is stale by design (live reinforcements and
    // losses only recount on despawn) — anchor startD to what actually exists right now, or
    // the break ratio is computed against the wrong start strength.
    private _grpG = _rec getOrDefault ["garrisonGroup", grpNull];
    if ((_rec get "spawned") && {!isNull _grpG}) then {
        _def = [_grpG] call STCTI_fnc_recountForce;
        _rec set ["defenderForce", _def];
    };

    // Bigger ops (tier 2+, i.e. rosters with an armor element) open with a live prep barrage
    // when someone is watching — the enemy has tubes too. Abstract fights skip the fireworks.
    if (count _roster > 3 && {[_id] call STCTI_fnc_isSectorObserved}) then {
        private _pos = _rec get "pos";
        for "_i" from 1 to 4 do {
            [{
                params ["_p"];
                private _t = _p getPos [random 80, random 360];
                private _sh = createVehicle ["Sh_155mm_AMOS", [_t select 0, _t select 1, 250], [], 0, "CAN_COLLIDE"];
                _sh setVelocity [0, 0, -220];
            }, [_pos], _i * 5 + random 3] call CBA_fnc_waitAndExecute;
        };
    };

    [_id, _att, _def, "enemy", "player"] call STCTI_fnc_beginEngagement;
}, [_id, _roster], STCTI_ATTACK_WARNING] call CBA_fnc_waitAndExecute;
true
