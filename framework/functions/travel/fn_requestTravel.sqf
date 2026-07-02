// fn_requestTravel.sqf — [CLIENT] params: [_destId, _mode]
// Client asks the server to travel. Validation, cost and cooldown are all server-side
// (fn_serverTravel) — the client only names the destination and mode. §E2.
params ["_destId", ["_mode", "redeploy"]];
[_destId, _mode, player, clientOwner] remoteExec ["STCTI_fnc_serverTravel", 2]; // 2 = server
