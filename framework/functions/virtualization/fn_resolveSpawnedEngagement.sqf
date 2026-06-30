// fn_resolveSpawnedEngagement.sqf — [SERVER] params: [_eng, _routedSide]
// Resolve a LIVE-spawned engagement whose loser was wiped out in combat: if the defender fell,
// flip the sector to the attacker; the winner's surviving units stay on as the sector's live
// garrison, the loser's remnants are deleted. Fires the same outcome event as the abstract path
// and marks the engagement done (the manager PFH then removes it). Mirrors checkBreak's effects.
params ["_eng", "_routed"];
if (!isServer) exitWith {};

private _id  = _eng get "sectorId";
private _rec = (STCTI_state get "sectors") get _id;
(_eng get "groups") params [["_attGrp", grpNull], ["_defGrp", grpNull]];

if (_routed isEqualTo "defender") then {
    // Attacker took the sector; attacker group becomes the new garrison.
    if (!isNull _defGrp) then { { deleteVehicle _x } forEach units _defGrp; deleteGroup _defGrp; };
    [_id, _eng get "attackerOwner"] call STCTI_fnc_setSectorOwner;   // clears garrison + spawned, recolours, fires capture
    if (!isNil "_rec") then {
        _rec set ["garrisonGroup", _attGrp];
        _rec set ["spawned", true];
        _rec set ["defenderForce", [_attGrp] call STCTI_fnc_recountForce];
    };
} else {
    // Attacker routed; defender holds. Remove attacker remnants, keep the defender as garrison.
    if (!isNull _attGrp) then { { deleteVehicle _x } forEach units _attGrp; deleteGroup _attGrp; };
    if (!isNil "_rec") then {
        _rec set ["garrisonGroup", _defGrp];
        _rec set ["spawned", !isNull _defGrp];
        _rec set ["defenderForce", [_defGrp] call STCTI_fnc_recountForce];
    };
};

[STCTI_EV_ENGAGEMENT_RESOLVED, [
    _id, _routed, _eng get "attacker", _eng get "defender",
    _eng get "startA", _eng get "startD", _eng get "attackerOwner", _eng get "defenderOwner"
]] call CBA_fnc_globalEvent;
diag_log format ["[STCTI] Engagement at %1 resolved LIVE: %2 routed.", _id, _routed];

_eng set ["groups", []];
_eng set ["spawned", false];
_eng set ["done", true];
