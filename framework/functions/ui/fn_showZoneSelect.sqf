// fn_showZoneSelect.sqf — [CLIENT] campaign-start "choose your starting zone" dialog.
// Code-only dialog (RscDisplayEmpty + engine control base classes), no description.ext
// dialog definitions needed. On confirm, asks the server to establish the base.
// Must run in a scheduled environment (called from spawn) — it waits + sleeps.
if (!hasInterface) exitWith {};
disableSerialization;

// Wait for the actual in-mission display (display 46 doesn't exist on the briefing/
// loading screen, where createDisplay would silently fail).
waitUntil { !isNull (findDisplay 46) && {!isNull player} && {alive player} };

// createDisplay can still fail for a few frames at start; retry briefly.
private _dlg = displayNull;
private _tries = 0;
while { isNull _dlg && _tries < 50 } do {
    _dlg = findDisplay 46 createDisplay "RscDisplayEmpty";
    _tries = _tries + 1;
    if (isNull _dlg) then { sleep 0.2; };
};
if (isNull _dlg) exitWith {
    systemChat "STCTI: could not open the zone-selection dialog.";
    diag_log "[STCTI] fn_showZoneSelect: RscDisplayEmpty createDisplay failed after retries.";
};
diag_log "[STCTI] fn_showZoneSelect: dialog opened.";

// Centered panel geometry.
private _panelW = 0.40 * safezoneW;
private _panelH = 0.42 * safezoneH;
private _px = safezoneX + (safezoneW - _panelW) / 2;
private _py = safezoneY + (safezoneH - _panelH) / 2;

// Dim full-screen backdrop.
private _bg = _dlg ctrlCreate ["RscText", -1];
_bg ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.6];
_bg ctrlCommit 0;

// Panel background.
private _panel = _dlg ctrlCreate ["RscText", -1];
_panel ctrlSetPosition [_px, _py, _panelW, _panelH];
_panel ctrlSetBackgroundColor [0.05, 0.05, 0.06, 0.95];
_panel ctrlCommit 0;

// Title.
private _title = _dlg ctrlCreate ["RscStructuredText", -1];
_title ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.01*safezoneH, _panelW - 0.02*safezoneW, 0.06*safezoneH];
_title ctrlSetStructuredText parseText "<t size='1.4' shadow='1'>Establish your base of operations</t><br/><t size='0.9' color='#aaaaaa'>Choose your faction and where the campaign begins.</t>";
_title ctrlCommit 0;

// Faction picker (Phase 3): label + combo over the STCTI_FACTION_POOL keys. The pick rides
// along with the base choice to fn_serverPlaceBase, which applies it campaign-wide.
private _fLabel = _dlg ctrlCreate ["RscText", -1];
_fLabel ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.085*safezoneH, 0.07*safezoneW, 0.04*safezoneH];
_fLabel ctrlSetText "Faction:";
_fLabel ctrlCommit 0;

private _fCombo = _dlg ctrlCreate ["RscCombo", 8802];
_fCombo ctrlSetPosition [_px + 0.08*safezoneW, _py + 0.085*safezoneH, _panelW - 0.09*safezoneW, 0.04*safezoneH];
_fCombo ctrlCommit 0;
{ _fCombo lbAdd _x; } forEach ["NATO", "CSAT", "AAF"];
_fCombo lbSetCurSel 0;

// Zone listbox.
private _lb = _dlg ctrlCreate ["RscListBox", 8801];
_lb ctrlSetPosition [_px + 0.01*safezoneW, _py + 0.14*safezoneH, _panelW - 0.02*safezoneW, _panelH - 0.23*safezoneH];
_lb ctrlCommit 0;
{ _lb lbAdd (_x select 0); } forEach STCTI_START_BASES;
_lb lbSetCurSel 0;

// Confirm button.
private _btn = _dlg ctrlCreate ["RscButton", -1];
_btn ctrlSetPosition [_px + 0.01*safezoneW, _py + _panelH - 0.07*safezoneH, _panelW - 0.02*safezoneW, 0.05*safezoneH];
_btn ctrlSetText "Establish Base Here";
_btn ctrlCommit 0;
_btn ctrlAddEventHandler ["ButtonClick", {
    params ["_ctrl"];
    private _d = ctrlParent _ctrl;
    private _sel = lbCurSel (_d displayCtrl 8801);
    if (_sel < 0) exitWith {};
    private _fCombo  = _d displayCtrl 8802;
    private _faction = _fCombo lbText (lbCurSel _fCombo max 0);
    _d closeDisplay 1;
    [_sel, _faction, player] remoteExec ["STCTI_fnc_serverPlaceBase", 2];
}];
