// fn_initHUD.sqf — [CLIENT] call from initPlayerLocal.
// Creates one structured-text control on the mission display and registers the
// RESOURCES_CHANGED handler. No description.ext UI classes needed. See §B2.
if (!hasInterface) exitWith {};
disableSerialization;

// Display 46 (the in-game mission display) may not exist for the first frame.
[{ !isNull (findDisplay 46) }, {
    private _display = findDisplay 46;
    private _ctrl = _display ctrlCreate ["RscStructuredText", -1];
    _ctrl ctrlSetPosition [
        safezoneX + 0.01 * safezoneW,
        safezoneY + 0.02 * safezoneH,
        0.34 * safezoneW,
        0.06 * safezoneH
    ];
    _ctrl ctrlCommit 0;
    uiNamespace setVariable ["STCTI_hud", _ctrl];

    // Listen for updates, then render once from current state (covers SP, where
    // the server's initial push may have fired before this handler existed).
    [STCTI_EV_RESOURCES_CHANGED, { _this call STCTI_fnc_updateHUD }] call CBA_fnc_addEventHandler;
    if (!isNil "STCTI_state") then {
        [STCTI_state get "resources"] call STCTI_fnc_updateHUD;
    };
}] call CBA_fnc_waitUntilAndExecute;
