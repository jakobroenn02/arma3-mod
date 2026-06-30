// fn_unitAttr.sqf — [GLOBAL] params: [_typeId, _attr] -> Number|String
// Reads one attribute of a unit type from CfgSTCTIUnitTypes (in description.ext).
// Falls back to sane defaults for an unknown type so the resolver never errors out.
// See abstract-combat-resolution-spec.md §2.
params ["_type", "_attr"];

private _cls = missionConfigFile >> "CfgSTCTIUnitTypes" >> _type;
if (!isClass _cls) exitWith {
    switch (_attr) do {
        case "category":   { "infantry" };
        case "armorClass": { "soft" };
        case "cp":         { 1 };
        default            { 0 };
    };
};

switch (_attr) do {
    case "category":   { getText   (_cls >> "category") };
    case "armorClass": { getText   (_cls >> "armorClass") };
    default            { getNumber (_cls >> _attr) };
};
