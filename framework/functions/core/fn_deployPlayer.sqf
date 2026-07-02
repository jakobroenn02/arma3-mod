// fn_deployPlayer.sqf — [CLIENT] params: [spawnPos, spawnDir]
// Teleports the local player to the exact base spawn point and faces them. Also swaps the
// loadout to the chosen faction's rifleman kit — the mission.sqm unit is a NATO body (engine
// sides stay west/east, see STCTI_FACTION_POOL), so a CSAT/AAF campaign shouldn't start in
// the wrong uniform. The arsenal is right there for re-gearing.
params ["_pos", ["_dir", 0]];
if (!hasInterface) exitWith {};
player setPosATL [_pos select 0, _pos select 1, 0];
player setDir _dir;

if (STCTI_PLAYER_FACTION isNotEqualTo "NATO") then {
    private _cls = (STCTI_FACTION get "player") getOrDefault ["rifleman", ""];
    if (_cls isNotEqualTo "") then {
        player setUnitLoadout (configFile >> "CfgVehicles" >> _cls);
    };
};
