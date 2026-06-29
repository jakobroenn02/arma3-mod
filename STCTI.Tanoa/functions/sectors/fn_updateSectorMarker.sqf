// fn_updateSectorMarker.sqf — [GLOBAL] params: [id]. Colours the marker by owner. See §C2.
params ["_id"];
private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith {};

private _colour = switch (_rec get "owner") do {
    case "player": { "ColorBLUFOR" };
    case "enemy":  { "ColorOPFOR" };
    default        { "ColorYellow" }; // contested
};
private _mName = "mk_" + _id;
_mName setMarkerColor _colour;
(_mName + "_dot") setMarkerColor _colour;
