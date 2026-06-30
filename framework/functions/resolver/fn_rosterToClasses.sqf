// fn_rosterToClasses.sqf — [GLOBAL] params: [_roster] -> Array of classnames
// Expands an abstract force (HashMap typeId -> count) into a flat list of real unit
// classnames for live spawning, via the STCTI_TYPE_CLASS faction map. The expanded list is
// the same composition the resolver fights abstractly, so live and abstract attacks have
// matching strength (required for the eventual spawn/despawn handoff). See spec §7.
params ["_roster"];

private _classes = [];
{
    private _cls = STCTI_TYPE_CLASS getOrDefault [_x, "O_Soldier_F"];
    for "_i" from 1 to _y do { _classes pushBack _cls; };
} forEach _roster;

_classes
