# Phase 1 — Vertical Slice: Task Breakdown

**Codename:** STCTI · **Phase goal:** prove the core loop (capture → income → spend → defend) is *fun* before building anything else.
**Exit gate:** in a real play session on Altis, you can take a sector, watch income rise, buy a vehicle with it, and repel a telegraphed enemy attack — and it feels good.

This includes the minimal **Phase 0** plumbing the slice can't run without. Everything is built in strict dependency order: each task depends only on tasks above it.

---

## Scope discipline — what's deliberately *fake* in the slice

Build the loop, not the framework. These are stubbed/hardcoded now and replaced in later phases:

| Concern | Phase 1 (fake) | Replaced by |
|---|---|---|
| Sectors | 3–4 **hand-placed** in code | Phase 3 (data-driven `CfgSTCTISectors`) |
| Garrisons | **Always spawned**, no caching | Phase 2 (virtualization) |
| Garage | **One or two hardcoded** vehicles, flat price | Phase 3 (unlock-gated catalog) |
| Enemy AI | **One dumb** timer attack, infantry only | Phase 4 (aggression + combined arms) |
| Resources | All four tick, but only **money** is spent | Phases 3–4 (manpower/fuel/ammo sinks) |
| Persistence | **None** — state resets on restart | Phase 6 |
| Faction map | **Minimal** (riflemen only) | Phase 3 (full role map) |

Do **not** gold-plate any of these now. The only question Phase 1 answers is "is it fun?".

---

## Dependency order (build top to bottom)

```
A. Foundation      init.sqf → initState → ledger (addRes / canAfford / spend)
B. Sync + HUD      pushHUD → updateHUD (client) → initHUD (client)
C. Sectors         registerSector → updateSectorMarker → setSectorOwner
                   → spawnSectorGarrison → updateSectorCapture → initSectors
D. Economy         economyTick
E. Garage          serverPurchase → requestPurchase → garage action
F. Enemy           launchAttack → directorTick
G. Bootstrap       startManagers → initServer.sqf → initPlayerLocal.sqf → description.ext
```

Convention: all functions are tagged `STCTI_fnc_*` via `CfgFunctions`. Each stub notes **locality** — `[SERVER]` runs only on the server (authority), `[CLIENT]` runs where a player is, `[GLOBAL]` is defined everywhere.

---

## A. Foundation

### A1 — `init.sqf` (constants) `[GLOBAL]`
Shared constants, event names, intervals, minimal faction map. No dependencies.

```sqf
// init.sqf — runs on every machine, first
STCTI_TAG = "STCTI";

// Event names (CBA events)
STCTI_EV_SECTOR_CAPTURED = "STCTI_SectorCaptured"; // args: [sectorId, newOwner]
STCTI_EV_RESOURCES_CHANGED = "STCTI_ResourcesChanged"; // args: [resourcesHashMap]
STCTI_EV_ATTACK_INBOUND  = "STCTI_AttackInbound";  // args: [sectorId]

// Tunables (slice values — tune by feel)
STCTI_ECONOMY_INTERVAL = 60;   // economy tick seconds
STCTI_CAPTURE_INTERVAL = 2;    // sector presence check seconds
STCTI_CAPTURE_RATE     = 0.10; // capture progress per check when uncontested
STCTI_ATTACK_MIN       = 600;  // min seconds between enemy attacks
STCTI_ATTACK_MAX       = 900;  // max seconds
STCTI_ATTACK_WARNING   = 60;   // warning lead time

// Minimal faction map (slice: riflemen only)
STCTI_FACTION_ENEMY = createHashMapFromArray [
    ["riflemen", ["O_Soldier_F", "O_Soldier_GL_F", "O_Soldier_AR_F"]]
];
STCTI_SIDE_ENEMY  = east;
STCTI_SIDE_PLAYER = west;
```

### A2 — `STCTI_fnc_initState` `[SERVER]`
Builds the single world-state spine. Depends: A1.

```sqf
// initState.sqf — call once, server only
// Returns: nothing (sets global STCTI_state)
if (!isServer) exitWith {};

STCTI_state = createHashMapFromArray [
    ["resources", createHashMapFromArray [
        ["money", 5000], ["manpower", 50], ["fuel", 2000], ["ammo", 2000]
    ]],
    ["sectors", createHashMap]   // sectorId -> sector record
];
```

### A3 — Ledger: `STCTI_fnc_addRes`, `STCTI_fnc_canAfford`, `STCTI_fnc_spend` `[SERVER]`
Server-authoritative resource access. Depends: A2. These are trivial enough to finish now.

