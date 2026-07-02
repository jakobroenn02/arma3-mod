// fn_garageMenu.sqf — [CLIENT] no params. Opens the vehicle-garage dialog: stored vehicles
// first (green, free to take out — STCTI_lastStored cache of GARAGE_CHANGED), then the full
// catalog with locked items grayed out (required unlock shown) and unaffordable items tinted
// red from the cached resource push (STCTI_lastRes, see fn_updateHUD). "Place" or double-click
// starts ghost placement (fn_garagePlace) for the selected item; "Cancel"/Esc closes. Code-only
// dialog (RscDisplayEmpty + engine control base classes), like fn_showZoneSelect — no
// description.ext UI. All checks here are cosmetic; the server re-validates on purchase (§E1).
if (!hasInterface) exitWith {};
disableSerialization;

private _dlg = findDisplay 46 createDisplay "RscDisplayEmpty";
if (isNull _dlg) exitWith { systemChat "STCTI: could not open the garage."; };

private _panelW = 0.34 * safezoneW;
private _panelH = 0.42 * safezoneH;
private _px = safezoneX + (safezoneW - _panelW) / 2;
private _py = safezoneY + (safezoneH - _panelH) / 2;

private _bg = _dlg ctrlCreate ["RscText", -1];
_bg ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.55];
_bg ctrlCommit 0;

private _panel = _dlg ctrlCreate ["RscText", -1];
_panel ctrlSetPosition [_px, _py, _panelW, _panelH];
_panel ctrlSetBackgroundColor [0.05, 0.05, 0.06, 0.95];
_panel ctrlCommit 0;

// -1 = balance unknown (no resource push yet) — then skip the affordability tint.
private _money = if (isNil "STCTI_lastRes") then { -1 } else { STCTI_lastRes getOrDefault ["money", 0] };
private _fuel  = if (isNil "STCTI_lastRes") then { -1 } else { STCTI_lastRes getOrDefault ["fuel", 0] };

private _title = _dlg ctrlCreate ["RscStructuredText", -1];
_title ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.01*safezoneH, _panelW - 0.02*safezoneW, 0.06*safezoneH];
_title ctrlSetStructuredText parseText format [
    "<t size='1.3' shadow='1'>Vehicle Garage</t><br/><t size='0.85' color='#aaaaaa'>%1Select an item, then Place it where you want it.</t>",
    if (_money < 0) then { "" } else { format ["<t color='#7ec8ff'>Money %1</t> — ", _money] }
];
_title ctrlCommit 0;

// List value encodes the row kind: 0 = purchasable, 1 = locked (Place refuses it),
// 2 = stored vehicle (retrieved for free — it was already paid for).
private _lb = _dlg ctrlCreate ["RscListBox", 9901];
_lb ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.09*safezoneH, _panelW - 0.02*safezoneW, _panelH - 0.18*safezoneH];
_lb ctrlCommit 0;
{
    _x params ["_cls", "_hits", "_fuel"];
    private _dmgs = _hits param [2, []];
    private _avg = 0;
    { _avg = _avg + _x; } forEach _dmgs;
    if !(_dmgs isEqualTo []) then { _avg = _avg / count _dmgs; };
    private _i = _lb lbAdd format ["Take out %1 — %2% condition, %3% fuel",
        getText (configFile >> "CfgVehicles" >> _cls >> "displayName"),
        round ((1 - _avg) * 100), round (_fuel * 100)];
    _lb lbSetData  [_i, _cls];
    _lb lbSetValue [_i, 2];
    _lb lbSetColor [_i, [0.6, 1, 0.63, 1]];
} forEach STCTI_lastStored;
{
    _x params ["_label", "_cls", "_price", "_unlock", ["_fuelC", 0]];
    private _locked = !(_unlock isEqualTo "" || {_unlock in STCTI_unlocks});
    private _i = _lb lbAdd (if (_locked) then { format ["%1 — locked: %2", _label, _unlock] } else { _label });
    _lb lbSetData  [_i, _cls];
    _lb lbSetValue [_i, parseNumber _locked];
    if (_locked) then {
        _lb lbSetColor [_i, [0.55, 0.55, 0.55, 0.7]];
    } else {
        private _short = (_money >= 0 && {_price > _money}) || {_fuel >= 0 && {_fuelC > _fuel}};
        if (_short) then { _lb lbSetColor [_i, [1, 0.45, 0.45, 1]]; };
    };
} forEach STCTI_garageCatalog;
if (lbSize _lb > 0) then { _lb lbSetCurSel 0; };

// Shared by the Place button and list double-click. Global because EH code blocks
// don't capture privates. Locked rows just flash a message and keep the menu open.
STCTI_garageMenuPlace = {
    params ["_d"];
    private _lb = _d displayCtrl 9901;
    private _sel = lbCurSel _lb;
    if (_sel < 0) exitWith {};
    private _kind = _lb lbValue _sel;
    if (_kind isEqualTo 1) exitWith { systemChat "STCTI: that item is still locked — capture the sector that unlocks it."; };
    private _cls = _lb lbData _sel;
    _d closeDisplay 2;
    // Stored rows are listed first, so the row index IS the storedVehicles index — pass it
    // through so retrieval takes THIS vehicle (matters when two of a class differ in condition).
    [_cls, if (_kind isEqualTo 2) then { "retrieve" } else { "buy" }, _sel] call STCTI_fnc_garagePlace;
};
_lb ctrlAddEventHandler ["LBDblClick", { [ctrlParent (_this select 0)] call STCTI_garageMenuPlace; }];

private _bw = (_panelW - 0.03*safezoneW) / 2;
private _by = _py + _panelH - 0.07*safezoneH;

private _place = _dlg ctrlCreate ["RscButton", -1];
_place ctrlSetPosition [_px + 0.01*safezoneW, _by, _bw, 0.05*safezoneH];
_place ctrlSetText "Place";
_place ctrlCommit 0;
_place ctrlAddEventHandler ["ButtonClick", { [ctrlParent (_this select 0)] call STCTI_garageMenuPlace; }];

private _cancel = _dlg ctrlCreate ["RscButton", -1];
_cancel ctrlSetPosition [_px + 0.02*safezoneW + _bw, _by, _bw, 0.05*safezoneH];
_cancel ctrlSetText "Cancel";
_cancel ctrlCommit 0;
_cancel ctrlAddEventHandler ["ButtonClick", { (ctrlParent (_this select 0)) closeDisplay 1; }];
