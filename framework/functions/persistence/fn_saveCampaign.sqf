// fn_saveCampaign.sqf — [SERVER] no params -> Bool (true if saved). Phase 6, design §10.
// Serializes the campaign spine to profileNamespace (server profile), keyed by world, versioned
// by STCTI_SAVE_VERSION. Live garrisons are recounted into their virtual maps first so
// live-fight losses persist. Active ENGAGEMENTS are deliberately NOT saved: a restart ends the
// fight, the sector keeps its current owner and (recounted) garrison, and the attacker force
// evaporates — logged so a mid-op save is visible in the rpt.
if (!isServer) exitWith { false };
if (!STCTI_PERSISTENCE) exitWith { false };
if (isNil "STCTI_baseEstablished") exitWith { false };   // pre-campaign: nothing worth saving

// Fold live truth back into the virtual maps before serializing.
{
    private _rec = _y;
    private _grp = _rec getOrDefault ["garrisonGroup", grpNull];
    if ((_rec get "spawned") && {!isNull _grp}) then {
        _rec set ["defenderForce", [_grp] call STCTI_fnc_recountForce];
    };
} forEach (STCTI_state get "sectors");
if (count STCTI_engagements > 0) then {
    diag_log format ["[STCTI] Save: %1 active engagement(s) NOT saved (fights end on restart).", count STCTI_engagements];
};

// Sector mutables only — everything else re-derives from map data at init.
private _sectors = [];
{
    private _rec = _y;
    private _df  = _rec getOrDefault ["defenderForce", createHashMap];
    private _dfPairs = (keys _df) apply { [_x, _df get _x] };
    _sectors pushBack [
        _rec get "id",
        _rec get "owner",
        _rec get "captureProgress",
        _dfPairs,
        +(_rec getOrDefault ["hardening", []])
    ];
} forEach (STCTI_state get "sectors");

private _res = STCTI_state get "resources";
private _save = [
    STCTI_SAVE_VERSION,
    STCTI_PLAYER_FACTION,
    missionNamespace getVariable ["STCTI_BASE_INDEX", 0],
    (keys _res) apply { [_x, _res get _x] },
    +STCTI_unlocks,
    +(STCTI_state get "storedVehicles"),
    _sectors,
    STCTI_state getOrDefault ["aggression", STCTI_AGGRO_START]
];

profileNamespace setVariable [format ["STCTI_save_%1", worldName], _save];
saveProfileNamespace;
diag_log format ["[STCTI] Campaign saved (%1 sectors, faction %2).", count _sectors, STCTI_PLAYER_FACTION];
true
