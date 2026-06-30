// fn_forceCount.sqf — [GLOBAL] params: [_force] -> Number
// Total unit count in an abstract force (HashMap typeId -> count). Used for budget costing.
params ["_force"];
private _n = 0;
{ _n = _n + _y } forEach _force;
_n
