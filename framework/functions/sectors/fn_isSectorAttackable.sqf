// fn_isSectorAttackable.sqf — [SERVER] params: [_sectorId] -> Bool
// The front-line rule (Warlords-style, conventional pacing): a non-player sector can only be
// captured if it touches friendly territory — adjacent (k-nearest graph from fn_initSectors)
// to a player-owned sector, or inside STCTI_FRONT_HQ_RADIUS of the base. Airborne insertion
// deliberately ignores this (paradrops behind the lines are doctrine); ground capture does not.
params ["_id"];
if (!STCTI_FRONTLINE) exitWith { true };

private _rec = (STCTI_state get "sectors") get _id;
if (isNil "_rec") exitWith { false };
if ((_rec get "owner") isEqualTo "player") exitWith { false };   // already ours
if (_rec getOrDefault ["hqLink", false]) exitWith { true };

((_rec getOrDefault ["adjacent", []]) findIf {
    private _o = (STCTI_state get "sectors") get _x;
    !isNil "_o" && {(_o get "owner") isEqualTo "player"}
}) > -1
