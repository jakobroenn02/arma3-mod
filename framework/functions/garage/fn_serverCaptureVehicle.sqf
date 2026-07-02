// fn_serverCaptureVehicle.sqf — [SERVER] params: [vehicle, requester]
// Battlefield capture (roadmap Phase 10e): seize a functioning enemy/abandoned vehicle by
// driving it into the garage radius and storing it as captured stock. Same validation shape as
// fn_serverStore minus the ownership requirement — capturing MARKS it owned, so from then on
// it stores/retrieves like a bought vehicle. Deliberate default (roadmap open decision 2):
// the captured HULL is yours; its CLASS does not become purchasable — that would be the
// reverse-engineering fiction, and it's off by design.
params ["_veh", "_requester"];
if (!isServer) exitWith {};

if (isNull _veh || {!alive _veh}) exitWith { ["That vehicle is gone."] remoteExec ["hint", _requester]; };
if (_veh getVariable ["STCTI_owned", false]) exitWith {
    ["Already yours — use Store."] remoteExec ["hint", _requester];
};
if !(crew _veh isEqualTo []) exitWith { ["Everyone must dismount first."] remoteExec ["hint", _requester]; };
if (isNil "STCTI_garage" || {isNull STCTI_garage} || {_veh distance2D getPosATL STCTI_garage > STCTI_GARAGE_RADIUS + 10}) exitWith {
    ["Bring it inside the garage perimeter to capture it."] remoteExec ["hint", _requester];
};

private _cls  = typeOf _veh;
private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
private _entry = [_cls, getAllHitPointsDamage _veh, fuel _veh];
deleteVehicle _veh;

private _stored = STCTI_state get "storedVehicles";
_stored pushBack _entry;
[STCTI_EV_GARAGE_CHANGED, [+_stored]] call CBA_fnc_globalEvent;
[format ["%1 captured into garage stock.", _name]] remoteExec ["hint", _requester];
diag_log format ["[STCTI] Vehicle captured into stock: %1.", _cls];
