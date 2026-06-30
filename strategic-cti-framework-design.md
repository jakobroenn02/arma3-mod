# Strategic CTI Framework — Design Document

**Codename:** STCTI · **Engine:** Arma 3 (SQF) · **Status:** Draft v0.2 · **Target maps (v1):** Altis, Malden, Tanoa

---

## 1. Context and goals

A single-player / co-op **Capture-The-Island** mission framework that plays like a slower, more deliberate Warlords with the depth of Antistasi — but framed as a **conventional military campaign** rather than a guerrilla insurgency. The player commands a force from a home base, captures sectors across the map to grow four parallel economies, and fights a combined-arms war (infantry, armor, air, drones) against a deliberately passive enemy that mounts occasional, well-telegraphed operations.

### Design pillars

1. **Conventional, not rebellion.** The player starts with real firepower; progression unlocks *more* and *better*, it doesn't start from a knife and a pistol.
2. **Slow, deliberate pace.** The enemy is passive by default. Attacks are infrequent and arrive with a short warning. Tempo is a tunable, not an accident.
3. **Combined arms as the point.** Every layer of Arma — infantry, heavy vehicles, air support, UAVs — should be reachable and useful in one campaign.
4. **Strategic command.** A High Command table lets the player direct AI across the whole map: patrols, staged attacks, supply runs, air support.
5. **Server-authoritative from day one.** Single-player today, co-op-capable tomorrow, with no rewrite.

### Non-goals (v1 scope boundaries)

- No PvP / TvT. Player(s) vs AI only.
- No *base building* in the survival-game sense (no free-placement construction, walls, no resource-node harvesting). The only construction allowed is **light defensive placement** at owned sectors — see §6.1.
- No custom maps or non-native factions in v1 (native maps + NATO/CSAT/AAF only).
- No *civilian-sentiment / influence simulation* (this is a war, not Overthrow). **Ambient civilians for atmosphere are in scope** — see §6.2.

---

## 2. Core gameplay loop

```
Capture sector ─▶ Grows an economy ─▶ Spend on forces & unlocks ─▶ Hold / push the line
      ▲                                                                      │
      └──────────────── enemy mounts a telegraphed operation ◀──────────────┘
```

The whole framework exists to make this loop satisfying. If it isn't fun with four sectors and a dumb enemy, more features won't save it (see Build Plan, Phase 1).

---

## 3. Resource model — the four economies

| Resource | Primary source | Spent on |
|---|---|---|
| **Money** | Towns | Vehicles, aircraft, arsenal gear, base upgrades |
| **Manpower** | Towns | Recruiting AI infantry, crews, pilots |
| **Fuel** | Fuel depots | Vehicle/aircraft purchase & sustained operations |
| **Ammo** | Ammo depots | Resupply, artillery/air ordnance, heavy weapons |

All four live in one server-owned ledger. Income is additive per tick from owned sectors; spending is a server-validated debit. Clients never mutate the ledger directly — they send a request, the server checks and applies it.

---

## 4. Sectors

Sectors are **data, not hand-placed scripts** (so one manager runs on every map). Three types:

- **Towns** — baseline **money + manpower**. The economic backbone; most numerous.
- **Resource bases** — boost **one** specific resource (a *fuel depot* raises fuel income, an *ammo depot* raises ammo). Creates real map-control decisions.
- **Military complexes** — strategic, low-count, high-value. Each grants a **unique effect**: unlock a weapon/vehicle category (jets, heavy armor, UAVs), periodic **intel** (enemy sector scans every N minutes), or other campaign capabilities. These are the progression gates.

Capturing a sector fires a `"SectorCaptured"` event — the single signal the economy, progression, and AI director all react to.

---

## 5. The player base

A fixed starting airfield / military complex containing:

- **Vehicle garage** — purchase & store vehicles (gated by unlocks and resources).
- **Arsenal** — gear, filtered by current unlock flags.
- **High Command table** — opens the strategic command UI (see §7, HC layer).

The base is an Eden composition; each station is an object with an action that opens the relevant server-validated interface.

### 6.1 Light defensive placement (the only "base building")

At **owned sectors**, the player can spend resources to harden a position — no free-placement construction, just a short menu of presets:

- **Reinforce garrison** — spend money + manpower to raise the sector's defending infantry count (above its captured baseline).
- **Place static turret** — spend money + ammo to add a static weapon (HMG / GMG / static AT or AA) at a predefined slot in the sector.

