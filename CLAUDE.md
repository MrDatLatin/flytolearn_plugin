# CLAUDE.md — FlyToLearn Plugin Project Memory

This file provides context for Claude Code (or any Claude instance) working on this project. Read this before making changes.

## Project Identity

- **Name:** FlyToLearn Aviation Challenge
- **Type:** SASL 3.16.4 plugin for X-Plane 12
- **Language:** Lua (LuaJIT / Lua 5.1 compatible)
- **Versions:** FlyToLearn Basic 1.3.2 / FlyToLearn Competition 1.4.2
- **Author:** Tom
- **License:** MIT
- **Purpose:** Educational flight scoring system for student pilot training

## Development Environment

- **Editor:** VSCode with Lua Language Server (set to LuaJIT runtime)
- **Testing:** Run X-Plane 12 with plugins installed in `Resources/plugins/FlyToLearn_Basic/` and `Resources/plugins/FlyToLearn_Competition/`
- **Debugging:** DataRefEditor plugin (free, from Laminar Research) for real-time dataref inspection
- **Logs:** Check `X-Plane 12/Resources/plugins/FlyToLearn_Basic/data/modules/SASLLog.txt` (or `FlyToLearn_Competition/`) and X-Plane's own `Log.txt`
- **Config:** `flytolearn_config.ini` in `Custom Module/` folder — auto-generated, INI format

## Key Architectural Facts

- SASL components are loaded by `main.lua` in the `components = {}` table. `timer_library` MUST load before `flytolearn`.
- Every component with an `update()` function gets called every frame by SASL.
- `timer_library.lua`'s `update()` calls `updateAll(components)` — this is how child components receive their update cycles.
- Datarefs are accessed via `globalPropertyf()` / `globalPropertyi()` to get handles, then `get()` / `set()` to read/write values.
- UI is built with SASL `contextWindow{}` popups, not X-Plane native widgets.
- All settings live in the global `settings` table. The global `config` table is the serializable copy written to disk on shutdown.
- Airport detection uses `findNavAid(nil, nil, lat, lon, nil, NAV_AIRPORT)` — finds nearest airport to given coordinates.

## Repository

- **GitHub:** https://github.com/MrDatLatin/flytolearn_plugin
- **Branch:** `main`
- **Local path (Mac):** `~/Documents/GitHub/flytolearn_plugin`

## File Map

### Core files (in repo — two independent plugin copies)
Each plugin has its own copy under `FlyToLearn_Basic/data/modules/` and `FlyToLearn_Competition/data/modules/`:
- `main.lua` — Entry point, global settings, config load/save, component registration
- `Custom Module/flytolearn.lua` — State machine, scoring logic, UI window creation, flight summary logging
- `Custom Module/timer_library.lua` — xLua-style timer functions adapted for SASL (MIT, by Jeffory J. Beckers)

### UI components (all now in repo ✅)
Located in `data/modules/Custom Module/`:
- `ftl_logo.lua` — Logo bar at bottom of screen
- `ftl_start.lua` — Start/departure screen
- `ftl_options.lua` — Scoring weight adjustment UI
- `ftl_reboot.lua` — Screen resolution change handler
- `ftl_score.lua` — Score display screen
- `ftl_inflight.lua` — In-flight status overlay
- `ftl_status.lua` — Status display (discovered in X-Plane install — not in original docs)
- `flight_start.lua` — Flight start handler (discovered in X-Plane install — not in original docs)
- `keyboard_handler.lua` — Keyboard input handling
- `ui_button.lua` — Reusable button drawing component

### UI assets (in repo ✅)
Image assets in `Custom Module/ui_assets/` — button state PNGs and RobotoCondensed-Regular.ttf font — are committed to the repo.

### Reference files (read-only, don't modify)
- `api.lua` — SASL API annotations (109K, useful for autocomplete)
- `init*.lua` — SASL framework internals
- `xplane-developer-documentation-reference.md` — Curated links to official Laminar Research docs

## Flight Phase State Machine

```
LIMBO (0) → DEPARTING (1) → INFLIGHT (2) → LANDED (3) → ENDED (4)
```

Transitions:
- LIMBO → DEPARTING: User clicks "Start" button
- DEPARTING → INFLIGHT: `on_ground` false **AND** groundspeed ≥ 20 m/s — records `takeoff_lat/lon`
  - Speed threshold prevents false liftoff at terrain-complex airports (e.g. LFHU) where `onground_all` returns 0 while stationary
- INFLIGHT → LANDED: Aircraft touches down AND min flight time (2 min) met — records `touchdown_lat/lon`
- INFLIGHT → DEPARTING: Touch down before min flight time (resets — prevents false triggers)
- LANDED → ENDED: Ground speed ≤ 0.01 (fully stopped) — records `landing_stop_lat/lon`
- Any phase → LIMBO: User clicks "Cancel"

