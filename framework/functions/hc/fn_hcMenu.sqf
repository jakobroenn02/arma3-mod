// fn_hcMenu.sqf — [CLIENT] no params. The High Command table dialog (Phase 5, design §5):
// pick a squad (left list, from the STCTI_lastHC broadcast cache) and a target sector (right
// list, derived from the global mk_* markers — clients have no STCTI_state), then issue an
// order. Patrol/Attack/Defend need a squad; Supply run / Air strike are base assets with their
// own costs; Recruit buys a new squad. The dialog stays open for issuing several orders;
// reopen it to refresh the lists after recruiting. Code-only dialog like fn_garageMenu.
// Squads are also in the vanilla HC bar (Ctrl+Space) for direct map control.
if (!hasInterface) exitWith {};
disableSerialization;

private _dlg = findDisplay 46 createDisplay "RscDisplayEmpty";
if (isNull _dlg) exitWith { systemChat "STCTI: could not open High Command."; };

private _panelW = 0.46 * safezoneW;
private _panelH = 0.52 * safezoneH;
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
_title ctrlSetStructuredText parseText "<t size='1.3' shadow='1'>High Command</t><br/><t size='0.85' color='#aaaaaa'>Squad + sector, then an order. Squads also answer to the vanilla HC bar (Ctrl+Space).</t>";
_title ctrlCommit 0;

private _colW = (_panelW - 0.03*safezoneW) / 2;
private _listH = _panelH - 0.28*safezoneH;

// Left: squads.
private _sqLabel = _dlg ctrlCreate ["RscText", -1];
_sqLabel ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.08*safezoneH, _colW, 0.035*safezoneH];
_sqLabel ctrlSetText "Squads";
_sqLabel ctrlCommit 0;
private _lbSq = _dlg ctrlCreate ["RscListBox", 9911];
_lbSq ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.12*safezoneH, _colW, _listH];
_lbSq ctrlCommit 0;
{
    if (!isNull _x && {({alive _x} count units _x) > 0}) then {
        private _i = _lbSq lbAdd format ["%1 — %2 men", groupId _x, {alive _x} count units _x];
        _lbSq lbSetValue [_i, _forEachIndex];   // index into STCTI_lastHC
    };
} forEach STCTI_lastHC;
if (lbSize _lbSq > 0) then { _lbSq lbSetCurSel 0; };

// Right: sectors (from the global markers; colour = owner).
private _seLabel = _dlg ctrlCreate ["RscText", -1];
_seLabel ctrlSetPosition [_px + 0.02*safezoneW + _colW, _py + 0.08*safezoneH, _colW, 0.035*safezoneH];
_seLabel ctrlSetText "Target sector";
_seLabel ctrlCommit 0;
private _lbSe = _dlg ctrlCreate ["RscListBox", 9912];
_lbSe ctrlSetPosition [_px + 0.02*safezoneW + _colW, _py + 0.12*safezoneH, _colW, _listH];
_lbSe ctrlCommit 0;
private _rows = [];
{
    private _id = _x select [3];
    private _own = switch (markerColor _x) do {
        case "ColorBLUFOR": { "ours" };
        case "ColorOPFOR":  { "enemy" };
        default             { "contested" };
    };
    _rows pushBack [format ["%1 (%2)", _id, _own], _id, _own];
} forEach (allMapMarkers select { _x select [0, 3] isEqualTo "mk_" && {!("_dot" in _x)} });
_rows sort true;
{
    _x params ["_label", "_id", "_own"];
    private _i = _lbSe lbAdd _label;
    _lbSe lbSetData [_i, _id];
    if (_own isEqualTo "ours") then { _lbSe lbSetColor [_i, [0.55, 0.75, 1, 1]]; };
    if (_own isEqualTo "enemy") then { _lbSe lbSetColor [_i, [1, 0.55, 0.55, 1]]; };
} forEach _rows;
if (lbSize _lbSe > 0) then { _lbSe lbSetCurSel 0; };

// Shared by all order buttons (global — EH code blocks don't capture privates).
STCTI_hcMenuOrder = {
    params ["_d", "_order"];
    private _lbSe = _d displayCtrl 9912;
    private _selSe = lbCurSel _lbSe;
    if (_selSe < 0) exitWith { systemChat "STCTI: pick a target sector."; };
    private _sectorId = _lbSe lbData _selSe;
    private _grp = grpNull;
    if !(_order in ["supply", "airstrike"]) then {
        private _lbSq = _d displayCtrl 9911;
        private _selSq = lbCurSel _lbSq;
        if (_selSq < 0) exitWith { systemChat "STCTI: pick a squad for that order."; };
        _grp = STCTI_lastHC param [_lbSq lbValue _selSq, grpNull];
    };
    [_grp, _order, _sectorId, clientOwner] remoteExec ["STCTI_fnc_serverHCOrder", 2]; // 2 = server
};

// Order buttons: two rows of three.
private _bw = (_panelW - 0.05*safezoneW) / 3;
private _bh = 0.05 * safezoneH;
private _rows2 = [
    [["Patrol", "patrol"], ["Defend", "defend"], ["Attack", "attack"]],
    [[format ["Supply run (%1$)", (STCTI_SUPPLY_COST param [0, ["money", 0]]) select 1], "supply"],
     ["Air strike", "airstrike"],
     ["RECRUIT", "recruit"]]
];
{
    private _rowY = _py + _panelH - (0.14 - 0.065 * _forEachIndex) * safezoneH;
    {
        _x params ["_label", "_order"];
        private _btn = _dlg ctrlCreate ["RscButton", -1];
        _btn ctrlSetPosition [_px + 0.01*safezoneW + _forEachIndex * (_bw + 0.015*safezoneW), _rowY, _bw, _bh];
        _btn ctrlSetText _label;
        _btn ctrlCommit 0;
        if (_order isEqualTo "recruit") then {
            _btn ctrlAddEventHandler ["ButtonClick", {
                [clientOwner] remoteExec ["STCTI_fnc_serverRecruit", 2];
                systemChat "STCTI: recruiting — reopen High Command to see the new squad.";
            }];
        } else {
            _btn setVariable ["STCTI_order", _order];
            _btn ctrlAddEventHandler ["ButtonClick", {
                params ["_ctrl"];
                [ctrlParent _ctrl, _ctrl getVariable "STCTI_order"] call STCTI_hcMenuOrder;
            }];
        };
    } forEach _x;
} forEach _rows2;
