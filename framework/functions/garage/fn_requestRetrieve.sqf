// fn_requestRetrieve.sqf — [CLIENT] params: [_class, _pos, _dir]
// Client asks the server to take a stored vehicle out of the garage at the placement transform
// the player chose (fn_garagePlace in "retrieve" mode). Whether the class is actually stored,
// plus position validity, is checked server-side (fn_serverRetrieve). §E2.
params ["_class", "_pos", ["_dir", 0], ["_storedIdx", -1]];
[_class, _pos, _dir, _storedIdx, clientOwner] remoteExec ["STCTI_fnc_serverRetrieve", 2]; // 2 = server
