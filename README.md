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

**Apex Rush** captures the fantasy of threading a modern open-wheel racing machine through tight street circuits at over 300 km/h. Built from the ground up in Godot 4, it merges the authentic atmosphere of Formula 1 with fast-paced, accessible arcade mechanics: instant throttle, responsive grip, overtake boost, and precision braking.

Whether chasing tenths against the Gold ghost car in **Time Trial** or fighting for race position across multi-lap sprints, every apex, kerb clip, and straightaway counts.

---

## ✨ Features

- 🏎️ **Arcade-Sim Hybrid Handling**: Top speeds exceeding 317 km/h (up to 364 km/h with overtake boost), sharp braking zones, and tuned floor-snap aerodynamics.
- 💨 **Active DRS (Drag Reduction System)**: Real-time detection and activation zones along high-speed straights. Opening the DRS wing flap boosts top end velocity and reduces high-speed drag.
- ⚡ **Overtake Boost (ERS)**: Passive energy recharge system with a high-drain boost mode that produces an exhaust visual glow, high-rev intake surge, and tarmac sparks.
- ⏱️ **Live Delta Telemetry & Multi-Tier Ghosts**: Micro-delta tracking sampled every 10 metres against Gold, Silver, and Bronze target lap times.
- ⏪ **Instant Flashback Rewind**: Tap `R` to rewind back to the previous checkpoint after a wall strike or spin; hold `R` to restart the session cleanly.
- 🛣️ **Procedural Spline Track Generation**: Dynamic Monaco-style street circuit generated via mathematical 3D Bézier splines complete with tarmac, barriers, multi-colored kerbs, start gantry, and harbour buildings.
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
| **DRS (in zone)** | `Spacebar` / `F` | `Right Bumper (RB / R1)` |
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
   git clone https://github.com/CodeVerse-AI-TS/f-12026.git
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
│   ├── car.gd               # Physics, input handling, DRS, boost mechanics
│   ├── car_model.gd         # Dynamic car geometry, liveries, sparks, wing animations
│   ├── chase_camera.gd      # Smooth dynamic multi-view camera controller
│   ├── engine_audio.gd      # Dynamic RPM pitch and exhaust audio synth
│   ├── game.gd              # Session rules, checkpoints, lap timers, flashbacks
│   ├── game_state.gd        # Persistent user settings, teams, audio volume
│   ├── ghost.gd             # Ghost car recording and playback
│   ├── hud.gd               # Speedometer, gear indicator, delta, sector splits
│   ├── track.gd             # Procedural 3D spline track, barriers, and buildings
│   ├── menu/                # Main menu UI logic
│   └── ui/                  # Pause menu, settings panels, and reusable UI components
├── shaders/                 # Custom GLSL / Godot shaders (film grade, lens flare)
└── starter/                 # Materials, urban textures, and visual packs
```

---

## 🤝 Contributing

Contributions are warmly welcomed! We are actively seeking pull requests for:
- 🏎️ New procedural and handcrafted circuits (Monza, Spa, Suzuka styles)
- 🌧️ Dynamic weather & wet track surface physics
- 🤖 Spline-based AI rival drivers for Quick Race mode
- 🔊 Expanded sound design (tyre squeal, curb thumps, wind noise)
- 🎮 Controller vibration / haptic feedback implementation
- 🌐 WebGL / HTML5 export optimization

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for our contribution guidelines, GDScript style conventions, and pull request workflow.

---

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details. Third-party asset attributions are detailed in [`LICENSES_SUMMER_ASSETS.md`](LICENSES_SUMMER_ASSETS.md).