Placed defenses are stored in the sector record and **virtualize like any other garrison** (§9): they exist as data when no player is near and spawn on approach. This is deliberately minimal — it gives the defend half of the loop some agency without becoming a construction game.

### 6.2 Ambient civilians

Purely atmospheric. A small number of civilian vehicles wander roads near populated/owned sectors to make the world feel alive. They have **no gameplay effect** — no sentiment, no economy, no morality system. Capped low, virtualized by proximity, and despawned far from players for performance. Strictly polish; see Build Plan, Phase 8.

---

## 6. Architecture overview

Server-authoritative. One world-state spine; clients render and request. (See the architecture diagram delivered in chat.)

```
Client (UI only)  ──requests──▶  Server (authority)  ──spawn/despawn──▶  World simulation
   HUD · map · HC table              World state                          sectors · AI groups
                                  + 6 managers
```

### Subsystems

| Subsystem | Responsibility | Key SQF mechanism |
|---|---|---|
| **World state** | Single source of truth (resources, ownership, unlocks, HC registry, stored vehicles) | One `HashMap` in `missionNamespace` / logic object |
| **Economy manager** | Per-tick income; validate & apply spends; push HUD | CBA PFH throttled ~60s |
| **Sector manager** | Capture state machine; fire ownership events | Trigger/radius presence check + per-sector FSM |
| **AI director** | Strategic pacing; schedule combined-arms operations | Aggression scalar + jittered long timer |
| **Progression** | Set unlock flags from captured complexes | Listens to `"SectorCaptured"` |
| **High command** | Map-wide AI orders (patrol/attack/supply/air) | Vanilla HC + custom order compiler |
| **Persistence** | Serialize/restore the spine | `profileNamespace` (v1) → DB extension (later) |
| **Garrison / virtualization** | Spawn forces when *observed*, cache as data otherwise | Observer-point check (altitude/sensor-scaled) + hysteresis + budget |
| **Abstract combat resolver** | Resolve unobserved AI-vs-AI fights as numbers | Strength model + attrition tick; hands off to/from spawned units |

---

## 7. Data model

### World state (server)

```sqf
STCTI_state = createHashMapFromArray [
    ["resources", createHashMapFromArray [
        ["money", 5000], ["manpower", 50], ["fuel", 2000], ["ammo", 2000]
    ]],
    ["sectors",        createHashMap],   // sectorId -> sector record (below)
    ["unlocks",        createHashMap],   // unlockId -> bool
    ["hcGroups",       []],              // registered group refs for High Command
    ["storedVehicles", []]
];
```

### Sector record (runtime)

```sqf
createHashMapFromArray [
    ["id",              "altis_kavala"],
    ["type",            "town"],          // town | resource_fuel | resource_ammo | military
    ["owner",           "enemy"],         // player | enemy | contested
    ["pos",             [3500, 13200, 0]],
    ["captureProgress", 0],               // 0..1
    ["income",          createHashMapFromArray [["money", 50], ["manpower", 2]]],
    ["garrison",        []],              // virtualized composition data
    ["grantsUnlock",    ""],              // "" or an unlockId
    ["spawned",         false]
];
```

### Sector config (authored data, per map)

The runtime record is built from a static config so designers add sectors by editing data, not code:

```cpp
class CfgSTCTISectors {
    class Altis {
        class Kavala {
            type          = "town";
            position[]    = {3500, 13200, 0};
            captureRadius = 250;
            income[]      = {{"money", 50}, {"manpower", 2}};
            garrison      = "STCTI_garrison_town_light";
            grantsUnlock  = "";
        };
        class Air_Station_Mike26 {
            type          = "military";
            position[]    = {23100, 18800, 0};
            captureRadius = 350;
            income[]      = {};
            garrison      = "STCTI_garrison_military_heavy";
            grantsUnlock  = "fixed_wing";   // unlocks jets in the garage
        };
    };
};
```

### Faction abstraction

Sector garrisons and enemy forces reference **roles**, not classnames, so swapping NATO/CSAT/AAF is one mapping:

```sqf
STCTI_faction_enemy = createHashMapFromArray [
    ["riflemen", ["O_Soldier_F", "O_Soldier_GL_F"]],
    ["at",       ["O_Soldier_AT_F"]],
    ["armor",    ["O_MBT_02_cannon_F"]],
    ["air",      ["O_Heli_Attack_02_F"]],
    ["uav",      ["O_UAV_02_dynamicLoadout_F"]]
];
```

---

## 8. AI director — pacing design

