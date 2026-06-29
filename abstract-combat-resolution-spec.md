# Abstract Combat-Resolution Model — Spec

**Codename:** STCTI · **Plugs into:** Phase 2 (virtualization) · **Status:** Draft v0.1
**Owner subsystem:** Abstract combat resolver (design doc §6, §9)

Resolves AI-vs-AI fights as numbers when no observer is present, so that staged/remote attacks actually happen without spawning entities. Must hand off seamlessly to/from spawned units (design doc §9).

---

## 1. Design goals & constraints

1. **Believable** — stronger force usually wins; defender has an edge; **combined arms matters** (infantry alone loses to unanswered armor/air). This is a design pillar, not a nicety.
2. **Pace-matched to live combat** — an unobserved fight should take *about as long* as the same fight would if spawned, or the seamless handoff feels wrong (fights "speed up" the moment you look away).
3. **Cheap** — runs for many sectors at once. O(unit types) per force per tick, no pairwise unit loops.
4. **Unit-count preserving** — the model tracks **discrete units per type**, not just a scalar, so at any instant the abstract state *is* a spawnable roster (e.g. `5 rifle, 1 MBT`).
5. **Tunable** — every constant is a CBA setting; the master pace dial is one number (`K`).

---

## 2. Data model

A force in the resolver is a per-type count map plus context:

```sqf
// force = HashMap: typeId -> count       e.g. ["rifleman", 6], ["mbt", 1]
// engagement record (one per contested, unobserved sector)
createHashMapFromArray [
    ["sectorId",   "kavala"],
    ["attacker",   createHashMapFromArray [["rifleman", 8]]],
    ["defender",   createHashMapFromArray [["rifleman", 5]]],
    ["defBonus",   0.15],            // from sector type
    ["startA",     8.0],            // Sraw at engagement start (for break ratio)
    ["startD",     5.75],           // Seff at start (defender; includes defBonus)
    ["accA",       0.0],            // fractional casualty accumulator, attacker
    ["accD",       0.0],
    ["ticks",      0],
    ["paused",     false]           // true while spawned/observed
];
```

### Unit-type config

A small attribute set per type — enough for counters without a full matrix:

```cpp
class CfgSTCTIUnitTypes {
    class rifleman   { cp = 1.0;  category = "infantry"; armorClass = "soft";    antiArmor = 0.10; antiAir = 0.0; };
    class at_team    { cp = 1.5;  category = "infantry"; armorClass = "soft";    antiArmor = 1.0;  antiAir = 0.0; };
    class aa_team    { cp = 1.3;  category = "infantry"; armorClass = "soft";    antiArmor = 0.0;  antiAir = 1.0; };
    class mrap       { cp = 3.0;  category = "armor";    armorClass = "light";   antiArmor = 0.3;  antiAir = 0.0; };
    class ifv        { cp = 6.0;  category = "armor";    armorClass = "armored"; antiArmor = 0.6;  antiAir = 0.0; };
    class mbt        { cp = 9.0;  category = "armor";    armorClass = "heavy";   antiArmor = 1.0;  antiAir = 0.0; };
    class uav_armed  { cp = 5.0;  category = "air";      armorClass = "air";     antiArmor = 0.7;  antiAir = 0.0; };
    class heli_atk   { cp = 10.0; category = "air";      armorClass = "air";     antiArmor = 1.0;  antiAir = 0.0; };
    class jet_cas    { cp = 12.0; category = "air";      armorClass = "air";     antiArmor = 1.0;  antiAir = 0.0; };
};
```

`cp` doubles as the **spawn back-reference** — it's how many of each type you instantiate on handoff. Keep CP roughly proportional to "how much of the fight this unit is worth."

---

## 3. Strength & output formula

For a force `F` fighting enemy `E` in sector `S`:

**Raw strength** (also the break-ratio basis):
```
Sraw(F) = Σ_t  count_F[t] · cp[t]
```

**Combined-arms multiplier** — reward distinct capability categories `{infantry, armor, air, AT, AA}`:
```
caMult(F) = clamp(1 + CA_STEP · (|caps(F)| − 1),  1.0,  CA_MAX)
```

**Counter coverage** — how well `F` answers `E`'s armor and air:
```
armorCP(E)      = Σ_t count_E[t]·cp[t]  where armorClass ∈ {armored, heavy}
antiArmorCP(F)  = Σ_t count_F[t]·cp[t]·antiArmor[t]
armorAnswered(F→E) = armorCP(E)>0 ? min(1, antiArmorCP(F)/armorCP(E)) : 1
                                                   // (air: airCP / antiAirCP, same shape)
```

**Offense effectiveness** — `F` wastes fire on targets it can't kill:
```
fArmor(E) = armorCP(E) / Sraw(E)            // enemy's armor share
fAir(E)   = airCP(E)   / Sraw(E)
offMult(F→E) = clamp(
      1 − P_ARMOR·fArmor(E)·(1 − armorAnswered(F→E))
        − P_AIR  ·fAir(E)  ·(1 − airAnswered(F→E)),
      0.1, 1.0)
```

