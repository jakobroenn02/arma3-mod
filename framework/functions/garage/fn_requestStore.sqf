// fn_requestStore.sqf — [CLIENT] params: [_veh]
// Client asks the server to park an owned vehicle in the garage. Ownership, position and
// emptiness are validated server-side (fn_serverStore) — the client only names the object. §E2.
params ["_veh"];
[_veh, clientOwner] remoteExec ["STCTI_fnc_serverStore", 2]; // 2 = server
