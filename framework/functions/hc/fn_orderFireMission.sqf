// fn_orderFireMission.sqf — [SERVER] params: [_sectorId, _requester]
// On-call artillery (HC order): charges STCTI_FIREMISSION_COST (the big ammo sink), then walks
// STCTI_FIREMISSION_SHELLS 155mm impacts across the target sector over ~35 seconds. Abstracted
// base battery — no physical gun to hunt (a counter-battery layer would need one; deliberate
// slice simplification). Works on any sector: softening a frontier target before an assault is
// the intended use.
params ["_sectorId", "_requester"];
if (!isServer) exitWith {};

private _rec = (STCTI_state get "sectors") get _sectorId;
if (isNil "_rec") exitWith { ["Unknown sector."] remoteExec ["hint", _requester]; };
if !(STCTI_FIREMISSION_COST call STCTI_fnc_spendMulti) exitWith {
    private _needs = (STCTI_FIREMISSION_COST apply { format ["%2 %1", _x select 0, _x select 1] }) joinString " + ";
    [format ["Not enough resources (needs %1).", _needs]] remoteExec ["hint", _requester];
};

private _pos = _rec get "pos";
private _r   = (_rec get "radius") * 0.5;
for "_i" from 1 to STCTI_FIREMISSION_SHELLS do {
    [{
        params ["_pos", "_r"];
        private _p = _pos getPos [random _r, random 360];
        private _sh = createVehicle ["Sh_155mm_AMOS", [_p select 0, _p select 1, 250], [], 0, "CAN_COLLIDE"];
        _sh setVelocity [0, 0, -220];
    }, [_pos, _r], 3 + _i * 4 + random 2] call CBA_fnc_waitAndExecute;
};

// Provocation: shelling gets noticed — the director's aggression creeps up per mission.
STCTI_state set ["aggression",
    ((STCTI_state getOrDefault ["aggression", STCTI_AGGRO_START]) + STCTI_FIREMISSION_AGGRO) min STCTI_AGGRO_CAP];

[format ["Fire mission on %1 — splash in 30 seconds, %2 rounds.", _sectorId, STCTI_FIREMISSION_SHELLS]] remoteExec ["hint", _requester];
diag_log format ["[STCTI] Fire mission on %1 by client %2.", _sectorId, _requester];
