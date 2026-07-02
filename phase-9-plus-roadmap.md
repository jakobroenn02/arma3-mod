# STCTI — Phase 9+ Roadmap: Mobility, Procurement, DLC & Sustainment

**Codename:** STCTI · **Engine:** Arma 3 (SQF) · **Status:** Draft v0.1 (handoff)
**Depends on:** Phases 1–8 (shipped) · **Target maps:** Altis, Malden, Tanoa (native), + optional DLC/CDLC extension packs (Phase 11)

This document specs the next block of work: the Antistasi-adjacent feature set (fast travel, expanded vehicles, unlockable hardware categories, weapons, DLC support) **reframed to fit STCTI's conventional-military pillar rather than Antistasi's guerrilla one.** It is written to be executed by the coder without me present. Each phase carries the usual goal / do / exit-gate / risk, a scope table, and locality tags on every function.

---

## 0. Framing — what we are and aren't porting from Antistasi

Antistasi's progression is **scavenging**: unlock a weapon by looting N of it, steal vehicles off the battlefield. That is the mechanical expression of "we started with nothing." STCTI's pillar 1 is the opposite — conventional force, real firepower from turn one, progression makes it *bigger and better*. So we port the **features** but not always the **acquisition model**. The conventional analog to looting is a **procurement + battlefield-capture logistics chain**: same outcome (more gear over time), different fiction, different code.

**Resolved design decision (this pass):** progression is **capture-gated AND procurement-gated**, not capture-only.

- **Capture** unlocks a hardware category *and* grants that site's unique strategic effect (intel, income, the physical spawn point). Cheap, but you have to hold ground.
- **Procurement** buys the *hardware-category unlock only* with resources — no unique effect. Expensive, always available, a deep money/ammo sink.

The important nuance: **procurement never grants the one-of-a-kind effects** (intel scans, the site itself, its income). So a buy path gives you *access to hardware* without trivialising *map control* — capturing a site is still strictly better than buying its catalog. This is the seam that keeps both systems meaningful.

---

## 1. Cross-cutting foundations (build these first — multiple phases depend on them)

These aren't a "phase"; they're shared plumbing. Do them before Phase 9/10 or you'll retrofit.

### 1.1 Travel-node concept `[data]`

STCTI has exactly one base today (`STCTI_BASE_POS` + the arsenal/garage/HC objects). "Base to base" needs a node set that doesn't exist yet.

