<div align="center">

# 🏎️ Apex Rush: F1 2026

**High-octane arcade F1 racing built in Godot 4 — where photoreal presentation meets exhilarating arcade handling.**

[![Godot Engine](https://img.shields.io/badge/Godot-4.x%20Forward%2B-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Web-blue)]()

</div>

---

## 🏁 Overview

**Apex Rush** captures the fantasy of threading a modern open-wheel racing machine through tight circuits at over 300 km/h. Built from the ground up in Godot 4, it merges the authentic atmosphere of Formula 1 with fast-paced, accessible arcade mechanics: instant throttle, responsive grip, overtake boost, and precision braking.

Compete against intelligent **AI rivals** in multi-lap Grand Prix sprints with active **pit stops and tyre strategy**, or chase tenths against the Gold ghost car in **Time Trial**.

---

## ✨ Features

- 🏎️ **Arcade-Sim Hybrid Handling**: Top speeds exceeding 317 km/h (up to 364 km/h with overtake boost), sharp braking zones, and tuned floor-snap aerodynamics.
- 🤖 **Grid Start & AI Rivals**: Full race grids against intelligent AI drivers that follow braking-aware speed curves, overtake, defend position, and execute pit strategies.
- 🛞 **Tyre Wear & Thermal Simulation**: Soft, Medium, Hard, Intermediate, and Wet compounds with per-wheel degradation, temperature windows, and cliff drops past 80% wear.
- ⛽ **Fuel Mass Dynamics**: Fuel burns off with throttle and boost usage, making the car lighter and more agile over the course of a stint.
- 🛠️ **Active Pit Lane & Crew Stops**: Request a pit stop (`P`), manage the 80 km/h pit lane speed limiter, and receive fresh rubber in animated pit stalls.
- 💨 **Active DRS (Drag Reduction System)**: Real-time detection and activation zones along high-speed straights. Opening the DRS wing flap boosts top end velocity and reduces drag.
- ⚡ **Overtake Boost (ERS)**: Passive energy recharge system with a high-drain boost mode producing an exhaust glow, high-rev intake surge, and tarmac sparks.
- 🚦 **5-Red-Lights Race Starts**: Authentic start sequence with randomized lights-out delays for true reaction tests.
- ⏱️ **Live Delta Telemetry & Standings**: Real-time position tracking (`P1..Pn`), gap to car ahead, micro-delta tracking sampled every 10m, and sector splits.
- ⏪ **Instant Flashback Rewind**: Tap `R` to rewind back to the previous checkpoint after a wall strike or spin; hold `R` to restart cleanly.
- 🛣️ **5 Procedural Circuit Presets & Themes**:
  - **Monte Carlo Street Circuit**: Iconic harbour barriers, tight chicanes, and elevation changes.
  - **Ocean Speedway**: Wide, banked high-speed sweepers built for maximum top speed.
  - **Alpine Tech Park**: Precision-demanding switchbacks and technical elevation drops.
  - **Dune Coast Circuit**: Flowing desert and coastal curves in high ambient heat.
  - **Harbour Night Sprint**: Floodlit walls under nocturnal lighting conditions.
- 🎥 **Multi-Angle Cameras**: Seamless toggling between aggressive close chase, cockpit, hood, and dynamic broadcast angles.
- 🎨 **PBR Shading & Post-Processing**: Custom cinematic film-grade color grading shaders, lens flare effects, and physically based car materials.

---

## 🎮 Controls

| Action | Keyboard | Controller / Gamepad |
| :--- | :--- | :--- |
| **Accelerate** | `W` or `Up Arrow` | `Right Trigger (RT / R2)` |
| **Brake / Reverse** | `S` or `Down Arrow` | `Left Trigger (LT / L2)` |
| **Steer Left / Right** | `A` / `D` or `Left` / `Right` | `Left Stick` |
| **Overtake Boost** | `Spacebar` | `A / X button` |
| **DRS (in zone)** | `Spacebar` / `E` | `Right Bumper (RB / R1)` |
| **Pit Request (Box Box)** | `P` | `D-Pad Down` |
| **Select Next Tyres** | `1` (Soft), `2` (Med), `3` (Hard), `4` (Wet) | `D-Pad Left / Right` |
| **Flashback (Rewind)** | `R` (Tap) | `Y / Triangle` (Tap) |
| **Restart Race** | `R` (Hold 1s) | `Y / Triangle` (Hold 1s) |
| **Cycle Camera** | `C` | `D-Pad Up` |
| **Pause / Menu** | `Escape` | `Start / Options` |

---

## 🚀 Quickstart & Setup

### Prerequisites
- [Godot Engine 4.x](https://godotengine.org/download) (Forward+ or Mobile renderer compatible)

### Running Locally
1. Clone the repository:
   ```bash
   git clone https://github.com/CodeVerse-AI-TS/F1--2026.git
   ```
2. Open **Godot Engine**.
3. Click **Import**, navigate to the cloned folder, select `project.godot`, and click **Import & Edit**.
4. Press **`F5`** (or the Play button in the top right) to launch the game starting from `scenes/menu.tscn`.

---

## 📂 Project Architecture

```
f-12026/
├── assets/                  # 3D models, textures, sounds, and icons
├── scenes/
│   ├── main.tscn            # Primary 3D race circuit scene
│   └── menu.tscn            # Main menu, team selection, and settings
├── scripts/
│   ├── ai_car.gd            # Autonomous rival AI with pathfinding and pit tactics
│   ├── car.gd               # Physics, input handling, DRS, fuel mass, and pit limiter
│   ├── car_model.gd         # Dynamic car geometry, liveries, sparks, wing animations
│   ├── chase_camera.gd      # Smooth dynamic multi-view camera controller
│   ├── engine_audio.gd      # Dynamic RPM pitch and exhaust audio synth
│   ├── game.gd              # Session rules, race starts, pit crew servicing, flashbacks
│   ├── game_state.gd        # Track presets, environmental themes, teams, persistent config
│   ├── ghost.gd             # Ghost car recording and playback
│   ├── hud.gd               # Speedometer, tyre telemetry, standings, and start lights
│   ├── track.gd             # Procedural 3D spline tracks, pit lane, and buildings
│   ├── tyre_model.gd        # Soft/Med/Hard/Wet tyre compounds, wear, and thermal grip
│   ├── menu/                # Main menu UI logic
│   └── ui/                  # Pause menu, settings panels, and reusable UI components
├── shaders/                 # Custom GLSL / Godot shaders (film grade, lens flare)
└── starter/                 # Materials, urban textures, and visual packs
```

---

## 🤝 Contributing & Roadmap

We are actively seeking contributions for our upcoming milestones! See [`ROADMAP.md`](ROADMAP.md) for the active development checklist.

Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) for our contribution guidelines, GDScript style conventions, and pull request workflow.

---

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details. Third-party asset attributions are detailed in [`LICENSES_SUMMER_ASSETS.md`](LICENSES_SUMMER_ASSETS.md).