The director owns one `aggression` scalar (0..1) that **rises slowly** on player captures and **decays** during quiet time, hard-capped low for a passive feel. On a **long, jittered** interval it rolls against aggression to launch **one** operation at a time:

1. Pick a target: a player-owned sector adjacent to enemy territory.
2. Assemble a combined-arms task force scaled by an **escalation tier**:
   - Tier 1 (low aggression): infantry + light vehicles
   - Tier 2: + armor element
   - Tier 3 (high aggression): + air / UAV element
3. Spawn off-map or at the nearest enemy sector; issue a waypoint chain to the objective.
4. Fire the **warning** (task + notification) with a short lead time.
5. Enter **cooldown** before the next operation is even considered.

**Pacing knobs (all tunable via CBA settings):** aggression cap, base interval, jitter range, cooldown length, warning lead time, escalation thresholds. These are the dials you'll spend the most playtesting time on.

---

## 9. Performance — virtualization (the real engineering)

The framework cannot keep hundreds of units alive map-wide, so every force has two states: **virtual** (composition + strength stored as data) and **spawned** (real entities). The whole difficulty is the transition rule — and naive "spawn when a player's body is within ~1.5 km" is **wrong**: it fails when the player stages an attack remotely (no body near the fight → it never happens) and when the player engages from range (a jet/UAV at altitude is "near" nothing on the ground).

### Spawn on *observation*, not body proximity

Compute an **observer point** per player = where their *attention* is, not where their feet are:

- on foot / in a ground vehicle → body position, base radius;
- in aircraft → the **sensor/camera target**, with a radius that **scales with altitude** (a jet at 1500 m can see and engage a fight 3–4 km away);
- piloting a UAV → the **drone camera's ground target** (the operator's body is at base; their attention is downrange — the trigger *must* follow the sensor).

A virtual force spawns if **any** observer point is in range **OR** a friendly (player-owned) force is engaging there *while observed*. Use **hysteresis** (e.g. spawn at 4 km, despawn at 5 km) to avoid boundary thrash. **Spawn the engagement, not a side** — instantiation is per-location; both factions spawn together or you get troops shooting at ghosts.

### Abstract resolver — unobserved combat is math, not entities

