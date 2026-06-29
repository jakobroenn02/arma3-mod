// fn_economyTick.sqf — [SERVER] called every STCTI_ECONOMY_INTERVAL seconds.
// Credits income from player-owned sectors; addRes auto-pushes the HUD. See §D1.
if (!isServer) exitWith {};

{
    private _rec = _y;
    if ((_rec get "owner") isEqualTo "player") then {
        {
            [_x, _y] call STCTI_fnc_addRes; // _x = resKey, _y = amount
        } forEach (_rec get "income");
    };
} forEach (STCTI_state get "sectors");
