// fn_spawnUnit.sqf — [SERVER] params: [_rtype, _kind, _role, _pos, _dir, _grp, _ownerKey] -> Object
// Spawns ONE garrison entity of the given spawn kind and tags it with STCTI_type (= resolverType)
// so the budget meter and recount see it. Returns the principal tagged object (the man, the
// vehicle, or the static — NOT crew). Vehicles are crewed and their crew folded into _grp; statics
// spawn unmanned for now (they still count in the resolver — sector-layout-spec §7). Faction classes
// come from STCTI_FACTION (men/vehicles, by resolverType) and STCTI_STATIC_CLASS (statics, by role).
params ["_rtype", "_kind", "_role", "_pos", "_dir", "_grp", "_ownerKey"];

private _facMap = STCTI_FACTION getOrDefault [_ownerKey, STCTI_FACTION get "enemy"];
private _ent = objNull;

switch (_kind) do {
    case "vehicle": {
        private _cls = _facMap getOrDefault [_rtype, "O_Soldier_F"];
        _ent = createVehicle [_cls, _pos, [], 0, "NONE"];
        _ent setDir _dir;
        _ent setPosATL [_pos select 0, _pos select 1, 0];
        private _crewGrp = createVehicleCrew _ent;
        { [_x] joinSilent _grp; } forEach units _crewGrp;
        deleteGroup _crewGrp;
    };
    case "static": {
        private _scls = (STCTI_STATIC_CLASS getOrDefault [_ownerKey, STCTI_STATIC_CLASS get "enemy"]) getOrDefault [_role, ""];
        if (_scls != "") then {
            _ent = createVehicle [_scls, _pos, [], 0, "NONE"];
            _ent setDir _dir;
            _ent setPosATL [_pos select 0, _pos select 1, 0];
            // TODO: man the static from _grp (follow-up; unmanned still counts in the resolver).
        };
    };
    default {   // infantry
        private _cls    = _facMap getOrDefault [_rtype, "O_Soldier_F"];
        private _before = units _grp;
        private _init   = format ["this setVariable ['STCTI_type', '%1', false]; this setDir %2;", _rtype, _dir];
        _cls createUnit [_pos, _grp, _init, 0.6, "PRIVATE"];
        private _new = (units _grp) - _before;
        if !(_new isEqualTo []) then { _ent = _new select 0; };
    };
};

if (!isNull _ent) then { _ent setVariable ["STCTI_type", _rtype, false]; };
_ent
