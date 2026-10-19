# 🗺️ Apex Rush (F1 2026) Project Roadmap

This roadmap tracks the ongoing development of **Apex Rush**. Community contributions, issues, and pull requests are welcomed across all milestones.

---

## ✅ Completed in v1.1.0

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
- [x] **Live Race Standings**: Real-time position tracking (`P1..Pn`), gap to car ahead, and post-race classification board.

---

## 🚀 Upcoming Milestones (Help Wanted)

### 🌧️ Milestone 2: Dynamic Weather & Wet Physics (In Progress)
- [ ] Dynamic rain particle system attached to the camera.
- [ ] Wet asphalt shader with screen-space puddles and spray reflections.
- [ ] Grip reduction calculation based on track saturation and tyre compound suitability.
- [ ] Tyre spray particle effects behind car diffuser at high speeds.

### 🎮 Milestone 3: Input & Audio Polish
- [x] **Circuit Minimap Overlay**: Real-time 2D track radar with live player and AI car blips.`n- [ ] Controller vibration / haptic rumble on kerb strikes and wall impacts (`Input.start_joy_vibration`).
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