**Defender bonus** (attacker = 1.0):
```
defMult(F) = F is defender ? (1 + defBonus(S)) : 1.0
```

**Combat output** — what `F` inflicts per tick of fighting:
```
Out(F→E) = Sraw(F) · caMult(F) · offMult(F→E) · defMult(F)
```

> Because `Out` scales with `Sraw(F)` and casualties scale with the *enemy's* `Out`, the system behaves like **Lanchester's square law**: the stronger side pulls ahead nonlinearly, so numerical superiority compounds — exactly the "concentrate force" intuition.

---

## 4. Attrition tick

One global per-frame handler iterates all contested, unpaused engagements every `RESOLVE_INTERVAL` real seconds and applies one step:

```
jitter ~ Uniform(1 − JITTER, 1 + JITTER)
lossCP(A) += K · Out(D→A) · jitter        // accumulate into accA
lossCP(D) += K · Out(A→D) · jitter        // accumulate into accD
```

`K` (per-tick lethality) × `RESOLVE_INTERVAL` (real cadence) set the **overall pace**. Fold the sim timestep into `K`; don't expose a separate Δt or you have two dials fighting. Accumulate fractional losses so small bleed isn't lost between ticks.

---

## 5. Casualty allocation — which units die

Convert each side's accumulated `lossCP` into **whole-unit removals**, weighted by vulnerability. The counter system lives here: a unit the enemy **can't answer** is nearly immortal (the "unanswered tank" effect).

```
baseVuln(armorClass):  soft 1.0 · light 0.6 · armored 0.35 · heavy 0.20 · air 0.30

counterFactor(unit u of F, enemy E):
    if armorClass(u) ∈ {armored, heavy}:  0.1 + 0.9 · armorAnswered(E→F)
    if armorClass(u) == air:              0.1 + 0.9 · airAnswered(E→F)
    else:                                 1.0

vuln(u) = baseVuln(armorClass(u)) · counterFactor(u, E)
```

