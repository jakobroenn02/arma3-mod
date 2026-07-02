// fn_updateHUD.sqf — [CLIENT] params: [resourcesHashMap]  (CBA event handler)
// Writes the four resource numbers into the structured-text HUD control. See §B1.
params ["_res"];
if (!hasInterface) exitWith {};
disableSerialization;

// Cache the latest server push so other UI (garage menu) can read current balances
// without asking the server. Nil until the first RESOURCES_CHANGED arrives.
STCTI_lastRes = _res;

private _ctrl = uiNamespace getVariable ["STCTI_hud", controlNull];
if (isNull _ctrl) exitWith {};

_ctrl ctrlSetStructuredText parseText format [
    "<t size='1.1' shadow='1'>"
    + "<t color='#7ec8ff'>Money</t> %1   "
    + "<t color='#9affa0'>Manpower</t> %2<br/>"
    + "<t color='#ffd27e'>Fuel</t> %3   "
    + "<t color='#ff9a9a'>Ammo</t> %4</t>",
    _res getOrDefault ["money", 0],
    _res getOrDefault ["manpower", 0],
    _res getOrDefault ["fuel", 0],
    _res getOrDefault ["ammo", 0]
];
