// fn_updateFrontline.sqf — [SERVER] no params. Renders the front line on the map: owned
// sectors at normal alpha, attackable enemy sectors bright (that's the front), out-of-reach
// enemy sectors faded. setMarkerAlpha broadcasts, so every client's map shows the same front.
// Called after every ownership flip (fn_setSectorOwner) and at base establish.
if (!isServer) exitWith {};

{
    private _alpha = if ((_y get "owner") isEqualTo "player") then {
        // Owned: bright while supplied, dimmed when the chain to the HQ is cut.
        [0.3, 0.6] select ([_x] call STCTI_fnc_isSectorSupplied)
    } else {
        [0.25, 0.85] select ([_x] call STCTI_fnc_isSectorAttackable)
    };
    ("mk_" + _x) setMarkerAlpha _alpha;
    ("mk_" + _x + "_dot") setMarkerAlpha ([0.4, 1] select (_alpha > 0.3));
} forEach (STCTI_state get "sectors");
