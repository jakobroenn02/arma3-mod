// fn_forceMetrics.sqf — [GLOBAL] params: [_force] -> HashMap of derived strength metrics
// One pass over the force's unit types (O(#types)) producing everything the output and
// casualty formulas need: Sraw, armor/air CP, anti-armor/anti-air CP, and the
// combined-arms multiplier. See spec §3.
//
// Capability set for combined arms (caMult): the distinct categories present
// {infantry, armor, air}, PLUS "AT" if any *infantry* type carries dedicated anti-armor
// (antiArmor >= STCTI_CA_AT_MIN) and "AA" likewise for anti-air. This reads riflemen's
// incidental antiArmor (0.10) as below-threshold so it doesn't count as an AT capability,
// and an MBT's antiArmor doesn't grant "AT" because it's armor, not an AT team — which is
// what reproduces caMult=1.05 for a rifle+MBT force in spec Example B.
params ["_force"];

private _sraw = 0;
private _armorCP = 0;
private _airCP = 0;
private _antiArmorCP = 0;
private _antiAirCP = 0;
private _caps = [];

{
    private _t = _x;
    private _n = _y;
    if (_n > 0) then {
        private _cp  = [_t, "cp"]         call STCTI_fnc_unitAttr;
        private _cat = [_t, "category"]   call STCTI_fnc_unitAttr;
        private _ac  = [_t, "armorClass"] call STCTI_fnc_unitAttr;
        private _aa  = [_t, "antiArmor"]  call STCTI_fnc_unitAttr;
        private _av  = [_t, "antiAir"]    call STCTI_fnc_unitAttr;

        _sraw = _sraw + _n * _cp;
        if (_ac in ["armored", "heavy"]) then { _armorCP = _armorCP + _n * _cp; };
        if (_ac isEqualTo "air")          then { _airCP   = _airCP   + _n * _cp; };
        _antiArmorCP = _antiArmorCP + _n * _cp * _aa;
        _antiAirCP   = _antiAirCP   + _n * _cp * _av;

        if !(_cat in _caps) then { _caps pushBack _cat; };
        if (_cat isEqualTo "infantry") then {
            if (_aa >= STCTI_CA_AT_MIN && {!("AT" in _caps)}) then { _caps pushBack "AT"; };
            if (_av >= STCTI_CA_AA_MIN && {!("AA" in _caps)}) then { _caps pushBack "AA"; };
        };
    };
} forEach _force;

// caMult = clamp(1 + CA_STEP·(|caps|−1), 1.0, CA_MAX)
private _caMult = (1 + STCTI_CA_STEP * ((count _caps) - 1)) min STCTI_CA_MAX max 1.0;

createHashMapFromArray [
    ["sraw", _sraw],
    ["armorCP", _armorCP],
    ["airCP", _airCP],
    ["antiArmorCP", _antiArmorCP],
    ["antiAirCP", _antiAirCP],
    ["caMult", _caMult]
]
