// fn_calibrate.sqf — [SERVER] params: [_attCount, _defCount, _sectorType]
// Pace-calibration aid for the master dial K (resolver spec §7). For the given rifleman rosters it:
//   1) runs the ABSTRACT resolver synchronously and reports time-to-break  T_abs = ticks·RESOLVE_INTERVAL;
//   2) spawns the SAME fight LIVE next to you (AI vs AI) and times it to the same break point T_live;
//   3) prints the K that would make them match:  K_suggested = K · T_abs / T_live.
// Both sides break at STCTI_BREAK_THRESHOLD of their starting count, so it's an apples-to-apples
// comparison. Stand on flat open ground and run, e.g.:  [8, 5, "town"] call STCTI_fnc_calibrate;
// Repeat a few times (use the median) and re-check a lopsided fight. Then set STCTI_K in init.sqf.
if (!isServer) exitWith {};
params [["_attCount", 8], ["_defCount", 5], ["_sectorType", "town"]];

private _defBonus = STCTI_DEFBONUS getOrDefault [_sectorType, 0.15];

// --- 1) Abstract time-to-break (synchronous) ---
private _att = createHashMapFromArray [["rifleman", _attCount]];
private _def = createHashMapFromArray [["rifleman", _defCount]];
private _accA = 0; private _accD = 0; private _ticks = 0; private _routed = "";
while { _routed isEqualTo "" && {_ticks < STCTI_MAX_TICKS + 1} } do {
    private _mA = [_att] call STCTI_fnc_forceMetrics;
    private _mD = [_def] call STCTI_fnc_forceMetrics;
    private _oAD = [_mA, _mD, false, _defBonus] call STCTI_fnc_forceOutput;
    private _oDA = [_mD, _mA, true,  _defBonus] call STCTI_fnc_forceOutput;
    _accA = [_att, _accA + STCTI_K * _oDA, _mA, _mD] call STCTI_fnc_applyCasualties;
    _accD = [_def, _accD + STCTI_K * _oAD, _mD, _mA] call STCTI_fnc_applyCasualties;
    _ticks = _ticks + 1;
    if (([_att] call STCTI_fnc_forceStrength) < STCTI_BREAK_THRESHOLD * _attCount) then { _routed = "attacker"; };
    if (([_def] call STCTI_fnc_forceStrength) < STCTI_BREAK_THRESHOLD * _defCount && {_routed isEqualTo ""}) then { _routed = "defender"; };
};
private _tAbs = _ticks * STCTI_RESOLVE_INTERVAL;

// --- 2) Live fight beside the player ---
private _p = getPosATL player;
private _attCenter = _p getPos [130, getDir player];
private _defCenter = _p getPos [60,  getDir player];
private _attGrp = [createHashMapFromArray [["rifleman", _attCount]], "enemy",  _attCenter, 25] call STCTI_fnc_spawnForce;
private _defGrp = [createHashMapFromArray [["rifleman", _defCount]], "player", _defCenter, 25] call STCTI_fnc_spawnForce;
{ _x setBehaviour "AWARE"; _x setCombatMode "RED"; } forEach [_attGrp, _defGrp];
(_attGrp addWaypoint [_defCenter, 0]) setWaypointType "SAD";

diag_log format ["[STCTI][calib] abstract: %1 broke after %2 ticks -> T_abs=%3 s (K=%4). Live fight spawned.",
    _routed, _ticks, _tAbs, STCTI_K];
hint format ["Calibration\nAbstract: %1 s (%2 ticks @ %3s)\nLive fight running - watch it...", round _tAbs, _ticks, STCTI_RESOLVE_INTERVAL];

// --- 3) Time the live fight to the same break point, then report + clean up ---
[{
    params ["_args", "_pfh"];
    _args params ["_attGrp", "_defGrp", "_t0", "_tAbs", "_attCount", "_defCount"];
    private _aN = { alive _x } count units _attGrp;
    private _dN = { alive _x } count units _defGrp;
    // keep waiting until one side drops below the break threshold of its starting count
    if (_aN >= STCTI_BREAK_THRESHOLD * _attCount && {_dN >= STCTI_BREAK_THRESHOLD * _defCount}) exitWith {};

    [_pfh] call CBA_fnc_removePerFrameHandler;
    private _tLive  = time - _t0;
    private _winner = if (_aN < STCTI_BREAK_THRESHOLD * _attCount) then { "defender" } else { "attacker" };
    private _suggK  = STCTI_K * _tAbs / (_tLive max 1);
    private _msg = format ["[STCTI][calib] LIVE: %1 won in %2 s  |  ABSTRACT: %3 s  |  suggested K = %4  (current %5)",
        _winner, round _tLive, round _tAbs, _suggK, STCTI_K];
    hint _msg; diag_log _msg;
    { deleteVehicle _x } forEach (units _attGrp + units _defGrp);
    deleteGroup _attGrp; deleteGroup _defGrp;
}, 1, [_attGrp, _defGrp, time, _tAbs, _attCount, _defCount]] call CBA_fnc_addPerFrameHandler;
