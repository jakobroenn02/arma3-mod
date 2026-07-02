// fn_spendMulti.sqf — [SERVER] _this: [[resKey, amount], ...] -> Bool (true if charged)
// All-or-nothing multi-resource spend: every cost is affordability-checked BEFORE anything is
// debited, so a purchase can never take the money but fail the fuel. Goes through the same
// canAfford/addRes choke points as fn_spend. §A3.
//     [["money", 500], ["fuel", 50]] call STCTI_fnc_spendMulti
if (!isServer) exitWith { false };
if (_this findIf { !(_x call STCTI_fnc_canAfford) } > -1) exitWith { false };
{ [_x select 0, -(_x select 1)] call STCTI_fnc_addRes; } forEach _this;
true
