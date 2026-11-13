# CLAUDE.md — FlyToLearn Plugin Project Memory

This file provides context for Claude Code (or any Claude instance) working on this project. Read this before making changes.

## Project Identity

- **Name:** FlyToLearn Aviation Challenge
- **Type:** SASL 3.16.4 plugin for X-Plane 12
- **Language:** Lua (LuaJIT / Lua 5.1 compatible)
- **Versions:** FlyToLearn Basic 1.3.4 / FlyToLearn Competition 1.4.4
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

Transitions (Basic v1.3.4 — body-AGL detection):
- LIMBO → DEPARTING: User clicks "Start" button. Captures `start_y_agl = get(xp_agl)` as the on-ground baseline body height (varies by aircraft: ~1.5m Cessna, ~3m airliner).
- DEPARTING → INFLIGHT: `xp_agl > start_y_agl + LIFTOFF_DELTA_M` (1.0m above on-ground baseline) — confirms solidly airborne — records `takeoff_lat/lon`
  - Uses `sim/flightmodel/position/y_agl` (aircraft body AGL). Geometric measurement immune to aerodynamic-unloading bug that plagued `onground_all`.
- INFLIGHT → LANDED: `xp_agl < start_y_agl + TOUCHDOWN_DELTA_M` (0.2m above on-ground baseline ≈ wheel contact) AND min flight time (2 min) met — records `touchdown_lat/lon` from pre-captured position
  - Pre-capture: while INFLIGHT, continuously saves lat/lon when `xp_agl < start_y_agl + PRE_CAPTURE_DELTA_M` (0.5m) AND `vh_ind_fpm2 < 0` (descending).
- INFLIGHT → DEPARTING: Touch down before min flight time (resets — prevents false triggers / bounce-on-takeoff)
- LANDED → ENDED: Ground speed ≤ 0.01 (fully stopped) — records `landing_stop_lat/lon`
- Any phase → LIMBO: User clicks "Cancel"

**Note:** Competition v1.4.4 still uses the broken v1.3.3 design with `sim/flightmodel2/gear/y_agl` (a non-existent dataref) — state machine freezes in DEPARTING. Mirror Basic v1.3.4 changes into Competition once Basic is verified across platforms.

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

-- Performance
sim/flightmodel/forces/g_nrml           -- float, normal G-force
sim/flightmodel/position/vh_ind_fpm     -- float, vertical speed fpm (instrument-lagged, used in score log)
sim/flightmodel/position/vh_ind_fpm2    -- float, instantaneous vertical speed fpm (no lag, used in touchdown pre-capture)
sim/flightmodel/position/y_agl          -- float, aircraft body height above ground in meters (primary ground detection in Basic v1.3.4)
-- DO NOT use: sim/flightmodel2/gear/y_agl — does NOT exist (verified via Log.txt and master DataRefs.txt). The CLAUDE.md and v1.3.3 code referenced it incorrectly.
-- Fallback candidate: sim/flightmodel2/position/y_agl (alternate body AGL, also in master DataRefs.txt)
-- Verify dataref existence in: /Users/tom.dubick/X-Plane 12/Resources/plugins/DataRefs.txt

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

- One-way operations: land ONLY on Runway 22 (uphill), takeoff ONLY on Runway 04 (downhill)
- 18.5% gradient, 537m runway, ~6,588 ft elevation
- Landing on Runway 04 is prohibited in real operations
- The competition route is LFHU (Altiport Huez) → LFLJ (Courchevel)

## Future Enhancements (Not Yet Started)

- Extend runway detection to work with any runway (not just hardcoded Courchevel)
- Landing quality grades: Butter / Soft / Firm / Hard / Crash
- Bounce detection (air→ground→air cycles within 10-15 second window)

## Recent Changes

### 2026-04-26 — Basic v1.3.4 — Body-AGL detection (replaces broken gear/y_agl)

Replaced the v1.3.3 gear-based detection (which used `sim/flightmodel2/gear/y_agl` — a dataref that does NOT exist in this X-Plane install, confirmed via Log.txt warning `findDataRef ... not found` and master DataRefs.txt search).

**Root cause:** The v1.3.3 dataref name was wrong/invented. State machine froze in DEPARTING because `min_gear_y_agl()` errored every frame on `math.min(nil, nil, nil)`.

**Fix:** Use `sim/flightmodel/position/y_agl` (aircraft body AGL — verified existing). Capture on-ground baseline `start_y_agl = get(xp_agl)` at Start click, then use three deltas:
- `LIFTOFF_DELTA_M = 1.0` — confirms INFLIGHT when body 1m above on-ground baseline
- `PRE_CAPTURE_DELTA_M = 0.5` — pre-capture touchdown lat/lon when body within 0.5m of baseline AND descending
- `TOUCHDOWN_DELTA_M = 0.2` — fires INFLIGHT → LANDED when body within 0.2m of baseline (~wheel contact)

Auto-adapts to any aircraft regardless of body height. Geometric measurement is immune to the aerodynamic-unloading bug that plagued `onground_all`. Both Bug 1 (false liftoff at 45 kts) and Bug 2 (late touchdown at 45 kts) remain prevented.

**Verified:** Working on Tom's Mac. Windows compatibility unknown — pending school PC test.

**Outstanding:** Competition v1.4.4 still has the v1.3.3 broken code. Mirror once Basic is cross-platform verified.

### 2026-04-26 — v1.3.3 / v1.4.4 — Touchdown detection rewrite (BROKEN — see v1.3.4)

Attempted to use `sim/flightmodel2/gear/y_agl` for per-wheel height detection. The dataref doesn't exist; this version freezes the state machine in DEPARTING. Use v1.3.4 (Basic) instead.

---

## Known Bugs & Tech Debt

1. **Competition v1.4.4 is broken** — uses non-existent `sim/flightmodel2/gear/y_agl`. State machine freezes in DEPARTING. Needs v1.3.4-style body-AGL fix mirrored over.
2. **`configuration.ini` is required but NOT in git repo.** SASL plugin won't load without `<plugin_root>/data/modules/configuration/configuration.ini`. Tom manually placed it for the installed Basic plugin. Any fresh `git clone` install will fail until this is added. Should be committed to repo (or generated on install).
3. `xp_gnd_speed2` declared as `globalPropertyf` but referenced inconsistently → type mismatch warning in SASL log
4. Typo: `flight_summary.score_wieght_time` (should be `weight`)
5. Many globals that should be locals (`flight_phase`, `start_time`, etc.)
6. `flight_start.lua` and `ftl_status.lua` discovered in X-Plane installation but not yet documented — purpose unknown
7. Per-frame debug `print()` calls in `ftl_status.lua` and `ftl_logo.lua` — log spam

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
