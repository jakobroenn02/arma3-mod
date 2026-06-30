// fn_isSectorObserved.sqf — [SERVER] params: [_sectorId, _spawned] -> Bool
// Is any player watching this sector closely enough that a fight here should be LIVE units
// (rather than resolved abstractly)? True if any observer point (body / altitude-scaled
// aircraft / UAV — see fn_observerPoints) lies within (sectorRadius + observerRadius).
//
// _spawned (default false): pass true when the sector's fight is already spawned, to add
// STCTI_OBS_HYSTERESIS to the threshold — so a force that just spawned doesn't thrash back to
// abstract the instant the player wobbles at the boundary (spawn near, despawn a bit farther).
params ["_sectorId", ["_spawned", false]];

private _rec = (STCTI_state get "sectors") get _sectorId;
if (isNil "_rec") exitWith { false };

private _pos    = _rec get "pos";
private _r      = _rec get "radius";
private _margin = if (_spawned) then { STCTI_OBS_HYSTERESIS } else { 0 };

private _observed = false;
{
    _x params ["_opos", "_orad"];
    if ((_opos distance2D _pos) < (_r + _orad + _margin)) exitWith { _observed = true; };
} forEach (call STCTI_fnc_observerPoints);

_observed
