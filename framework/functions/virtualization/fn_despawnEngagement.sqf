// fn_despawnEngagement.sqf — [SERVER] params: [_eng]
// Observer left an ongoing live fight (resolver spec §7, "observer leaves → despawn"): recount
// both sides' survivors back into the engagement counts, delete the units, and unpause so the
// resolver resumes the fight abstractly from the new counts. startA/startD are left unchanged so
// the break ratio stays anchored to the engagement's start. Idempotent.
params ["_eng"];
if (!isServer) exitWith {};
if !(_eng get "spawned") exitWith {};

(_eng get "groups") params [["_attGrp", grpNull], ["_defGrp", grpNull]];
_eng set ["attacker", [_attGrp] call STCTI_fnc_recountForce];
_eng set ["defender", [_defGrp] call STCTI_fnc_recountForce];
{ [_x] call STCTI_fnc_despawnGroup; } forEach [_attGrp, _defGrp];

_eng set ["groups", []];
_eng set ["spawned", false];
_eng set ["paused", false];   // resolver resumes

// The defender group was also the sector's standing garrison — it's gone now, so the sector
// returns to virtual until re-observed.
private _rec = (STCTI_state get "sectors") get (_eng get "sectorId");
if (!isNil "_rec") then { _rec set ["garrisonGroup", grpNull]; _rec set ["spawned", false]; };

diag_log format ["[STCTI] Engagement at %1 DESPAWNED (observer left); resolver resumes (A=%2 D=%3).",
    _eng get "sectorId", _eng get "attacker", _eng get "defender"];
