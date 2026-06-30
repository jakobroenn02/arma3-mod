// fn_syncEngagement.sqf — [SERVER] params: [_eng]
// While an engagement is spawned the abstract resolver is paused, so the live fight needs its own
// end condition: if either side is wiped out in live combat, resolve the engagement at that
// outcome. Called each manager tick for spawned engagements.
params ["_eng"];
if (!isServer) exitWith {};
if !(_eng get "spawned") exitWith {};

(_eng get "groups") params [["_attGrp", grpNull], ["_defGrp", grpNull]];
private _attN = { alive _x } count (units _attGrp);
private _defN = { alive _x } count (units _defGrp);

if (_attN <= 0 || {_defN <= 0}) then {
    [_eng, if (_attN <= 0) then { "attacker" } else { "defender" }] call STCTI_fnc_resolveSpawnedEngagement;
};