```sqf
// addRes.sqf — params: [resKey, amount]  (amount may be negative)
params ["_key", "_amt"];
private _res = STCTI_state get "resources";
_res set [_key, (_res getOrDefault [_key, 0]) + _amt];
[STCTI_EV_RESOURCES_CHANGED, [_res]] call CBA_fnc_serverEvent; // push to clients (see B1)

// canAfford.sqf — params: [resKey, amount] -> Bool
params ["_key", "_amt"];
((STCTI_state get "resources") getOrDefault [_key, 0]) >= _amt

// spend.sqf — params: [resKey, amount] -> Bool (true if charged)
// THE choke point for all spending. Validate, then debit.
params ["_key", "_amt"];
if !([_key, _amt] call STCTI_fnc_canAfford) exitWith { false };
[_key, -_amt] call STCTI_fnc_addRes;
true
```

---

## B. Sync + HUD

### B1 — `STCTI_fnc_updateHUD` `[CLIENT]`
Renders the four resource numbers. Subscribes to `RESOURCES_CHANGED`. Depends: A1.

```sqf
// updateHUD.sqf — params: [resourcesHashMap]  (CBA event handler on clients)
params ["_res"];
// TODO: write _res values into the HUD controls created by initHUD
// e.g. (uiNamespace getVariable "STCTI_hud_money") ctrlSetText str (_res get "money");
```

### B2 — `STCTI_fnc_initHUD` `[CLIENT]`
Creates the HUD once on the local player; registers B1 as the event handler. Depends: B1.

```sqf
// initHUD.sqf — call from initPlayerLocal
if (!hasInterface) exitWith {};
// TODO: create a minimal HUD (RscTitles or ctrlCreate) with 4 text fields
// Store control refs in uiNamespace for updateHUD to find.
[STCTI_EV_RESOURCES_CHANGED, { _this call STCTI_fnc_updateHUD }] call CBA_fnc_addEventHandler;
```

> Slice shortcut: a `systemChat`/`hint` of the four numbers is a legitimate stand-in if you want to defer real UI. The loop doesn't need pretty — it needs *visible feedback*.

---

## C. Sectors

### C1 — `STCTI_fnc_registerSector` `[SERVER]`
Creates a sector record + map marker, stores it in state. Depends: A2.

```sqf
// registerSector.sqf — params: [id, type, pos, radius, incomeArray]
params ["_id", "_type", "_pos", "_radius", ["_income", []]];
private _rec = createHashMapFromArray [
    ["id", _id], ["type", _type], ["pos", _pos], ["radius", _radius],
    ["owner", "enemy"], ["captureProgress", 0],
    ["income", createHashMapFromArray _income],
    ["garrison", []], ["spawned", false]
];
(STCTI_state get "sectors") set [_id, _rec];
// TODO: create a map marker named ("mk_" + _id); colour via updateSectorMarker
[_id] call STCTI_fnc_updateSectorMarker;
```

### C2 — `STCTI_fnc_updateSectorMarker` `[GLOBAL]`
Colours the marker by owner. Depends: C1 (marker exists).

```sqf
// updateSectorMarker.sqf — params: [id]
params ["_id"];
private _rec = (STCTI_state get "sectors") get _id;
private _colour = switch (_rec get "owner") do {
    case "player": { "ColorBLUFOR" };
    case "enemy":  { "ColorOPFOR" };
    default        { "ColorYellow" }; // contested
};
("mk_" + _id) setMarkerColor _colour;
```

### C3 — `STCTI_fnc_setSectorOwner` `[SERVER]`
Flips ownership and fires the capture event. The single mutation point for ownership. Depends: C1, C2.

```sqf
// setSectorOwner.sqf — params: [id, newOwner]
params ["_id", "_owner"];
private _rec = (STCTI_state get "sectors") get _id;
if ((_rec get "owner") isEqualTo _owner) exitWith {};
_rec set ["owner", _owner];
[_id] call STCTI_fnc_updateSectorMarker;
[STCTI_EV_SECTOR_CAPTURED, [_id, _owner]] call CBA_fnc_serverEvent;
```

### C4 — `STCTI_fnc_spawnSectorGarrison` `[SERVER]`
Spawns a dumb enemy infantry garrison at a sector (always-on in the slice). Depends: A1.

```sqf
// spawnSectorGarrison.sqf — params: [id, count]
params ["_id", ["_count", 6]];
private _rec = (STCTI_state get "sectors") get _id;
if (_rec get "spawned") exitWith {};
private _pool = STCTI_FACTION_ENEMY get "riflemen";
private _grp = createGroup [STCTI_SIDE_ENEMY, true];
for "_i" from 1 to _count do {
    (selectRandom _pool) createUnit [_rec get "pos", _grp, "", 1, "PRIVATE"];
};
// TODO: light defensive waypoints around the sector centre
_rec set ["garrison", units _grp];
_rec set ["spawned", true];
```

### C5 — `STCTI_fnc_updateSectorCapture` `[SERVER]`
Per-tick presence check → progress → flip via C3. Depends: C3.

