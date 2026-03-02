# FlyToLearn Plugin — Handoff Document

This document captures the complete project context, architecture decisions, active work items, and institutional knowledge accumulated during development. It is intended for any developer (human or AI assistant) who needs to understand or continue work on this plugin.

**Last updated:** March 1, 2026
**Author:** Tom
**Current version:** 1.1.3

---

## Project Purpose

FlyToLearn Aviation Challenge is an educational flight scoring plugin for X-Plane 12. It automates performance assessment for student pilots practicing specific routes, reducing instructor workload in setting up and evaluating repetitive training flights. The primary training scenario is the LFHU (Altiport Huez) to LFLJ (Courchevel) route in the French Alps — a demanding mountain flying exercise.

---

## Architecture Overview

### Technology Stack

- **Host application:** X-Plane 12
- **Plugin framework:** SASL 3.16.4 Free Edition (Scriptable Aviation Simulation Library)
- **Language:** Lua (LuaJIT, Lua 5.1 compatible)
- **SASL maintainers:** FlightFactor / StepToSky (separate license from FlyToLearn)

### How SASL Works

SASL is a Lua scripting layer that sits between X-Plane and plugin code. Key concepts:

- **Components** — Each `.lua` file in `Custom Module/` is a SASL component loaded by `main.lua`
- **`update()` function** — Called every frame by SASL (like X-Plane's flight loop callback)
- **`globalPropertyf()` / `globalPropertyi()`** — Create handles to X-Plane datarefs
- **`get()` / `set()`** — Read/write dataref values through those handles
- **`contextWindow{}`** — Create UI popup windows
- **`findNavAid()` / `getNavAidInfo()`** — Query X-Plane's navigation database
- **Component loading order** — Defined in `main.lua`'s `components` table; `timer_library` must load first

### File Organization on Disk

```
X-Plane 12/Resources/plugins/FlyToLearn/
├── lin_x64/          # Linux SASL binary
├── mac_x64/          # macOS SASL binary
├── win_x64/          # Windows SASL binary
└── data/
    └── modules/
        ├── main.lua              # Entry point
        └── Custom Module/
            ├── flytolearn.lua        # Core logic & state machine
            ├── timer_library.lua     # Timer utilities (loaded first)
            ├── ftl_logo.lua          # Logo bar at bottom of screen
            ├── ftl_start.lua         # Start/departure screen
            ├── ftl_options.lua       # Weight configuration UI
            ├── ftl_reboot.lua        # Screen resolution change handler
            ├── ftl_score.lua         # Score display screen
            ├── ftl_inflight.lua      # In-flight status overlay
            ├── ftl_status.lua        # Status display (found in install, not in original docs)
            ├── flight_start.lua      # Flight start handler (found in install, not in original docs)
            ├── keyboard_handler.lua  # Keyboard input
            ├── ui_button.lua         # Reusable button drawing
            ├── flytolearn_config.ini # Persisted settings (auto-generated, not in repo)
            └── ui_assets/            # Image assets and fonts (not yet in repo)
```

### Component Loading Chain

```
main.lua
  ├── keyboard_handler (included via `include`)
  ├── timer_library {} (component #1 — must be first)
  └── flytolearn {}   (component #2)
        ├── Creates contextWindows referencing:
        │   ├── ftl_logo {}
        │   ├── ftl_start {}
        │   ├── ftl_options {}
        │   ├── ftl_reboot {}
        │   ├── ftl_score {}
        │   └── ftl_inflight {}
        └── Uses ui_button {} (within UI components)
```

---

## Core Logic Deep Dive: flytolearn.lua

### State Machine

The flight phase drives all behavior:

```
FTL_PHASE_LIMBO (0)
    ↓ user clicks "Start"
FTL_PHASE_DEPARTING (1)  — finds departure airport, waits for wheels-off
    ↓ on_ground becomes false
FTL_PHASE_INFLIGHT (2)   — records start values, forces sim speed to 1x
    ↓ on_ground becomes true AND min flight time met
FTL_PHASE_LANDED (3)     — calculates score, finds arrival airport, writes log
    ↓ ground_speed ≤ 0.01
FTL_PHASE_ENDED (4)      — shows score popup
```

**Important edge case:** If the aircraft touches down before the minimum flight time (default 2 minutes), the phase resets to `DEPARTING` instead of advancing to `LANDED`. This prevents false scores from bouncing on departure.

### Scoring Calculation

Values are captured at the moment of landing:

```lua
calc_dist = end_dist / 1852          -- meters to nautical miles
calc_load = payload_wt / 0.453592    -- kg to lbs
calc_time = end_time / 60            -- seconds to minutes
calc_fuel = end_fuel / 0.453592      -- kg to lbs

weighted_dist = calc_dist * settings.distance_weight
weighted_load = calc_load * settings.payload_weight
weighted_time = calc_time * settings.time_weight
weighted_fuel = calc_fuel * settings.fuel_weight

final_score = (weighted_dist * weighted_load) / (weighted_time * weighted_fuel) * 100
```

**Design note:** Payload is computed as `total_weight - empty_weight - fuel_weight` at the moment of departure (wheels-off).

### Data Already Captured But Not Used for Scoring

The plugin already reads G-force and vertical speed at landing and writes them to the flight summary log, but does not factor them into the score:

```lua
flight_summary.landing_force = get(xp_gforce)     -- captured at touchdown
flight_summary.vert_speed = get(xp_vs_fpm)        -- captured at touchdown
```

This is the foundation for the planned landing quality enhancement.

### Sim Speed Lock

During `DEPARTING` and `INFLIGHT` phases, the plugin forces simulation speed to 1x every frame to prevent students from fast-forwarding. This uses three datarefs:

```lua
set(xp_sim_speed, 1)
set(xp_gnd_speed1, 1)
set(xp_gnd_speed2, 1)
```

**Known issue in SASL log:** `"sim/time/ground_speed_flt": Casting float to int` — this is a type mismatch warning (the dataref is a float but declared as `globalPropertyi`). It works but should be cleaned up.

### Airport Detection

Uses SASL's `findNavAid()` with `NAV_AIRPORT` type, passing current lat/lon. Returns the nearest airport. This is how departure and arrival airports are identified — the aircraft just needs to be near an airport, not on a specific runway.

### UI Architecture

All UI is rendered through SASL `contextWindow` popups:

- `ftl_logo_frame` — Logo bar, always at screen bottom, toggleable via Plugins menu
- `start_popup` — Centered, shown when logo clicked in LIMBO phase
- `options_popup` — Weight adjustment sliders
- `score_popup` — Final score display, shown when flight ends
- `inflight_popup` — Status during flight, shown when logo clicked mid-flight
- `reload_popup` — Shown when screen resolution changes (requires plugin reboot)

Mouse interaction is handled through named button callbacks in `settings.ftl_logo.doMouseUp()`, `doMouseDown()`, `doMouseHold()`, and `doMouseWheel()`.

---

## Configuration System

Settings flow:

```
main.lua startup
  → Check if flytolearn_config.ini exists
  → If yes: load into `config` table, copy to `settings` table
  → If no: populate `config` from `settings` defaults, log warning
  
main.lua shutdown (onModuleDone)
  → Copy `settings` back to `config`
  → Write config to .ini file
```

The `settings` table is global and accessed from all components. The `config` table is the serialized version.

---

## Timer Library

`timer_library.lua` (by Jeffory J. Beckers / Jemma Studios, MIT License) provides xLua-compatible timer functions for SASL:

- `timer_lib.run_at_interval(func, seconds)` — Repeating timer
- `timer_lib.run_after_time(func, seconds)` — One-shot delayed execution
- `timer_lib.run_timer(func, delay, interval)` — Delayed start, then repeating
- `timer_lib.stop_timer(func)` — Cancel a timer
- `timer_lib.is_timer_scheduled(func)` — Check if timer exists

Also exposes `timer_lib.SIM_PERIOD`, `timer_lib.RUN_TIME_SEC`, `timer_lib.FLIGHT_TIME_SEC`.

**Note:** The timer library's `update()` function calls `updateAll(components)`, which is how child components get their update cycles.

---

## Active Development: Landing Quality Enhancement

### Status: IMPLEMENTED — PENDING IN-SIM TEST ✅🔧

Landing quality enhancement coded and deployed to X-Plane installation on March 1, 2026. Code committed and pushed to GitHub (commit 3185df0). Backup copies of pre-enhancement files saved as `flytolearn.lua.bak` and `ftl_score.lua.bak` in the X-Plane plugin folder.

### Requirements (Agreed)

**G-Force Monitoring:**
- Track peak G-force during the landing roll (from touchdown to full stop)
- **> 2.5G** = Hard landing → 5% score penalty
- **> 3.5G** = Crash → Flight disqualified
- Crash detection: rely on G threshold only — skip X-Plane native crash dataref hook (X-Plane resets on crash before LANDED phase completes anyway)

**Runway Boundary Checking:**
- Detect whether the aircraft touched down on the correct runway
- Initially targeting **Courchevel (LFLJ) Runway 04** specifically
- Landing off-runway = disqualification
- Landing on wrong runway (22 instead of 04) = disqualification with message: "Not designated runway — Please land on Courchevel Rwy 04"
- Wrong-runway detection method: if touchdown lat/lon is in the upper half of the runway rectangle (closer to Rwy 22 threshold), the aircraft came in on Rwy 22

**Penalty Integration:**
- Uses percentage-based deductions (consistent with existing scoring philosophy)
- Formula: `final_score = existing_score × (1 - landing_penalties/100)`
- DQ sets `final_score = 0`

### Runway Coordinates (Confirmed)

Captured in-sim via DataRefEditor, March 1, 2026:

| Point | Latitude | Longitude |
|-------|----------|-----------|
| Rwy 04 Threshold (touchdown end, south/lower) | 45.395948 | 6.632793 |
| Rwy 22 Threshold (stop end, north/upper) | 45.399094 | 6.637169 |

- Width: **18m** (published figure)
- Heading: **040°** magnetic (coord-derived bearing ~044° — use calculated bearing in code)
- Coord-derived length: ~489m (vs 537m published — spawn point inset explains difference)

### Implementation Plan (Agreed March 1, 2026)

**Files to modify: `flytolearn.lua` and `ftl_score.lua` only**

#### Phase 1 — New Constants and Variables (`flytolearn.lua` top section)
```lua
-- Runway constants (LFLJ Rwy 04)
RWY04_LAT, RWY04_LON = 45.395948, 6.632793
RWY22_LAT, RWY22_LON = 45.399094, 6.637169
RWY_WIDTH_M = 18

-- New landing quality tracking variables
peak_gforce = 0
touchdown_lat, touchdown_lon = 0, 0
landing_dq = false
landing_dq_reason = ""
landing_penalty_pct = 0
```

#### Phase 2 — Three New Functions (`flytolearn.lua`)

**`is_within_runway(lat, lon)`**
- Rotated rectangle check using the two threshold coordinate pairs
- Algorithm: convert to metres, project along/perpendicular to centerline, check both bounds
- Also used to detect wrong-runway landing: touchdown in upper half (along > rwy_length/2) = Rwy 22

**`calculate_landing_penalties()`**
- Returns percentage deduction
- peak_gforce > 2.5 → +5%
- Returns 0 if no penalties

**`check_disqualification()`**
- Returns `dq (bool), reason (string)`
- peak_gforce > 3.5 → DQ, "Crash landing detected"
- not is_within_runway(touchdown_lat, touchdown_lon) → DQ, "Landed off runway"
- touchdown in upper half → DQ, "Not designated runway — Please land on Courchevel Rwy 04"

#### Phase 3 — State Machine Changes (`update()`)

- **INFLIGHT→LANDED transition:** capture `touchdown_lat/lon`, initialise `peak_gforce` with current G reading. Remove `write_flight_info()` call (moved to ENDED).
- **During LANDED (every frame):** `if get(xp_gforce) > peak_gforce then peak_gforce = get(xp_gforce) end`
- **LANDED→ENDED transition:** call `check_disqualification()`, call `calculate_landing_penalties()`, apply to `final_score`, update `flight_summary`, call `write_flight_info()`, show score popup.

#### Phase 4 — Log File Additions (`write_flight_info()`)
New `flight_summary` fields and log lines:
- `peak_gforce`, `landing_penalty_pct`, `landing_dq`, `landing_dq_reason`, `base_score`

#### Phase 5 — Score Screen (`ftl_score.lua`)
- Add one landing quality line between fuel and score
- Three states: Clean / Hard landing (-5%) / DISQUALIFIED + reason

### Future Expansion

- Extend runway checking to work with any runway (not just hardcoded Courchevel)
- Add landing quality grades: Butter / Soft / Firm / Hard / Crash
- Bounce detection (track ground→air→ground cycles within 10-15 seconds)

---

## Courchevel / LFLJ — Aviation Context

Understanding Courchevel operations is critical for correct implementation:

- **One-way operations** — Landing ALWAYS on Runway 04 (uphill), takeoff ALWAYS on Runway 22 (downhill)
- Landing on Runway 22 (downhill) is extremely dangerous and prohibited in real operations
- The 18.5% gradient is the steepest in Europe for a paved runway
- The runway slopes uphill from the 04 threshold, which naturally helps deceleration
- Surrounded by mountains — missed approach requires specific procedures

The plugin should enforce proper procedures by disqualifying any landing attempt on Runway 22.

---

## Training Route: LFHU → LFLJ

- **Departure:** LFHU (Altiport Huez) — a mountain altiport, takeoff is downhill
- **Arrival:** LFLJ (Courchevel) — land uphill on Runway 04
- **Setup tip:** Save a situation file at LFHU positioned for takeoff so students can reload quickly: **File → Save Flight** in X-Plane 12

---

## Known Issues & Technical Debt

1. **Type mismatch warning** — `xp_gnd_speed2` is declared as `globalPropertyi` but the underlying dataref `sim/time/ground_speed_flt` is a float. Should be `globalPropertyf`.

2. **Typo in flight summary** — `flight_summary.score_wieght_time` (should be `weight`). Affects log file output only.

3. **Global variable usage** — Many variables that could be local are global (`flight_phase`, `start_time`, etc.). Works fine in SASL's sandboxed environment but is not best practice.

4. **Missing UI assets** — The `ui_assets/` folder (PNG button images and RobotoCondensed-Regular.ttf font) has not yet been copied into the repo. All Lua source files are now present. Copy from: `X-Plane 12/Resources/plugins/FlyToLearn/data/modules/Custom Module/ui_assets/`

5. **Sim speed forcing** — Uses three datarefs to force 1x speed. The `xp_gnd_speed1` and `xp_gnd_speed2` datarefs may not be the ideal approach — needs investigation if any side effects exist.

6. **Debug mode left on** — `main.lua` has `LOG_DEBUG` active. The commented-out `LOG_INFO` line should be uncommented for distribution builds.

---

## Reference Documentation

The following are available as project knowledge or in the docs folder:

- **`xplane-developer-documentation-reference.md`** — Curated links to all official Laminar Research developer docs (SDK, datarefs, flight model, tools)
- **`api.lua`** — Complete SASL 3.16.4 API annotations (109K lines, useful for IDE autocomplete)
- **`functions.txt`** — Flat list of all SASL API function names
- **`changelog.txt`** — SASL framework changelog (not FlyToLearn's changelog)
- **`init*.lua` files** — SASL framework internals (read-only reference, don't modify)

### Key External Resources

- SASL Framework: FlightFactor / StepToSky
- DataRefEditor: https://developer.x-plane.com/tools/datarefeditor/
- X-Plane SDK: https://developer.x-plane.com/sdk/
- Datarefs reference: https://developer.x-plane.com/datarefs/
- X-Plane Scenery Gateway (airport data): https://gateway.x-plane.com/

---

## Conversation History Summary

Development context was established across four Claude conversations in December 2024:

1. **"Adding hyperlinks to X-Plane project documents"** (Dec 26) — Created the developer documentation reference guide stored as project knowledge.

2. **"Fly to learn plugin documentation review"** (Dec 29) — Initial code review, feasibility analysis for landing quality features, agreed on G-force thresholds, penalty percentages, runway-specific detection approach, and DQ rules. Attempted to find Courchevel coordinates via web APIs (unsuccessful — need in-sim capture).

3. **"Contact information review"** (Dec 29) — Confirmed flight plan (LFHU→LFLJ), validated Runway 04 is correct for landing, discussed DataRefEditor installation, estimated 4-8 hours for implementation.

4. **"Taking screenshots in X-Plane"** (Dec 30) — Discussed situation file saving for reusable training setups, identified LOWS as potential default airport, clarified X-Plane 12 scenery installation process.

---

## Session: March 1, 2026 — GitHub Repo Setup (Claude Cowork)

This session established the GitHub repository and copied all source files from the X-Plane installation into the repo. No code was written or modified.

**What was done:**
- Created the `flytolearn_plugin` repo directory structure on disk
- Reviewed the actual X-Plane installation and discovered two files not previously documented: `flight_start.lua` and `ftl_status.lua`
- Copied all Lua source files from the X-Plane installation into the repo
- Initialized git repo with `main` branch
- Created `.gitignore` (excludes `.DS_Store`, `flytolearn_config.ini`, SASL logs, editor files)
- Made initial commit (18 files, 2,255 lines)
- Pushed to GitHub: https://github.com/MrDatLatin/flytolearn_plugin
- Set up git credential storage on Mac for future pushes

**What was NOT done (still outstanding):**
- `ui_assets/` folder (PNG images + font) not yet copied to repo
- No code changes — landing quality enhancement still blocked on runway coordinates
- `flight_start.lua` and `ftl_status.lua` need to be reviewed and documented

---

## Session: March 1, 2026 — Runway Coordinates + Implementation Planning (Claude Code)

**What was done:**
- Installed DataRefEditor in X-Plane 12
- Captured LFLJ Rwy 04 and Rwy 22 threshold coordinates in-sim — landing quality feature is now unblocked
- Validated coordinates: distance ~489m (vs 537m published — spawn point inset), bearing ~044° (vs 040° magnetic — acceptable)
- Confirmed runway width: 18m (published figure)
- Agreed full implementation plan for landing quality enhancement (see Active Development section above)
- Updated HANDOFF.md, MEMORY.md, README.md, and `docs/lflj_runway_coordinates.csv` with confirmed data

**What was NOT done:**
- No code written yet — implementation approved, begins next session
- `ui_assets/` folder still not in repo
- `flight_start.lua` and `ftl_status.lua` still not reviewed

**Next steps (after this session):**
- Test landing quality enhancement in X-Plane (see test plan below)
- Bump version to 1.2.0 after successful test
- Copy `ui_assets/` into repo and commit
- Review `flight_start.lua` and `ftl_status.lua`

---

## Session: March 1, 2026 — Landing Quality Implementation (Claude Code, continued)

**What was done:**
- Implemented all 5 phases of the landing quality enhancement plan in `flytolearn.lua` and `ftl_score.lua`
- Committed to GitHub: commit `3185df0` — "Add landing quality enhancement to scoring system"
- Pushed to GitHub: https://github.com/MrDatLatin/flytolearn_plugin
- Backed up pre-enhancement plugin files in X-Plane as `flytolearn.lua.bak` and `ftl_score.lua.bak`
- Copied updated `flytolearn.lua` (25,938 bytes) and `ftl_score.lua` (3,999 bytes) to X-Plane installation

**What was NOT done:**
- Not yet tested in X-Plane — version remains at 1.1.3 until test passes
- `flight_start.lua` and `ftl_status.lua` still not reviewed

**Also completed this session:**
- Copied all 47 `ui_assets/` files (PNGs + RobotoCondensed-Regular.ttf) into repo — commit `b6c4dac`
- Created `docs/ftl_test_plan.csv` with 6-scenario test plan for team distribution
- Created `FlyToLearn_v1.1.3_test.zip` on Desktop (16 MB) — cross-platform (Mac/Win/Linux), excludes `.bak` files and `flytolearn_config.ini` so testers get clean defaults on first run

**Test plan:**

| # | Test | How | Expected Result |
|---|------|-----|-----------------|
| 1 | Clean landing | Spawn at LFLJ Rwy 22 end, take off downhill, quick circuit, land gently on Rwy 04 | "Landing: Clean" in white, full score |
| 2 | Hard landing | Same circuit, grease the threshold then yank the nose down firmly on touchdown | "Landing: Hard landing (-5%)" in yellow |
| 3 | Crash / DQ by G | Really slam it in | "DISQUALIFIED — Crash landing detected" in red |
| 4 | Wrong runway | Land coming from the northeast, touching down near the Rwy 22 end (upper half) | "DISQUALIFIED — Not designated runway…" in red |
| 5 | Off-runway | Land in the grass next to the runway | "DISQUALIFIED — Landed off runway" in red |
| 6 | Log file | After any successful flight, find `flytolearn_summary_*.info` in X-Plane root folder | Check it has Peak G, Landing Penalty, Disqualified, Base Score lines |

**To speed up testing:** `min_flight_length` is currently set to `0.1` in `flytolearn_config.ini` — allows scoring after ~6 seconds airborne.
**⚠️ Reset to `2` when testing is complete** (edit `flytolearn_config.ini` line 9, or change it via the Options screen in-sim).
