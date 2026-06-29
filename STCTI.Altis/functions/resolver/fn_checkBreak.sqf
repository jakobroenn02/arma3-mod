// fn_checkBreak.sqf — [SERVER] params: [_eng] -> "" | "attacker" | "defender"
// A force routs when its current raw Sraw falls below BREAK_THRESHOLD of its start value.
// (Break uses RAW start strength — spec Example A breaks the defender at 0.30·5, not
// 0.30·5.75 — so defBonus affects output only, never the break ratio.) On a rout, resolves
// the sector and flags the engagement done; the resolver PFH removes it after iterating.
// See spec §6.
params ["_eng"];

private _att = _eng get "attacker";
private _def = _eng get "defender";
private _srawA = [_att] call STCTI_fnc_forceStrength;
private _srawD = [_def] call STCTI_fnc_forceStrength;
private _startA = _eng get "startA";
private _startD = _eng get "startD";
private _brA = if (_startA > 0) then { _srawA / _startA } else { 0 };
private _brD = if (_startD > 0) then { _srawD / _startD } else { 0 };

private _routed = "";
if (_srawA <= 0 || _brA < STCTI_BREAK_THRESHOLD) then { _routed = "attacker"; };
if (_srawD <= 0 || _brD < STCTI_BREAK_THRESHOLD) then {
    // If both break the same tick, the weaker (lower ratio) side routs.
    if (_routed isEqualTo "" || {_brD <= _brA}) then { _routed = "defender"; };
};
// Stalemate safeguard: after MAX_TICKS the lower break-ratio side routs.
if (_routed isEqualTo "" && {(_eng get "ticks") >= STCTI_MAX_TICKS}) then {
    _routed = if (_brA < _brD) then { "attacker" } else { "defender" };
};

if (_routed isEqualTo "") exitWith { "" };

private _sectorId = _eng get "sectorId";

switch (_routed) do {
    case "defender": {
        // Attacker takes the sector. Apply a small pursuit loss, then the survivors
        // become the new garrison; ownership flips to whoever attacked.
        private _mA = [_att] call STCTI_fnc_forceMetrics;
        private _mD = [_def] call STCTI_fnc_forceMetrics;
        [_att, STCTI_PURSUIT_LOSS * _startA, _mA, _mD] call STCTI_fnc_applyCasualties;

        [_sectorId, _eng get "attackerOwner"] call STCTI_fnc_setSectorOwner;
        private _rec = (STCTI_state get "sectors") get _sectorId;
        // Surviving attackers become the new garrison (overwrites the baseline set on capture).
        if (!isNil "_rec") then { _rec set ["defenderForce", _att]; };
    };
    case "attacker": {
        // Assault fails; the defender holds. (Surviving attackers as a retreating virtual
        // force is a Phase-2 follow-up — see spec §6 / handoff work.)
    };
};

[STCTI_EV_ENGAGEMENT_RESOLVED, [_sectorId, _routed, _att, _def, _startA, _startD, _eng get "attackerOwner", _eng get "defenderOwner"]] call CBA_fnc_globalEvent;
diag_log format ["[STCTI] Engagement at %1 resolved: %2 routed. Survivors A=%3 D=%4 (ticks %5)",
    _sectorId, _routed, _att, _def, _eng get "ticks"];

_eng set ["done", true];
_routed
