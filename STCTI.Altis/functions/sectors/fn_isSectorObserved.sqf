// fn_isSectorObserved.sqf — [SERVER] params: [_sectorId] -> Bool
// Is any player close enough to a sector that an attack there should spawn as LIVE units
// (rather than resolve abstractly)?
//
// [PLACEHOLDER] Proximity-only: a player within (sectorRadius + STCTI_OBSERVE_RANGE) of the
// centre counts as observing. This is deliberately the single seam that Phase 2 step 2
// replaces with proper observer points — body position on foot, the sensor/camera target in
// aircraft with an altitude-scaled radius, and the UAV camera's ground target when piloting a
// drone (see strategic-cti-framework-design.md §9). Keep that upgrade contained to this file.
params ["_sectorId"];

private _rec = (STCTI_state get "sectors") get _sectorId;
if (isNil "_rec") exitWith { false };

private _pos   = _rec get "pos";
private _reach = (_rec get "radius") + STCTI_OBSERVE_RANGE;

private _observed = false;
{
    if (alive _x && {(_x distance2D _pos) < _reach}) exitWith { _observed = true; };
} forEach allPlayers;

_observed
