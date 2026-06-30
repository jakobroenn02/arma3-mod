// fn_observerDebug.sqf — [SERVER] no params. Hints the current observer points and each
// sector's observed state, for verifying the observer-point system in-engine. Run from the
// debug console:  call STCTI_fnc_observerDebug;
// Fly/drive around and watch sectors flip observed=true near you, and the radius grow with
// altitude when you're in an aircraft or piloting a UAV.
if (!isServer) exitWith {};

private _pts = call STCTI_fnc_observerPoints;
private _txt = format ["[STCTI] observer points: %1\n", count _pts];
{
    _x params ["_p", "_rad"];
    _txt = _txt + format ["  at [%1, %2]  r=%3 m\n", round (_p select 0), round (_p select 1), round _rad];
} forEach _pts;

{
    private _rec = (STCTI_state get "sectors") get _x;
    _txt = _txt + format ["  sector %1 (%2): observed=%3\n", _x, _rec get "owner", [_x] call STCTI_fnc_isSectorObserved];
} forEach (keys (STCTI_state get "sectors"));

hint _txt;
diag_log _txt;
