// fn_startProgression.sqf — [SERVER] grants a sector's unlock when the player captures it, then
// broadcasts the unlock set so clients' garage gating + notifications update. Capturing the airfield
// (grantsUnlock = "fixed_wing") makes the CAS jet purchasable, etc. Idempotent per unlock.
if (!isServer) exitWith {};
if (isNil "STCTI_unlocks") then { STCTI_unlocks = []; };

[STCTI_EV_SECTOR_CAPTURED, {
    params ["_id", "_owner"];
    if !(_owner isEqualTo "player") exitWith {};
    private _rec = (STCTI_state get "sectors") get _id;
    if (isNil "_rec") exitWith {};
    private _unlock = _rec getOrDefault ["grantsUnlock", ""];
    if (_unlock isEqualTo "" || {_unlock in STCTI_unlocks}) exitWith {};

    STCTI_unlocks pushBack _unlock;
    [STCTI_EV_UNLOCKS_CHANGED, [STCTI_unlocks, _unlock]] call CBA_fnc_globalEvent;
    diag_log format ["[STCTI] Unlock granted: %1 (captured %2).", _unlock, _id];
}] call CBA_fnc_addEventHandler;

diag_log "[STCTI] Progression manager started.";
