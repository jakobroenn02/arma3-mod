// fn_spawnEngagement.sqf — [SERVER] params: [_eng]
// Hand an abstract engagement off to LIVE units (resolver spec §7, "observer arrives → spawn"):
// pause the resolver for it, spawn the attacker assaulting the sector and the defender holding
// it. If the sector already has a live standing garrison, ADOPT it as the defender rather than
// spawning a second one (no flicker, counts stay consistent). Idempotent.
params ["_eng"];
if (!isServer) exitWith {};
if (_eng get "spawned") exitWith {};

_eng set ["paused", true];   // stop the abstract resolver ticking this engagement

private _id  = _eng get "sectorId";
private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
private _pos = _rec get "pos";
private _r   = _rec get "radius";
private _attOwner = _eng get "attackerOwner";   // "player" | "enemy"
private _defOwner = _eng get "defenderOwner";

// Defender: adopt the live standing garrison if one is up, else spawn from the engagement counts.
private _defGrp = _rec getOrDefault ["garrisonGroup", grpNull];
if (isNull _defGrp || {!(_rec get "spawned")}) then {
    _defGrp = [_eng get "defender", _defOwner, _pos, _r * 0.5] call STCTI_fnc_spawnForce;
    _rec set ["garrisonGroup", _defGrp];
    _rec set ["spawned", true];
};
_defGrp setBehaviour "AWARE";
_defGrp setCombatMode "RED";

// Attacker: stage on LAND just outside the sector (coastal sectors were spawning attackers in the
// sea), then assault the centre. Sample bearings until one is on land.
private _attCenter = _pos;
for "_try" from 1 to 16 do {
    private _cand = _pos getPos [_r + 100 + random 300, random 360];
    if !(surfaceIsWater _cand) exitWith { _attCenter = _cand; };
};
private _attGrp = [_eng get "attacker", _attOwner, _attCenter, 50] call STCTI_fnc_spawnForce;
private _wp = _attGrp addWaypoint [_pos, 0];
_wp setWaypointType "SAD";
_attGrp setBehaviour "AWARE";
_attGrp setCombatMode "RED";

[_attGrp] call STCTI_fnc_offloadGroup;   // headless-client offload (no-op in SP)
[_defGrp] call STCTI_fnc_offloadGroup;

_eng set ["groups", [_attGrp, _defGrp]];
_eng set ["spawned", true];
diag_log format ["[STCTI] Engagement at %1 SPAWNED live (observer arrived).", _id];
