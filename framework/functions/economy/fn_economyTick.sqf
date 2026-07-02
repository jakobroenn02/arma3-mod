// fn_economyTick.sqf — [SERVER] called every STCTI_ECONOMY_INTERVAL seconds.
// Credits income from player-owned sectors that are SUPPLIED (connected to the HQ beachhead
// through owned adjacent sectors — fn_isSectorSupplied); a cut-off sector holds its ground but
// pays nothing until the chain is restored. addRes auto-pushes the HUD. See §D1.
if (!isServer) exitWith {};

{
    private _rec = _y;
    if ((_rec get "owner") isEqualTo "player" && {[_x] call STCTI_fnc_isSectorSupplied}) then {
        {
            [_x, _y] call STCTI_fnc_addRes; // _x = resKey, _y = amount
        } forEach (_rec get "income");
    };
} forEach (STCTI_state get "sectors");
