// fn_travelMenu.sqf — [CLIENT] no params. Strategic-travel dialog (Phase 9): lists the HQ plus
// every travel node (STCTI_TRAVEL_NODE_IDS, broadcast once — node-ness is config-static) with
// ownership read from the marker colour. Redeploy needs an owned uncontested node; Insert can
// target any node (that's the assault-staging flavour) — the server re-validates either way.
if (!hasInterface) exitWith {};
disableSerialization;
if (isNil "STCTI_TRAVEL_NODE_IDS") exitWith { systemChat "STCTI: travel network not up yet."; };

private _dlg = findDisplay 46 createDisplay "RscDisplayEmpty";
if (isNull _dlg) exitWith { systemChat "STCTI: could not open travel."; };

private _panelW = 0.36 * safezoneW;
private _panelH = 0.46 * safezoneH;
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
_title ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.01*safezoneH, _panelW - 0.02*safezoneW, 0.075*safezoneH];
_title ctrlSetStructuredText parseText format [
    "<t size='1.3' shadow='1'>Strategic travel</t><br/><t size='0.85' color='#aaaaaa'>Redeploy: owned node, %1 fuel. Insert: airborne onto any node, %2 fuel. You + your AI squad; vehicles only via insert (the one you sit in).</t>",
    STCTI_TRAVEL_FUEL_COST, STCTI_TRAVEL_INSERT_FUEL
];
_title ctrlCommit 0;

private _lb = _dlg ctrlCreate ["RscListBox", 9931];
_lb ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.10*safezoneH, _panelW - 0.02*safezoneW, _panelH - 0.19*safezoneH];
_lb ctrlCommit 0;
private _i0 = _lb lbAdd "HQ (base)";
_lb lbSetData [_i0, "__hq"];
_lb lbSetColor [_i0, [0.55, 0.9, 1, 1]];
private _rows = [];
{
    private _m = "mk_" + _x;
    private _own = switch (markerColor _m) do {
        case "ColorBLUFOR": { "ours" };
        case "ColorOPFOR":  { "enemy" };
        default             { "contested" };
    };
    _rows pushBack [format ["%1 (%2)", _x, _own], _x, _own];
} forEach STCTI_TRAVEL_NODE_IDS;
_rows sort true;
{
    _x params ["_label", "_id", "_own"];
    private _i = _lb lbAdd _label;
    _lb lbSetData [_i, _id];
    if (_own isEqualTo "ours")  then { _lb lbSetColor [_i, [0.55, 0.75, 1, 1]]; };
    if (_own isEqualTo "enemy") then { _lb lbSetColor [_i, [1, 0.55, 0.55, 1]]; };
} forEach _rows;
_lb lbSetCurSel 0;

private _bw = (_panelW - 0.04*safezoneW) / 3;
private _by = _py + _panelH - 0.07*safezoneH;
{
    _x params ["_label", "_mode", "_col"];
    private _btn = _dlg ctrlCreate ["RscButton", -1];
    _btn ctrlSetPosition [_px + 0.01*safezoneW + _forEachIndex * (_bw + 0.01*safezoneW), _by, _bw, 0.05*safezoneH];
    _btn ctrlSetText _label;
    _btn ctrlCommit 0;
    if (_mode isEqualTo "") then {
        _btn ctrlAddEventHandler ["ButtonClick", { (ctrlParent (_this select 0)) closeDisplay 1; }];
    } else {
        _btn setVariable ["STCTI_mode", _mode];
        _btn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _d  = ctrlParent _ctrl;
            private _lb = _d displayCtrl 9931;
            private _sel = lbCurSel _lb;
            if (_sel < 0) exitWith {};
            [_lb lbData _sel, _ctrl getVariable "STCTI_mode"] call STCTI_fnc_requestTravel;
            _d closeDisplay 2;
        }];
    };
} forEach [["Redeploy", "redeploy", 0], ["Insert (HALO)", "insert", 0], ["Cancel", "", 0]];
