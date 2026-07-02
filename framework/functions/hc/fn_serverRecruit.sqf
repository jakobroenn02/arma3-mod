// fn_serverRecruit.sqf — [SERVER] params: [_requester]
// Recruits one High Command squad (Phase 5): charges STCTI_RECRUIT_COST (money + manpower —
// the design's recruiting sink), spawns STCTI_RECRUIT_COMP as a player-side group at the HC
// board via the normal spawnForce path (tagged, budget-counted), registers it in
// STCTI_state.hcGroups and broadcasts HC_CHANGED so every client's vanilla HC bar (Ctrl+Space)
// and table dialog pick it up. Dead squads are pruned on every change.
params ["_requester"];
if (!isServer) exitWith {};

if !(STCTI_RECRUIT_COST call STCTI_fnc_spendMulti) exitWith {
    private _needs = (STCTI_RECRUIT_COST apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    [format ["Not enough resources (needs %1).", _needs]] remoteExec ["hint", _requester];
};

private _comp = createHashMap;
{ _comp set [_x select 0, _x select 1]; } forEach STCTI_RECRUIT_COMP;
private _at  = if (isNil "STCTI_hcBoard" || {isNull STCTI_hcBoard}) then { STCTI_BASE_POS } else { getPosATL STCTI_hcBoard };
private _grp = [_comp, "player", _at, 12] call STCTI_fnc_spawnForce;
_grp setBehaviour "SAFE";

private _hc = (STCTI_state get "hcGroups") select { !isNull _x && {{alive _x} count units _x > 0} };
_hc pushBack _grp;
STCTI_state set ["hcGroups", _hc];
[STCTI_EV_HC_CHANGED, [+_hc]] call CBA_fnc_globalEvent;

[format ["Squad %1 recruited and awaiting orders.", groupId _grp]] remoteExec ["hint", _requester];
diag_log format ["[STCTI] HC squad recruited: %1 (%2 total).", groupId _grp, count _hc];