```sqf
// updateSectorCapture.sqf — params: [id]  (called each capture tick per sector)
params ["_id"];
private _rec = (STCTI_state get "sectors") get _id;
private _pos = _rec get "pos";
private _r   = _rec get "radius";
private _playersNear = ({ side _x == STCTI_SIDE_PLAYER && alive _x } count (_pos nearEntities ["Man", _r])) > 0;
private _enemyNear    = ({ side _x == STCTI_SIDE_ENEMY  && alive _x } count (_pos nearEntities ["Man", _r])) > 0;

if (_playersNear && !_enemyNear) then {
    private _p = (_rec get "captureProgress") + STCTI_CAPTURE_RATE;
    _rec set ["captureProgress", _p min 1];
    if (_p >= 1 && {(_rec get "owner") != "player"}) then {
        [_id, "player"] call STCTI_fnc_setSectorOwner;
    };
};
// TODO (later): enemy retake when only enemy present — open question in design doc §15
```

### C6 — `STCTI_fnc_initSectors` `[SERVER]`
Hand-places the 3–4 slice sectors. Depends: C1, C4.

```sqf
// initSectors.sqf — server, called once after initState
{
    _x params ["_id", "_type", "_pos", "_radius", "_income"];
    [_id, _type, _pos, _radius, _income] call STCTI_fnc_registerSector;
    [_id] call STCTI_fnc_spawnSectorGarrison;
} forEach [
    // id, type, position, captureRadius, income
    ["kavala",  "town",          [3500,13200,0], 200, [["money",50],["manpower",2]]],
    ["airfield","military",       [23100,18800,0],300, [["money",30]]],
    ["fueldepot","resource_fuel", [9200,15500,0], 200, [["fuel",40]]]
];
```

---

## D. Economy

### D1 — `STCTI_fnc_economyTick` `[SERVER]`
Sums income from player-owned sectors, credits the ledger (which auto-pushes the HUD via A3). Depends: A3, C-tier.

```sqf
// economyTick.sqf — server, called every STCTI_ECONOMY_INTERVAL seconds
{
    private _rec = _y;
    if ((_rec get "owner") isEqualTo "player") then {
        {
            [_x, _y] call STCTI_fnc_addRes; // _x = resKey, _y = amount
        } forEach (_rec get "income");
    };
} forEach (STCTI_state get "sectors");
```

---

## E. Garage (minimal)

### E1 — `STCTI_fnc_serverPurchase` `[SERVER]`
Validates spend, spawns the vehicle. The authority side. Depends: A3.

```sqf
// serverPurchase.sqf — params: [classname, price, spawnPos, requester]
params ["_class", "_price", "_pos", "_requester"];
if !(["money", _price] call STCTI_fnc_spend) exitWith {
    ["Not enough money."] remoteExec ["hint", _requester]; // feedback
};
private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
// TODO (Phase 3): register into storedVehicles
```

### E2 — `STCTI_fnc_requestPurchase` `[CLIENT]`
Client asks the server to buy. Depends: E1.

```sqf
// requestPurchase.sqf — params: [classname, price]
params ["_class", "_price"];
private _pos = (getPosATL player) getPos [12, getDir player]; // drop in front
[_class, _price, _pos, clientOwner] remoteExec ["STCTI_fnc_serverPurchase", 2]; // 2 = server
```

### E3 — Garage action `[CLIENT]`
Slice version: an `addAction` on the base garage object. No dialog needed yet. Depends: E2. Wired in `initPlayerLocal`.

```sqf
// in initPlayerLocal, on the garage object:
_garageObj addAction ["Buy Hunter (500)", { ["B_MRAP_01_F", 500] call STCTI_fnc_requestPurchase; }];
_garageObj addAction ["Buy Marshall (1500)", { ["B_APC_Wheeled_01_cannon_F", 1500] call STCTI_fnc_requestPurchase; }];
```

---

## F. Enemy (one dumb attack)

### F1 — `STCTI_fnc_launchAttack` `[SERVER]`
Picks a player sector, spawns an infantry squad nearby, orders an assault, fires the warning. Depends: C-tier.

```sqf
// launchAttack.sqf — server
private _targets = (values (STCTI_state get "sectors")) select { (_x get "owner") isEqualTo "player" };
if (_targets isEqualTo []) exitWith {}; // nothing to attack yet
private _target = selectRandom _targets;
private _tpos   = _target get "pos";

// warn the player NOW; spawn after the warning delay
[STCTI_EV_ATTACK_INBOUND, [_target get "id"]] call CBA_fnc_serverEvent;

[{
    params ["_tpos"];
    private _spawn = _tpos getPos [1200, random 360];
    private _grp = [_spawn, STCTI_SIDE_ENEMY, (STCTI_FACTION_ENEMY get "riflemen")] call BIS_fnc_spawnGroup;
    private _wp = _grp addWaypoint [_tpos, 0];
    _wp setWaypointType "SAD";
    _grp setBehaviour "AWARE";
}, [_tpos], STCTI_ATTACK_WARNING] call CBA_fnc_waitAndExecute;
```

