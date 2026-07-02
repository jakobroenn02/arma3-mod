// fn_setSectorOwner.sqf — [SERVER] params: [id, newOwner]
// The single mutation point for ownership. Flips owner, recolours, fires event. See §C3.
params ["_id", "_owner"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
if ((_rec get "owner") isEqualTo _owner) exitWith {};

_rec set ["owner", _owner];
_rec set ["captureProgress", if (_owner isEqualTo "player") then {1} else {0}];
_rec set ["hardening", []];   // player-built statics don't change hands — the new owner starts clean

// Ownership changed: drop the previous owner's live garrison so the virtualization manager
// re-spawns the NEW owner's garrison (from defenderForce) on its next tick.
private _g = _rec getOrDefault ["garrisonGroup", grpNull];
if (!isNull _g) then { [_g] call STCTI_fnc_despawnGroup; };
_rec set ["garrisonGroup", grpNull];
_rec set ["spawned", false];

// On player capture, seed a baseline virtual garrison so an unobserved enemy attack has
// something to fight (rather than instantly flipping). Tune via STCTI_PLAYER_GARRISON.
// (When an abstract fight resolves, checkBreak overwrites this with the survivors.)
if (_owner isEqualTo "player") then {
    _rec set ["defenderForce", createHashMapFromArray [["rifleman", STCTI_PLAYER_GARRISON]]];
};

[_id] call STCTI_fnc_updateSectorMarker;
call STCTI_fnc_updateFrontline;   // ownership moved — the front moved with it

// globalEvent so clients (economy HUD feedback, notifications) react everywhere.
[STCTI_EV_SECTOR_CAPTURED, [_id, _owner]] call CBA_fnc_globalEvent;

// Campaign victory: every sector in player hands. Re-verified after a short delay so the
// final capture's feedback lands (and a same-tick counterflip cancels it).
if (_owner isEqualTo "player" && {((values (STCTI_state get "sectors")) findIf { (_x get "owner") isNotEqualTo "player" }) < 0}) then {
    [{
        if (((values (STCTI_state get "sectors")) findIf { (_x get "owner") isNotEqualTo "player" }) < 0) then {
            ["The island is ours — campaign complete!"] remoteExec ["systemChat", 0];
            "EveryoneWon" call BIS_fnc_endMissionServer;
        };
    }, [], 8] call CBA_fnc_waitAndExecute;
};
