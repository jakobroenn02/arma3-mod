// fn_garagePlace.sqf — [CLIENT] params: [_class]. Crosshair ghost placement. The ghost follows
// the player's look point (screenToWorld centre), so full freelook and movement work while
// placing; it clamps to STCTI_GARAGE_RADIUS around the garage flag. Confirm/rotate/cancel are
// KEYBOARD keys on display 46: keyboard events can be consumed there (returning true blocks the
// engine default), but mouse buttons cannot — an LMB confirm always also fires the weapon, and
// the cursor-display alternative freezes the camera. Hence: Q/E rotate, Space places, Esc
// cancels. Instructions are a static bar on display 46 for the whole placement — not a popup.
if (!hasInterface) exitWith {};
disableSerialization;
params ["_class", ["_mode", "buy"], ["_storedIdx", -1]];   // "buy" = purchase, "retrieve" = take out (idx = which stored entry)
if (!isNil "STCTI_placeGhost") exitWith {};   // already placing something
STCTI_placeStoredIdx = _storedIdx;

// Label + cost for the instruction bar only — the server re-validates both on purchase (§E1).
private _entry = STCTI_garageCatalog select { (_x select 1) isEqualTo _class };
private _price = if (_entry isEqualTo []) then { 0 } else { (_entry select 0) select 2 };
private _fuelC = if (_entry isEqualTo []) then { 0 } else { (_entry select 0) param [4, 0] };
private _name  = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
private _cost  = if (_mode isEqualTo "retrieve") then { "from garage" } else {
    format ["%1 money", _price] + (if (_fuelC > 0) then { format [" + %1 fuel", _fuelC] } else { "" })
};
STCTI_placeMode = _mode;

private _p0 = screenToWorld [0.5, 0.5];
if (count _p0 < 2) then { _p0 = getPosATL player; };

STCTI_placeClass = _class;
STCTI_placeDir   = getDir player;
STCTI_placeGhost = _class createVehicleLocal _p0;
STCTI_placeGhost enableSimulation false;
STCTI_placeGhost allowDamage false;

// Static instruction bar, bottom-centre, on the mission display (like fn_initHUD). Two
// pre-parsed variants so the PFH can swap them when the spot becomes (in)valid;
// STCTI_placeBlocked gates the Space confirm.
private _controlsLine = "<t align='center' size='0.9' color='#cccccc'>Look: position   Q/E: rotate   Space: place   Esc: cancel</t>";
STCTI_placeHintOk = parseText format [
    "<t align='center' size='1.1' shadow='1'>Placing %1 — <t color='#7ec8ff'>%2</t></t><br/>%3",
    _name, _cost, _controlsLine
];
STCTI_placeIsShip = _class isKindOf "Ship";   // boats need water; everything else needs land
STCTI_placeHintBad = parseText format [
    "<t align='center' size='1.1' shadow='1' color='#ff6a6a'>Cannot place %1 here (%2)</t><br/>%3",
    _name, ["water", "needs water"] select STCTI_placeIsShip, _controlsLine
];
STCTI_placeBlocked = false;

private _dsp = findDisplay 46;
private _hw = 0.44 * safezoneW;
private _hint = _dsp ctrlCreate ["RscStructuredText", -1];
_hint ctrlSetPosition [safezoneX + (safezoneW - _hw) / 2, safezoneY + safezoneH - 0.13 * safezoneH, _hw, 0.10 * safezoneH];
_hint ctrlSetBackgroundColor [0, 0, 0, 0.55];
_hint ctrlSetStructuredText STCTI_placeHintOk;
_hint ctrlCommit 0;
uiNamespace setVariable ["STCTI_placeHint", _hint];

// Finish: tear down PFH + key EH + hint + ghost; if confirmed, buy at the ghost's transform.
// Idempotent (guarded on STCTI_placeGhost) so double-triggering is harmless.
STCTI_placeFinish = {
    params ["_confirm"];
    if (isNil "STCTI_placeGhost") exitWith {};
    [STCTI_placePFH] call CBA_fnc_removePerFrameHandler;
    (findDisplay 46) displayRemoveEventHandler ["KeyDown", STCTI_placeEHkey];
    private _hint = uiNamespace getVariable ["STCTI_placeHint", controlNull];
    if (!isNull _hint) then { ctrlDelete _hint; };
    uiNamespace setVariable ["STCTI_placeHint", controlNull];
    private _pos = getPosATL STCTI_placeGhost;
    private _dir = STCTI_placeDir;
    private _cls = STCTI_placeClass;
    deleteVehicle STCTI_placeGhost;
    STCTI_placeGhost = nil;
    if (_confirm) then {
        if (STCTI_placeMode isEqualTo "retrieve") then {
            [_cls, _pos, _dir, STCTI_placeStoredIdx] call STCTI_fnc_requestRetrieve;
        } else {
            [_cls, _pos, _dir] call STCTI_fnc_requestPurchase;
        };
    };
};

// Per-frame: ghost under the look-point, clamped to the garage radius, flat on the surface.
STCTI_placePFH = [{
    if (isNil "STCTI_placeGhost") exitWith {};
    private _p = screenToWorld [0.5, 0.5];
    if (count _p < 2) exitWith {};   // looking at the sky — keep the last valid spot
    if (!isNil "STCTI_garage" && {!isNull STCTI_garage}) then {
        private _gPos = getPosATL STCTI_garage;
        if (_p distance2D _gPos > STCTI_GARAGE_RADIUS) then {
            _p = _gPos getPos [STCTI_GARAGE_RADIUS, _gPos getDir _p];
        };
    };
    if (STCTI_placeIsShip) then {
        STCTI_placeGhost setPos [_p select 0, _p select 1, 0];   // AGL — floats at the sea surface
    } else {
        STCTI_placeGhost setPosATL [_p select 0, _p select 1, 0];
        STCTI_placeGhost setVectorUp (surfaceNormal _p);
    };
    STCTI_placeGhost setDir STCTI_placeDir;
    // Valid-spot check; swap the hint only when the state flips (parseText is not free).
    private _blocked = if (STCTI_placeIsShip) then { !surfaceIsWater _p } else { surfaceIsWater _p };
    if (_blocked isNotEqualTo STCTI_placeBlocked) then {
        STCTI_placeBlocked = _blocked;
        private _hint = uiNamespace getVariable ["STCTI_placeHint", controlNull];
        if (!isNull _hint) then {
            _hint ctrlSetStructuredText (if (_blocked) then { STCTI_placeHintBad } else { STCTI_placeHintOk });
        };
    };
}, 0] call CBA_fnc_addPerFrameHandler;

// DIK codes: 1 = Esc, 16 = Q, 18 = E, 57 = Space. Returning true consumes the key, so
// Space does not also trigger its default action and Esc does not open the pause menu.
// Q/E repeat while held, giving continuous rotation (lean is unavailable during placement).
STCTI_placeEHkey = _dsp displayAddEventHandler ["KeyDown", {
    params ["", "_key"];
    switch (_key) do {
        case 1:  { [false] call STCTI_placeFinish; true };
        case 57: { if (!STCTI_placeBlocked) then { [true] call STCTI_placeFinish; }; true };
        case 16: { STCTI_placeDir = (STCTI_placeDir - 5) % 360; true };
        case 18: { STCTI_placeDir = (STCTI_placeDir + 5) % 360; true };
        default  { false };
    };
}];