- Add `travelNode` (Bool) to the **sector record** and to `CfgSTCTISectors` (default: `true` for `town` and `military`, `false` for bare resource depots — tunable per sector).
- HQ is always a node.
- Broadcast the **static** node-id set once at base establish via `publicVariable "STCTI_TRAVEL_NODE_IDS"` (an array of sectorIds). Node-ness is config-static, so it never needs re-broadcasting; **ownership** is already reflected in marker colour, which clients can read. Valid destinations, client-side = `STCTI_TRAVEL_NODE_IDS` ∩ (markers coloured `ColorBLUFOR`). Server re-validates on request (never trust the client's dest).

> **CS note (single source of truth):** node-ness lives in config, ownership lives in the marker/state. The client *derives* the valid set from two authoritative sources it already has; it stores no third copy that could drift. Same discipline as §14 of the design doc.

### 1.2 Unlock taxonomy `[data + one refactor]`

Today `STCTI_unlocks` is a flat ID set and the only real id in use is `fixed_wing`. Formalise a **category × tier** scheme so vehicles and arsenal tiers gate consistently:

```
unlock id   = "cat_<category>"            e.g. cat_armor, cat_rotary, cat_uav
tiered id   = "cat_<category>_t<n>"       e.g. cat_armor_t2   (heavy MBTs)
legacy alias: keep "fixed_wing" == "cat_fixedwing_t1" so shipped data still resolves
```

Categories (v1): `infantry` (always on, id `""`), `wheeled`, `apc`, `armor`, `rotary`, `fixedwing`, `uav`, `naval`, `arty`.

**Refactor to do now — factor the grant path.** Capture (`fn_startProgression`) and procurement (Phase 10) both need "add unlock → broadcast `UNLOCKS_CHANGED` → `fn_updateArsenal`." Extract that into one function so there is exactly one place unlocks are granted:

```sqf
// fn_grantUnlock.sqf — [SERVER] params: [_unlockId] -> Bool (true if newly granted)
// The single mutation point for STCTI_unlocks. Idempotent. Both capture and procurement call it.
params ["_id"];
if (!isServer) exitWith { false };
if (_id isEqualTo "" || {_id in STCTI_unlocks}) exitWith { false };
STCTI_unlocks pushBack _id;
[STCTI_EV_UNLOCKS_CHANGED, [STCTI_unlocks, _id]] call CBA_fnc_globalEvent;
call STCTI_fnc_updateArsenal;
diag_log format ["[STCTI] Unlock granted: %1.", _id];
true
```

`fn_startProgression`'s handler collapses to `[_unlock] call STCTI_fnc_grantUnlock;`. This is a pure DRY win — no behaviour change, one authority for the invariant "an unlock is granted exactly once and everything downstream is notified."

### 1.3 Procurement resource sink `[data]`

One cost table, keyed by unlock id, tier-scaled. Lives in `init.sqf` next to the other tunables:

```sqf
// Procurement: buy a hardware-category unlock with resources (no site effect). Phase 10.
STCTI_PROCURE_COST = createHashMapFromArray [
    ["cat_wheeled",     [["money", 800],  ["ammo", 0]]],
    ["cat_apc",         [["money", 1800], ["ammo", 100]]],
    ["cat_armor",       [["money", 3500], ["ammo", 200]]],
    ["cat_armor_t2",    [["money", 6000], ["ammo", 400]]],
    ["cat_rotary",      [["money", 3000], ["ammo", 150]]],
    ["cat_fixedwing",   [["money", 8000], ["ammo", 500]]],
    ["cat_uav",         [["money", 4000], ["ammo", 200]]],
    ["cat_naval",       [["money", 1500], ["ammo", 50]]]
];
```

---

## 2. Phase 9 — Strategic mobility (fast travel + insertion)

**Goal:** redeploy across the map without a 15-minute drive, without it feeling like a cheat.
**Depends:** §1.1 (travel nodes).

### Do

A request/validate/apply flow that mirrors `fn_serverPurchase`, plus a correct **locality dance** for moving a player and their AI group.

| Function | Locality | Contract |
|---|---|---|
| `STCTI_fnc_travelMenu` | `[CLIENT]` | Dialog: list valid destination nodes (§1.1), issue a travel/insert request. Reuses the HC-menu sector-list pattern. |
| `STCTI_fnc_requestTravel` | `[CLIENT]` | `[_destId, _mode, player] remoteExec ["STCTI_fnc_serverTravel", 2]`. `_mode` = `"redeploy"` \| `"insert"`. |
| `STCTI_fnc_serverTravel` | `[SERVER]` | Authority: validate dest owned+node+uncontested, source not in active hostile observation, cooldown elapsed, affordability. Charge fuel. Then `remoteExec` `fn_doTravel` **to the requester**. Never moves the unit itself. |
| `STCTI_fnc_doTravel` | `[CLIENT]` | Runs where the player is local: relocate `player` + subordinate AI to the destination (redeploy = at the flag; insert = HALO/parachute near a chosen edge). |

**Why the server doesn't just `setPosATL` the player:** a player unit (and AI in a player's group) is **local to that client**, not the server. Position commands are reliable when run where the object is local. So the server's job is *decision + charge*; the actual move is `remoteExec`'d back to the owning client. This is the same authority/locality split the whole framework already uses — the server owns the ledger and the ruling, the client owns its own body.

Constants (`init.sqf`):

```sqf
STCTI_TRAVEL_FUEL_COST      = 40;    // redeploy between owned nodes
STCTI_TRAVEL_INSERT_FUEL    = 120;   // airborne insertion (costs more; can target a frontier)
STCTI_TRAVEL_COOLDOWN       = 120;   // per-player seconds between travels
STCTI_TRAVEL_BLOCK_IN_COMBAT = true; // refuse if the requester was recently damaged / in a firefight
```

