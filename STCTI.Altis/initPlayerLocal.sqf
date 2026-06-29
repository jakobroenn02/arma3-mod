// initPlayerLocal.sqf — [CLIENT] UI, HUD, garage actions, warning handler. See §G3.
if (!hasInterface) exitWith {};

call STCTI_fnc_initHUD;

// Attack-warning handler (F2).
[STCTI_EV_ATTACK_INBOUND, {
    params ["_id"];
    [format ["Enemy forces inbound — %1 under threat!", _id]] call BIS_fnc_showNotification;
    playSound "FD_Start_F";
}] call CBA_fnc_addEventHandler;

// Capture feedback (nice-to-have for the slice).
[STCTI_EV_SECTOR_CAPTURED, {
    params ["_id", "_owner"];
    if (_owner isEqualTo "player") then {
        [format ["Sector captured: %1", _id]] call BIS_fnc_showNotification;
    };
}] call CBA_fnc_addEventHandler;

// Garage actions (E3): wait for the server-spawned garage, then wire the menu.
[{ !isNil "STCTI_garage" && {!isNull STCTI_garage} }, {
    STCTI_garage addAction ["Buy Hunter (500)",   { ["B_MRAP_01_F", 500] call STCTI_fnc_requestPurchase; }];
    STCTI_garage addAction ["Buy Marshall (1500)", { ["B_APC_Wheeled_01_cannon_F", 1500] call STCTI_fnc_requestPurchase; }];
}] call CBA_fnc_waitUntilAndExecute;

// Push current resources to this (joining) client once.
if (isServer) then {
    [STCTI_EV_RESOURCES_CHANGED, [STCTI_state get "resources"]] call CBA_fnc_globalEvent;
};
