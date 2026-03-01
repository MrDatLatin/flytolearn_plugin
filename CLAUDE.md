# CLAUDE.md — FlyToLearn Plugin Project Memory

This file provides context for Claude Code (or any Claude instance) working on this project. Read this before making changes.

## Project Identity

- **Name:** FlyToLearn Aviation Challenge
- **Type:** SASL 3.16.4 plugin for X-Plane 12
- **Language:** Lua (LuaJIT / Lua 5.1 compatible)
- **Version:** 1.1.3
- **Author:** Tom
- **License:** MIT
- **Purpose:** Educational flight scoring system for student pilot training

## Development Environment

- **Editor:** VSCode with Lua Language Server (set to LuaJIT runtime)
- **Testing:** Run X-Plane 12 with the plugin installed in `Resources/plugins/FlyToLearn/`
- **Debugging:** DataRefEditor plugin (free, from Laminar Research) for real-time dataref inspection
- **Logs:** Check `X-Plane 12/Resources/plugins/FlyToLearn/data/modules/SASLLog.txt` and X-Plane's own `Log.txt`
- **Config:** `flytolearn_config.ini` in `Custom Module/` folder — auto-generated, INI format

## Key Architectural Facts

- SASL components are loaded by `main.lua` in the `components = {}` table. `timer_library` MUST load before `flytolearn`.
- Every component with an `update()` function gets called every frame by SASL.
- `timer_library.lua`'s `update()` calls `updateAll(components)` — this is how child components receive their update cycles.
- Datarefs are accessed via `globalPropertyf()` / `globalPropertyi()` to get handles, then `get()` / `set()` to read/write values.
- UI is built with SASL `contextWindow{}` popups, not X-Plane native widgets.
- All settings live in the global `settings` table. The global `config` table is the serializable copy written to disk on shutdown.
- Airport detection uses `findNavAid(nil, nil, lat, lon, nil, NAV_AIRPORT)` — finds nearest airport to given coordinates.

## File Map

### Core files (in repo)
- `main.lua` — Entry point, global settings, config load/save, component registration
- `flytolearn.lua` — State machine, scoring logic, UI window creation, flight summary logging
- `timer_library.lua` — xLua-style timer functions adapted for SASL (MIT, by Jeffory J. Beckers)

### UI components (⚠️ NOT YET IN REPO — must be copied from X-Plane installation)
- `ftl_logo.lua`, `ftl_start.lua`, `ftl_options.lua`, `ftl_reboot.lua`, `ftl_score.lua`, `ftl_inflight.lua`, `keyboard_handler.lua`, `ui_button.lua`
- Source: `X-Plane 12/Resources/plugins/FlyToLearn/data/modules/Custom Module/`

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
- DEPARTING → INFLIGHT: Aircraft leaves the ground (`on_ground` → false)
- INFLIGHT → LANDED: Aircraft touches down AND min flight time (2 min) met
- INFLIGHT → DEPARTING: Touch down before min flight time (resets — prevents false triggers)
- LANDED → ENDED: Ground speed ≤ 0.01 (fully stopped)
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

## Active Work Item: Landing Quality Enhancement

### Status: BLOCKED — waiting on runway coordinates

**Next step:** Tom needs to install DataRefEditor, position aircraft at LFLJ Runway 04 threshold and end points, and record lat/lon coordinates.

### Agreed Requirements

1. **G-force penalties:**
   - Track PEAK G during entire landing roll (not just touchdown instant)
   - \> 2.5G = 5% score penalty (hard landing)
   - \> 3.5G = flight disqualified (crash)
   - X-Plane native crash detection → hard landing deduction only (no double penalty)

2. **Runway boundary checking (Courchevel LFLJ Rwy 04 first):**
   - Must land AND stop within runway rectangle
   - Off-runway = disqualified
   - Wrong runway (22) = disqualified with message: "Not designated runway — Please land on Courchevel Rwy 04"

3. **Score integration:**
   - Percentage-based deductions: `final_score = existing_score × (1 - penalties/100)`
   - Consistent with existing scoring architecture

### Functions to Implement

```lua
is_within_runway(lat, lon)          -- bool: inside Rwy 04 boundary?
calculate_landing_penalties()       -- number: percentage deduction
check_disqualification()            -- bool: DQ conditions met?
```

### Aviation Context for Courchevel

- One-way operations: land ONLY on Runway 04 (uphill), takeoff ONLY on Runway 22 (downhill)
- 18.5% gradient, 537m runway, ~6,588 ft elevation
- Landing on Runway 22 is prohibited in real operations
- The training route is LFHU (Altiport Huez) → LFLJ (Courchevel)

## Future Enhancements (Not Yet Started)

- Extend runway detection to work with any runway (not just hardcoded Courchevel)
- Landing quality grades: Butter / Soft / Firm / Hard / Crash
- Bounce detection (air→ground→air cycles within 10-15 second window)

## Known Bugs & Tech Debt

1. `xp_gnd_speed2` declared as `globalPropertyi` but dataref is float → type mismatch warning in SASL log
2. Typo: `flight_summary.score_wieght_time` (should be `weight`)
3. Many globals that should be locals (`flight_phase`, `start_time`, etc.)
4. Debug mode (`LOG_DEBUG`) left active in `main.lua` — switch to `LOG_INFO` for distribution
5. 8 UI component files + image assets not yet added to repo

## Coding Conventions

- **Ask before writing code** — Tom prefers to review approach and give permission before implementation
- Use percentage-based deductions for penalties, not multipliers
- Follow existing naming patterns (`FTL_PHASE_*` constants, `xp_*` dataref handles, `flight_summary.*` for log data)
- Keep UI logic in the `ftl_*.lua` component files, scoring logic in `flytolearn.lua`
- Use `debug_lib.on_debug()` for debug-only logging
- Write flight summaries as `.info` files to X-Plane root directory

## Useful Commands

```bash
# Find all Lua files in the plugin
find "X-Plane 12/Resources/plugins/FlyToLearn/" -name "*.lua"

# Watch SASL log for errors during development
tail -f "X-Plane 12/Resources/plugins/FlyToLearn/data/modules/SASLLog.txt"

# Check X-Plane log for plugin load issues
grep -i "flytolearn\|sasl" "X-Plane 12/Log.txt"
```
