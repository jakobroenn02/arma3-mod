// fn_addRes.sqf — [SERVER] params: [resKey, amount]  (amount may be negative)
// Mutates the ledger and pushes the new resources to every machine. See §A3.
params ["_key", "_amt"];
if (!isServer) exitWith {};

private _res = STCTI_state get "resources";
_res set [_key, (_res getOrDefault [_key, 0]) + _amt];

// globalEvent (not serverEvent) so the HUD updates on every client, incl. this one.
[STCTI_EV_RESOURCES_CHANGED, [_res]] call CBA_fnc_globalEvent;
