// fn_startPersistence.sqf — [SERVER] arms the autosave loop (STCTI_AUTOSAVE_INTERVAL) and a
// save-on-capture hook (ownership flips are the state most worth not losing). Double-start
// guarded like the other managers. saveCampaign itself no-ops until the base is established.
if (!isServer) exitWith {};
if (!STCTI_PERSISTENCE) exitWith { diag_log "[STCTI] Persistence disabled (STCTI_PERSISTENCE)."; };
if (!isNil "STCTI_persistPFH") exitWith {};

STCTI_persistPFH = [{ call STCTI_fnc_saveCampaign; }, STCTI_AUTOSAVE_INTERVAL] call CBA_fnc_addPerFrameHandler;
[STCTI_EV_SECTOR_CAPTURED, { call STCTI_fnc_saveCampaign; }] call CBA_fnc_addEventHandler;

diag_log format ["[STCTI] Persistence manager started (autosave %1s).", STCTI_AUTOSAVE_INTERVAL];
