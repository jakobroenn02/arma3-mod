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
    ["STCTI_Alert", [format ["Enemy forces inbound — %1 under threat!", _id]]] call BIS_fnc_showNotification;
    playSound "FD_Start_F";
}] call CBA_fnc_addEventHandler;

// Capture feedback (nice-to-have for the slice).
[STCTI_EV_SECTOR_CAPTURED, {
    params ["_id", "_owner"];
    if (_owner isEqualTo "player") then {
        ["STCTI_Info", [format ["Sector captured: %1", _id]]] call BIS_fnc_showNotification;
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
    // Red alert if the player lost a sector; neutral info otherwise.
    private _tpl = if (_routed isEqualTo "defender" && {_defOwner isEqualTo "player"}) then { "STCTI_Alert" } else { "STCTI_Info" };
    [_tpl, [_msg]] call BIS_fnc_showNotification;
}] call CBA_fnc_addEventHandler;

// Garage actions (E3): generate from the catalog once the garage exists. Unlock-gated items
// only appear once their unlock is granted (the action condition reads STCTI_unlocks).
[{ !isNil "STCTI_garage" && {!isNull STCTI_garage} }, {
    {
        _x params ["_label", "_cls", "_price", "_unlock"];
        private _cond = if (_unlock isEqualTo "") then { "true" } else { format ["'%1' in STCTI_unlocks", _unlock] };
        STCTI_garage addAction [_label, { [_this select 3] call STCTI_fnc_requestPurchase; }, _cls, 1.5, false, true, "", _cond];
    } forEach STCTI_GARAGE;
}] call CBA_fnc_waitUntilAndExecute;

// Unlock changes: refresh the local unlock set (garage conditions read it) and notify.
[STCTI_EV_UNLOCKS_CHANGED, {
    params ["_unlocks", "_new"];
    STCTI_unlocks = _unlocks;
    if (_new != "") then { ["STCTI_Info", [format ["New unlock: %1", _new]]] call BIS_fnc_showNotification; };
}] call CBA_fnc_addEventHandler;

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
