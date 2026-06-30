// fn_requestPurchase.sqf — [CLIENT] params: [classname, price]
// Client asks the server to buy; drops the vehicle in front of the player. See §E2.
params ["_class", "_price"];
private _pos = (getPosATL player) getPos [12, getDir player];
[_class, _price, _pos, clientOwner] remoteExec ["STCTI_fnc_serverPurchase", 2]; // 2 = server
