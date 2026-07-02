// fn_loadCampaign.sqf — [SERVER] no params -> Bool (true if a campaign was restored).
// Phase 6, design §10. Call ONCE from initServer, after initSectors (records must exist) and
// before the managers start. Restores: faction + base (via serverPlaceBase with a null
// requester — nobody gets teleported), resources, unlocks (garage + arsenal re-gate), stored
// vehicles, per-sector owner/progress/garrison/hardening, and director aggression. A version
// mismatch ignores the save (new campaign) rather than guessing at migration.
if (!isServer) exitWith { false };
if (!STCTI_PERSISTENCE) exitWith { false };

private _save = profileNamespace getVariable [format ["STCTI_save_%1", worldName], []];
if (_save isEqualTo []) exitWith { false };
_save params ["_ver", "_faction", "_baseIndex", "_resPairs", "_unlocks", "_stored", "_sectors", "_aggro"];
if (_ver isNotEqualTo STCTI_SAVE_VERSION) exitWith {
    diag_log format ["[STCTI] Save version %1 != %2 — ignoring save (new campaign).", _ver, STCTI_SAVE_VERSION];
    false
};

// Base + faction first: applyFaction broadcasts the catalog, the flag/arsenal get placed,
// STCTI_baseEstablished suppresses the zone-select dialog on every client.
[_baseIndex, _faction, objNull] call STCTI_fnc_serverPlaceBase;

// Ledger (mutate in place — the HUD push below and initPlayerLocal's join push read this map).
private _res = STCTI_state get "resources";
{ _res set [_x select 0, _x select 1]; } forEach _resPairs;
[STCTI_EV_RESOURCES_CHANGED, [_res]] call CBA_fnc_globalEvent;

// Unlocks re-gate the garage everywhere and re-tier the arsenal. Old saves may carry legacy
// ids — normalize through the same alias map fn_grantUnlock uses (then dedupe).
private _norm = _unlocks apply { STCTI_UNLOCK_ALIASES getOrDefault [_x, _x] };
STCTI_unlocks = _norm arrayIntersect _norm;
[STCTI_EV_UNLOCKS_CHANGED, [STCTI_unlocks, ""]] call CBA_fnc_globalEvent;
call STCTI_fnc_updateArsenal;

// Garage contents.
STCTI_state set ["storedVehicles", +_stored];
[STCTI_EV_GARAGE_CHANGED, [+_stored]] call CBA_fnc_globalEvent;

// Sector mutables. No SECTOR_CAPTURED events here — restoring is not capturing (no unlock
// grants, no aggression spikes, no notification spam); markers are recoloured directly.
{
    _x params ["_id", "_owner", "_prog", "_dfPairs", "_hardening"];
    private _rec = (STCTI_state get "sectors") get _id;
    if (isNil "_rec") then {
        diag_log format ["[STCTI] Load: saved sector %1 no longer exists — skipped.", _id];
    } else {
        _rec set ["owner", _owner];
        _rec set ["captureProgress", _prog];
        _rec set ["defenderForce", createHashMapFromArray _dfPairs];
        _rec set ["hardening", _hardening];
        [_id] call STCTI_fnc_updateSectorMarker;
    };
} forEach _sectors;

STCTI_state set ["aggression", _aggro];

diag_log format ["[STCTI] Campaign RESTORED (%1 sectors, faction %2, aggression %3).",
    count _sectors, _faction, _aggro];
true
