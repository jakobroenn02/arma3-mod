// fn_applyCasualties.sqf — [SERVER] params: [_force, _acc, _selfMetrics, _enemyMetrics] -> Number (remaining acc)
// Converts an accumulated loss budget (_acc, in CP) into whole-unit removals from _force,
// weighted by vulnerability. MUTATES _force in place; returns the leftover accumulator
// (carried to next tick). See spec §5.
//
// Vulnerability: baseVuln(armorClass)·counterFactor. Armor/air the enemy can't answer has
// counterFactor ≈ 0.1 → effectively immortal (the "unanswered tank"), forcing combined arms.
params ["_force", "_acc", "_self", "_enemy"];

// How well the ENEMY answers THIS force's armor/air (drives counterFactor).
private _selfArmorCP = _self get "armorCP";
private _selfAirCP   = _self get "airCP";
private _armAnsEF = if (_selfArmorCP > 0) then { 1 min ((_enemy get "antiArmorCP") / _selfArmorCP) } else { 1 };
private _airAnsEF = if (_selfAirCP   > 0) then { 1 min ((_enemy get "antiAirCP")   / _selfAirCP)   } else { 1 };

private _continue = true;
while { _continue } do {
    private _types = (keys _force) select { (_force get _x) > 0 };
    if (_types isEqualTo []) exitWith { _continue = false };

    // Stop once the budget can't even afford the cheapest remaining unit (carry remainder).
    private _minCp = 1e9;
    { private _cp = [_x, "cp"] call STCTI_fnc_unitAttr; if (_cp < _minCp) then { _minCp = _cp }; } forEach _types;
    if (_acc < _minCp) exitWith { _continue = false };

    // Build vulnerability weights for each present type.
    private _weights = [];
    private _total = 0;
    {
        private _t  = _x;
        private _ac = [_t, "armorClass"] call STCTI_fnc_unitAttr;
        private _cf = switch (true) do {
            case (_ac in ["armored", "heavy"]): { 0.1 + 0.9 * _armAnsEF };
            case (_ac isEqualTo "air"):         { 0.1 + 0.9 * _airAnsEF };
            default                             { 1 };
        };
        private _bv = STCTI_BASEVULN getOrDefault [_ac, 1];
        private _w  = (_force get _t) * _bv * _cf;
        _weights pushBack [_t, _w];
        _total = _total + _w;
    } forEach _types;
    if (_total <= 0) exitWith { _continue = false };

    // Weighted random pick of which type takes the loss.
    private _r = random _total;
    private _pick = (_weights select ((count _weights) - 1)) select 0;
    private _cum = 0;
    { _cum = _cum + (_x select 1); if (_r <= _cum) exitWith { _pick = _x select 0 }; } forEach _weights;

    private _pcp = [_pick, "cp"] call STCTI_fnc_unitAttr;
    if (_acc >= _pcp) then {
        _force set [_pick, (_force get _pick) - 1];
        _acc = _acc - _pcp;
    } else {
        _continue = false;   // not enough budget to kill this unit yet
    };
};

_acc
