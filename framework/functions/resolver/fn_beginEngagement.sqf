// fn_beginEngagement.sqf — [SERVER] params:
//   [_sectorId, _attacker, _defender, _attackerOwner, _defenderOwner, _defBonus(optional)]
// Registers a contested, unobserved sector with the resolver. _attacker/_defender are
// force HashMaps (typeId -> count). _attackerOwner/_defenderOwner are "player"|"enemy" so
// the resolver knows who captures the sector if the defender routs. _defBonus defaults to
// the sector type's terrain edge. Returns the engagement record. See spec §2.
params ["_sectorId", "_att", "_def", "_attOwner", "_defOwner", ["_defBonus", -1]];
if (!isServer) exitWith {};

if (_defBonus < 0) then {
    private _rec = (STCTI_state get "sectors") get _sectorId;
    private _type = if (isNil "_rec") then { "town" } else { _rec get "type" };
    _defBonus = STCTI_DEFBONUS getOrDefault [_type, 0.15];
};

private _eng = createHashMapFromArray [
    ["sectorId", _sectorId],
    ["attacker", _att],
    ["defender", _def],
    ["attackerOwner", _attOwner],
    ["defenderOwner", _defOwner],
    ["defBonus", _defBonus],
    ["startA", [_att] call STCTI_fnc_forceStrength],   // raw Sraw at start; break ratio anchors here
    ["startD", [_def] call STCTI_fnc_forceStrength],
    ["accA", 0],
    ["accD", 0],
    ["ticks", 0],
    ["paused", false],
    ["done", false],
    ["spawned", false],   // live-units state (virtualization handoff)
    ["groups", []]        // [attackerGroup, defenderGroup] while spawned
];
STCTI_engagements set [_sectorId, _eng];
diag_log format ["[STCTI] Engagement begun at %1: A=%2 (Sraw %3) vs D=%4 (Sraw %5)",
    _sectorId, _att, _eng get "startA", _def, _eng get "startD"];

// If a player is already watching, hand off to live immediately so there's no abstract gap
// while the manager's next tick comes around; otherwise it resolves abstractly until observed.
if ([_sectorId] call STCTI_fnc_isSectorObserved) then { _eng call STCTI_fnc_spawnEngagement; };
_eng