Removal loop for side `F` (run after adding this tick's `lossCP` to its accumulator):

```
while accF ≥ min cp among F's remaining types:
    pick a type t from F weighted by  count_F[t] · vuln[t]
    if accF ≥ cp[t]:
        count_F[t] -= 1
        accF       -= cp[t]
    else:
        break        // not enough budget to kill this unit yet; carry remainder
```

Effect: soft units die first; heavy armor is sticky; armor/air with **no enemy counter** has `counterFactor ≈ 0.1` and effectively survives the whole abstract fight — which is what forces the player to bring AT/AA, fulfilling the combined-arms pillar.

---

## 6. Break / outcome

Forces **rout** rather than fight to the last man (more realistic, and ends fights sooner):

```
breakRatio(F) = Sraw_now(F) / Sraw_start(F)
F routs when breakRatio(F) < BREAK_THRESHOLD   (default 0.30)
safeguard: if ticks > MAX_TICKS, the lower breakRatio side routs (no infinite stalemate)
```

Resolution:
- **Defender routs** → attacker captures the sector (`setSectorOwner`); surviving attackers become the new garrison (apply a small `PURSUIT_LOSS` first). Fire `SectorCaptured`.
- **Attacker routs** → assault fails; surviving attackers become a **retreating virtual force** routed to the nearest friendly sector.
- Report both via the notification system: *"Assault on Kavala failed — 6 of 8 lost."*

---

## 7. Handoff contract (the part that must be exact)

The resolver and the spawn system share one engagement record. Transitions:

**Observer arrives → spawn:**
1. Set `paused = true` (stop ticking this engagement).
2. Spawn `count_F[t]` real units per type, per side, in plausible attack/defend positions.
3. Live AI now drives the fight.

**Observer leaves → despawn:**
1. **Recount surviving real units** per type back into `count_F[t]`.
2. Leave `startA / startD` unchanged (break ratio stays anchored to engagement start).
3. Set `paused = false`; the resolver resumes from the new counts.

**Pace matching (why this works):** keep timescale 1:1 and calibrate `K` so abstract time-to-resolution ≈ live time-to-resolution. Then crossing the spawn/despawn boundary doesn't visibly change who's winning or how fast.

**Calibration method:**
1. Spawn 5 representative assaults live; record median duration `T_live`.
2. Run the resolver on the same rosters; measure `ticks_to_resolve · RESOLVE_INTERVAL = T_abs`.
3. `K` scales duration inversely — adjust `K` until `T_abs ≈ T_live`. Re-check with a lopsided fight and an armor fight.

---

## 8. Tunables (CBA settings)

| Constant | Default | Controls |
|---|---|---|
| `K` | 0.03 | **Master pace** — per-tick lethality |
| `RESOLVE_INTERVAL` | 10 s | Real seconds between ticks |
| `JITTER` | 0.25 | Per-tick randomness (±) |
| `CA_STEP` / `CA_MAX` | 0.05 / 1.20 | Combined-arms bonus per category / cap |
| `P_ARMOR` / `P_AIR` | 0.5 / 0.5 | Offense penalty for unanswered armor / air |
| `baseVuln[*]` | see §5 | Per-armor-class survivability |
| `defBonus[type]` | town .15 · resource .20 · military .35 | Defender terrain edge |
| `BREAK_THRESHOLD` | 0.30 | Strength fraction at which a force routs |
| `MAX_TICKS` | 240 | Stalemate safeguard (~40 min @10s) |
| `PURSUIT_LOSS` | 0.05 | Attacker attrition on a successful capture |

---

## 9. SQF function sketches

```sqf
// STCTI_fnc_forceStrength — params: [_force] -> Number (Sraw)
params ["_force"];
private _s = 0;
{ _s = _s + _y * ([_x, "cp"] call STCTI_fnc_unitAttr); } forEach _force;
_s

// STCTI_fnc_forceOutput — params: [_force, _enemy, _isDefender, _defBonus] -> Number
// implements §3: Sraw · caMult · offMult · defMult
// TODO: compute caps set, armorCP/airCP, answered ratios, clamp offMult

// STCTI_fnc_resolveTick — params: [_eng]  (one engagement record)
// 1. compute Out(A->D), Out(D->A)
// 2. accA += K*Out(D->A)*jitter ; accD += K*Out(A->D)*jitter
// 3. [_eng,"attacker"] call STCTI_fnc_applyCasualties ; same for defender
// 4. _eng call STCTI_fnc_checkBreak

// STCTI_fnc_applyCasualties — params: [_eng, _sideKey]
// implements §5 weighted whole-unit removal loop using the side's accumulator

// STCTI_fnc_checkBreak — params: [_eng] -> "" | "attacker" | "defender"
// implements §6; on rout, flip sector / spawn retreating force, notify

// STCTI_fnc_startResolver — server, one global PFH
[{
    {
        if !(_y get "paused") then { _y call STCTI_fnc_resolveTick; };
    } forEach STCTI_engagements;   // HashMap sectorId -> engagement
}, STCTI_RESOLVE_INTERVAL] call CBA_fnc_addPerFrameHandler;
```

---

## 10. Worked examples (validate your implementation against these)

Constants: `K=0.03`, `JITTER=0` (deterministic for the check), `defBonus(town)=0.15`, `P_ARMOR=0.5`, `BREAK=0.30`.

### Example A — even infantry, town defender (attacker should win, take losses)

- Attacker: 8 × rifleman → `Sraw=8`, caMult=1, offMult=1.
- Defender: 5 × rifleman, town → `Seff = 5·1.15 = 5.75`.
- `Out(A→D)=8`, `Out(D→A)=5.75`.
- Per tick: `lossCP(A)=0.03·5.75=0.173`, `lossCP(D)=0.03·8=0.240`.
- Defender bleeds faster; square law widens the gap as A stays larger. Defender routs near `Sraw_D < 0.30·5 = 1.5` (≈1 rifleman left). **Expected outcome:** attacker captures with ~6 units after ~30–40 ticks (~5–7 min @10s). ✔ believable infantry fight.

### Example B — infantry vs unanswered MBT (attacker should *rout*)

- Attacker: 8 × rifleman, **no AT** → `antiArmorCP=0`.
- Defender: 4 × rifleman + 1 × mbt (cp 9, heavy), town.
- `armorCP(D)=9`, `Sraw(D)=13`, `fArmor(D)=0.69`, `armorAnswered(A→D)=0`.
- `offMult(A→D)=1 − 0.5·0.69·1 = 0.654` → attacker fire cut ~35%.
- `caMult(D)=1.05` (infantry+armor); `Seff` output: `Out(D→A)=13·1.05·1.15 ≈ 15.7`, `Out(A→D)=8·0.654 ≈ 5.23`.
- Per tick: `lossCP(A)=0.03·15.7 ≈ 0.47`, `lossCP(D)=0.03·5.23 ≈ 0.157`.
- Casualty allocation on D: MBT `counterFactor = 0.1+0.9·0 = 0.1`, `vuln_mbt = 0.20·0.1 = 0.02` vs rifleman `vuln=1.0` → **D's losses fall almost entirely on riflemen; the MBT is effectively immortal here.**
- Attacker bleeds ~3× faster and routs (`Sraw_A < 2.4`) in ~15–20 ticks while D keeps the tank and most riflemen. **Expected outcome:** assault fails. ✔ This is the model *enforcing* the combined-arms pillar — bring AT or don't attack armor.

---

## 11. v1 simplifications & open questions

- **Two sides per sector** only. Additional arrivals (reinforcements, a second group) merge into the existing attacker/defender force mid-fight; true 3-way is deferred.
- **Air = high-CP unit** in v1. Later, optionally model **sorties**: air contributes for a loiter window then returns to base (removed from the force), so it isn't permanently present. Flag for post-v1.
- **No morale beyond the break threshold** — routing is a strength ratio, not a separate morale stat. Probably fine; revisit if fights feel too binary.
- **Reinforcement timing**: does a supply run that boosts a garrison apply instantly, or arrive as a delayed virtual force? (Ties to the High Command supply-run order — decide alongside Phase 5.)
- **Calibrate `K` against real fights before tuning anything else** — every other constant is relative to the pace `K` sets.