Cooldown is tracked server-side keyed by `getPlayerUID` (stable across reconnect), not `clientOwner`:

```sqf
// in serverTravel, before charging:
private _uid = getPlayerUID _player;
private _readyAt = STCTI_travelCooldown getOrDefault [_uid, 0];
if (time < _readyAt) exitWith { ["Redeploy on cooldown."] remoteExec ["hint", _requester]; };
// ... on success:
STCTI_travelCooldown set [_uid, time + STCTI_TRAVEL_COOLDOWN];
```

### Two modes

- **Redeploy** — to an owned, uncontested node. Cheap fuel, safe arrival at the flag. This is the "base to base."
- **Insert** — airborne/HALO onto or near a chosen sector (including a frontier). Costs `STCTI_TRAVEL_INSERT_FUEL`, arrives at altitude under canopy. The conventional "combat insertion" flavour; makes the fast-travel system double as an assault-staging tool.

> **OPEN DECISION (defaulted — override if you disagree):** what moves with the player?
> **Default chosen:** *redeploy moves you + your subordinate AI group; it does not move vehicles.* Bringing a vehicle is only available via **insert** and only for the vehicle you are currently in (it drops with you). Rationale: group-move is cheap and locality-clean (player-group AI is local to the player); vehicle relocation has messier locality and invites "teleport my tank to the front" abuse. If you'd rather redeploy be player-only (Antistasi-strict) or allow a stored garage vehicle to be summoned at the destination, say so and I'll respec `fn_doTravel`.

### Scope

| In scope | Out of scope |
|---|---|
| Redeploy between owned nodes; airborne insert; fuel cost; per-player cooldown; combat lockout | Vehicle *summoning* from garage to a remote node; squad-wide (all players) group travel; travel to un-owned/contested sectors |

**Exit gate:** from HQ you can redeploy to any owned uncontested node for a fuel cost on a cooldown; you cannot redeploy into a contested sector or while in combat; insert drops you (and your current vehicle) near a frontier for a higher cost; AI subordinates arrive with you, cleanly, no desync in a hosted MP test.

**Risk:** low–medium. The only fiddly bit is the group relocation + the insert parachute handoff in MP.

---

## 3. Phase 10 — Procurement & progression depth (vehicles, hardware-location unlocks, weapons)

**Goal:** the full combined-arms roster becomes reachable — by capturing sites *or* by paying for the category — and the arsenal grows with it.
**Depends:** §1.2 (taxonomy + `fn_grantUnlock`), §1.3 (procure cost table).

This unifies your three asks ("added vehicles / unlock vehicle locations / weapons") because they're one system: **unlock ids gate both the garage catalog and the arsenal tiers.**

### Do

**(a) Hardware-location unlocks — content, near-zero code.** Add military-complex subtypes to `CfgSTCTISectors`, each `grantsUnlock`ing a category. The machinery already exists (`fixed_wing` → jets); this is more of the same:

```cpp
class armor_depot   { type="military"; grantsUnlock="cat_armor";   layout="military_small"; /* ... */ };
class heliport      { type="military"; grantsUnlock="cat_rotary";  layout="military_small"; /* ... */ };
class uav_terminal  { type="military"; grantsUnlock="cat_uav";     layout="military_small"; /* ... */ };
class motor_pool    { type="military"; grantsUnlock="cat_wheeled"; layout="military_small"; /* ... */ };
class naval_base    { type="military"; grantsUnlock="cat_naval";   layout="military_small"; /* ... */ };
```

**(b) Expanded vehicle catalog.** Grow `STCTI_garageCatalogTemplate` (role-based, faction-resolved by `fn_applyFaction`) to span the taxonomy, each entry gating on its category id:

```sqf
// [role, price, requiredUnlock, fuelCost]
STCTI_garageCatalogTemplate = [
    ["mrap",       500,  "",              50],
    ["truck",      400,  "cat_wheeled",   40],
    ["apc",        1500, "cat_apc",       150],
    ["ifv",        2200, "cat_apc",       180],
    ["mbt",        4500, "cat_armor",     300],
    ["mbt_heavy",  7000, "cat_armor_t2",  400],
    ["heli_transport", 3000, "cat_rotary", 200],
    ["heli_attack",    5500, "cat_rotary", 300],
    ["jet_cas",    8000, "cat_fixedwing", 500],
    ["uav_recon",  2500, "cat_uav",       120],
    ["uav_ucav",   6000, "cat_uav",       350],
    ["boat",       900,  "cat_naval",     60]
];
```

