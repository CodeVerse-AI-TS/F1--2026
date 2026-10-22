# 🗺️ Apex Rush (F1 2026) Project Roadmap

This roadmap tracks the ongoing development of **Apex Rush**. Community contributions, issues, and pull requests are welcomed across all milestones.

---

## ✅ Completed in v1.3.0 (Grand Prix & Immersion Overhaul)

- [x] **Authentic Grand Prix Circuits & Dynamic Banking**:
  - Monte Carlo Street Circuit with Casino climb, Portier rock tunnel, descent gallery, and flyover crossing over the start straight.
  - Spa-Francorchamps with 40m elevation climb through Eau Rouge and Raidillon.
  - Autodromo Nazionale Monza featuring Rettifilo, Curva Grande, Ascari, and Parabolica.
  - Silverstone Circuit with Maggotts-Becketts-Chapel and Hangar Straight underpass.
  - Suzuka Circuit with iconic figure-eight crossover.
- [x] **Procedural 3D Tunnel Architecture & Viaducts**: Arched vault ceilings, overhead fluorescent tube lights, structural bridge piers, and realistic concrete soffits.
- [x] **Interactive Steering Wheel LCD Multi-Function Display (MFD)**: Cockpit digital gear counter, live speedometer, and 5-stage progressive shift light LEDs.
- [x] **Brake Countdown Distance Boards**: Procedural 150m, 100m, and 50m foam marker boards erected along barriers before heavy braking zones.
- [x] **Procedural Team Radio & Pit-Wall Audio**: Walkie-talkie chirp synthesis and broadcast team radio subtitle banners for safety cars and race control.
- [x] **Advanced Audio Synthesis**: Ignition-cut pneumatic exhaust pops on upshifts, kerb rumble vibration audio, and multi-tap concrete tunnel echo.
- [x] **Visual FX Expansion**: Tyre lock-up smoke particle emitters and refractive exhaust heat shimmer during throttle application.
- [x] **Post-Race Podium & Championship Trophies**: 3-tier podium celebration screen with Gold, Silver, and Bronze trophies and FIA points classification.
- [x] **Visibility & Tonemapping Overhaul**: ACES tonemapper with restrained exposure, glow threshold raised to 1.15 to prevent tarmac bloom, and elevated Chase Camera forward sightlines.

---

## ✅ Completed in v1.2.0

- [x] **Full Championship Season**: 5-round calendar with qualifying sessions, official F1 points scoring (25-18-15-12-10-8-6-4-2-1), and persistent driver/constructor standings.
- [x] **Dynamic Weather & Rain Physics**: CPU particle rain emitters, dynamic wetness transitions (Dry, Damp, Light Rain, Heavy Rain), and tyre compound water grip scaling.
- [x] **Safety Car System**: Deploys on major incidents, illuminates amber flashing roof lights, neutralises the race, and bunches the field at a governed pace.
- [x] **Hyper-Competitive AI Overhaul**: AI drivers now deploy ERS overtake boosts (~98 m/s), take slipstream drafts (+12% acceleration), execute inside-line divebombs in braking zones, and defend lines.
- [x] **Directional Minimap Marker**: Real-time 2D radar with animated heading chevron, pulsating radar halo, and live position tag (`P1..Pn`).
- [x] **Autonomous AI Rivals**: Spline-pathfinding AI drivers with individual skill, aggression, overtaking, defending, and pit stop tactics.
- [x] **Tyre Degradation & Compounds**: Realistic physics simulation of Soft, Medium, Hard, Intermediate, and Wet compounds with wear cliffs and thermal windows.
- [x] **Active Pit Lane Infrastructure**: Procedural pit lane road mesh, garages, illuminated pit boxes, and 80 km/h speed limiter enforcement.
- [x] **Pit Stop Servicing**: Crew servicing sequence with randomized stop durations, tyre swapping, and fuel replenishment.
- [x] **Multi-Track Presets**:
  - Monte Carlo Street Circuit (harbour walls, precision street lap)
  - Ocean Speedway (high-speed oval sweepers)
  - Alpine Tech Park (elevation changes and sharp technical corners)
  - Dune Coast Circuit (fast flowing coastal curves)
  - Harbour Night Sprint (floodlit evening street race)
- [x] **Environmental Themes**: Street, Speed, Technical, Desert, and Night lighting presets.
- [x] **5-Red-Lights Grid Start**: Authentic Formula 1 starting sequence with random reaction delays.
- [x] **Persistent Local Leaderboards**: Automatic submission of best lap times and race completions per circuit.

---

## 🚀 Upcoming Milestones (Help Wanted)

### 🎮 Milestone 3: Input & Audio Polish
- [ ] Controller vibration / haptic rumble on kerb strikes and wall impacts (`Input.start_joy_vibration`).
- [ ] Dynamic tyre screech audio on lateral grip loss.
- [ ] High-speed wind rush sound scaling from 200 to 360 km/h.
- [ ] Custom key rebinding menu in settings.

### 🌐 Milestone 4: WebGL & Handheld Optimization
- [ ] Automated HTML5 Web export with GitHub Pages / Itch.io deployment.
- [ ] Steam Deck controller configuration and 16:10 aspect ratio adjustments.
- [ ] Mobile touch controls overlay for Android / iOS builds.

### ⏱️ Milestone 5: Global Leaderboards & Online Time Trials
- [ ] Lightweight backend API for global lap time submissions.
- [ ] In-game leaderboard browser showing top ghost times per circuit.