When two opposing virtual forces share a sector and **no observer is near**, nothing spawns. A lightweight model ticks attrition (each side's strength = unit count × type weight + sector defensive bonus) until one breaks, and reports the outcome via notification. This is what makes "stage an attack and walk away" a feature instead of a frame-rate bomb — and it's required by the High Command table (staged attacks / supply runs must resolve whether or not the player tags along).

### Seamless handoff (the hard part)

If an abstract fight is in progress and a player flies over to join, the system must **spawn both sides mid-battle with counts matching the resolver's current state**, in plausible positions, then hand off to live AI. On exit, despawn and **write survivor counts back** into the virtual state so the resolver resumes correctly. Clean bidirectional handoff (no overlapping/teleporting units, win-state preserved) is the piece to prototype most carefully.

### Budget & priority

Smart triggers don't remove the ceiling. Enforce a global **per-side unit budget**; instantiate in **priority order** (nearest / most-observed engagement first), leaving the rest abstract until budget frees. In MP, offload spawned AI to a **headless client**.

Build this **before** adding content (Phase 2) — retrofitting it is a near-rewrite. Prior art: Antistasi (caching), KP Liberation, ALiVE (profiling / virtual AI).

---

## 10. Persistence

- **v1:** serialize the whole spine to `profileNamespace` + `saveProfileNamespace` (server profile). Simple, dependency-free, proven by Antistasi.
- **Later:** `iniDBI2` / `extDB3` for robust dedicated-server persistence and save slots.
- Native SP saves handle live units; spine serialization is what survives a full restart.

---

## 11. Locality / MP model

Even as SP-first, design server-authoritative:

- **Server owns:** state spine, economy ticks, sector logic, AI spawning, the director, persistence.
- **Clients own:** UI, HUD, local input. They `remoteExec` requests to the server and receive state pushes.
- Use **CBA events** for cross-machine signalling; never mutate global state client-side.
- In SP, server == client, so this is free; in co-op it Just Works.

---

## 12. Tech stack & project layout

- **Dependency:** CBA_A3 (PFH, events, settings). ACE optional. Keep the core CBA-only.
- **Optional dependency — LAMBS Danger** (GPLv2 + amendments; **runtime dependency only, never bundled**). Treated exactly like ACE: detected at runtime (`STCTI_HAS_LAMBS_AI` / `STCTI_HAS_LAMBS_WP` in `init.sqf`), degrades gracefully to vanilla when absent. Two distinct uses: (1) its danger FSM upgrades **all** AI tactics automatically with zero code from us (cover, suppression, building-clearing, flanking); (2) its `lambs_wp_fnc_task*` orders (Assault/Patrol/Garrison/Creep/Retreat) are the intended **Phase 5 order-execution backend**, to be wrapped behind a thin `STCTI_fnc_order*` API with a vanilla-waypoint fallback so the core stays CBA-only and uncoupled. Licensing: *calling* its functions does not make our code derivative (per its amendments); *repackaging* it into `@stcti` would pull GPLv2 distribution obligations onto our release — defer that to a deliberate Phase 7/8 distribution decision, if ever.
- **Function library:** `CfgFunctions` under tag `STCTI` → `STCTI_fnc_economyTick`, `STCTI_fnc_sectorCapture`, …

```
@stcti_mission/
├── description.ext            # CfgFunctions, CfgSTCTISectors, dialogs
├── init.sqf                   # shared config / constants
├── initServer.sqf             # managers, state init, load
├── initPlayerLocal.sqf        # UI, HUD, HC registration
├── functions/
│   ├── core/                  # state, events, helpers
│   ├── economy/
│   ├── sectors/
│   ├── ai_director/
│   ├── highcommand/
│   ├── garrison/              # virtualization
│   └── persistence/
├── config/
│   ├── sectors/               # per-map sector data
│   └── factions/              # role -> classname maps
└── ui/                        # dialogs, HUD definitions
```

---

## 13. Build plan — what to tackle, in what order

Ordered to **de-risk the two things that kill projects like this** (is it fun? does it perform?) before investing in content and UI. Each phase has a hard **exit gate**.

### Phase 0 — Skeleton & tooling
**Goal:** a mission that loads with the plumbing in place.
**Do:** repo + version control; CBA dependency; `init` split; the state spine; a debug workflow (read/write resources from the debug console).
**Exit:** mission loads on Altis; `STCTI_state` initializes; you can mutate resources live.
**Risk:** low.

### Phase 1 — Vertical slice (the fun gate) ⭐
**Goal:** prove the core loop is fun before building anything fancy.
**Do:** one map, **3–4 hand-placed** sectors; four resources ticking; capture flips ownership; garage spends money; **one dumb** timer-based infantry attack.
**Exit:** capture → income → spend → defend is **playable and enjoyable** in a real session.
**Risk:** this is the **go/no-go** decision point. If it isn't fun here, redesign — don't proceed.

### Phase 2 — Virtualization & performance
**Goal:** make map-scale AI survivable *and* correct for remote/long-range engagements.
**Do:** virtual/spawned force model; **observer-point** spawn trigger (altitude- and sensor-scaled, follows UAV camera) with hysteresis; spawn-the-engagement (both sides together); **abstract combat resolver** for unobserved AI-vs-AI; bidirectional handoff (spawn mid-fight at resolver counts, write survivors back); per-side budget + priority; headless-client hook (stub).
**Exit:** full Altis sector set exists as data at stable FPS; a remotely staged attack resolves abstractly; flying over an ongoing fight spawns both sides mid-battle with matching strength.
**Risk:** **high** — the hardest subsystem, and the handoff is the trickiest part. Comes early on purpose.

### Phase 3 — Data-driven sectors & progression
**Goal:** content authoring without code.
**Do:** move sectors to `CfgSTCTISectors`; faction abstraction layer; implement all three sector types + their effects; unlock flags wired to the garage/arsenal; **light defensive placement** at owned sectors (reinforce garrison + place static turret, resource-costed — §6.1); **player faction selection at campaign setup** (see below).
**Exit:** adding a sector = editing data; capturing a military complex unlocks its category; the player can harden an owned sector; the player picks their faction at setup and the whole campaign uses it.
**Risk:** medium (mostly schema discipline).

> **Player faction selection (setup phase).** The player chooses which native faction to play (NATO / CSAT / AAF) at campaign start, alongside the existing base selection. Implementation: the faction abstraction is already side-aware — `STCTI_FACTION` maps `"player"|"enemy" -> (role -> classname)`, and `STCTI_SIDE_PLAYER/ENEMY` set the sides. Faction selection just populates those two from the chosen native faction (and picks a distinct enemy faction), so all spawning (`fn_spawnForce`), garrisons, and the garage/arsenal follow automatically. UI piggybacks on the campaign-start zone-select dialog (`fn_showZoneSelect`). Stays within the v1 non-goal of native factions only (§1).

### Phase 4 — AI director depth
**Goal:** the pacing that defines the game.
**Do:** aggression model; combined-arms task-force assembly; jittered scheduling with warnings + cooldown; escalation tiers (infantry → armor → air/UAV).
**Exit:** enemy is passive by default, mounts believable telegraphed operations, fully tunable.
**Risk:** medium — long tail of **balance** tuning.
**LAMBS note:** the optional LAMBS dependency (§12) buys the *tactical* half for free — squads fight with cover/suppression/flanking once engaged — so Phase 4 narrows to the **operational brain only**: deciding *when/where/what force* to commit. Don't reimplement squad tactics. Caveat: smarter live AI shifts balance, and it changes the `K` calibration target (calibrate the resolver's pace against LAMBS-driven live fights, not vanilla).

