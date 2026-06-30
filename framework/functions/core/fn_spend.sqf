// fn_spend.sqf — [SERVER] params: [resKey, amount] -> Bool (true if charged)
// THE choke point for all spending. Validate, then debit. See §A3.
params ["_key", "_amt"];
if (!isServer) exitWith { false };
if !([_key, _amt] call STCTI_fnc_canAfford) exitWith { false };
[_key, -_amt] call STCTI_fnc_addRes;
true
