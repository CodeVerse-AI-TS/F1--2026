extends Control
## Screen-edge speed streaks. Thin radial lines that lengthen and brighten with
## speed and turn blue while boosting, so 300+ km/h reads as fast without a
## post-process shader. Angles are seeded once so the streaks never shimmer.

## 0..1, driven by the session from the car's speed.
var amount := 0.0
## 0..1, 1 while the overtake boost is open.
var boost := 0.0

var _t := 0.0
## Each entry: x = angle, y = length scale, z = pulse phase.
var _seeds: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	for i in 96:
		_seeds.append(Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.35, 1.0),
			rng.randf_range(0.0, 1.0)))

## speed 0..1 (fraction of top speed), boost flag from car.boosting.
func set_speed(speed: float, boosting := false) -> void:
	amount = clampf(speed, 0.0, 1.0)
	boost = 1.0 if boosting else 0.0

func _process(delta: float) -> void:
	if amount <= 0.01 and boost <= 0.01:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var alpha := amount * 0.5 + boost * 0.3
	if alpha <= 0.01:
		return
	var c := size * 0.5
	var reach := maxf(size.x, size.y) * 0.75
	for s in _seeds:
		var dir := Vector2(cos(s.x), sin(s.x))
		var pulse := 0.6 + 0.4 * sin(_t * 9.0 + s.z * TAU)
		# streaks start further out at low speed and sweep in towards the middle
		var inner := reach * (0.46 + 0.24 * (1.0 - amount))
		var seg := reach * 0.34 * s.y * (0.35 + amount) * pulse
		var p0 := c + dir * inner
		var col := Color(1.0, 1.0, 1.0, alpha * 0.32 * s.y)
		if boost > 0.01:
			col = col.lerp(Color(0.45, 0.8, 1.0, col.a), boost)
		draw_line(p0, p0 + dir * seg, col, 1.4 + 2.2 * s.y, true)
