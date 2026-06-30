// fn_garageMenu.sqf — [CLIENT] no params. Opens the vehicle-garage dialog: a list of the
// purchasable items currently available (catalog filtered by unlocks). "Place" starts ghost
// placement (fn_garagePlace) for the selected item; "Cancel" closes. Code-only dialog
// (RscDisplayEmpty + engine control base classes), like fn_showZoneSelect — no description.ext UI.
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

private _title = _dlg ctrlCreate ["RscStructuredText", -1];
_title ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.01*safezoneH, _panelW - 0.02*safezoneW, 0.06*safezoneH];
_title ctrlSetStructuredText parseText "<t size='1.3' shadow='1'>Vehicle Garage</t><br/><t size='0.85' color='#aaaaaa'>Select an item, then Place it where you want it.</t>";
_title ctrlCommit 0;

private _lb = _dlg ctrlCreate ["RscListBox", 9901];
_lb ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.09*safezoneH, _panelW - 0.02*safezoneW, _panelH - 0.18*safezoneH];
_lb ctrlCommit 0;
{
    _x params ["_label", "_cls", "_price", "_unlock"];
    if (_unlock isEqualTo "" || {_unlock in STCTI_unlocks}) then {
        private _i = _lb lbAdd _label;
        _lb lbSetData [_i, _cls];
    };
} forEach STCTI_garageCatalog;
if (lbSize _lb > 0) then { _lb lbSetCurSel 0; };

private _bw = (_panelW - 0.03*safezoneW) / 2;
private _by = _py + _panelH - 0.07*safezoneH;

private _place = _dlg ctrlCreate ["RscButton", -1];
_place ctrlSetPosition [_px + 0.01*safezoneW, _by, _bw, 0.05*safezoneH];
_place ctrlSetText "Place";
_place ctrlCommit 0;
_place ctrlAddEventHandler ["ButtonClick", {
    private _d = ctrlParent (_this select 0);
    private _lb = _d displayCtrl 9901;
    private _sel = lbCurSel _lb;
    if (_sel < 0) exitWith {};
    private _cls = _lb lbData _sel;
    _d closeDisplay 2;
    [_cls] call STCTI_fnc_garagePlace;
}];

private _cancel = _dlg ctrlCreate ["RscButton", -1];
_cancel ctrlSetPosition [_px + 0.02*safezoneW + _bw, _by, _bw, 0.05*safezoneH];
_cancel ctrlSetText "Cancel";
_cancel ctrlCommit 0;
_cancel ctrlAddEventHandler ["ButtonClick", { (ctrlParent (_this select 0)) closeDisplay 1; }];
