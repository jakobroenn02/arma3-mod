// fn_resolverSelfTest.sqf — [SERVER] no params. Runs the spec §10 worked examples to
// completion synchronously (ignoring the PFH) and diag_logs the outcomes, so you can
// confirm the resolver behaves correctly in-engine. Run from the debug console:
//     call STCTI_fnc_resolverSelfTest;
// Expected: Example A -> defender routs, attacker keeps ~6 riflemen.
//           Example B -> attacker routs, the MBT survives.
if (!isServer) exitWith {};

private _runOne = {
    params ["_label", "_att", "_def", "_sectorType"];
    private _defBonus = STCTI_DEFBONUS getOrDefault [_sectorType, 0.15];
    private _eng = createHashMapFromArray [
        ["sectorId", "selftest"], ["attacker", _att], ["defender", _def],
        ["attackerOwner", "player"], ["defenderOwner", "enemy"], ["defBonus", _defBonus],
        ["startA", [_att] call STCTI_fnc_forceStrength],
        ["startD", [_def] call STCTI_fnc_forceStrength],
        ["accA", 0], ["accD", 0], ["ticks", 0], ["paused", false], ["done", false]
    ];
    // Tick locally without touching STCTI_engagements or flipping a real sector.
    private _routed = "";
    while { _routed isEqualTo "" && {(_eng get "ticks") < STCTI_MAX_TICKS + 1} } do {
        private _mA = [_att] call STCTI_fnc_forceMetrics;
        private _mD = [_def] call STCTI_fnc_forceMetrics;
        private _oAD = [_mA, _mD, false, _defBonus] call STCTI_fnc_forceOutput;
        private _oDA = [_mD, _mA, true,  _defBonus] call STCTI_fnc_forceOutput;
        private _jA = 1 + STCTI_JITTER * (random 2 - 1);
        private _jD = 1 + STCTI_JITTER * (random 2 - 1);
        _eng set ["accA", [_att, (_eng get "accA") + STCTI_K * _oDA * _jA, _mA, _mD] call STCTI_fnc_applyCasualties];
        _eng set ["accD", [_def, (_eng get "accD") + STCTI_K * _oAD * _jD, _mD, _mA] call STCTI_fnc_applyCasualties];
        _eng set ["ticks", (_eng get "ticks") + 1];
        private _brA = ([_att] call STCTI_fnc_forceStrength) / (_eng get "startA");
        private _brD = ([_def] call STCTI_fnc_forceStrength) / (_eng get "startD");
        if (_brA < STCTI_BREAK_THRESHOLD) then { _routed = "attacker"; };
        if (_brD < STCTI_BREAK_THRESHOLD && {_routed isEqualTo "" || _brD <= _brA}) then { _routed = "defender"; };
    };
    diag_log format ["[STCTI][selftest] %1: %2 routed after %3 ticks. Survivors A=%4 D=%5",
        _label, _routed, _eng get "ticks", _att, _def];
    systemChat format ["STCTI selftest %1: %2 routed (A=%3 D=%4)", _label, _routed, _att, _def];
};

["Example A (8rifle vs 5rifle town)",
    createHashMapFromArray [["rifleman", 8]],
    createHashMapFromArray [["rifleman", 5]], "town"] call _runOne;

["Example B (8rifle vs 4rifle+1mbt town)",
    createHashMapFromArray [["rifleman", 8]],
    createHashMapFromArray [["rifleman", 4], ["mbt", 1]], "town"] call _runOne;
