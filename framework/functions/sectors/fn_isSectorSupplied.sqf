// fn_isSectorSupplied.sqf — [SERVER] params: [_sectorId] -> Bool
// Supply-line rule: a player sector is supplied while a chain of OWNED, ADJACENT sectors
// (front-line graph) connects it to the HQ beachhead (any owned hqLink sector). BFS over the
// graph, player-owned nodes only. Cut the chain and everything beyond it starves — the
// map-physical logistics the roadmap's Phase 12 asked for, at zero sim cost.
params ["_id"];
if (!STCTI_FRONTLINE || {!STCTI_SUPPLY_RULE}) exitWith { true };

private _sectors = STCTI_state get "sectors";
private _rec = _sectors get _id;
if (isNil "_rec") exitWith { false };
if ((_rec get "owner") isNotEqualTo "player") exitWith { false };
if (_rec getOrDefault ["hqLink", false]) exitWith { true };

private _seen  = [_id];
private _queue = +(_rec getOrDefault ["adjacent", []]);
private _supplied = false;
while { !_supplied && {count _queue > 0} } do {
    private _cur = _queue deleteAt 0;
    if !(_cur in _seen) then {
        _seen pushBack _cur;
        private _o = _sectors get _cur;
        if (!isNil "_o" && {(_o get "owner") isEqualTo "player"}) then {
            if (_o getOrDefault ["hqLink", false]) then {
                _supplied = true;
            } else {
                _queue append (_o getOrDefault ["adjacent", []]);
            };
        };
    };
};
_supplied