## Current Scoring Formula

```
final_score = (weighted_dist × weighted_load) / (weighted_time × weighted_fuel) × 100
```

Each weight is configurable from 0.5 to 2.0 through the in-game UI.

## X-Plane Datarefs Used

```lua
-- Position & movement
sim/flightmodel/position/latitude        -- float, aircraft lat
sim/flightmodel/position/longitude       -- float, aircraft lon
sim/flightmodel/controls/dist            -- float, distance traveled in meters
sim/flightmodel2/position/groundspeed    -- float, ground speed
sim/flightmodel/failures/onground_all    -- int, 1 = on ground

-- Weight & fuel
sim/flightmodel/weight/m_total           -- float, total weight kg
sim/flightmodel/weight/m_fuel_total      -- float, fuel weight kg
sim/aircraft/weight/acf_m_empty          -- float, empty weight kg

-- Performance (captured but NOT yet used in scoring)
sim/flightmodel/forces/g_nrml           -- float, normal G-force
sim/flightmodel/position/vh_ind_fpm     -- float, vertical speed fpm

-- Time & sim control
sim/time/total_flight_time_sec          -- float, flight time
sim/time/sim_speed                      -- int, simulation rate
sim/time/ground_speed                   -- int, ground speed setting
sim/time/ground_speed_flt               -- int (should be float — known bug)

-- Electrical
sim/cockpit2/electrical/battery_on      -- float array, battery state
```

## Landing Quality Enhancement

### Status: IMPLEMENTED ✅ — deployed in v1.3.2 (Basic) / v1.4.2 (Competition)

Implemented across all prior sessions. Key functions in `flytolearn.lua`:

```lua
is_within_runway(lat, lon)          -- bool: inside designated runway boundary?
calculate_landing_penalties()       -- number: percentage deduction
check_disqualification()            -- bool: DQ conditions met?
```

### Rules (Implemented)

| Condition | Result |
|-----------|--------|
| G-force ≤ 2.5 | Clean landing — no deduction |
| G-force 2.5–3.5 | Hard landing — 5% penalty |
| G-force > 3.5 | Crash — disqualified |
| Touchdown outside runway rectangle | Off runway — disqualified |
| Touchdown in upper half of runway (wrong-way approach) | Wrong runway — disqualified |

### Aviation Context for Courchevel (Competition)

- One-way operations: land ONLY on Runway 04 (uphill), takeoff ONLY on Runway 22 (downhill)
- 18.5% gradient, 537m runway, ~6,588 ft elevation
- Landing on Runway 22 is prohibited in real operations
- The competition route is LFHU (Altiport Huez) → LFLJ (Courchevel)

## Future Enhancements (Not Yet Started)

- Extend runway detection to work with any runway (not just hardcoded Courchevel)
- Landing quality grades: Butter / Soft / Firm / Hard / Crash
- Bounce detection (air→ground→air cycles within 10-15 second window)

## Known Bugs & Tech Debt

1. `xp_gnd_speed2` declared as `globalPropertyi` but dataref is float → type mismatch warning in SASL log
2. Typo: `flight_summary.score_wieght_time` (should be `weight`)
3. Many globals that should be locals (`flight_phase`, `start_time`, etc.)
4. `flight_start.lua` and `ftl_status.lua` discovered in X-Plane installation but not yet documented — purpose unknown

## Coding Conventions

- **Ask before writing code** — Tom prefers to review approach and give permission before implementation
- Use percentage-based deductions for penalties, not multipliers
- Follow existing naming patterns (`FTL_PHASE_*` constants, `xp_*` dataref handles, `flight_summary.*` for log data)
- Keep UI logic in the `ftl_*.lua` component files, scoring logic in `flytolearn.lua`
- Use `debug_lib.on_debug()` for debug-only logging
- Write flight summaries as `.info` files to X-Plane root directory

## Useful Commands

```bash
# Find all Lua files in either plugin
find "X-Plane 12/Resources/plugins/FlyToLearn_Basic/" -name "*.lua"
find "X-Plane 12/Resources/plugins/FlyToLearn_Competition/" -name "*.lua"

# Watch SASL log for errors during development
tail -f "X-Plane 12/Resources/plugins/FlyToLearn_Basic/data/modules/SASLLog.txt"
tail -f "X-Plane 12/Resources/plugins/FlyToLearn_Competition/data/modules/SASLLog.txt"

# Check X-Plane log for plugin load issues
grep -i "flytolearn\|sasl" "X-Plane 12/Log.txt"
```
