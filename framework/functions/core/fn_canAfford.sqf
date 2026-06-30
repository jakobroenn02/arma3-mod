// fn_canAfford.sqf — [SERVER] params: [resKey, amount] -> Bool. See §A3.
params ["_key", "_amt"];
((STCTI_state get "resources") getOrDefault [_key, 0]) >= _amt
