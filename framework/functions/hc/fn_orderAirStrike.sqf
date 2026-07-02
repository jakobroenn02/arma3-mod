// fn_orderAirStrike.sqf — [SERVER] params: [_sectorId, _requester]
// Air-support order (Phase 5): needs the fixed_wing unlock, charges STCTI_AIRSTRIKE_COST,
// spawns the faction CAS jet 4 km out, gives it SAD over the target for STCTI_AIRSTRIKE_TIME
// seconds, then it leaves and despawns. The jet is expendable within its window — if AA gets
// it, that's the risk the ammo/fuel paid for.
params ["_sectorId", "_requester"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _sectorId;
if (isNil "_rec") exitWith { ["Unknown sector."] remoteExec ["hint", _requester]; };
if !("fixed_wing" in STCTI_unlocks) exitWith {
    ["Air support requires the fixed-wing unlock (capture the airfield)."] remoteExec ["hint", _requester];
};
if !(STCTI_AIRSTRIKE_COST call STCTI_fnc_spendMulti) exitWith {
    ["Not enough resources for air support."] remoteExec ["hint", _requester];
};

private _tPos = _rec get "pos";
private _cls  = ((STCTI_FACTION_POOL get STCTI_PLAYER_FACTION) get "units") getOrDefault ["jet_cas", "B_Plane_CAS_01_dynamicLoadout_F"];
private _from = _tPos getPos [4000, _tPos getDir STCTI_BASE_POS];   // run in from the base side
private _veh  = createVehicle [_cls, [_from select 0, _from select 1, 500], [], 0, "FLY"];
_veh setDir (_from getDir _tPos);
_veh flyInHeight 300;
private _crewG = createVehicleCrew _veh;
private _grp   = createGroup [STCTI_SIDE_PLAYER, false];
{ [_x] joinSilent _grp; } forEach units _crewG;
deleteGroup _crewG;
_grp setBehaviour "COMBAT";
_grp setCombatMode "RED";
private _sad = _grp addWaypoint [_tPos, 300];
_sad setWaypointType "SAD";

[format ["CAS inbound on %1 — on station %2s.", _sectorId, STCTI_AIRSTRIKE_TIME]] remoteExec ["hint", _requester];

// Off-station: leave and despawn (or clean up the wreck's crew if it was shot down).
[{
    params ["_veh", "_grp"];
    { deleteVehicle _x } forEach (units _grp);
    if (!isNull _veh) then { deleteVehicle _veh; };
    deleteGroup _grp;
}, [_veh, _grp], STCTI_AIRSTRIKE_TIME] call CBA_fnc_waitAndExecute;
