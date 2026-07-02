# Sector Layout & Authoring Spec

**Codename:** STCTI · **Plugs into:** Phase 3 (data-driven sectors) · **Status:** Draft v0.1
**Owner subsystems:** Sector manager, Abstract combat resolver, Light defensive placement (§6.1)

How a designer defines what defends a sector — vehicles, static weapons, infantry posts — and
how that one definition feeds **three** consumers without any of them being authored twice.

---

## 0. Two invariants (read these first)

1. **Positions are relative, never absolute.** A base is authored once as a set of offsets
   from a centre, then instantiated at any sector's `pos` + `heading`. Moving or re-using a
   base is one number change. Absolute map coordinates are *banned* in layout data — they break
   reuse and are incompatible with auto-detected town sectors (which have no hand-authored point).

2. **The layout is the single source of truth.** The same slot list produces:
   - **live geometry** when a sector is observed and spawns real units (`fn_layoutToWorld`);
   - **the abstract resolver's composition** when the sector is fought over unobserved
     (`fn_layoutComposition` — a derived tally, *not* a separately-typed `defenderForce`);
   - **the §6.1 hardening menu** — an unfilled static slot *is* a build option.

   Never restate composition as a literal. If `military_small` contains an `mbt` slot and three
   `inf_post` slots, then its resolver force *is* `{mbt:1, rifleman:3}` — counted from the layout,
   never hand-typed alongside it. This is what stops the live spawn and the resolver from silently
   disagreeing.

---

## 1. Data model

### 1.1 Slot

A slot is one emplacement, authored in **polar** offsets so it rotates with the base:

```sqf
// [ role, distFromCentre, bearingFromCentre, facingOffset ]
//   distFromCentre   metres from sector centre
//   bearingFromCentre degrees, RELATIVE to base heading (0 = base's "forward")
//   facingOffset      unit/weapon facing, degrees RELATIVE to base heading
["static_he", 22, 40, 40]
```

### 1.2 Layout archetypes (`STCTI_LAYOUTS`)

A layout is an ordered list of slots, keyed by an id. Author once, reuse on many sectors:

```sqf
STCTI_LAYOUTS = createHashMapFromArray [
    ["military_small", [
        ["mbt",       18, 200,   0],
        ["static_he", 22,  40,  40],
        ["static_at", 24, 150, 150],
        ["inf_post",  15,  90,  90],
        ["inf_post",  15, 270, 270],
        ["inf_post",  20,   0,   0]
    ]],
    ["fuel_depot", [
        ["static_he", 16,  60,  60],
        ["inf_post",  12, 180, 180],
        ["inf_post",  12,   0,   0]
    ]],
    ["town_light", []]   // towns: no authored slots — see §4
];
```

### 1.3 Role table (`STCTI_ROLES`)

Each role maps to *how it spawns* and *what it counts as* in the resolver. One table is the
faction-abstraction seam (Phase 3 makes the live classes faction-specific; slice may hardcode).

```sqf
// role -> [ spawnKind, resolverType ]
//   spawnKind    : "infantry" | "vehicle" | "static"
//   resolverType : a CfgSTCTIUnitTypes id (rifleman, at_team, mbt, ...) — what this slot
//                  contributes to abstract strength. "" => not counted (pure decoration).
STCTI_ROLES = createHashMapFromArray [
    ["inf_post",  ["infantry", "rifleman"]],
    ["at_post",   ["infantry", "at_team"]],
    ["aa_post",   ["infantry", "aa_team"]],
    ["mrap",      ["vehicle",  "mrap"]],
    ["ifv",       ["vehicle",  "ifv"]],
    ["mbt",       ["vehicle",  "mbt"]],
    ["static_he", ["static",   "rifleman"]],   // resolverType values are TUNABLE — pick the
    ["static_at", ["static",   "at_team"]],    // CfgSTCTIUnitTypes id that best represents the
    ["static_aa", ["static",   "aa_team"]]     // slot's combat weight; revisit during balance.
];

// Live classnames. Vehicles/infantry resolve via the existing faction map keyed by resolverType;
// statics need their own (a static weapon is an object, not a man). Extend per Phase 3 faction work.
STCTI_STATIC_CLASS = createHashMapFromArray [
    ["static_he", "O_HMG_01_high_F"],
    ["static_at", "O_static_AT_F"],
    ["static_aa", "O_static_AA_F"]
];
```

### 1.4 Authored sector config (`CfgSTCTISectors`)

Strategic sectors (military / resource / factory) are authored data, per map. This **replaces**
the hand-placed `fn_initSectors` table for those sectors. (Towns are auto-detected — §4.) Note
`layout` (was `garrison` in the design-doc sketch) and the new `heading`:

