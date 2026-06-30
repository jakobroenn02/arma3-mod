# STCTI — Strategic Capture-The-Island (Arma 3)

A server-authoritative conventional-warfare CTI framework for Arma 3. See the design docs:

- [strategic-cti-framework-design.md](strategic-cti-framework-design.md) — master design (all phases)
- [phase-1-vertical-slice-tasks.md](phase-1-vertical-slice-tasks.md) — Phase 1 task breakdown
- [abstract-combat-resolution-spec.md](abstract-combat-resolution-spec.md) — Phase 2 abstract resolver

## Current state: Phase 2 (abstract resolver + director wiring) — Altis & Tanoa

Proves the core loop **capture → income → spend → defend**, and resolves attacks on sectors
you aren't watching as math via the **abstract combat resolver** (an attack on an observed
sector still spawns live). Everything outside that loop is deliberately faked (see the
"Scope discipline" table in the Phase 1 doc).

### Source layout — shared code, per-map data (build-step)

All logic is **shared** in `framework/`; the only per-map data is each map's start-base table,
sector table (`mapData.sqf`), and `mission.sqm`. `build.ps1` stamps them together into the
playable `STCTI.<Map>/` folders. This keeps one source of truth and avoids the per-map logic
fork the design doc warns about in §14. (Migrates to a real `@stcti` addon at Phase 7.)

```
framework/                     # canonical shared logic — EDIT HERE
  description.ext, init.sqf, initServer.sqf, initPlayerLocal.sqf, functions/**
maps/<Map>/                    # per-map DATA only — EDIT HERE
  mapData.sqf  (STCTI_START_BASES + STCTI_SECTOR_TABLE)
  mission.sqm
build.ps1                      # framework/ + maps/<Map>/  ->  STCTI.<Map>/
STCTI.<Map>/                   # GENERATED — never hand-edit (overwritten each build)
```

### Requirements

- Arma 3 + **CBA_A3** (hard dependency — PFH, events).

### Build & run it
1. **Build:** from the repo root, run `pwsh ./build.ps1` (regenerates `STCTI.Altis/` and `STCTI.Tanoa/`).
2. Copy (or symlink/junction) the `STCTI.<Map>/` folder into your Arma 3 `…/Missions/` folder.
3. Launch Arma 3 with **@CBA_A3** enabled.
4. Open the mission in the Eden editor and hit Play (this runs `init.sqf` / `initServer.sqf`).

> Tip: junction the missions folder to the repo so edits are live —
> `New-Item -ItemType Junction -Path "$env:USERPROFILE\Documents\Arma 3\missions\STCTI.Altis" -Target "<repo>\STCTI.Altis"`.
> Re-run `build.ps1` after editing `framework/` or `maps/`; never edit `STCTI.<Map>/` directly.

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
