// fn_setupPlayerActions.sqf — [CLIENT] no params. Adds every player-BODY-attached action
// (reinforce, build statics, strategic travel). Actions die with the unit object, so this runs
// once per body via the CBA "unit" player event in initPlayerLocal — join and every respawn.
// Helpers it references (STCTI_localOwnedSector, STCTI_travelEligible) are mission-globals
// defined once in initPlayerLocal.
if (!hasInterface) exitWith {};

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

// Strategic travel (Phase 9): at the base or inside any owned travel node.
player addAction ["<t color='#7ee8ff'>Strategic travel</t>", { call STCTI_fnc_travelMenu; },
    nil, 1.25, false, true, "", "call STCTI_travelEligible"];
