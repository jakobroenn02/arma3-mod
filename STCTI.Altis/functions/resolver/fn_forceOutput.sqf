// fn_forceOutput.sqf — [GLOBAL] params: [_selfMetrics, _enemyMetrics, _isDefender, _defBonus] -> Number
// Combat output Out(F→E) = Sraw(F)·caMult(F)·offMult(F→E)·defMult(F). See spec §3.
// offMult penalises a force for the enemy armor/air share it can't answer.
params ["_self", "_enemy", "_isDef", "_defBonus"];

private _eSraw = _enemy get "sraw";
private _offMult = 1;
if (_eSraw > 0) then {
    private _eArmorCP = _enemy get "armorCP";
    private _eAirCP   = _enemy get "airCP";
    private _fArmor = _eArmorCP / _eSraw;            // enemy's armor share
    private _fAir   = _eAirCP   / _eSraw;            // enemy's air share
    private _armAns = if (_eArmorCP > 0) then { 1 min ((_self get "antiArmorCP") / _eArmorCP) } else { 1 };
    private _airAns = if (_eAirCP   > 0) then { 1 min ((_self get "antiAirCP")   / _eAirCP)   } else { 1 };
    _offMult = (1
        - STCTI_P_ARMOR * _fArmor * (1 - _armAns)
        - STCTI_P_AIR   * _fAir   * (1 - _airAns)) max 0.1 min 1.0;
};

private _defMult = if (_isDef) then { 1 + _defBonus } else { 1 };

(_self get "sraw") * (_self get "caMult") * _offMult * _defMult
