// fn_resolveTick.sqf — [SERVER] params: [_eng]  (one engagement record)
// One attrition step: compute both sides' output, accumulate fractional losses (with
// jitter), convert to whole-unit removals, advance the tick, then test for a break.
// See spec §4.
params ["_eng"];
if (_eng get "paused") exitWith {};

private _att = _eng get "attacker";
private _def = _eng get "defender";
private _mA = [_att] call STCTI_fnc_forceMetrics;
private _mD = [_def] call STCTI_fnc_forceMetrics;
private _defBonus = _eng get "defBonus";

// Output each side inflicts this tick (defender gets the terrain bonus).
private _outAtoD = [_mA, _mD, false, _defBonus] call STCTI_fnc_forceOutput;
private _outDtoA = [_mD, _mA, true,  _defBonus] call STCTI_fnc_forceOutput;

// Per-tick jitter ~ Uniform(1−JITTER, 1+JITTER).
private _jA = 1 + STCTI_JITTER * (random 2 - 1);
private _jD = 1 + STCTI_JITTER * (random 2 - 1);

// Accumulate losses: each side bleeds proportional to the ENEMY's output × K.
private _accA = (_eng get "accA") + STCTI_K * _outDtoA * _jA;
private _accD = (_eng get "accD") + STCTI_K * _outAtoD * _jD;

// Convert budgets to whole-unit removals (metrics captured at tick start, order-independent).
_accA = [_att, _accA, _mA, _mD] call STCTI_fnc_applyCasualties;
_accD = [_def, _accD, _mD, _mA] call STCTI_fnc_applyCasualties;

_eng set ["accA", _accA];
_eng set ["accD", _accD];
_eng set ["ticks", (_eng get "ticks") + 1];

_eng call STCTI_fnc_checkBreak;
