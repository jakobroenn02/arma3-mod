// fn_serverPlaceStatic.sqf — [SERVER] params: [sectorId, staticRole, posATL, dir, requester]
// "Build static turret" sector action (design: spend money + ammo to add a static weapon to a
// sector you hold). The spot is remembered as a sector "hardening" slot [role, pos, dir], which
// fn_spawnGarrison feeds to fn_spawnForce — so the turret comes back at the same spot when the
// garrison respawns (as long as its resolverType count survives in defenderForce; if it dies,
// the slot stays empty). If the garrison is live, the static is spawned manned immediately.
// Hardening does not change hands — fn_setSectorOwner clears it when the sector flips.
params ["_id", "_role", "_pos", "_dir", "_requester"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith { ["Unknown sector."] remoteExec ["hint", _requester]; };
if ((_rec get "owner") != "player") exitWith { ["You can only fortify a sector you hold."] remoteExec ["hint", _requester]; };

(STCTI_ROLES getOrDefault [_role, ["", ""]]) params ["_kind", "_rtype"];
if (_kind != "static" || {_rtype isEqualTo ""}) exitWith { ["Unknown static type."] remoteExec ["hint", _requester]; };
if (_pos distance2D (_rec get "pos") > (_rec get "radius") + 10) exitWith {
    ["Build inside the sector you want to fortify."] remoteExec ["hint", _requester];
};
if (surfaceIsWater _pos) exitWith { ["Cannot build that in water."] remoteExec ["hint", _requester]; };

private _cost = STCTI_STATIC_COST getOrDefault [_role, [["money", 300], ["ammo", 100]]];
if !(_cost call STCTI_fnc_spendMulti) exitWith {
    private _needs = (_cost apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    [format ["Not enough resources (needs %1).", _needs]] remoteExec ["hint", _requester];
};

private _hard = _rec getOrDefault ["hardening", []];
_hard pushBack [_role, _pos, _dir];
_rec set ["hardening", _hard];

private _grp = _rec getOrDefault ["garrisonGroup", grpNull];
if (_rec get "spawned") then {
    // Live garrison: spawn the manned static now. An empty spawned garrison has no group yet —
    // create one so recount/despawn track the turret like any other garrison entity.
    if (isNull _grp) then {
        _grp = createGroup [STCTI_SIDE_PLAYER, false];
        _grp setVariable ["STCTI_entities", []];
        _rec set ["garrisonGroup", _grp];
    };
    private _e = [_rtype, "static", _role, _pos, _dir, _grp, "player"] call STCTI_fnc_spawnUnit;
    private _ents = _grp getVariable ["STCTI_entities", []];
    if (!isNull _e) then { _ents pushBack _e; };
    _grp setVariable ["STCTI_entities", _ents];
} else {
    // Virtual: the static contributes its resolverType to the abstract force; the hardening
    // slot gives it back its identity/position on the next spawn.
    private _force = _rec get "defenderForce";
    _force set [_rtype, (_force getOrDefault [_rtype, 0]) + 1];
};

[format ["Static emplacement built at %1.", _id]] remoteExec ["hint", _requester];
diag_log format ["[STCTI] Static %1 built at %2 by client %3.", _role, _id, _requester];