New roles must be added to each faction's role pool (`STCTI_FACTION_POOL`) so NATO/CSAT/AAF each resolve them — the abstraction already exists, this is filling the table.

**(c) Weapons — free rider.** The arsenal whitelist (`fn_updateArsenal`) already derives from unlock-keyed `arsenalUnits` tiers. Add tiers keyed to the same category ids (e.g. `cat_armor` tier adds crewman kit; a `cat_marksman` tier adds DMRs). No new arsenal code — just data keyed to the taxonomy.

**(d) Procurement path — small, high-leverage.** Because §1.2 factored `fn_grantUnlock`, procurement is literally "spend resources, then grant the unlock":

| Function | Locality | Contract |
|---|---|---|
| `STCTI_fnc_requestProcure` | `[CLIENT]` | `[_unlockId, clientOwner] remoteExec ["STCTI_fnc_serverProcure", 2]` |
| `STCTI_fnc_serverProcure` | `[SERVER]` | Look up cost in `STCTI_PROCURE_COST` (server-authoritative; client only names the id — same anti-forgery rule as `fn_serverPurchase`). Reject if already unlocked or unknown id. `spendMulti` the cost. On success `[_unlockId] call STCTI_fnc_grantUnlock`. |

```sqf
// fn_serverProcure.sqf — [SERVER] params: [_unlockId, _requester]
params ["_id", "_requester"];
if (!isServer) exitWith {};
if (_id in STCTI_unlocks) exitWith { ["Already unlocked."] remoteExec ["hint", _requester]; };
private _cost = STCTI_PROCURE_COST getOrDefault [_id, []];
if (_cost isEqualTo []) exitWith { ["That can't be procured — capture the site."] remoteExec ["hint", _requester]; };
if !(_cost call STCTI_fnc_spendMulti) exitWith { ["Not enough resources."] remoteExec ["hint", _requester]; };
[_id] call STCTI_fnc_grantUnlock;
[format ["Procured: %1.", _id]] remoteExec ["hint", _requester];
```

Note what the cost table's *absence* of an entry does: unique-effect unlocks (intel, etc.) simply aren't in `STCTI_PROCURE_COST`, so `serverProcure` refuses them — capture stays the only path to those. The data table *is* the policy.

**(e) Battlefield capture (optional but recommended).** Conventional doctrine: seize and field enemy materiel. Drive an intact enemy/abandoned vehicle into HQ garage radius and store it as **captured stock**. Reuses the existing store path:

