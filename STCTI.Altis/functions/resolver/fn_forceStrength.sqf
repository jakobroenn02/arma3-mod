// fn_forceStrength.sqf — [GLOBAL] params: [_force] -> Number (Sraw)
// _force = HashMap typeId -> count. Raw strength = Σ count·cp. See spec §3.
params ["_force"];
private _s = 0;
{ if (_y > 0) then { _s = _s + _y * ([_x, "cp"] call STCTI_fnc_unitAttr); }; } forEach _force;
_s
