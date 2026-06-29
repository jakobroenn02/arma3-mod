# STCTI — Strategic Capture-The-Island (Arma 3)

A server-authoritative conventional-warfare CTI framework for Arma 3. See the design docs:

- [strategic-cti-framework-design.md](strategic-cti-framework-design.md) — master design (all phases)
- [phase-1-vertical-slice-tasks.md](phase-1-vertical-slice-tasks.md) — Phase 1 task breakdown
- [abstract-combat-resolution-spec.md](abstract-combat-resolution-spec.md) — Phase 2 abstract resolver

## Current state: Phase 1 vertical slice (`STCTI.Altis/`)

Proves the core loop **capture → income → spend → defend**. Everything outside that loop
is deliberately faked (see the "Scope discipline" table in the Phase 1 doc).

### Requirements
- Arma 3 + **CBA_A3** (hard dependency — PFH, events).

### Run it
1. Copy `STCTI.Altis/` into your Arma 3 `MPMissions/` (or `…/Missions/`) folder.
2. Launch Arma 3 with **@CBA_A3** enabled.
3. Editor → Scenarios / Multiplayer → host the `STCTI` mission on Altis (or open
   `STCTI.Altis` in the Eden editor and hit Play).

> The player + base start ~500 m north of Kavala (`[3500,13700]`). If the start position
> is awkward on your terrain, move the player unit in Eden — nothing else depends on it.

### Verify the exit gate (Phase 1 doc §Verification)
1. **Income** — capture `kavala` (stand in it, no enemies, until the marker turns blue). +50 money within ~1 min.
2. **Spend** — at the base HQ object, use the "Buy Hunter (500)" action. Money drops, a Hunter spawns.
3. **Defend** — wait for (or shorten `STCTI_ATTACK_MIN` in `init.sqf` to ~30 for testing) the telegraphed attack; repel it.
4. **Feel** — play 20–30 min. Is the loop fun? That's the only Phase 1 judgement that matters.

### Deviation from the spec
The task stubs use `CBA_fnc_serverEvent` to push state to clients. `serverEvent` runs
**only on the server**, so it can't reach remote clients in co-op. This build uses
`CBA_fnc_globalEvent` for the three cross-machine events (`ResourcesChanged`,
`SectorCaptured`, `AttackInbound`). Identical behaviour in SP; correct for co-op later.

### Layout
```
STCTI.Altis/
├── description.ext         # CfgFunctions
├── mission.sqm            # minimal: one playable BLUFOR unit at base
├── init.sqf               # constants, event names, tunables, CBA guard
├── initServer.sqf         # state + sectors + managers + director + garage
├── initPlayerLocal.sqf    # HUD, garage actions, attack/capture notifications
└── functions/{core,sectors,economy,garage,ai,ui}/
```
