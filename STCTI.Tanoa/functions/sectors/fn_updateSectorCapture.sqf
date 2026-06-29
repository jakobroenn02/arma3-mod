// fn_updateSectorCapture.sqf — [SERVER] params: [id]  (per sector, each capture tick)
// Presence check -> capture progress -> flip via setSectorOwner. See §C5.
params ["_id"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};
private _pos = _rec get "pos";
private _r   = _rec get "radius";

private _near = _pos nearEntities ["Man", _r];
private _playersNear = ({ side _x == STCTI_SIDE_PLAYER && alive _x } count _near) > 0;
private _enemyNear   = ({ side _x == STCTI_SIDE_ENEMY  && alive _x } count _near) > 0;

private _progress = _rec get "captureProgress";

switch (true) do {
    // Player present, no enemy: capture progresses.
    case (_playersNear && !_enemyNear): {
        private _p = (_progress + STCTI_CAPTURE_RATE) min 1;
        _rec set ["captureProgress", _p];
        if (_p >= 1 && {(_rec get "owner") != "player"}) then {
            [_id, "player"] call STCTI_fnc_setSectorOwner;
        };
    };
    // Both present while capturing: contested — mark it amber, hold progress.
    case (_playersNear && _enemyNear): {
        if ((_rec get "owner") isEqualTo "enemy" && _progress > 0) then {
            _rec set ["owner", "contested"];
            [_id] call STCTI_fnc_updateSectorMarker;
        };
    };
    // Nobody contesting an enemy sector: progress decays back.
    default {
        if (_progress > 0 && {(_rec get "owner") != "player"}) then {
            _rec set ["captureProgress", (_progress - STCTI_CAPTURE_RATE) max 0];
            if ((_rec get "owner") isEqualTo "contested") then {
                _rec set ["owner", "enemy"];
                [_id] call STCTI_fnc_updateSectorMarker;
            };
        };
    };
};
// TODO (later): enemy retake when only enemy present — open question in design doc §15.
