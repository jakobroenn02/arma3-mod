// fn_serverStore.sqf — [SERVER] params: [vehicle, requester]
// The authority side of "put vehicle in garage": only STCTI-owned (purchased/retrieved), living,
// empty vehicles near the garage flag can be stored. Storing records the classname in
// STCTI_state.storedVehicles and deletes the object — Antistasi-style, the vehicle is the
// player's until it explodes, so a stored one can always be taken out again (fn_serverRetrieve).
params ["_veh", "_requester"];
if (!isServer) exitWith {};

if (isNull _veh || {!alive _veh}) exitWith { ["That vehicle is gone."] remoteExec ["hint", _requester]; };
if !(_veh getVariable ["STCTI_owned", false]) exitWith {
    ["Only vehicles bought from the garage can be stored."] remoteExec ["hint", _requester];
};
if !(crew _veh isEqualTo []) exitWith { ["Everyone must dismount first."] remoteExec ["hint", _requester]; };
if (isNil "STCTI_garage" || {isNull STCTI_garage} || {_veh distance2D getPosATL STCTI_garage > STCTI_GARAGE_RADIUS + 10}) exitWith {
    ["Too far from the garage to store that."] remoteExec ["hint", _requester];
};

// Condition travels with the vehicle: hit points + fuel are restored on retrieval
// (fn_serverRetrieve). Entry shape: [classname, getAllHitPointsDamage, fuel].
private _cls  = typeOf _veh;
private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
private _entry = [_cls, getAllHitPointsDamage _veh, fuel _veh];
deleteVehicle _veh;

private _stored = STCTI_state get "storedVehicles";
_stored pushBack _entry;
[STCTI_EV_GARAGE_CHANGED, [+_stored]] call CBA_fnc_globalEvent;
[format ["%1 stored in the garage.", _name]] remoteExec ["hint", _requester];
