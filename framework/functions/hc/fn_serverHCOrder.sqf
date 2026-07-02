// fn_serverHCOrder.sqf — [SERVER] params: [_grp, _order, _sectorId, _requester]
// The order compiler's entry point (Phase 5): validates the target sector (and the squad, for
// squad orders), then dispatches to the STCTI_fnc_order* backend. "supply" and "airstrike"
// are base assets — no squad needed, they carry their own costs.
params ["_grp", "_order", "_sectorId", "_requester"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _sectorId;
if (isNil "_rec") exitWith { ["Unknown target sector."] remoteExec ["hint", _requester]; };

switch (_order) do {
    case "supply":      { [_sectorId, _requester] call STCTI_fnc_orderSupply; };
    case "airstrike":   { [_sectorId, _requester] call STCTI_fnc_orderAirStrike; };
    case "firemission": { [_sectorId, _requester] call STCTI_fnc_orderFireMission; };
    default {
        if (isNull _grp || {({alive _x} count units _grp) == 0}) exitWith {
            ["That squad no longer exists."] remoteExec ["hint", _requester];
        };
        private _pos = _rec get "pos";
        private _r   = _rec get "radius";
        switch (_order) do {
            case "patrol": { [_grp, _pos, _r]       call STCTI_fnc_orderPatrol; };
            case "attack": { [_grp, _pos, _r * 0.5] call STCTI_fnc_orderAttack; };
            case "defend": { [_grp, _pos, _r * 0.6] call STCTI_fnc_orderDefend; };
            default { [format ["Unknown order %1.", _order]] remoteExec ["hint", _requester]; };
        };
        [format ["%1 ordered to %2 %3.", groupId _grp, _order, _sectorId]] remoteExec ["hint", _requester];
        diag_log format ["[STCTI] HC order: %1 -> %2 %3.", groupId _grp, _order, _sectorId];
    };
};
