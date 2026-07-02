// fn_serverProcure.sqf — [SERVER] params: [_unlockId, _requester]
// Procurement (roadmap Phase 10d): buy a hardware-category unlock with resources. The absence
// of an id in STCTI_PROCURE_COST IS the policy — unique site effects (intel, income, the spawn
// point) can never be bought, so capturing a site stays strictly better than paying. Grants
// through fn_grantUnlock, the single unlock authority.
params ["_id", "_requester"];
if (!isServer) exitWith {};

_id = STCTI_UNLOCK_ALIASES getOrDefault [_id, _id];
if (_id in STCTI_unlocks) exitWith { ["Already unlocked."] remoteExec ["hint", _requester]; };
private _cost = STCTI_PROCURE_COST getOrDefault [_id, []];
if (_cost isEqualTo []) exitWith {
    ["That can't be procured — capture the site that grants it."] remoteExec ["hint", _requester];
};
if !(_cost call STCTI_fnc_spendMulti) exitWith {
    private _needs = (_cost apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    [format ["Not enough resources (needs %1).", _needs]] remoteExec ["hint", _requester];
};

[_id] call STCTI_fnc_grantUnlock;
[format ["Procured: %1 hardware is now available.", _id]] remoteExec ["hint", _requester];
