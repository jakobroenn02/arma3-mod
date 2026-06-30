// fn_observerPoints.sqf — [SERVER] no params -> Array of [groundPos, radius]
// Where each player's *attention* is, not just their feet — the design doc §9 insight: naive
// body-proximity fails for remote/long-range engagements (a jet at altitude is "near" nothing
// on the ground; a UAV operator's body is at base while their attention is downrange).
//
//   • on foot / ground vehicle → body position, base radius;
//   • in an aircraft           → position projected downrange along facing, radius scaled by altitude;
//   • piloting a UAV           → the UAV's position projected downrange, radius scaled by altitude.
//
// MP-safe: uses only server-knowable data (positions/vectorDir), no client-only camera commands.
// True camera/sensor-following needs each client to publish its own observer point to the server —
// a documented refinement for dedicated MP; in SP/hosted the server IS the player's machine.
if (!isServer) exitWith { [] };

private _pts = [];
{
    private _p = _x;
    if (alive _p) then {
        private _veh = vehicle _p;
        private _uav = getConnectedUAV _p;
        private _opos = getPosATL _p;
        private _orad = STCTI_OBS_GROUND_R;

        // The "eye in the sky" carrier: a manned aircraft, or a UAV this player is operating.
        private _sky = objNull;
        if (_veh isKindOf "Air" && {!isNull _veh} && {_veh != _p}) then { _sky = _veh; };
        if (isNull _sky && {!isNull _uav}) then { _sky = _uav; };

        if (!isNull _sky) then {
            private _alt = (getPosATL _sky) select 2;
            _orad = (STCTI_OBS_GROUND_R + _alt * STCTI_OBS_ALT_FACTOR) min STCTI_OBS_MAX_R;
            private _ahead = (vectorDir _sky) vectorMultiply (_alt * STCTI_OBS_LOOKAHEAD);
            _opos = (getPosATL _sky) vectorAdd _ahead;
        };

        _pts pushBack [[_opos select 0, _opos select 1, 0], _orad];
    };
} forEach allPlayers;

_pts
