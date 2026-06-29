// fn_startManagers.sqf — [SERVER] starts the recurring loops (capture + economy). See §G1.
if (!isServer) exitWith {};

// Capture loop
[{
    { [_x] call STCTI_fnc_updateSectorCapture; } forEach (keys (STCTI_state get "sectors"));
}, STCTI_CAPTURE_INTERVAL] call CBA_fnc_addPerFrameHandler;

// Economy loop
[{ call STCTI_fnc_economyTick; }, STCTI_ECONOMY_INTERVAL] call CBA_fnc_addPerFrameHandler;
