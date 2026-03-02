# FlyToLearn Aviation Challenge

A SASL 3.x plugin for X-Plane 12 that scores student pilot flight performance. Built as an educational tool to provide objective, automated scoring for flight training scenarios.

**Current Version:** 1.1.3  
**License:** MIT  
**Author:** Tom  
**Framework:** SASL 3.16.4 (Free Edition) — LuaJIT / Lua 5.1 compatible  
**Platform:** X-Plane 12 (Windows confirmed; macOS/Linux untested)

---

## What It Does

FlyToLearn runs inside X-Plane as a SASL plugin and tracks a flight from departure to arrival, then produces a score based on configurable weights for distance, payload, fuel efficiency, and elapsed time. It's designed for instructor-led training where students repeatedly fly specific routes (e.g., LFHU → LFLJ in the French Alps) and receive consistent, comparable scores.

### Scoring Formula

```
final_score = (weighted_distance × weighted_payload) / (weighted_time × weighted_fuel) × 100
```

Each factor has a configurable weight (0.5–2.0) adjustable through the in-sim UI.

### Flight Phase State Machine

```
LIMBO → DEPARTING → INFLIGHT → LANDED → ENDED
```

- **LIMBO** — Plugin loaded, waiting for user to start a challenge
- **DEPARTING** — On ground, start button pressed, waiting for takeoff
- **INFLIGHT** — Airborne, sim speed locked to 1x, tracking distance/fuel/time
- **LANDED** — Touched down, calculating score, finding arrival airport
- **ENDED** — Stopped (groundspeed ≤ 0.01), score popup displayed, summary log written

### Flight Summary Logging

Each completed flight writes a `.info` file to the X-Plane root directory with raw X-Plane data, converted values, scoring weights, and final score.

---

## Repository

**GitHub:** https://github.com/MrDatLatin/flytolearn_plugin

## Repository Structure

```
flytolearn_plugin/
├── data/
│   └── modules/
│       ├── main.lua                      # Entry point, config, component loading
│       └── Custom Module/
│           ├── flytolearn.lua            # Core scoring logic & state machine
│           ├── timer_library.lua         # xLua-style timer functions for SASL
│           ├── ftl_logo.lua              # Logo bar component
│           ├── ftl_start.lua             # Start screen UI
│           ├── ftl_options.lua           # Options/weights UI
│           ├── ftl_reboot.lua            # Screen change handler
│           ├── ftl_score.lua             # Score display UI
│           ├── ftl_inflight.lua          # Inflight status UI
│           ├── ftl_status.lua            # Status display
│           ├── flight_start.lua          # Flight start handler
│           ├── keyboard_handler.lua      # Input handling
│           ├── ui_button.lua             # Reusable button component
│           └── ui_assets/                # ⚠️ NOT YET IN REPO — PNG images & fonts
├── docs/
│   └── HANDOFF.md                        # Full project context & design decisions
├── CLAUDE.md                             # Claude Code project memory
├── README.md                             # This file
└── LICENSE                               # MIT License
```

### ⚠️ Still Needed

The `ui_assets/` folder containing PNG button images and the RobotoCondensed font has not yet been copied into the repo. Source location:

```
X-Plane 12/Resources/plugins/FlyToLearn/data/modules/Custom Module/ui_assets/
```

---

## Installation

1. Copy the `FlyToLearn/` folder to `X-Plane 12/Resources/plugins/`
2. The folder structure inside X-Plane should be:
   ```
   X-Plane 12/
   └── Resources/
       └── plugins/
           └── FlyToLearn/
               └── data/
                   └── modules/
                       ├── main.lua
                       ├── flytolearn.lua
                       ├── timer_library.lua
                       └── Custom Module/
                           ├── ftl_logo.lua
                           ├── ftl_start.lua
                           ├── ... (other UI files)
                           └── flytolearn_config.ini
   ```
3. Launch X-Plane 12 — the plugin loads automatically
4. Access via **Plugins → Fly To Learn → Show Fly To Learn**

---

## Configuration

