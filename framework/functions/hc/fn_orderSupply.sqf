// fn_orderSupply.sqf — [SERVER] params: [_sectorId, _requester]
// Supply-run order (Phase 5): charges STCTI_SUPPLY_COST, spawns a faction supply truck at the
// base and drives it to the target sector; on arrival the cargo is credited as resources
// (STCTI_SUPPLY_REWARD) and the truck despawns. If the truck dies en route the cargo is lost —
// escort it or pick safer targets. Slice simplification: the run is a LIVE vehicle, not an
// abstract engagement (the resolver-integrated version is a follow-up; log makes that visible).
params ["_sectorId", "_requester"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _sectorId;
if (isNil "_rec") exitWith { ["Unknown sector."] remoteExec ["hint", _requester]; };
if ((_rec get "owner") != "player") exitWith {
    ["Supply runs can only target a sector you hold."] remoteExec ["hint", _requester];
};
if !(STCTI_SUPPLY_COST call STCTI_fnc_spendMulti) exitWith {
    ["Not enough resources for a supply run."] remoteExec ["hint", _requester];
};

private _cls   = (STCTI_FACTION_POOL get STCTI_PLAYER_FACTION) getOrDefault ["truck", "B_Truck_01_transport_F"];
private _start = STCTI_BASE_POS getPos [30, random 360];
private _veh   = createVehicle [_cls, _start, [], 0, "NONE"];
private _crewG = createVehicleCrew _veh;
private _grp   = createGroup [STCTI_SIDE_PLAYER, false];
{ [_x] joinSilent _grp; } forEach units _crewG;
deleteGroup _crewG;
_grp setBehaviour "SAFE";
private _wp = _grp addWaypoint [_rec get "pos", 30];
_wp setWaypointType "MOVE";

[format ["Supply truck dispatched to %1.", _sectorId]] remoteExec ["hint", _requester];

// Arrival / loss watch. Arrival = truck alive within the sector radius.
[
    { params ["_veh", "_pos", "_r"]; !alive _veh || {_veh distance2D _pos < _r} },
    {
        params ["_veh", "", "", "_sectorId", "_requester", "_grp"];
        if (alive _veh) then {
            { [_x select 0, _x select 1] call STCTI_fnc_addRes; } forEach STCTI_SUPPLY_REWARD;
            [format ["Supplies from the %1 run delivered.", _sectorId]] remoteExec ["hint", _requester];
            { deleteVehicle _x } forEach (units _grp);
            deleteVehicle _veh;
            deleteGroup _grp;
        } else {
            [format ["The supply truck to %1 was destroyed.", _sectorId]] remoteExec ["hint", _requester];
            { deleteVehicle _x } forEach (units _grp);
            deleteGroup _grp;
        };
    },
    [_veh, _rec get "pos", (_rec get "radius") max 50, _sectorId, _requester, _grp]
] call CBA_fnc_waitUntilAndExecute;
