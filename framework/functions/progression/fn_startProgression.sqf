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
    // fn_grantUnlock is the single unlock authority (alias-normalized, idempotent, broadcasts).
    [_rec getOrDefault ["grantsUnlock", ""]] call STCTI_fnc_grantUnlock;
}] call CBA_fnc_addEventHandler;

diag_log "[STCTI] Progression manager started.";