Settings are stored in `flytolearn_config.ini` and persist between sessions. Defaults:

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `distance_weight` | 1.0 | 0.5–2.0 | Multiplier for distance factor |
| `payload_weight` | 1.0 | 0.5–2.0 | Multiplier for payload factor |
| `fuel_weight` | 1.0 | 0.5–2.0 | Multiplier for fuel factor |
| `time_weight` | 1.0 | 0.5–2.0 | Multiplier for time factor |
| `min_flight_length` | 2 | minutes | Minimum flight time to count |
| `alpha` | 1.0 | 0.25–1.0 | UI transparency |

---

## Development Setup

### Requirements

- **X-Plane 12** with SASL 3.16.4 (bundled with plugin)
- **VSCode** with Lua Language Server extension
- **DataRefEditor** (free from Laminar Research) — essential for debugging

### VSCode Configuration

Point your workspace at the plugin modules folder and configure for LuaJIT:

```json
{
  "Lua.runtime.version": "LuaJIT"
}
```

The `api.lua` file in the repo provides SASL function annotations for autocomplete.

### Useful DataRefs

The plugin currently reads these X-Plane datarefs:

| Dataref | Type | Usage |
|---------|------|-------|
| `sim/flightmodel/position/latitude` | float | Aircraft position |
| `sim/flightmodel/position/longitude` | float | Aircraft position |
| `sim/flightmodel/controls/dist` | float | Distance traveled (meters) |
| `sim/time/total_flight_time_sec` | float | Flight time |
| `sim/flightmodel/weight/m_total` | float | Total aircraft weight |
| `sim/flightmodel/weight/m_fuel_total` | float | Fuel weight |
| `sim/aircraft/weight/acf_m_empty` | float | Empty weight |
| `sim/flightmodel2/position/groundspeed` | float | Ground speed |
| `sim/flightmodel/failures/onground_all` | int | Ground contact |
| `sim/flightmodel/forces/g_nrml` | float | Normal G-force |
| `sim/flightmodel/position/vh_ind_fpm` | float | Vertical speed (fpm) |

### Debug Mode

`main.lua` line 29 controls log verbosity:
```lua
sasl.setLogLevel(LOG_DEBUG)   -- development (current)
-- sasl.setLogLevel(LOG_INFO)  -- distribution
```

---

## Changelog

### v1.1.3 — 2024-Apr-02
- Changed final score calculation, rounded log values to 4 digits

### v1.1.2 — 2024-Apr-02
- Added X-Plane raw data to log files

### v1.1.1 — 2024-Mar-22
- Divided final score by 100
- Added minimum flight time of 2 minutes (configurable)

### v1.1.0 — 2024-Mar-20
- Corrected scoring algorithm

### v1.0.1 — 2024-Feb-26
- Added Plugins menu toggle for show/hide
- Reduced dead mouse area at bottom of screen

---

## Planned Enhancements

See [HANDOFF.md](docs/HANDOFF.md) for full implementation details.

### Implemented — Pending Test: Landing Quality Enhancement
Coded March 1, 2026. Deployed to X-Plane. Commit `3185df0`. Version bump to **1.2.0** after successful test.

- **G-force monitoring** ✅ — Peak G tracked across full landing roll (not just touchdown instant)
  - > 2.5G = 5% score penalty (hard landing)
  - > 3.5G = flight disqualified (crash)
- **Runway boundary detection** ✅ — Rotated rectangle check against confirmed LFLJ Rwy 04 coordinates
  - Off-runway landing = disqualification
  - Landing on wrong runway (Rwy 22) = disqualification with specific message
- **Score integration** ✅ — Percentage-based deductions applied after base score calculation
- **Score screen updates** ✅ — Landing quality line added to final score display

### Future
- Extend runway detection to any runway (not just hardcoded Courchevel)
- Landing quality grades: Butter / Soft / Firm / Hard / Crash
- Bounce detection

---

## Training Scenario: LFHU → LFLJ

The primary training route is Altiport Huez (LFHU) to Courchevel (LFLJ), a challenging mountain flying exercise in the French Alps.

- **Departure:** LFHU — downhill takeoff
- **Arrival:** LFLJ Runway 04 — mandatory uphill landing (one-way operations)
- **Tip:** Use X-Plane's **File → Save Flight** to create a reusable starting position at LFHU so students don't have to taxi and turn around each time.
