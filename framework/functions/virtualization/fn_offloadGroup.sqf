// fn_offloadGroup.sqf — [SERVER] params: [_group]. Headless-client offload hook (stub).
// In MP, spawned AI should be handed to a headless client to keep the server CPU free. If one is
// registered in STCTI_HC, transfer the group to it; in SP or with no HC this is a no-op and the
// server keeps the AI. Real HC registration + load-balancing across multiple HCs comes later.
params ["_grp"];
if (!isServer) exitWith {};
if (isNull _grp) exitWith {};
if (!isNil "STCTI_HC" && {!isNull STCTI_HC}) then { _grp setGroupOwner (owner STCTI_HC); };
