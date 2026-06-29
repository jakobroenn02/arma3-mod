// fn_directorTick.sqf — [SERVER] dumb self-rescheduling scheduler. See §F2.
if (!isServer) exitWith {};

[{
    call STCTI_fnc_launchAttack;
    call STCTI_fnc_directorTick; // reschedule
}, [], STCTI_ATTACK_MIN + random (STCTI_ATTACK_MAX - STCTI_ATTACK_MIN)] call CBA_fnc_waitAndExecute;
