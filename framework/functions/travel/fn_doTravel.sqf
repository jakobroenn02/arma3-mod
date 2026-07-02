// fn_doTravel.sqf — [CLIENT] params: [_pos, _mode]. Runs where the traveller is LOCAL (the
// server only decided and charged — fn_serverTravel). Redeploy: you + your subordinate AI
// arrive on the ground at the node; vehicles stay behind (roadmap open-decision 1 default).
// Insert: you arrive at altitude under canopy — inside your current vehicle if you're in one
// (it drops on a cargo chute), on a steerable chute otherwise; AI subordinates arrive on the
// ground nearby either way (clean in MP, no mid-air AI shenanigans).
params ["_pos", ["_mode", "redeploy"]];
if (!hasInterface) exitWith {};

private _ground = {
    params ["_unit", "_center"];
    if (vehicle _unit isNotEqualTo _unit) then { moveOut _unit; };
    private _p = _center getPos [4 + random 10, random 360];
    if (surfaceIsWater _p) then { _p = _center; };
    _unit setPosATL [_p select 0, _p select 1, 0];
};

private _subordinates = (units group player) - [player];

if (_mode isEqualTo "insert") then {
    if (vehicle player isNotEqualTo player) then {
        // Vehicle drop: the vehicle you sit in comes with you, under a cargo chute.
        private _veh = vehicle player;
        private _chute = createVehicle ["B_Parachute_02_F", [_pos select 0, _pos select 1, 250], [], 0, "FLY"];
        _chute setPos [_pos select 0, _pos select 1, 250];
        _veh attachTo [_chute, [0, 0, -3]];
        [
            { params ["_chute"]; isNull _chute || {(getPos _chute select 2) < 4} },
            { params ["", "_veh"]; detach _veh; },
            [_chute, _veh]
        ] call CBA_fnc_waitUntilAndExecute;
        // Subordinates not in the vehicle arrive on the ground below.
        { if (vehicle _x isNotEqualTo _veh) then { [_x, _pos] call _ground; }; } forEach _subordinates;
    } else {
        player setPos [_pos select 0, _pos select 1, 200];
        private _chute = createVehicle ["Steerable_Parachute_F", [_pos select 0, _pos select 1, 200], [], 0, "FLY"];
        player moveInDriver _chute;
        { [_x, _pos] call _ground; } forEach _subordinates;
    };
    systemChat "STCTI: insertion away — steer to the objective.";
} else {
    [player, _pos] call _ground;
    { [_x, _pos] call _ground; } forEach _subordinates;
    systemChat "STCTI: redeployed.";
};
