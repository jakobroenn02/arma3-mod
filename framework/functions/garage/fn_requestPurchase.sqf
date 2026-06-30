// fn_requestPurchase.sqf — [CLIENT] params: [classname]
// Client asks the server to buy; the vehicle drops in front of the player. Price and required
// unlock are validated server-side from STCTI_garageCatalog (authority) — the client only names it. §E2.
params ["_class"];
private _pos = (getPosATL player) getPos [12, getDir player];
[_class, _pos, clientOwner] remoteExec ["STCTI_fnc_serverPurchase", 2]; // 2 = server