| Function | Locality | Contract |
|---|---|---|
| `STCTI_fnc_serverCaptureVehicle` | `[SERVER]` | Validate: vehicle is empty (or you're the only crew), not already `STCTI_owned`, within garage radius. Mark `STCTI_owned`, push into `storedVehicles`. Optionally grant a `captured_<class>` unlock so that class becomes purchasable as captured stock. |

> **Design tension (flagged, not blocking):** capture-to-keep is the closest thing here to Antistasi scavenging. It stays inside the conventional pillar *because it's seizure of a functioning asset, not looting a counter*. If you want the class to become *buildable* (not just the one captured hull), that's the reverse-engineering fiction — reasonable, but it's the point where "conventional procurement" shades toward "scavenging economy." Default: **keep the captured hull, do NOT auto-unlock its class for purchase.** Flip if you want the Antistasi feel.

### Scope

| In scope | Out of scope |
|---|---|
| Category×tier taxonomy; new military-site subtypes; expanded catalog + faction roles; arsenal tiers; procurement of hardware categories; capture-and-store enemy vehicles | Procurement of unique site effects (intel/income); per-weapon "kill N to unlock"; auto-unlocking captured *classes* for purchase (opt-in only) |

**Exit gate:** capturing distinct site types unlocks distinct hardware categories; the garage + arsenal span the full combined-arms roster across all three native factions; you can also *buy* a category unlock with money+ammo (but never buy intel/income); an unlisted-in-procurement id is refused; a captured enemy MBT can be stored and driven again.

**Risk:** medium — mostly content and balance. `fn_grantUnlock` refactor de-risks the code side. Capture-to-store has the usual ownership/locality edge cases (crew, damage, JIP).

---

## 4. Phase 11 — DLC / CDLC support (explicit post-v1 scope expansion)

**Goal:** fold owned DLC hardware/factions into the pools without breaking native-only players.
**Depends:** the faction role→class abstraction (already shipped) — this is where it pays off.
**Scope note up front:** v1's non-goals say *native factions only*. DLC/CDLC factions are non-native, so **this is v2 by definition.** Ship native v1 first; this phase is the deliberate scope-expansion gate.

### Do

Reuse the **exact** optional-dependency pattern from LAMBS/ACE (`isClass (configFile >> "CfgPatches" >> ...)`). Two tiers, and they are **not** the same:

**Tier A — first-party DLC** (Apex, Tanks, Jets, Marksmen, Contact). Content is usable by everyone even unowned (engine shows a store nag). Safe to fold into role pools *unconditionally*. Low risk, roughly in-fantasy.

**Tier B — CDLC** (Global Mobilization, S.O.G. Prairie Fire, Western Sahara, Spearhead 1944, CSLA). Content requires **every player in MP to own it**, and it's separately licensed. So CDLC ships as **opt-in extension packs**: per-DLC data files that register roles/catalog/factions *only when their CfgPatches is detected*, mirroring how LAMBS degrades to vanilla when absent.

```sqf
// init.sqf — DLC detection table (mirrors STCTI_HAS_LAMBS_*).
STCTI_DLC = createHashMapFromArray [
    ["apex", isClass (configFile >> "CfgPatches" >> "A3_Characters_F_Tanoa")],
    ["gm",   isClass (configFile >> "CfgPatches" >> "gm_core")],           // CDLC
    ["vn",   isClass (configFile >> "CfgPatches" >> "vn_main")],           // CDLC S.O.G.
    ["ws",   isClass (configFile >> "CfgPatches" >> "WS_core")],           // CDLC W.Sahara
    ["spe",  isClass (configFile >> "CfgPatches" >> "SPE_core")]           // CDLC Spearhead
];
```

Extension-pack loader (only touches pools that are present):

```sqf
// per-dlc file config/dlc/gm.sqf, sourced at faction-apply IF STCTI_DLC get "gm":
// merges gm role→class entries into STCTI_FACTION_POOL and catalog rows into the template.
```

### Scope

| In scope | Out of scope |
|---|---|
| DLC detection table; first-party hardware into pools; CDLC opt-in extension packs (roles/catalog/factions gated on detection) | CDLC *maps* as playable islands (own effort); guaranteeing MP ownership (engine/mission-maker responsibility — we detect + degrade, we don't police) |

**Exit gate:** with a CDLC loaded, its factions/vehicles appear in setup + catalog; with it absent, STCTI runs native-only with zero errors; first-party DLC hardware is always present in the pools.

**Risk:** low–medium technically. The real complexity is the MP-ownership rule and scope discipline about whether whole CDLC factions (vs just their hardware) are in.

---

## 5. Phase 12 — Logistics & sustainment (stretch — the rest of "all that Antistasi stuff")

**Goal:** make the fuel/ammo economies *map-physical*, and deliver the design doc's promised military-site effects.
**Depends:** §1.1 (nodes), Phase 9 (mobility). **Scope-watch:** this is where feature creep lives — everything here is optional and independently cuttable.

### Candidate features (pick, don't do all)

- **Resupply convoys** — ammo/fuel trucks that ferry a resource bonus between owned nodes; a cut line has consequences. Ties fuel/ammo to the map instead of pure abstract income. Reuses the HC order/waypoint layer.
- **Repair / rearm / refuel** at HQ and owned military sites — service points for garage vehicles.
- **Intel from captured military sites** — periodic enemy-sector scans. **The design doc §4 already promises this** as a military-complex effect and I don't believe it's built; this is arguably a *bug-fix-to-spec*, not a new feature. Cheapest high-value item here.
- **Fixed defensive artillery / on-call fire** at owned nodes — extends the existing HC CAS/supply orders.

**Exit gate:** owning the logistics chain matters — a severed supply route measurably degrades a front; captured military sites deliver periodic intel.

**Risk:** medium, mostly scope. Do intel first (it's owed), convoys second, the rest only if they earn it.

---

## 6. What we're deliberately NOT building (pillar guard)

These are core Antistasi mechanics that violate STCTI's stated non-goals — listed so they don't creep back in via "but Antistasi has it":

- **Undercover / civilian disguise** — guerrilla identity mechanic; conventional armies wear uniforms. Out.
- **Civilian sentiment / war level / HR-from-population** — explicitly a design non-goal (this is a war, not Overthrow). Out.
- **Aggro-from-being-seen** — replaced by the aggression *director* (Phase 4), which is strategic, not stealth. Out.
- **Weapon-unlock-by-looting** — replaced by capture + procurement (Phase 10). Out.

---

## 7. Dependency graph & suggested order

```
§1 foundations (nodes, taxonomy, grantUnlock refactor, procure table)
      │
      ├──▶ Phase 9  (mobility)         ── needs §1.1
      │
      ├──▶ Phase 10 (procurement)      ── needs §1.2 + §1.3
      │          │
      │          └──▶ Phase 11 (DLC)   ── needs Phase 10 catalog/pool shape; v2 gate
      │
      └──▶ Phase 12 (logistics)        ── needs §1.1 + Phase 9; do "intel" first (owed to spec)
```

9 and 10 are independent of each other and parallelizable. 11 follows 10 (and crosses the v1 non-goal — ship native v1 first). 12 is optional throughout.

---

## 8. Open decisions (need your call before/at implementation)

1. **Fast-travel payload** (§2) — defaulted to *you + AI group; vehicles via insert only*. Confirm or change to player-only / allow garage-vehicle summon.
2. **Captured-class buildability** (§3e) — defaulted to *keep the hull, don't auto-unlock the class*. Confirm or enable reverse-engineering (Antistasi-flavoured).
3. **DLC scope** (§4) — first-party only (safe, in-fantasy) vs. full CDLC extension packs (bigger, licensing/MP constraints). Recommend: first-party in v1.x, CDLC as a tracked v2 item.
4. **Tuning literals** — every cost/cooldown/fuel value here is a placeholder; they become CBA settings and get calibrated in a balance pass, same as the resolver's `K`.

---

## 9. Acceptance checklist (per phase, for the coder to self-verify)

**§1 foundations**
- [ ] `travelNode` on sector record + config; `STCTI_TRAVEL_NODE_IDS` broadcast once at base establish.
- [ ] `fn_grantUnlock` is the *only* writer of `STCTI_unlocks`; `fn_startProgression` calls it; no behaviour change.
- [ ] `STCTI_PROCURE_COST` present; unique-effect ids deliberately absent.

**Phase 9 — mobility**
- [ ] Redeploy charges fuel, respects cooldown, refuses contested dest and in-combat source.
- [ ] Move executes on the requester's client (not the server); AI group arrives, no desync (hosted MP test).
- [ ] Insert drops player (+ current vehicle) under canopy near the chosen sector for the higher cost.

**Phase 10 — procurement**
- [ ] New military subtypes each unlock their category on capture.
- [ ] Catalog + arsenal span the taxonomy across NATO/CSAT/AAF.
- [ ] `serverProcure` looks up cost server-side, refuses unknown/already-owned/unique ids, grants via `fn_grantUnlock`.
- [ ] Captured enemy vehicle stores and re-deploys; class does NOT auto-unlock (default).

**Phase 11 — DLC**
- [ ] Detection table populated; native-only load is error-free with no DLC.
- [ ] First-party hardware always in pools; CDLC pools register only when detected.

**Phase 12 — logistics**
- [ ] Intel scans fire from captured military sites (spec §4 finally honoured).
- [ ] (If built) a severed convoy route degrades the dependent front measurably.
