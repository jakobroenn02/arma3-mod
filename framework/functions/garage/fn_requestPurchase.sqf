// fn_requestPurchase.sqf — [CLIENT] params: [_class, _pos, _dir]
// Client asks the server to buy and spawn the vehicle at the placement transform the player chose
// (fn_garagePlace). Price and required unlock are validated server-side from STCTI_garageCatalog
// (authority) — the client only names the item and where it goes. §E2.
params ["_class", "_pos", ["_dir", 0]];
[_class, _pos, _dir, clientOwner] remoteExec ["STCTI_fnc_serverPurchase", 2]; // 2 = server
