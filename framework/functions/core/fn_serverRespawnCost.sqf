// fn_serverRespawnCost.sqf — [SERVER] params: [_requester]
// Conventional reinforcement isn't free: each player respawn debits manpower. An empty pool
// doesn't block the respawn (the engine already spawned the body) — it just gets called out,
// which is its own kind of pressure on holding manpower towns.
params ["_requester"];
if (!isServer) exitWith {};
if (["manpower", STCTI_RESPAWN_MANPOWER] call STCTI_fnc_spend) then {
    [format ["Reinforcement deployed (-%1 manpower).", STCTI_RESPAWN_MANPOWER]] remoteExec ["hint", _requester];
} else {
    ["Manpower reserves depleted — hold more towns."] remoteExec ["hint", _requester];
};
