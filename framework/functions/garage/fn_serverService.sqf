// fn_serverService.sqf — [SERVER] params: [vehicle, requester]
// Repair / refuel / rearm at the garage (roadmap Phase 12): flat STCTI_SERVICE_COST for a full
// service of an owned vehicle inside the garage perimeter. The map-physical fuel/ammo economy
// gets its sustainment sink; the garage flag is the service point.
params ["_veh", "_requester"];
if (!isServer) exitWith {};

if (isNull _veh || {!alive _veh}) exitWith { ["That vehicle is gone."] remoteExec ["hint", _requester]; };
if !(_veh getVariable ["STCTI_owned", false]) exitWith {
    ["Only owned vehicles get serviced here."] remoteExec ["hint", _requester];
};
if (isNil "STCTI_garage" || {isNull STCTI_garage} || {_veh distance2D getPosATL STCTI_garage > STCTI_GARAGE_RADIUS + 10}) exitWith {
    ["Bring it inside the garage perimeter for service."] remoteExec ["hint", _requester];
};
if !(STCTI_SERVICE_COST call STCTI_fnc_spendMulti) exitWith {
    private _needs = (STCTI_SERVICE_COST apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    [format ["Not enough resources (needs %1).", _needs]] remoteExec ["hint", _requester];
};

_veh setDamage 0;
_veh setFuel 1;
_veh setVehicleAmmo 1;
[format ["%1 serviced — repaired, refuelled, rearmed.", getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName")]] remoteExec ["hint", _requester];
