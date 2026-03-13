# FlyToLearn Aviation Challenge

A SASL 3.x plugin for X-Plane 12 that scores student pilot flight performance. Built as an educational tool to provide objective, automated scoring for flight training scenarios.

**License:** MIT
**Author:** Tom
**Framework:** SASL 3.16.4 (Free Edition) — LuaJIT / Lua 5.1 compatible
**Platform:** X-Plane 12 (Mac, Windows, Linux)

---

## Two Plugins — One Repo

This repository contains two independent, self-contained plugins. Each can be installed on its own or both can run simultaneously in X-Plane 12 without conflict.

| Plugin | Version | Route | Scenery |
|--------|---------|-------|---------|
| **FlyToLearn Basic** | 1.3.2 | KBFI → KRNT (Seattle) | X-Plane 12 default demo scenery |
| **FlyToLearn Competition** | 1.4.2 | LFHU → LFLJ (French Alps) | Western Europe scenery required (built-in downloader) |

---

## What It Does

FlyToLearn runs inside X-Plane as a SASL plugin and tracks a flight from departure to arrival, then produces a score based on configurable weights for distance, payload, fuel efficiency, and elapsed time. It's designed for instructor-led training where students repeatedly fly specific routes and receive consistent, comparable scores.

### Scoring Formula

```
final_score = (weighted_distance × weighted_payload) / (weighted_time × weighted_fuel) × 100
```

Each factor has a configurable weight (0.5–2.0) adjustable through the in-sim UI. Landing quality penalties are applied after the base score is calculated.

### Landing Quality

| Result | Condition | Score Effect |
|--------|-----------|--------------|
| Clean | G-force ≤ 2.5 at landing | No deduction |
| Hard landing | G-force 2.5–3.5 | −5% penalty |
| Crash (DQ) | G-force > 3.5 | Score = 0 |
| Wrong runway (DQ) | Landed on prohibited runway | Score = 0 |
| Off runway (DQ) | Touched down off pavement | Score = 0 |

### Flight Phase State Machine

```
LIMBO → DEPARTING → INFLIGHT → LANDED → ENDED
```

- **LIMBO** — Plugin loaded, waiting for user to start a challenge
- **DEPARTING** — On ground, start button pressed, waiting for takeoff
- **INFLIGHT** — Airborne (confirmed by ≥ 20 m/s groundspeed), sim speed locked to 1×, tracking distance/fuel/time
- **LANDED** — Touched down, tracking peak G-force, calculating score
- **ENDED** — Stopped (groundspeed ≤ 0.01), score popup displayed, summary log written

**Edge case:** Touch-down before the 2-minute minimum resets to DEPARTING — prevents false scores from departure bounces.

---

## Repository Structure

```
flytolearn_plugin/
├── data/                                    # Competition source (v1.4.2, LFLJ)
│   └── modules/
│       ├── main.lua                         # Entry point, config, component loading
│       └── Custom Module/
│           ├── flytolearn.lua               # Core scoring logic & state machine
│           ├── timer_library.lua            # xLua-style timer functions for SASL
│           ├── ftl_logo.lua                 # Logo bar component
│           ├── ftl_start.lua                # Start screen UI
│           ├── ftl_options.lua              # Options/weights UI
│           ├── ftl_reboot.lua               # Screen change handler
│           ├── ftl_score.lua                # Score display UI
│           ├── ftl_inflight.lua             # Inflight status UI
│           ├── ftl_status.lua               # Status display
│           ├── flight_start.lua             # Flight start handler
│           ├── keyboard_handler.lua         # Input handling
│           ├── ui_button.lua                # Reusable button component
│           └── ui_assets/                   # PNG button images & RobotoCondensed font
├── FlyToLearn_Basic/                        # Basic plugin — v1.3.2, KBFI→KRNT
│   └── data/modules/                        # Same structure as above, KRNT coords
├── FlyToLearn_Competition/                  # Competition plugin — v1.4.2, LFHU→LFLJ
│   └── data/modules/                        # Same structure as above, LFLJ coords
├── docs/
│   ├── HANDOFF.md                           # Full project context & dev history
│   ├── ftl_test_plan.csv                    # 6-scenario landing quality test plan
│   ├── lflj_runway_coordinates.csv          # Confirmed in-sim runway coordinates
│   ├── FlyToLearn_Basic_Install_Instructions.html
│   ├── FlyToLearn_Basic_Flight_Instructions.html
│   ├── FlyToLearn_Competition_Install_Instructions.html
│   └── FlyToLearn_Competition_Flight_Instructions.html
├── CLAUDE.md                                # Claude Code project memory
├── README.md                                # This file
└── LICENSE                                  # MIT License
```

