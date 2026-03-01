# FlyToLearn Plugin — Handoff Document

This document captures the complete project context, architecture decisions, active work items, and institutional knowledge accumulated during development. It is intended for any developer (human or AI assistant) who needs to understand or continue work on this plugin.

**Last updated:** December 2024  
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
        ├── flytolearn.lua        # Core logic (loaded as component by SASL)
        ├── timer_library.lua     # Timer utilities (loaded first)
        └── Custom Module/
            ├── ftl_logo.lua      # Logo bar at bottom of screen
            ├── ftl_start.lua     # Start/departure screen
            ├── ftl_options.lua   # Weight configuration UI
            ├── ftl_reboot.lua    # Screen resolution change handler
            ├── ftl_score.lua     # Score display screen
            ├── ftl_inflight.lua  # In-flight status overlay
            ├── keyboard_handler.lua  # Keyboard input
            ├── ui_button.lua     # Reusable button drawing
            └── flytolearn_config.ini # Persisted settings
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

### Requirements (Agreed)

The next major feature adds landing quality assessment to the scoring system. Requirements were established across multiple conversations:

**G-Force Monitoring:**
- Track peak G-force during the landing roll (from touchdown to full stop)
- **> 2.5G** = Hard landing → 5% score penalty
- **> 3.5G** = Crash → Flight disqualified
- If X-Plane's own crash detection triggers → apply hard landing deduction only (not double-penalize)

**Runway Boundary Checking:**
- Detect whether the aircraft landed and stopped on the correct runway
- Initially targeting **Courchevel (LFLJ) Runway 04** specifically
- Landing off-runway = disqualification
- Landing on wrong runway (22 instead of 04) = disqualification with message: "Not designated runway — Please land on Courchevel Rwy 04"

**Penalty Integration:**
- Uses percentage-based deductions (consistent with existing scoring philosophy)
- Formula: `final_score = existing_score × (1 - landing_penalties/100)`
- Penalties are additive (5% hard landing + other potential penalties)

### Prerequisite: Runway Coordinates

The implementation is blocked on obtaining precise coordinates for Courchevel Runway 04 from within X-Plane. **This has not been done yet.**

**How to capture coordinates:**

1. Install DataRefEditor plugin (free from https://developer.x-plane.com/tools/datarefeditor/)
2. Load X-Plane, set departure to LFLJ
3. Position aircraft at Runway 04 threshold (the downhill end, where you touch down)
4. Record `sim/flightmodel/position/latitude` and `sim/flightmodel/position/longitude`
5. Taxi/reposition to the opposite end (Runway 22 threshold / Runway 04 end)
6. Record those coordinates too
7. Note runway width (estimate) and confirm heading ≈ 040°

**Approximate coordinates (need verification in X-Plane):**
- Rwy 04 Threshold: ~45.3967°N, ~6.6347°E
- Elevation: ~6,588 ft
- Runway length: 537 m / 1,762 ft
- Gradient: 18.5% uphill

### Implementation Plan

Once coordinates are obtained, the estimated work is 4–8 hours:

| Phase | Task | Estimate |
|-------|------|----------|
| 1 | Runway boundary checking (rectangle from two coordinate pairs + width) | 1–2 hours |
| 2 | Peak G-force tracking during landing roll | 30 min–1 hour |
| 3 | Crash/disqualification detection (X-Plane native + G threshold) | 30 min–1 hour |
| 4 | Landing penalty calculations integrated with existing score | 30 min–1 hour |
| 5 | Score screen updates to display landing quality info | 30 min–1 hour |
| 6 | Testing and refinement | 1–2 hours |

### New Functions Needed

```
is_within_runway(lat, lon)          → bool (is position inside Rwy 04 rectangle?)
calculate_landing_penalties()       → number (percentage deduction)
check_disqualification()            → bool (should flight be DQ'd?)
```

### State Machine Changes

The `LANDED` phase needs to be enhanced to:
1. Capture peak G-force (not just instantaneous G at first ground contact)
2. Continuously track G during the landing roll until stopped
3. Check final position against runway boundaries when transitioning to `ENDED`

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

4. **Missing UI files in repo** — 8 Lua files and image assets need to be copied from the working installation. See README for the full list.

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