```cpp
class CfgSTCTISectors {
    class Altis {
        class airfield {
            type          = "military";
            position[]    = {23100, 18800, 0};
            heading       = 135;            // base "forward" bearing; layout rotates to this
            captureRadius = 350;
            income[]      = {};
            layout        = "military_small";
            grantsUnlock  = "fixed_wing";
        };
        class fueldepot {
            type          = "resource_fuel";
            position[]    = {9200, 15500, 0};
            heading       = 0;
            captureRadius = 200;
            income[]      = {{"fuel", 40}};
            layout        = "fuel_depot";
            grantsUnlock  = "";
        };
    };
};
```

The runtime sector record (from `fn_registerSector`) gains two fields: `["heading", N]` and
`["layout", "id"]`. Everything downstream reads them off the record.

---

## 2. Functions to build

### 2.1 `STCTI_fnc_layoutToWorld` `[GLOBAL]`
Offsets → world space. The geometry primitive both spawn and (later) hardening use.

```sqf
// params: [_centre, _heading, _layoutId] -> [[role, worldPos, worldDir], ...]
params ["_centre", "_heading", "_layoutId"];
(STCTI_LAYOUTS getOrDefault [_layoutId, []]) apply {
    _x params ["_role", "_dist", "_bear", "_face"];
    [_role, [_centre, _dist, _heading + _bear] call BIS_fnc_relPos, _heading + _face]
};
```

### 2.2 `STCTI_fnc_layoutComposition` `[GLOBAL]`
Layout id → resolver force HashMap. **This is the single-source-of-truth derivation.** The
resolver's enemy `defenderForce` for a base comes from here, never from a hand-typed literal.

```sqf
// params: [_layoutId] -> HashMap (resolverTypeId -> count)
params ["_layoutId"];
private _force = createHashMap;
{
    private _role = _x select 0;
    (STCTI_ROLES getOrDefault [_role, ["", ""]]) params ["_kind", "_rtype"];
    if (_rtype != "") then { _force set [_rtype, (_force getOrDefault [_rtype, 0]) + 1]; };
} forEach (STCTI_LAYOUTS getOrDefault [_layoutId, []]);
_force
```

### 2.3 `STCTI_fnc_spawnSectorGarrison` `[SERVER]` — rewrite the placement loop
Replace the current `random _r / random 360` scatter with slot-driven placement. Record which
slots got filled (for §6.1). Hand infantry to LAMBS garrison so they occupy nearby buildings.

```sqf
private _layoutId = _rec get "layout";
private _heading  = _rec getOrDefault ["heading", 0];
private _pool     = STCTI_FACTION_ENEMY get "riflemen";        // slice infantry pool
private _grp      = createGroup [STCTI_SIDE_ENEMY, true];
private _filled   = [];

{
    _x params ["_role", "_wpos", "_wdir"];
    (STCTI_ROLES getOrDefault [_role, ["", ""]]) params ["_kind", "_rtype"];
    switch (_kind) do {
        case "infantry": {
            private _u = (selectRandom _pool) createUnit [_wpos, _grp, "", 1, "PRIVATE"];
            _u setDir _wdir;
        };
        case "vehicle": {
            private _cls = STCTI_TYPE_CLASS getOrDefault [_rtype, "O_Soldier_F"];
            private _v = createVehicle [_cls, _wpos, [], 0, "CAN_COLLIDE"];
            _v setDir _wdir;
        };
        case "static": {
            private _cls = STCTI_STATIC_CLASS getOrDefault [_role, ""];
            if (_cls != "") then {
                private _s = createVehicle [_cls, _wpos, [], 0, "CAN_COLLIDE"];
                _s setDir _wdir;
                // TODO: crew the static from _grp so it's manned.
            };
        };
    };
    _filled pushBack _role;
} forEach ([_rec get "pos", _heading, _layoutId] call STCTI_fnc_layoutToWorld);

// LAMBS: let the infantry garrison the sector (buildings + posts) instead of standing still.
[_grp, _rec get "pos", _rec get "radius"] call lambs_wp_fnc_taskGarrison;

_rec set ["garrison", units _grp];
_rec set ["spawned", true];
_rec set ["filledSlots", _filled];
```