---

## Installation

For students, use the provided ZIP files. Each extracts to a folder that drops directly into `X-Plane 12/Resources/plugins/`.

- `FlyToLearn_Basic_v1.3.2.zip` → `Resources/plugins/FlyToLearn_Basic/`
- `FlyToLearn_Competition_v1.4.2.zip` → `Resources/plugins/FlyToLearn_Competition/`

Both ZIPs include all three platform binaries (Mac/Win/Linux). `flytolearn_config.ini` is excluded so students start with clean defaults.

See `docs/` for full installation and flight instruction sheets.

---

## Configuration

Settings are stored in `flytolearn_config.ini` inside each plugin folder and persist between sessions. Defaults:

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `distance_weight` | 1.0 | 0.5–2.0 | Multiplier for distance factor |
| `payload_weight` | 1.0 | 0.5–2.0 | Multiplier for payload factor |
| `fuel_weight` | 1.0 | 0.5–2.0 | Multiplier for fuel factor |
| `time_weight` | 1.0 | 0.5–2.0 | Multiplier for time factor |
| `min_flight_length` | 2 | minutes | Minimum airborne time before scoring counts |
| `alpha` | 1.0 | 0.25–1.0 | UI transparency |

---

## Development Setup

### Requirements

- **X-Plane 12** with SASL 3.16.4 (bundled with plugin)
- **VSCode** with Lua Language Server extension
- **DataRefEditor** (free from Laminar Research) — essential for debugging datarefs

### VSCode Configuration

```json
{
  "Lua.runtime.version": "LuaJIT"
}
```

### Key Datarefs

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
| `sim/flightmodel/forces/g_nrml` | float | Normal G-force (landing quality) |

---

## Changelog

### FlyToLearn Competition v1.4.2 — 2026-Mar-11
- Fixed false "en route" status at LFHU: added 20 m/s groundspeed threshold to DEPARTING→INFLIGHT transition (prevents false liftoff at terrain-complex mountain airports where `onground_all` returns 0 while stationary)
- Added position recording to flight log: takeoff lat/lon (at liftoff), touchdown lat/lon, landing stop lat/lon (when aircraft fully stops)
- Updated install instructions: XDD/DVD authentication flow, Western Europe scenery via X-Plane built-in downloader

### FlyToLearn Basic v1.3.2 — 2026-Mar-11
- Fixed false "en route" status at terrain-complex airports: 20 m/s groundspeed threshold added to liftoff detection
- Added position recording to flight log: takeoff lat/lon, touchdown lat/lon, landing stop lat/lon
- Updated install instructions: XDD/DVD authentication flow

### FlyToLearn Competition v1.4.0 — 2026-Mar-10
- Switched to LFLJ Courchevel production coordinates (from KRNT temp test config)
- Wrong-runway DQ message updated to reference Rwy 04
- Packaged as independent `FlyToLearn_Competition` plugin folder

### FlyToLearn Basic v1.3.0 — 2026-Mar-10
- KBFI → KRNT route established as permanent Basic training route
- Packaged as independent `FlyToLearn_Basic` plugin folder
- Wrong-runway DQ message references Rwy 16

### v1.2.0 — 2026-Mar-08
- Added landing quality: G-force monitoring, runway boundary detection, score penalties/DQ
- Fixed score screen layout — uniform spacing, landing quality line now visible
- Fixed landing quality font size (42 → 32) to prevent text overflow on long DQ messages
- Fixed critical longitude sign bug in KRNT coordinates (Western hemisphere = negative)
- Switched log level from LOG_DEBUG to LOG_INFO for distribution

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

## Training Scenarios

### Basic — KBFI → KRNT (Seattle)
Boeing Field to Renton Municipal Airport, ~3 nm, flat terrain, default X-Plane 12 demo scenery. Introductory route for new students. Land on Runway 16 (heading south, ~160°), approaching from the north.

### Competition — LFHU → LFLJ (French Alps)
Altiport Huez to Courchevel Altiport, ~25 nm through high Alpine terrain. Requires Western Europe scenery, installed via X-Plane's built-in scenery downloader (authenticate with XDD/DVD product key, select Western Europe region). One-way operations enforced: **must land Runway 04 only** (uphill, heading ~044°). Landing on Runway 22 is prohibited and results in immediate disqualification — matches real-world Courchevel operations.

---

## Future Enhancements

- Extend runway detection to work with any runway (not just hardcoded coordinates)
- Landing quality grades: Butter / Soft / Firm / Hard / Crash
- Bounce detection (track air→ground→air cycles within a short window)
- Review `flight_start.lua` and `ftl_status.lua` (discovered in X-Plane install, not yet documented)
