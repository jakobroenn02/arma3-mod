// fn_procureMenu.sqf — [CLIENT] no params. The procurement dialog (roadmap Phase 10d): lists
// every hardware category in STCTI_PROCURE_COST with its cost and owned/available state;
// "Procure" buys the selected category unlock (server-validated). Code-only dialog like
// fn_garageMenu. Capture-only unlocks never appear here — the cost table is the policy.
if (!hasInterface) exitWith {};
disableSerialization;

private _dlg = findDisplay 46 createDisplay "RscDisplayEmpty";
if (isNull _dlg) exitWith { systemChat "STCTI: could not open procurement."; };

private _panelW = 0.36 * safezoneW;
private _panelH = 0.44 * safezoneH;
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
_title ctrlSetStructuredText parseText "<t size='1.3' shadow='1'>Procurement</t><br/><t size='0.85' color='#aaaaaa'>Buy hardware-category access. Capturing the matching site is cheaper — and comes with the site.</t>";
_title ctrlCommit 0;

private _lb = _dlg ctrlCreate ["RscListBox", 9921];
_lb ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.09*safezoneH, _panelW - 0.02*safezoneW, _panelH - 0.18*safezoneH];
_lb ctrlCommit 0;
private _rows = [];
{
    private _cost = (_y apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    _rows pushBack [format ["%1 — %2", _x, _cost], _x];
} forEach STCTI_PROCURE_COST;
_rows sort true;
{
    _x params ["_label", "_id"];
    private _owned = _id in STCTI_unlocks;
    private _i = _lb lbAdd (if (_owned) then { format ["%1 — OWNED", _id] } else { _label });
    _lb lbSetData [_i, _id];
    if (_owned) then { _lb lbSetColor [_i, [0.6, 1, 0.63, 1]]; };
} forEach _rows;
if (lbSize _lb > 0) then { _lb lbSetCurSel 0; };

private _bw = (_panelW - 0.03*safezoneW) / 2;
private _by = _py + _panelH - 0.07*safezoneH;

private _buy = _dlg ctrlCreate ["RscButton", -1];
_buy ctrlSetPosition [_px + 0.01*safezoneW, _by, _bw, 0.05*safezoneH];
_buy ctrlSetText "Procure";
_buy ctrlCommit 0;
_buy ctrlAddEventHandler ["ButtonClick", {
    private _d = ctrlParent (_this select 0);
    private _lb = _d displayCtrl 9921;
    private _sel = lbCurSel _lb;
    if (_sel < 0) exitWith {};
    [_lb lbData _sel] call STCTI_fnc_requestProcure;
    _d closeDisplay 2;
}];

private _cancel = _dlg ctrlCreate ["RscButton", -1];
_cancel ctrlSetPosition [_px + 0.02*safezoneW + _bw, _by, _bw, 0.05*safezoneH];
_cancel ctrlSetText "Cancel";
_cancel ctrlCommit 0;
_cancel ctrlAddEventHandler ["ButtonClick", { (ctrlParent (_this select 0)) closeDisplay 1; }];
