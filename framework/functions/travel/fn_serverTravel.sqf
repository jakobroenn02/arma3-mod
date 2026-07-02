// fn_serverTravel.sqf — [SERVER] params: [_destId, _mode, _player, _requester]
// The travel authority (Phase 9): validates destination (redeploy: owned + travel node +
// uncontested; insert: any registered sector), the combat lockout, and the per-player UID
// cooldown; charges fuel; then remoteExecs fn_doTravel BACK TO THE REQUESTER. The server never
// moves the unit itself — a player (and their group AI) is local to their client, and position
// commands belong where the object is local. Decision + ledger here, the body moves at home.
params ["_destId", "_mode", "_player", "_requester"];
if (!isServer) exitWith {};
if (isNull _player || {!alive _player}) exitWith {};

// Destination.
private _pos = [];
if (_destId isEqualTo "__hq") then {
    _pos = +STCTI_BASE_POS;
} else {
    private _rec = (STCTI_state get "sectors") get _destId;
    if (isNil "_rec") exitWith {};   // fall through with _pos = [] -> refused below
    if (_mode isEqualTo "redeploy") then {
        if !(_rec getOrDefault ["travelNode", false]) exitWith {};
        if ((_rec get "owner") isNotEqualTo "player") exitWith {};
        if (_destId in keys STCTI_engagements) exitWith {};   // being fought over = contested
        _pos = +(_rec get "pos");
    } else {
        _pos = +(_rec get "pos");   // insert may target any sector, ownership be damned
    };
};
if (_pos isEqualTo []) exitWith {
    ["Destination invalid — it must be an owned, uncontested travel node."] remoteExec ["hint", _requester];
};

// Combat lockout: no redeploying out of a firefight. (Single top-level exitWith — an exitWith
// inside a then-block would only leave that block and the travel would proceed.)
if (STCTI_TRAVEL_BLOCK_IN_COMBAT && {
    (((getPosATL _player) nearEntities [["Man", "Car", "Tank", "Air"], STCTI_TRAVEL_COMBAT_RADIUS])
        findIf { alive _x && {side _x == STCTI_SIDE_ENEMY} }) > -1
}) exitWith {
    ["Cannot travel — enemies nearby."] remoteExec ["hint", _requester];
};

// Per-player cooldown, keyed by UID (stable across reconnects, unlike clientOwner).
if (isNil "STCTI_travelCooldown") then { STCTI_travelCooldown = createHashMap; };
private _uid = getPlayerUID _player;
if (time < (STCTI_travelCooldown getOrDefault [_uid, 0])) exitWith {
    [format ["Redeploy on cooldown (%1s).", ceil ((STCTI_travelCooldown get _uid) - time)]] remoteExec ["hint", _requester];
};

// Charge.
private _cost = [STCTI_TRAVEL_FUEL_COST, STCTI_TRAVEL_INSERT_FUEL] select (_mode isEqualTo "insert");
if !([["fuel", _cost]] call STCTI_fnc_spendMulti) exitWith {
    [format ["Not enough fuel (%1 needed).", _cost]] remoteExec ["hint", _requester];
};
STCTI_travelCooldown set [_uid, time + STCTI_TRAVEL_COOLDOWN];

// Insert arrives NEAR the target, not on the flagpole.
if (_mode isEqualTo "insert") then { _pos = _pos getPos [150 + random 150, random 360]; };

[_pos, _mode] remoteExec ["STCTI_fnc_doTravel", _requester];
diag_log format ["[STCTI] Travel: %1 -> %2 (%3, %4 fuel).", name _player, _destId, _mode, _cost];
