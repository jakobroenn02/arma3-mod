// initPlayerLocal.sqf — [CLIENT] UI, HUD, garage actions, warning handler. See §G3.
if (!hasInterface) exitWith {};

// Get the player onto land immediately (mission.sqm start may be over water) so they
// aren't drowning while the campaign-start zone selection is up.
private _hold = [[worldSize/2, worldSize/2, 0], 0, worldSize/2, 10, 0, 0.6, 0] call BIS_fnc_findSafePos;
if (count _hold >= 2) then { player setPosATL [_hold select 0, _hold select 1, 0]; };

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

// Abstract engagement outcome — report a staged/unobserved fight's result (resolver §6),
// phrased from the player's side.
[STCTI_EV_ENGAGEMENT_RESOLVED, {
    params ["_id", "_routed", "_att", "_def", "_startA", "_startD", "_attOwner", "_defOwner"];
    private _msg = switch (true) do {
        // Defender broke -> attacker took the sector.
        case (_routed isEqualTo "defender" && {_attOwner isEqualTo "player"}): { format ["%1 captured — your assault succeeded.", _id] };
        case (_routed isEqualTo "defender"):                                   { format ["Lost %1 — the enemy overran the garrison.", _id] };
        // Attacker broke -> defender held.
        case (_routed isEqualTo "attacker" && {_defOwner isEqualTo "player"}): { format ["Held %1 — enemy assault repelled.", _id] };
        default                                                               { format ["Assault on %1 failed.", _id] };
    };
    [_msg] call BIS_fnc_showNotification;
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

// Campaign start: pick a starting base (first player) or deploy to the established one.
[] spawn {
    waitUntil { !isNull player && {alive player} };
    if (!isNil "STCTI_baseEstablished") then {
        [STCTI_BASE_POS, STCTI_BASE_DIR] call STCTI_fnc_deployPlayer;  // base already exists
    } else {
        call STCTI_fnc_showZoneSelect;                                // establish it
    };
};
