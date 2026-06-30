// fn_despawnGroup.sqf — [SERVER] params: [_group]. Deletes a spawned force completely:
// all men in the group (infantry + vehicle crew), then the tracked vehicle/static objects
// (recorded on the group as STCTI_entities by fn_spawnForce), then the now-empty group. Used by
// every despawn/cleanup path so mixed forces (a tank isn't in `units group`) are fully removed.
params ["_grp"];
if (isNull _grp) exitWith {};
{ deleteVehicle _x } forEach units _grp;
{ if (!isNull _x) then { deleteVehicle _x }; } forEach (_grp getVariable ["STCTI_entities", []]);
deleteGroup _grp;