### 2.4 `STCTI_fnc_registerSector` `[SERVER]` — derive the enemy garrison
On registration, set the enemy `defenderForce` from the layout (the invariant). Store `heading`
and `layout` on the record. (Player-capture baseline and abstract survivors still overwrite it
later — that's correct; only the *initial enemy* composition is layout-derived.)

```sqf
// after building _rec, before storing:
_rec set ["heading", _heading];
_rec set ["layout",  _layoutId];
_rec set ["defenderForce", [_layoutId] call STCTI_fnc_layoutComposition];
```

### 2.5 `STCTI_fnc_initSectors` `[SERVER]` — one merge point
Both sources flow through the same `fn_registerSector`. The rest of the codebase never knows or
cares which tier a sector came from.

```sqf
// 1) Auto-detect towns (tier 1 — see the detection spec). Default layout + heading.
private _center = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
{
    private _id = text _x;
    private _sz = size _x;
    private _radius = (_sz select 0) max (_sz select 1) max 150;
    [_id, "town", locationPosition _x, _radius, [["money",50],["manpower",2]], 0, "town_light"]
        call STCTI_fnc_registerSector;
} forEach (nearestLocations [_center, ["NameCityCapital","NameCity","NameVillage"], 1e6]);

// 2) Authored strategic sectors from CfgSTCTISectors >> <map>.
private _root = missionConfigFile >> "CfgSTCTISectors" >> worldName;
{
    private _c = _x;
    [ configName _c,
      getText   (_c >> "type"),
      getArray  (_c >> "position"),
      getNumber (_c >> "captureRadius"),
      getArray  (_c >> "income"),
      getNumber (_c >> "heading"),
      getText   (_c >> "layout")
    ] call STCTI_fnc_registerSector;
} forEach (configProperties [_root, "isClass _x", true]);
```

> `fn_registerSector`'s params grow by two (`_heading`, `_layoutId`), both with defaults
> (`["_heading", 0], ["_layoutId", "town_light"]`) so existing callers don't break.

### 2.6 §6.1 hardening (later, but design the data for it now)
The hardening menu offers the layout's **static slots that aren't in `filledSlots`**. Filling one
spawns that static via `fn_layoutToWorld` for that single slot and appends it to `filledSlots`.
No new geometry data — it reuses the same layout. Just flag the empty-slot subset.

---

## 3. Data flow (the whole point on one line)

```
              ┌─ fn_layoutToWorld     → live unit geometry (observed spawn)
layout (id) ──┼─ fn_layoutComposition → resolver force counts (unobserved fight)
              └─ empty static slots   → §6.1 hardening menu options
```

Author the layout once; all three stay in sync by construction.

---

## 4. Towns don't need authored slots

Town garrisons go into buildings, not revetments. Give towns the empty `town_light` layout and let
LAMBS `taskGarrison` populate building positions around the centre at spawn time. If a town needs a
nominal abstract strength while unobserved, either (a) add a couple of `inf_post` slots to
`town_light`, or (b) keep the existing `STCTI_PLAYER_GARRISON`-style baseline for the enemy side.
Prefer (a) so the invariant holds (composition derived from layout).

---

## 5. Authoring workflow — Eden export to relative slots

Designers build the base visually, then export offsets. Place a centre helper (any object) facing
the intended heading, select the emplacement objects, run in the debug console:

```sqf
private _c = getPosATL centreLogic;     // the centre helper
private _h = getDir   centreLogic;      // its facing = base heading
copyToClipboard str ((get3DENSelected "object") apply {
    [ typeOf _x,
      round (_c distance2D (getPosATL _x)),
      round ((_c getDir (getPosATL _x)) - _h),
      round ((getDir _x) - _h) ]
});
```

Output is `[class, dist, bearing, facing]` rows; the designer maps each `class` to a `role` and
pastes into `STCTI_LAYOUTS`. Author visually, store relative.

---

## 6. Acceptance criteria

- [ ] An authored `military` sector spawns its vehicles, statics and infantry posts at the correct
      positions and facings **relative to its `heading`** when observed.
- [ ] Changing only `position` or `heading` in `CfgSTCTISectors` moves/rotates the entire base; no
      other edits needed.
- [ ] The same base attacked **unobserved** hands the resolver a composition whose counts equal what
      would have spawned live (verify: tally `fn_layoutComposition` vs. the live spawn for one base).
- [ ] Auto-detected towns register with `town_light` + heading 0 and still get a sensible garrison
      (LAMBS building occupation).
- [ ] Authored sectors and towns both pass through `fn_registerSector` — no second code path.
- [ ] `defenderForce` for an enemy base is never a hand-typed literal; it's `fn_layoutComposition`.
- [ ] (When §6.1 lands) hardening offers exactly the unfilled `static_*` slots.

---

## 7. Scope discipline (don't gold-plate)

- **No layout editor UI.** Eden + the export snippet is the tool.
- **A handful of roles** is enough for the slice (3 statics, 2–3 vehicles, 2–3 infantry posts).
- **`resolverType` values are tuning knobs**, not gospel — set sane defaults, revisit at balance.
- **Faction abstraction of live classes** is the seam (`STCTI_TYPE_CLASS` / `STCTI_STATIC_CLASS`)
  but may stay slice-hardcoded to one faction until Phase 3 proper.
- **Statics manning/crewing** can be a follow-up; an unmanned static still counts in the resolver.
- This is **base garrison/emplacement data only** — it is *not* the player garage. Garage purchases
  spawn in front of the player and belong to no sector layout; keep the two concerns in separate code.
