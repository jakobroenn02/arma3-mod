// fn_grantUnlock.sqf — [SERVER] params: [_unlockId] -> Bool (true if newly granted)
// THE single mutation point for STCTI_unlocks (roadmap §1.2): normalizes legacy ids through
// STCTI_UNLOCK_ALIASES, grants idempotently, broadcasts UNLOCKS_CHANGED, re-tiers the arsenal.
// Both capture (fn_startProgression) and procurement (fn_serverProcure) route through here, so
// the invariant "an unlock is granted exactly once and everything downstream is notified" has
// exactly one owner.
params ["_id"];
if (!isServer) exitWith { false };
_id = STCTI_UNLOCK_ALIASES getOrDefault [_id, _id];
if (_id isEqualTo "" || {_id in STCTI_unlocks}) exitWith { false };

STCTI_unlocks pushBack _id;
[STCTI_EV_UNLOCKS_CHANGED, [STCTI_unlocks, _id]] call CBA_fnc_globalEvent;
call STCTI_fnc_updateArsenal;
diag_log format ["[STCTI] Unlock granted: %1.", _id];
true
