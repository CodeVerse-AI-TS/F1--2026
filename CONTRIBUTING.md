# Contributing to Apex Rush (F1 2026)

Thank you for your interest in contributing to **Apex Rush**! Open-source contributions from developers, 3D artists, sound designers, and racing enthusiasts make this project better for everyone.

---

## 🌟 Areas Where You Can Contribute

1. **Circuits & Track Design**:
   - Add new procedural tracks in `scripts/track.gd` (e.g., Monza high-speed oval, Spa elevation changes, Suzuka chicanes).
   - Implement track surface variety (varying grip levels, kerb heights).
2. **Gameplay & Physics**:
   - AI opponents that navigate the track curve spline with obstacle avoidance.
   - Dynamic weather conditions (rain particles, wet asphalt reflections, reduced grip).
   - Gamepad rumble / haptic feedback using Godot's `Input.start_joy_vibration`.
3. **Audio & Visual Effects**:
   - Sound effects: tyre squeal on tight cornering, kerb rumble, wind resistance audio.
   - Visual FX: heat haze exhaust shader, water spray on wet surfaces, motion blur.
4. **Platform & Web Optimization**:
   - Testing and tuning for Godot HTML5 / Web export.
   - Steam Deck / handheld gamepad input mapping.

---

## 🛠️ Development Workflow

### 1. Fork & Clone
1. Fork the repository on GitHub.
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/f-12026.git
   cd f-12026
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### 2. Working in Godot
- Use **Godot Engine 4.x** (Forward+ renderer).
- Keep changes modular:
  - Car physics and mechanics belong in `scripts/car.gd`.
  - Visuals, liveries, and meshes belong in `scripts/car_model.gd`.
  - Session rules, timers, and checkpoints belong in `scripts/game.gd`.
  - Track generation belongs in `scripts/track.gd`.

### 3. GDScript Style Guide
- Follow official Godot GDScript standards:
  - **Static Typing**: Use type hints wherever possible (`var speed: float = 0.0`, `func get_xform(off: float) -> Transform3D:`).
  - **Naming Conventions**:
    - `snake_case` for functions, variables, signals, and file names.
    - `PascalCase` for classes and preloaded script constants.
    - `SCREAMING_SNAKE_CASE` for constants.
  - **Comments**: Keep explanations concise and focused on "why", not just "what".

---

## 🚀 Submitting a Pull Request

1. Test your changes thoroughly by running the main scene (`F5` or `scenes/menu.tscn`).
2. Commit your changes with clear, descriptive commit messages:
   ```bash
   git commit -m "feat(physics): add gamepad haptic rumble on kerb strike"
   ```
3. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
4. Open a Pull Request against the `main` branch with:
   - A summary of the changes made.
   - Screenshots or a short recording (if visual or audio changes were introduced).
   - Any linked GitHub issues (e.g., `Closes #12`).

---

## 💡 Reporting Bugs & Requesting Features

- Use the GitHub **Issues** tab.
- Check existing issues before opening a duplicate.
- When filing a bug, include your OS version, Godot version, steps to reproduce, and any Godot console logs.
