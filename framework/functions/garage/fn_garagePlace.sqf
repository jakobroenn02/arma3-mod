// fn_garagePlace.sqf — [CLIENT] params: [_class]. Antistasi-style ghost placement. A LOCAL,
// simulation-off preview of the vehicle follows where you look; scroll rotates it, LMB confirms
// (the server then spawns the real vehicle at that position/heading), RMB or Esc cancels.
// Uses display-46 event handlers so the click/scroll/Esc are captured (no firing/zoom) while placing.
if (!hasInterface) exitWith {};
params ["_class"];
if (!isNil "STCTI_placeGhost") exitWith {};   // already placing something

private _p0 = screenToWorld [0.5, 0.5];
if (count _p0 < 2) then { _p0 = getPosATL player; };

STCTI_placeClass = _class;
STCTI_placeDir   = getDir player;
STCTI_placeGhost = _class createVehicleLocal _p0;
STCTI_placeGhost enableSimulation false;
STCTI_placeGhost allowDamage false;

// Finish: tear down PFH + EHs + ghost; if confirmed, ask the server to buy at the ghost's transform.
STCTI_placeFinish = {
    params ["_confirm"];
    if (isNil "STCTI_placeGhost") exitWith {};
    [STCTI_placePFH] call CBA_fnc_removePerFrameHandler;
    private _dsp = findDisplay 46;
    _dsp displayRemoveEventHandler ["MouseButtonDown", STCTI_placeEHmouse];
    _dsp displayRemoveEventHandler ["MouseZChanged",   STCTI_placeEHscroll];
    _dsp displayRemoveEventHandler ["KeyDown",         STCTI_placeEHkey];
    private _pos = getPosATL STCTI_placeGhost;
    private _dir = STCTI_placeDir;
    private _cls = STCTI_placeClass;
    deleteVehicle STCTI_placeGhost;
    STCTI_placeGhost = nil;
    if (_confirm) then { [_cls, _pos, _dir] call STCTI_fnc_requestPurchase; };
};

// Per-frame: keep the ghost under the look-point, at the current rotation, sitting on the surface.
STCTI_placePFH = [{
    if (isNil "STCTI_placeGhost") exitWith {};
    private _p = screenToWorld [0.5, 0.5];
    if (count _p >= 2) then {
        STCTI_placeGhost setPosATL [_p select 0, _p select 1, 0];
        STCTI_placeGhost setVectorUp (surfaceNormal _p);
        STCTI_placeGhost setDir STCTI_placeDir;
    };
}, 0] call CBA_fnc_addPerFrameHandler;

private _dsp = findDisplay 46;
STCTI_placeEHmouse = _dsp displayAddEventHandler ["MouseButtonDown", {
    params ["", "_btn"];
    if (_btn isEqualTo 0) then { [true]  call STCTI_placeFinish; };   // LMB = confirm
    if (_btn isEqualTo 1) then { [false] call STCTI_placeFinish; };   // RMB = cancel
    true   // block the default (firing)
}];
STCTI_placeEHscroll = _dsp displayAddEventHandler ["MouseZChanged", {
    params ["", "_scroll"];
    STCTI_placeDir = (STCTI_placeDir + (_scroll * 10)) % 360;
    true   // block default (zoom / action menu)
}];
STCTI_placeEHkey = _dsp displayAddEventHandler ["KeyDown", {
    params ["", "_key"];
    if (_key isEqualTo 1) exitWith { [false] call STCTI_placeFinish; true };   // Esc = cancel
    false
}];

["STCTI_Info", ["Placing — look to position, scroll to rotate, LMB to confirm, RMB/Esc to cancel."]] call BIS_fnc_showNotification;
