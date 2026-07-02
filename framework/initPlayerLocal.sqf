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

// Garage actions (E3): the flag opens the garage dialog (fn_garageMenu) — buy + take out —
// and stores the nearest empty owned vehicle back into the garage.
[{ !isNil "STCTI_garage" && {!isNull STCTI_garage} }, {
    STCTI_garage addAction ["<t color='#7ec8ff'>Vehicle Garage</t>", { call STCTI_fnc_garageMenu; }, nil, 1.5, false, true, "", "true", 15];
    STCTI_garage addAction ["<t color='#9affa0'>Store nearby vehicle</t>", {
        private _near = (getPosATL STCTI_garage) nearEntities [["Car", "Tank", "Air", "Ship"], STCTI_GARAGE_RADIUS];
        private _owned = _near select { _x getVariable ["STCTI_owned", false] && {alive _x} && {crew _x isEqualTo []} };
        if (_owned isEqualTo []) exitWith { systemChat "STCTI: no empty owned vehicle near the garage."; };
        [_owned select 0] call STCTI_fnc_requestStore;
    }, nil, 1.4, false, true, "", "true", 15];
}] call CBA_fnc_waitUntilAndExecute;

// Stored-vehicle list: keep the local cache fresh for the garage menu.
[STCTI_EV_GARAGE_CHANGED, { params ["_stored"]; STCTI_lastStored = _stored; }] call CBA_fnc_addEventHandler;

// High Command (Phase 5): the map board opens the order dialog, and every HC_CHANGED push
// re-syncs the vanilla HC bar (Ctrl+Space) to the current squad list.
[{ !isNil "STCTI_hcBoard" && {!isNull STCTI_hcBoard} }, {
    STCTI_hcBoard addAction ["<t color='#d8b4ff'>High Command</t>", { call STCTI_fnc_hcMenu; }, nil, 1.5, false, true, "", "true", 15];
}] call CBA_fnc_waitUntilAndExecute;
[STCTI_EV_HC_CHANGED, {
    params ["_grps"];
    STCTI_lastHC = _grps;
    { player hcRemoveGroup _x; } forEach (hcAllGroups player);
    { if (!isNull _x) then { player hcSetGroup [_x]; }; } forEach _grps;
}] call CBA_fnc_addEventHandler;

// Reinforce-garrison action: shown only while standing inside a sector the players hold.
// Clients have no STCTI_state, but the sector markers are global and sized to the capture
// radius, so "inside an owned sector" is derivable from marker colour + position alone.
STCTI_localOwnedSector = {
    private _ret = "";
    {
        if (markerColor _x isEqualTo "ColorBLUFOR" && {player distance2D markerPos _x <= (markerSize _x select 0)}) exitWith {
            _ret = _x select [3];   // marker is "mk_" + sectorId
        };
    } forEach (allMapMarkers select { _x select [0, 3] isEqualTo "mk_" && {!("_dot" in _x)} });
    _ret
};
player addAction [
    format ["<t color='#9affa0'>Reinforce garrison (%1)</t>",
        (STCTI_REINFORCE_COST apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + "],
    {
        private _id = call STCTI_localOwnedSector;
        if (_id isEqualTo "") exitWith {};
        [_id, clientOwner] remoteExec ["STCTI_fnc_serverReinforce", 2]; // 2 = server (validates + charges)
    },
    nil, 1.2, false, true, "", "(call STCTI_localOwnedSector) != ''"
];

// Build-static actions (one per type): placed where the player stands, facing their heading.
{
    _x params ["_role", "_label"];
    private _cost = STCTI_STATIC_COST get _role;
    player addAction [
        format ["<t color='#9affa0'>Build %1 (%2)</t>", _label,
            (_cost apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + "],
        {
            params ["", "", "", "_role"];
            private _id = call STCTI_localOwnedSector;
            if (_id isEqualTo "") exitWith {};
            private _p = getPosATL player getPos [3, getDir player];
            [_id, _role, [_p select 0, _p select 1, 0], getDir player, clientOwner]
                remoteExec ["STCTI_fnc_serverPlaceStatic", 2]; // 2 = server (validates + charges)
        },
        _role, 1.1, false, true, "", "(call STCTI_localOwnedSector) != ''"
    ];
} forEach [
    ["static_he", "HMG emplacement"],
    ["static_at", "AT emplacement"],
    ["static_aa", "AA emplacement"]
];

// Unlock changes: refresh the local unlock set (garage conditions read it) and notify.
[STCTI_EV_UNLOCKS_CHANGED, {
    params ["_unlocks", "_new"];
    STCTI_unlocks = _unlocks;
    if (_new != "") then { ["STCTI_Info", [format ["New unlock: %1", _new]]] call BIS_fnc_showNotification; };
}] call CBA_fnc_addEventHandler;

// Push current resources + garage contents to this (joining) client once.
if (isServer) then {
    [STCTI_EV_RESOURCES_CHANGED, [STCTI_state get "resources"]] call CBA_fnc_globalEvent;
    [STCTI_EV_GARAGE_CHANGED, [+(STCTI_state get "storedVehicles")]] call CBA_fnc_globalEvent;
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