### Phase 5 — High Command planning layer
**Goal:** strategic command from the table.
**Do:** register player groups into vanilla HC; build the table dialog; implement order types (patrol, staged attack, supply run, air support).
**Exit:** player directs map-wide AI from the table; orders compile to working waypoints/tasks.
**Risk:** medium (custom UI is fiddly).
**LAMBS note:** LAMBS provides the order *execution backend* (`lambs_wp_fnc_task*` ≈ patrol/assault/garrison/creep/retreat). Phase 5 = the HC **table UI + order compiler** that targets a thin `STCTI_fnc_order*` abstraction (LAMBS if `STCTI_HAS_LAMBS_WP`, else vanilla waypoints). The command interface is still ours to build; LAMBS only shrinks the execution layer.

### Phase 6 — Persistence
**Goal:** campaigns survive restarts.
**Do:** serialize/restore the spine to `profileNamespace`; save/load triggers; autosave.
**Exit:** a server restart restores resources, ownership, unlocks, and stored vehicles.
**Risk:** medium (edge cases around live units).

### Phase 7 — Multi-map & faction rollout
**Goal:** ship the v1 map set.
**Do:** author Malden + Tanoa sector data; validate faction abstraction across NATO/CSAT/AAF.
**Exit:** all three maps playable end-to-end.
**Risk:** low if Phase 3 was done right (this is the payoff for data-driven design).

### Phase 8 — Polish & balance
**Goal:** make it feel finished.
**Do:** economy tuning; HUD/notification polish; **ambient civilian traffic** (§6.2); edge cases; dedicated-server + headless validation; optional ACE compatibility.
**Exit:** a stable, balanced, releasable build.
**Risk:** low, open-ended.

**Dependency notes:** 0→1→2 are strictly sequential. 3 must precede 7. 4, 5, 6 depend on 2+3 but are **independent of each other** — parallelizable, or reorder to taste (e.g. do Persistence before the HC UI if you want saves sooner).

---

## 14. Key decisions log

| Decision | Rationale | Alternatives rejected |
|---|---|---|
| Server-authoritative state | Free in SP, no rewrite for co-op | Client-side state (breaks in MP) |
| One world-state HashMap | Single save target, single sync target | Scattered globals (sync/save nightmare) |
| Data-driven sectors | One codebase, N maps | Per-map scripts (forks the logic) |
| CBA dependency | PFH/events/settings for free | Vanilla-only (reinvent three wheels) |
| `profileNamespace` persistence (v1) | Simple, dependency-free, proven | DB extension first (premature complexity) |
| Virtualization in Phase 2 | Retrofitting it is a rewrite | Add it "later" (the classic trap) |

---

## 15. Open questions

- Manpower model: a hard cap, or a regenerating pool? Does losing units refund manpower?
- Do resource bases **multiply** their resource or add a **flat** bonus? (Affects map-control math.)
- Intel from military complexes: full sector scan, or fog-of-war reveal with decay?
- Should the enemy ever *recapture* player sectors, or only contest pushes? (Major pacing lever.)
- Fast travel: in, out, or cost-gated? (Warlords disables it; Antistasi gates it.)

---

## 16. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Map-scale AI tanks performance | Project-ending | Virtualization early (Phase 2); unit budget; headless client |
| Core loop isn't fun | Wasted effort | Vertical-slice gate (Phase 1) before content |
| AI director feels random or oppressive | Bad pacing | Expose every knob as a CBA setting; playtest-driven tuning |
| Persistence corruption on restart | Lost campaigns | Serialize one spine; version the save format; autosave + backups |
| Scope creep (PvP, base building, custom maps) | Never ships | Non-goals in §1.; revisit only post-v1 |
