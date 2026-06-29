// fn_deployPlayer.sqf — [CLIENT] params: [spawnPos, spawnDir]
// Teleports the local player to the exact base spawn point and faces them.
params ["_pos", ["_dir", 0]];
if (!hasInterface) exitWith {};
player setPosATL [_pos select 0, _pos select 1, 0];
player setDir _dir;
