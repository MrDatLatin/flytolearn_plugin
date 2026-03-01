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

## Repository Structure

```
flytolearn_plugin/
├── data/
│   └── modules/
│       ├── main.lua                  # Entry point, config, component loading
│       ├── flytolearn.lua            # Core scoring logic & state machine
│       ├── timer_library.lua         # xLua-style timer functions for SASL
│       ├── Custom Module/
│       │   ├── ftl_logo.lua          # ⚠️ NOT YET IN REPO — Logo bar component
│       │   ├── ftl_start.lua         # ⚠️ NOT YET IN REPO — Start screen UI
│       │   ├── ftl_options.lua       # ⚠️ NOT YET IN REPO — Options/weights UI
│       │   ├── ftl_reboot.lua        # ⚠️ NOT YET IN REPO — Screen change handler
│       │   ├── ftl_score.lua         # ⚠️ NOT YET IN REPO — Score display UI
│       │   ├── ftl_inflight.lua      # ⚠️ NOT YET IN REPO — Inflight status UI
│       │   ├── keyboard_handler.lua  # ⚠️ NOT YET IN REPO — Input handling
│       │   └── ui_button.lua         # ⚠️ NOT YET IN REPO — Reusable button component
│       └── Custom Module/
│           └── flytolearn_config.ini # Runtime config (auto-generated)
├── docs/
│   ├── HANDOFF.md                    # Full project context & design decisions
│   └── xplane-developer-documentation-reference.md
├── CLAUDE.md                         # Claude Code project memory
├── README.md                         # This file
├── CHANGELOG.md                      # Version history
└── LICENSE                           # MIT License
```

### ⚠️ Missing Files

The following UI component files are referenced by `main.lua` and `flytolearn.lua` but have **not yet been added to the repository**. They must be copied from the working X-Plane installation:

**Source location on disk:**
```
X-Plane 12/Resources/plugins/FlyToLearn/data/modules/Custom Module/
```

Files needed:
- `ftl_logo.lua` — Logo/status bar drawn at bottom of X-Plane screen
- `ftl_start.lua` — Start screen with departure airport detection
- `ftl_options.lua` — Scoring weight adjustment UI
- `ftl_reboot.lua` — Screen resolution change handler
- `ftl_score.lua` — Final score display
- `ftl_inflight.lua` — In-flight status display
- `keyboard_handler.lua` — Keyboard input handling
- `ui_button.lua` — Reusable button drawing component

Also needed (image assets):
- `defdecore.png` — Window decoration texture
- `interactive.png` — Interactive element texture
- `cursors.png` — Cursor textures
- Any FTL logo/branding images used by `ftl_logo.lua`

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

See [HANDOFF.md](docs/HANDOFF.md) for full details on the next phase of development:

- **Landing quality scoring** — G-force monitoring with penalties for hard landings
- **Runway boundary detection** — Verify landing on correct runway (starting with Courchevel LFLJ Rwy 04)
- **Crash detection integration** — Hook into X-Plane's native crash system
- **Landing grades** — Butter/Soft/Firm/Hard/Crash categories (future)

---

## Training Scenario: LFHU → LFLJ

The primary training route is Altiport Huez (LFHU) to Courchevel (LFLJ), a challenging mountain flying exercise in the French Alps.

- **Departure:** LFHU — downhill takeoff
- **Arrival:** LFLJ Runway 04 — mandatory uphill landing (one-way operations)
- **Tip:** Use X-Plane's **File → Save Flight** to create a reusable starting position at LFHU so students don't have to taxi and turn around each time.
