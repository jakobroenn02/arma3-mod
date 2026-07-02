// fn_serverReinforce.sqf — [SERVER] params: [sectorId, requester]
// "Reinforce garrison" sector action (design: spend money + manpower to raise the defending
// infantry above its baseline). Costs STCTI_REINFORCE_COST, adds STCTI_REINFORCE_SIZE riflemen.
// If the garrison is live right now, the men are spawned straight into the garrison group (and
// its STCTI_entities) so despawn/recount stays truthful; if virtual, defenderForce is bumped and
// the next spawnGarrison materializes them. No cap for the slice — the spawn budget bounds live
// units, and income bounds the abstract side.
params ["_id", "_requester"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith { ["Unknown sector."] remoteExec ["hint", _requester]; };
if ((_rec get "owner") != "player") exitWith { ["You can only reinforce a sector you hold."] remoteExec ["hint", _requester]; };

if !(STCTI_REINFORCE_COST call STCTI_fnc_spendMulti) exitWith {
    private _needs = (STCTI_REINFORCE_COST apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    [format ["Not enough resources (needs %1).", _needs]] remoteExec ["hint", _requester];
};

private _grp = _rec getOrDefault ["garrisonGroup", grpNull];
if ((_rec get "spawned") && {!isNull _grp}) then {
    // Live garrison: spawn the reinforcements around the sector centre, on land.
    private _pos  = _rec get "pos";
    private _ents = _grp getVariable ["STCTI_entities", []];
    for "_i" from 1 to STCTI_REINFORCE_SIZE do {
        private _p = _pos;
        for "_try" from 1 to 12 do {
            private _c = _pos getPos [random 25, random 360];
            if !(surfaceIsWater _c) exitWith { _p = _c; };
        };
        private _e = ["rifleman", "infantry", "", _p, random 360, _grp, "player"] call STCTI_fnc_spawnUnit;
        if (!isNull _e) then { _ents pushBack _e; };
    };
    _grp setVariable ["STCTI_entities", _ents];
} else {
    // Virtual garrison: bump the abstract force; spawnGarrison materializes it when observed.
    private _force = _rec get "defenderForce";
    _force set ["rifleman", (_force getOrDefault ["rifleman", 0]) + STCTI_REINFORCE_SIZE];
};

[format ["%1 reinforced (+%2 riflemen).", _id, STCTI_REINFORCE_SIZE]] remoteExec ["hint", _requester];
diag_log format ["[STCTI] Sector %1 reinforced by client %2 (+%3 riflemen).", _id, _requester, STCTI_REINFORCE_SIZE];