### F2 — `STCTI_fnc_directorTick` `[SERVER]`
Dumb scheduler: wait a random interval, launch one attack, repeat. Depends: F1.

```sqf
// directorTick.sqf — server, self-rescheduling
[{
    call STCTI_fnc_launchAttack;
    call STCTI_fnc_directorTick; // reschedule
}, [], STCTI_ATTACK_MIN + random (STCTI_ATTACK_MAX - STCTI_ATTACK_MIN)] call CBA_fnc_waitAndExecute;
```

Also add a client handler for the warning (in `initPlayerLocal`):

```sqf
[STCTI_EV_ATTACK_INBOUND, {
    params ["_id"];
    ["Enemy forces inbound — sector under threat!"] call BIS_fnc_showNotification;
}] call CBA_fnc_addEventHandler;
```

---

## G. Bootstrap & wiring

### G1 — `STCTI_fnc_startManagers` `[SERVER]`
Starts the two recurring loops (capture + economy). Depends: C5, D1.

```sqf
// startManagers.sqf — server
// Capture loop
[{
    { [_x] call STCTI_fnc_updateSectorCapture; } forEach (keys (STCTI_state get "sectors"));
}, STCTI_CAPTURE_INTERVAL] call CBA_fnc_addPerFrameHandler;
// Economy loop
[{ call STCTI_fnc_economyTick; }, STCTI_ECONOMY_INTERVAL] call CBA_fnc_addPerFrameHandler;
```

### G2 — `initServer.sqf` `[SERVER]`
```sqf
call STCTI_fnc_initState;
call STCTI_fnc_initSectors;
call STCTI_fnc_startManagers;
call STCTI_fnc_directorTick;
```

### G3 — `initPlayerLocal.sqf` `[CLIENT]`
```sqf
call STCTI_fnc_initHUD;
// garage actions (E3) + attack-warning handler (F2) go here
// push current resources to the joining client once:
if (isServer) then { [STCTI_EV_RESOURCES_CHANGED, [STCTI_state get "resources"]] call CBA_fnc_serverEvent; };
```

### G4 — `description.ext` (CfgFunctions)
```cpp
class CfgFunctions {
    class STCTI {
        class core {
            file = "functions\core";
            class initState {};
            class addRes {};
            class canAfford {};
            class spend {};
            class startManagers {};
        };
        class sectors {
            file = "functions\sectors";
            class registerSector {};
            class updateSectorMarker {};
            class setSectorOwner {};
            class spawnSectorGarrison {};
            class updateSectorCapture {};
            class initSectors {};
        };
        class economy { file = "functions\economy"; class economyTick {}; };
        class garage {
            file = "functions\garage";
            class serverPurchase {};
            class requestPurchase {};
        };
        class ai { file = "functions\ai"; class launchAttack {}; class directorTick {}; };
        class ui { file = "functions\ui"; class initHUD {}; class updateHUD {}; };
    };
};
```

---

## Verification — proving the exit gate

Run these in order; each maps to one quarter of the loop:

1. **Income** — start mission, note money. Capture `kavala` (stand in it until the marker turns blue). Within ~1 minute the economy tick should credit +50 money. ✅ *capture → income*
2. **Spend** — walk to the base garage, buy the Hunter. Money drops by 500, a Hunter spawns. ✅ *income → spend*
3. **Defend** — wait (or shorten `STCTI_ATTACK_MIN` to ~30s for testing). A warning fires, then an enemy squad assaults a player sector. Repel it. ✅ *spend → defend*
4. **Feel** — do all of the above for 20–30 minutes. **Is it fun?** This is the only judgement that matters. Note what's boring or annoying — that's your Phase 2+ backlog.

---

## Definition of done (Phase 1)

- [ ] State spine initializes server-side; resources visible on the client HUD.
- [ ] 3–4 sectors registered, markers coloured by owner.
- [ ] Standing in an uncontested enemy sector captures it; marker flips; `SectorCaptured` fires.
- [ ] Economy tick credits income only from player-owned sectors; HUD updates.
- [ ] Garage purchase debits money server-side and spawns a vehicle; insufficient funds is handled.
- [ ] Director launches a telegraphed infantry attack on a player sector on a randomized timer.
- [ ] **Go/no-go call made:** is the core loop fun? Documented notes either way.

> If the loop is fun → proceed to Phase 2 (virtualization). If not → the cheapest moment to redesign is right now, before any of the fake parts become real.
