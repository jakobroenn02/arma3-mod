// fn_startManagers.sqf — [SERVER] starts the recurring loops (capture + economy). See §G1.
if (!isServer) exitWith {};

// Capture loop
[{
    { [_x] call STCTI_fnc_updateSectorCapture; } forEach (keys (STCTI_state get "sectors"));
}, STCTI_CAPTURE_INTERVAL] call CBA_fnc_addPerFrameHandler;

// Economy loop
[{ call STCTI_fnc_economyTick; }, STCTI_ECONOMY_INTERVAL] call CBA_fnc_addPerFrameHandler;

// --- AI director inputs (Phase 4, design §8) ------------------------------------
// Player captures raise aggression; the decay half lives in fn_directorTick's rolls.
[STCTI_EV_SECTOR_CAPTURED, {
    params ["_id", "_owner"];
    if !(_owner isEqualTo "player") exitWith {};
    private _a = ((STCTI_state getOrDefault ["aggression", STCTI_AGGRO_START]) + STCTI_AGGRO_PER_CAPTURE) min STCTI_AGGRO_CAP;
    STCTI_state set ["aggression", _a];
    diag_log format ["[STCTI] Aggression up to %1 (player captured %2).", _a, _id];
}] call CBA_fnc_addEventHandler;

// Close the shared defend task when an enemy op resolves (both the abstract path — checkBreak —
// and the live path — resolveSpawnedEngagement — fire this event). SUCCEEDED requires the
// attacker routed AND the sector still being ours — the retake drain can flip ownership while
// an abstract engagement is still running, and "held it" would be a lie then.
[STCTI_EV_ENGAGEMENT_RESOLVED, {
    params ["_id", "_routed", "", "", "", "", "_attOwner"];
    if !(_attOwner isEqualTo "enemy") exitWith {};
    private _tid = format ["STCTI_op_%1", _id];
    if (_tid call BIS_fnc_taskExists) then {
        private _rec  = (STCTI_state get "sectors") get _id;
        private _held = _routed isEqualTo "attacker"
            && {!isNil "_rec" && {(_rec get "owner") isEqualTo "player"}};
        [_tid, if (_held) then { "SUCCEEDED" } else { "FAILED" }] call BIS_fnc_taskSetState;
    };
}] call CBA_fnc_addEventHandler;
