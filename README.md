# STCTI — Strategic Capture-The-Island (Arma 3)

A server-authoritative conventional-warfare CTI framework for Arma 3. See the design docs:

- [old-md/strategic-cti-framework-design.md](old-md/strategic-cti-framework-design.md) — master design (phases 1–8)
- [phase-9-plus-roadmap.md](phase-9-plus-roadmap.md) — mobility, procurement, DLC & sustainment (phases 9+)
- [old-md/abstract-combat-resolution-spec.md](old-md/abstract-combat-resolution-spec.md) — Phase 2 abstract resolver

## Current state: phases 1–8 + the Phase 9+ roadmap — Altis, Malden & Tanoa

The full loop is in: **capture → income → spend → defend → command**, persisted across restarts.

- **Phase 1–2** — capture/economy spine; unobserved fights resolve as math (abstract resolver),
  observed ones spawn live with seamless handoff both ways; spawn budget + observer hysteresis.
- **Phase 3** — data-driven sectors (auto-detected towns + authored `CfgSTCTISectors`); faction
  selection (NATO/CSAT/AAF) at campaign setup; unlock-gated garage **and** arsenal; sector
  hardening (reinforce garrison, build static HMG/AT/AA emplacements).
- **Phase 4** — AI director: aggression scalar (rises on your captures, decays when quiet,
  hard-capped), one telegraphed operation at a time with cooldown, escalation tiers
  (infantry → armor → air), frontier targeting, shared defend tasks.
- **Phase 5** — High Command: map board at base → recruit squads (money + manpower), order
  patrol/defend/attack on any sector, costed supply runs and CAS strikes. Squads also answer
  to the vanilla HC bar (Ctrl+Space). LAMBS `task*` used when loaded, vanilla waypoints else.
- **Phase 6** — persistence: autosaves the campaign spine (ownership, resources, unlocks,
  garage, hardening, faction, aggression) to the server profile; restores on mission start.
  Fresh campaign: `call STCTI_fnc_wipeSave` in the debug console, then restart.
- **Phase 7** — Malden joined Altis + Tanoa (per-map data only; Malden coordinates are
  placeholders pending an editor export — base placement land-snaps, so it's playable).
- **Phase 8 (ongoing polish)** — ambient civilian traffic, faction loadout on deploy,
  quality-of-life fixes. Balance tuning is the open long tail.
- **Phase 9 — strategic mobility** — "Strategic travel" (at base or any owned town/military
  node): redeploy to owned nodes for fuel on a cooldown (you + your AI squad), or pay more to
  HALO-insert onto any node — in your current vehicle if you're sitting in one. Combat lockout;
  server-validated.
- **Phase 10 — procurement & full roster** — the garage spans the whole combined-arms
  taxonomy (trucks, APCs, IFVs, MBTs incl. heavy, transport/attack helos, jets, recon/armed
  UAVs, boats), each row gated on a hardware category. Categories unlock by **capturing** the
  matching military site (armor depot, heliport, motor pool, UAV terminal, naval base…) or by
  **procuring** them with money+ammo at the garage — but unique site effects (intel, income)
  can never be bought. Arsenal tiers ride the same unlocks (crew kit with armor, pilot kit with
  air). Intact enemy vehicles driven into the garage perimeter can be **captured into stock**.
- **Phase 11 — DLC detection** — first-party DLC hardware sits in the pools (usable by all);
  CDLC extension packs are detected (`STCTI_DLC`) but deliberately deferred to v2.
- **Phase 12 — sustainment** — holding any military site grants periodic **intel** (enemy map
  dots annotated with garrison strength); the garage services owned vehicles
  (repair/refuel/rearm for resources).
- **The front** — capture only progresses in sectors **adjacent to friendly territory** (or the
  HQ beachhead); out-of-reach sectors render faded. Income only flows from sectors **supplied**
  through an owned chain back to the HQ — cut the chain, starve the rest (works both ways).
  Enemy garrisons **entrench over time** where nobody is watching; enemy **supply convoys** run
  near the front and can be ambushed (loot + the destination garrison goes without — intact
  trucks can be captured). Respawn at base costs manpower; hold **every** sector to win.
  Artillery **fire missions** (HC board) soften a sector for money+ammo — big ops shell you back.

### Vehicle garage (Antistasi-style)

Buy vehicles (money + fuel) at the garage flag; place them with the crosshair (Space places,
Q/E rotate, Esc cancels). Bought vehicles are yours until they explode: store them at the flag,
take them out again for free — condition (damage + fuel) persists through the garage and the
campaign save.

### Source layout — shared code, per-map data (build-step)

All logic is **shared** in `framework/`; the only per-map data is each map's start-base table
(`mapData.sqf`) and `mission.sqm`. `build.ps1` stamps them together into the playable
`STCTI.<Map>/` folders. One source of truth — no per-map logic forks (design §14). (Migrates
to a real `@stcti` addon as a distribution step, if ever.)

```
framework/                     # canonical shared logic — EDIT HERE
  description.ext, init.sqf, initServer.sqf, initPlayerLocal.sqf, functions/**
maps/<Map>/                    # per-map DATA only — EDIT HERE
  mapData.sqf  (STCTI_START_BASES)
  mission.sqm
build.ps1                      # framework/ + maps/<Map>/  ->  STCTI.<Map>/
STCTI.<Map>/                   # GENERATED — never hand-edit (overwritten each build)
```

### Requirements

- Arma 3 + **CBA_A3** (hard dependency — PFH, events).
- **LAMBS Danger** (optional): smarter squad AI + richer HC order execution. Auto-detected.

### Build & run it
1. **Build:** from the repo root, run `pwsh ./build.ps1` (regenerates all `STCTI.<Map>/` folders).
2. Copy (or symlink/junction) the `STCTI.<Map>/` folder into your Arma 3 `…/Missions/` folder.
3. Launch Arma 3 with **@CBA_A3** enabled (and @LAMBS if you want it).
4. Open the mission in the Eden editor and hit Play (this runs `init.sqf` / `initServer.sqf`).

> Tip: junction the missions folder to the repo so edits are live —
> `New-Item -ItemType Junction -Path "$env:USERPROFILE\Documents\Arma 3\missions\STCTI.Altis" -Target "<repo>\STCTI.Altis"`.
> Re-run `build.ps1` after editing `framework/` or `maps/`; never edit `STCTI.<Map>/` directly.

### First campaign, in five minutes

1. Pick your **faction** and **starting zone** in the setup dialog.
2. Stand in a nearby town until its marker turns blue — money + manpower start flowing.
3. At base: gear up (arsenal), buy a Hunter (garage flag), recruit a squad (High Command board).
4. Order the squad to patrol your town; capture the fuel depot for fuel income; take the
   airfield to unlock jets, pilot gear, and CAS strikes.
5. When the "enemy forces moving" warning fires, reinforce the garrison / build statics /
   defend it yourself. Your progress autosaves — quit and pick the campaign up later.

### Deviations from the spec (deliberate, documented in code)

- `CBA_fnc_globalEvent` instead of `serverEvent` for cross-machine pushes (spec stubs were
  server-only; identical in SP, correct in co-op).
- Faction selection swaps **class maps only** — engine sides stay player=west/enemy=east
  (the mission.sqm player unit can't follow a side swap; joined units take group side anyway).
- Director attacks are **engagement-based** (no physical approach convoys); the warning lead
  time stands in for travel. Convoys belong to a later order-layer pass.
- Ghost placement confirms with **Space**, not LMB — display-46 mouse events cannot block
  weapon fire in the engine.
