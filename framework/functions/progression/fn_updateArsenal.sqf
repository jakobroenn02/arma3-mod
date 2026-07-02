// fn_updateArsenal.sqf — [SERVER] no params. Whitelists the base arsenal box (STCTI_arsenalBox)
// from the player faction's arsenal tiers vs the current unlock set (design §Phase-3: "unlock
// flags wired to the garage/arsenal"). Each tier names UNIT classes; their config gear (weapons,
// magazines, linked items, uniform, backpack) becomes the whitelist — so the arsenal always
// matches what the faction's own infantry carry, and capturing e.g. the airfield adds the pilot
// kit. Additive and idempotent: unlocks never revoke, so re-running just re-adds the same items
// (the BIS virtual-cargo functions de-duplicate). Called at base placement and on each unlock.
if (!isServer) exitWith {};
if (isNil "STCTI_arsenalBox" || {isNull STCTI_arsenalBox}) exitWith {};

private _tiers = (STCTI_FACTION_POOL get STCTI_PLAYER_FACTION) getOrDefault ["arsenalUnits", createHashMap];
private _weapons = [];
private _mags    = [];
private _items   = [];
private _packs   = [];

{
    // _x = unlockId, _y = unit classes of that tier
    if (_x isEqualTo "" || {_x in STCTI_unlocks}) then {
        {
            private _cfg = configFile >> "CfgVehicles" >> _x;
            if (isClass _cfg) then {
                _weapons append ((getArray (_cfg >> "weapons")) - ["Throw", "Put"]);
                _mags    append (getArray (_cfg >> "magazines"));
                _items   append (getArray (_cfg >> "linkedItems"));
                _items   append (getArray (_cfg >> "items"));
                private _u = getText (_cfg >> "uniformClass");
                if (_u != "") then { _items pushBack _u; };
                private _b = getText (_cfg >> "backpack");
                if (_b != "") then { _packs pushBack _b; };
            };
        } forEach _y;
    };
} forEach _tiers;

_weapons = _weapons arrayIntersect _weapons;   // arrayIntersect self = dedupe
_mags    = _mags    arrayIntersect _mags;
_items   = _items   arrayIntersect _items;
_packs   = _packs   arrayIntersect _packs;

[STCTI_arsenalBox, _weapons, true] call BIS_fnc_addVirtualWeaponCargo;
[STCTI_arsenalBox, _mags,    true] call BIS_fnc_addVirtualMagazineCargo;
[STCTI_arsenalBox, _items,   true] call BIS_fnc_addVirtualItemCargo;
[STCTI_arsenalBox, _packs,   true] call BIS_fnc_addVirtualBackpackCargo;

diag_log format ["[STCTI] Arsenal whitelist updated (%1): %2 weapons, %3 mags, %4 items, %5 packs.",
    STCTI_PLAYER_FACTION, count _weapons, count _mags, count _items, count _packs];
