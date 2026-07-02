// fn_requestProcure.sqf — [CLIENT] params: [_unlockId]
// Client asks the server to buy a hardware-category unlock. Cost and eligibility live
// server-side in STCTI_PROCURE_COST (the client only names the id — §E2 anti-forgery rule).
params ["_id"];
[_id, clientOwner] remoteExec ["STCTI_fnc_serverProcure", 2]; // 2 = server
