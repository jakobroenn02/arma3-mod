// fn_directorTick.sqf — [SERVER] the AI director's operational brain (Phase 4, design §8).
// Arms ONE self-rescheduling jittered loop (double-start guarded, like the other managers).
// Each roll: decay aggression (quiet time — captures push it back up via the fn_startManagers
// handler); force-resolve any spawned enemy op that has stalled past STCTI_OP_TIMEOUT (a live
// engagement is paused for the resolver, so MAX_TICKS can never fire — a lone surviving heli or
// crewman would otherwise hold the one-op gate open forever); then, if no enemy operation is
// running and the cooldown has passed, roll against aggression to launch ONE operation sized by
// the highest escalation tier at/below the current aggression. Deliberately only the
// WHEN/WHERE/WHAT brain — squad tactics stay with the engine/LAMBS (design §Phase-4).
if (!isServer) exitWith {};
if (!isNil "STCTI_directorLoop") exitWith {};   // already armed

STCTI_directorLoop = {
    private _a = (((STCTI_state getOrDefault ["aggression", STCTI_AGGRO_START]) - STCTI_AGGRO_DECAY)
                  max STCTI_AGGRO_FLOOR) min STCTI_AGGRO_CAP;
    STCTI_state set ["aggression", _a];

    // Stalled-op safeguard: a spawned engagement past the timeout culminates — the attacker
    // withdraws (resolveSpawnedEngagement despawns the remnants and closes the defend task).
    {
        if ((_x get "attackerOwner") isEqualTo "enemy" && {!(_x get "done")} && {_x get "spawned"}
            && {time - (_x getOrDefault ["startedAt", time]) > STCTI_OP_TIMEOUT}) then {
            diag_log format ["[STCTI] Director: op at %1 stalled past %2s — forcing attacker withdrawal.",
                _x get "sectorId", STCTI_OP_TIMEOUT];
            [_x, "attacker"] call STCTI_fnc_resolveSpawnedEngagement;
        };
    } forEach (values STCTI_engagements);

    // One operation at a time: any live enemy-attacker engagement blocks the roll.
    private _opActive = ((values STCTI_engagements) findIf {
        (_x get "attackerOwner") isEqualTo "enemy" && {!(_x get "done")}
    }) > -1;

    if (!_opActive && {time >= (STCTI_state getOrDefault ["opCooldownUntil", 0])} && {random 1 < _a}) then {
        // Escalation: the highest tier whose threshold the aggression clears.
        private _roster = [];
        { _x params ["_th", "_r"]; if (_a >= _th) then { _roster = _r; }; } forEach STCTI_ESCALATION;
        if ([_roster] call STCTI_fnc_launchAttack) then {
            STCTI_state set ["opCooldownUntil", time + STCTI_OP_COOLDOWN];
            diag_log format ["[STCTI] Director: op launched (aggression %1, roster %2).", _a, _roster];
        };
    };

    [STCTI_directorLoop, [], STCTI_ATTACK_MIN + random (STCTI_ATTACK_MAX - STCTI_ATTACK_MIN)] call CBA_fnc_waitAndExecute;
};

[STCTI_directorLoop, [], STCTI_ATTACK_MIN + random (STCTI_ATTACK_MAX - STCTI_ATTACK_MIN)] call CBA_fnc_waitAndExecute;
