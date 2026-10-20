extends CanvasLayer
## Race HUD: lap timer and splits, targets, speed/gear/rpm, Overtake Boost meter, toasts.

const GOLD := Color(1.0, 0.8, 0.35)
const SILVER := Color(0.82, 0.86, 0.92)
const BRONZE := Color(0.85, 0.55, 0.32)
const GREEN := Color(0.35, 1.0, 0.45)
const PURPLE := Color(0.8, 0.45, 1.0)
const RED := Color(1.0, 0.3, 0.25)

const MinimapScript = preload("res://scripts/ui/minimap.gd")
const SpeedFxScript = preload("res://scripts/ui/speed_fx.gd")
const GameState = preload("res://scripts/game_state.gd")

var _minimap: Control
var _minimap_panel: Panel

var _lap: Label
var _best: Label
var _splits: Array[Label] = []
var _targets: Label
var _speed: Label
var _gear: Label
var _rpm: ProgressBar
var _boost: ProgressBar
var _boost_label: Label
var _toast: Label
var _title: Control
var _toast_t := 0.0
var _lap_head: Label
var _unit_label: Label
var _ring: Control
var _drs_panel: Panel
var _drs_style: StyleBoxFlat
var _drs_label: Label
var _leds: Array[ColorRect] = []
var _delta: Label
var _gap: Label
## Screen-edge streaks: added first so they sit behind every panel.
var _speed_fx: Control

const DRS_COLORS := [Color(0.25, 0.25, 0.28, 0.85), Color(1.0, 0.65, 0.1, 0.95), Color(0.2, 0.9, 0.3, 0.95)]
const LED_COUNT := 15

func _ready() -> void:
	# speed streaks first, so every panel draws on top of them
	_speed_fx = SpeedFxScript.new()
	add_child(_speed_fx)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# top-left timing panel
	var tl := _panel(root, Vector2(24, 24), Vector2(330, 196))
	_lap_head = _label(tl, "LAP", 14, Color(0.7, 0.7, 0.75), Vector2(16, 10))
	_lap = _label(tl, "0:00.000", 42, Color.WHITE, Vector2(16, 26))
	_best = _label(tl, "BEST  --:--.---", 18, PURPLE, Vector2(16, 84))
	for k in 3:
		_splits.append(_label(tl, "S%d  --.---" % (k + 1), 17, Color(0.85, 0.85, 0.88), Vector2(16, 114 + k * 24)))

	# top-right targets
	var tr := _panel(root, Vector2(0, 24), Vector2(250, 130))
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -274
	tr.offset_right = -24
	_label(tr, "TIME TRIAL TARGETS", 13, Color(0.7, 0.7, 0.75), Vector2(16, 10))
	_targets = _label(tr, "", 18, Color.WHITE, Vector2(16, 32))

	# bottom-right speed
	var br := _panel(root, Vector2(0, 0), Vector2(270, 150))
	br.anchor_left = 1.0
	br.anchor_right = 1.0
	br.anchor_top = 1.0
	br.anchor_bottom = 1.0
	br.offset_left = -294
	br.offset_right = -24
	br.offset_top = -174
	br.offset_bottom = -24
	_speed = _label(br, "0", 68, Color.WHITE, Vector2(16, 4))
	_unit_label = _label(br, "KM/H", 16, Color(0.7, 0.7, 0.75), Vector2(18, 86))
	_gear = _label(br, "N", 56, GOLD, Vector2(200, 14))
	_rpm = _bar(br, Vector2(16, 116), Vector2(238, 12), Color(1.0, 0.4, 0.2))

	# bottom-center boost
	var bc := Control.new()
	bc.anchor_left = 0.5
	bc.anchor_right = 0.5
	bc.anchor_top = 1.0
	bc.anchor_bottom = 1.0
	bc.offset_left = -220
	bc.offset_right = 220
	bc.offset_top = -86
	bc.offset_bottom = -30
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bc)
	_boost_label = _label(bc, "OVERTAKE BOOST  [SPACE]", 14, GOLD, Vector2(0, 0))
	_boost = _bar(bc, Vector2(0, 22), Vector2(440, 18), GOLD)

	# toast
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 150
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_toast, 34, Color.WHITE)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# controls hint
	var hint := _label(root, "W/S throttle-brake   A/D steer   SPACE boost   E DRS   P pit  1-4 tyres   C camera   R checkpoint (hold: restart)   ESC pause", 14, Color(1, 1, 1, 0.55), Vector2(24, 0))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -40

	_build_title(root)

	# hold-R restart progress ring
	_ring = RestartRing.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.offset_left = -45
	_ring.offset_right = 45
	_ring.offset_top = -45
	_ring.offset_bottom = 45
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ring)
	_build_race_widgets(root)
	_build_tyre_panel(root)
	_build_conditions(root)

func _build_race_widgets(root: Control) -> void:
	# DRS badge, left of the boost meter
	_drs_panel = Panel.new()
	_drs_style = StyleBoxFlat.new()
	_drs_style.bg_color = DRS_COLORS[0]
	_drs_style.set_corner_radius_all(4)
	_drs_panel.add_theme_stylebox_override("panel", _drs_style)
	_drs_panel.anchor_left = 0.5
	_drs_panel.anchor_right = 0.5
	_drs_panel.anchor_top = 1.0
	_drs_panel.anchor_bottom = 1.0
	_drs_panel.offset_left = -330
	_drs_panel.offset_right = -236
	_drs_panel.offset_top = -72
	_drs_panel.offset_bottom = -30
	_drs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_drs_panel)
	_drs_label = _label(_drs_panel, "DRS", 24, Color(1, 1, 1, 0.6), Vector2(20, 5))
	# rev lights across the top centre: 5 green, 5 red, 5 blue
	var leds := HBoxContainer.new()
	leds.anchor_left = 0.5
	leds.anchor_right = 0.5
	leds.offset_left = -180
	leds.offset_right = 180
	leds.offset_top = 22
	leds.offset_bottom = 38
	leds.add_theme_constant_override("separation", 6)
	leds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(leds)
	for k in LED_COUNT:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(18, 14)
		r.color = Color(0.1, 0.1, 0.12, 0.7)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leds.add_child(r)
		_leds.append(r)
	# live delta vs best lap and gap to the car ahead
	_delta = Label.new()
	_delta.anchor_left = 0.5
	_delta.anchor_right = 0.5
	_delta.offset_left = -150
	_delta.offset_right = 150
	_delta.offset_top = 46
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_delta, 30, Color.WHITE)
	_delta.text = ""
	root.add_child(_delta)
	_gap = Label.new()
	_gap.anchor_left = 0.5
	_gap.anchor_right = 0.5
	_gap.offset_left = -200
	_gap.offset_right = 200
	_gap.offset_top = 86
	_gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_gap, 16, Color(0.7, 0.85, 1.0))
	root.add_child(_gap)

	# minimap, under the targets panel on the right
	_minimap_panel = Panel.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.02, 0.02, 0.03, 0.5)
	msb.border_color = Color(1.0, 0.8, 0.35, 0.7)
	msb.border_width_left = 3
	msb.set_corner_radius_all(6)
	_minimap_panel.add_theme_stylebox_override("panel", msb)
	_minimap_panel.anchor_left = 1.0
	_minimap_panel.anchor_right = 1.0
	_minimap_panel.offset_left = -294
	_minimap_panel.offset_right = -24
	_minimap_panel.offset_top = 166
	_minimap_panel.offset_bottom = 356
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_minimap_panel)
	_minimap = MinimapScript.new()
	_minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_minimap.offset_left = 10
	_minimap.offset_top = 24
	_minimap.offset_right = -8
	_minimap.offset_bottom = -8
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_panel.add_child(_minimap)
	_label(_minimap_panel, "CIRCUIT", 12, Color(0.7, 0.7, 0.75), Vector2(12, 6))

## Called once by the session with the track data so the outline can be projected.
func setup_minimap(track_data: Dictionary) -> void:
	if _minimap and _minimap.has_method("setup"):
		_minimap.setup(track_data)

## One entry per car: {"pos": Vector3, "player": bool}.
func set_minimap(cars: Array) -> void:
	if _minimap and _minimap.has_method("set_cars"):
		_minimap.set_cars(cars)

# ---------- tyres and pit ----------

var _tyre_panel: Panel
var _tyre_fills: Array[ColorRect] = []
var _tyre_texts: Array[Label] = []
var _compound_lbl: Label
var _tyre_temp_lbl: Label
var _pit_lbl: Label
var _pit_style: StyleBoxFlat

## Four tyre wear bars (FL, FR, RL, RR as 0..1 wear) plus compound badge and temperature state.
func _build_tyre_panel(root: Control) -> void:
	_tyre_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.55)
	sb.border_color = Color(1.0, 0.8, 0.35, 0.8)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	_tyre_panel.add_theme_stylebox_override("panel", sb)
	_tyre_panel.anchor_top = 1.0
	_tyre_panel.anchor_bottom = 1.0
	_tyre_panel.offset_left = 24
	_tyre_panel.offset_right = 268
	_tyre_panel.offset_top = -176
	_tyre_panel.offset_bottom = -24
	_tyre_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tyre_panel)
	_label(_tyre_panel, "TYRES", 13, Color(0.7, 0.7, 0.75), Vector2(14, 8))
	_compound_lbl = _label(_tyre_panel, "M", 30, Color(0.98, 0.85, 0.2), Vector2(200, 4))
	_tyre_temp_lbl = _label(_tyre_panel, "COLD", 12, Color(0.7, 0.8, 1.0), Vector2(120, 20))
	# two rows of two tyres: FL FR / RL RR
	for k in 4:
		var x := 14.0 + (k % 2) * 118.0
		var y := 42.0 + (k / 2) * 46.0
		var tag: String = ["FL", "FR", "RL", "RR"][k]
		_label(_tyre_panel, tag, 12, Color(0.75, 0.75, 0.8), Vector2(x, y))
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.55)
		bg.position = Vector2(x + 22, y + 3)
		bg.size = Vector2(66, 9)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tyre_panel.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(0.35, 1.0, 0.45)
		fill.position = Vector2(x + 22, y + 3)
		fill.size = Vector2(66, 9)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tyre_panel.add_child(fill)
		_tyre_fills.append(fill)
		_tyre_texts.append(_label(_tyre_panel, "0%", 11, Color(0.9, 0.9, 0.92), Vector2(x, y + 16)))
	# pit / BOX BOX banner above the tyre panel
	_pit_lbl = Label.new()
	_pit_lbl.anchor_left = 0.0
	_pit_lbl.anchor_top = 1.0
	_pit_lbl.offset_left = 24
	_pit_lbl.offset_right = 268
	_pit_lbl.offset_top = -212
	_pit_lbl.offset_bottom = -180
	_pit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_pit_lbl, 20, Color.WHITE)
	_pit_lbl.modulate.a = 0.0
	root.add_child(_pit_lbl)

## wear: Array of four 0..1 values (FL, FR, RL, RR). compound: short name, col: its colour.
func set_tyres(wear: Array, compound: String, col: Color, temp_state: int) -> void:
	_compound_lbl.text = compound
	_compound_lbl.add_theme_color_override("font_color", col)
	for k in 4:
		var w: float = clampf(float(wear[k]), 0.0, 1.0)
		var left := 1.0 - w
		_tyre_fills[k].size.x = 66.0 * left
		_tyre_fills[k].color = Color(0.35, 1.0, 0.45) if w < 0.6 else (Color(1.0, 0.75, 0.2) if w < 0.85 else Color(1.0, 0.25, 0.2))
		_tyre_texts[k].text = "%d%%" % int(round(w * 100.0))
	_tyre_temp_lbl.text = ["COLD", "OPTIMAL", "OVERHEAT"][clampi(temp_state, 0, 2)]
	_tyre_temp_lbl.add_theme_color_override("font_color",
		[Color(0.6, 0.8, 1.0), Color(0.4, 1.0, 0.5), Color(1.0, 0.35, 0.25)][clampi(temp_state, 0, 2)])

## Pit lane banner: "" hides it. Amber = request armed, green = in the box / serviced.
func set_pit_banner(text: String, col := Color(1.0, 0.8, 0.3)) -> void:
	_pit_lbl.text = text
	_pit_lbl.add_theme_color_override("font_color", col)
	_pit_lbl.modulate.a = 1.0 if text != "" else 0.0

## 0 = unavailable (grey), 1 = available (amber), 2 = open (green).
func set_drs(state: int) -> void:
	_drs_style.bg_color = DRS_COLORS[clampi(state, 0, 2)]
	_drs_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55) if state == 0 else Color(0.05, 0.05, 0.05))

func set_rev_leds(ratio: float) -> void:
	var lit := int(round(clampf(ratio, 0.0, 1.0) * LED_COUNT))
	var flash := ratio > 0.97 and fmod(Time.get_ticks_msec() * 0.001, 0.12) < 0.06
	for k in LED_COUNT:
		var on := k < lit and not flash
		var c := Color(0.2, 1.0, 0.3) if k < 5 else (Color(1.0, 0.15, 0.1) if k < 10 else Color(0.3, 0.4, 1.0))
		_leds[k].color = c if on else Color(0.1, 0.1, 0.12, 0.7)

func set_delta(d: float, has_ref: bool) -> void:
	if not has_ref:
		_delta.text = ""
		return
	_delta.text = "%s%.2f" % ["+" if d >= 0.0 else "-", absf(d)]
	_delta.add_theme_color_override("font_color", RED if d > 0.0 else GREEN)

func set_gap(text: String) -> void:
	_gap.text = text

var _pos_label: Label
var _standings: Label
var _lights_box: HBoxContainer
var _lights: Array[Panel] = []

## Race position and the live standings list under the timing panel.
func set_race_info(pos: int, total: int, standings: String) -> void:
	if _pos_label == null:
		var root: Control = get_child(0)
		_pos_label = _label(root, "", 44, Color.WHITE, Vector2(24, 228))
		_standings = _label(root, "", 15, Color(0.9, 0.9, 0.92), Vector2(26, 284))
	_pos_label.text = "P%d / %d" % [pos, total] if total > 0 else ""
	_standings.text = standings

## Five red start lights: n = number lit (0-5), n < 0 hides them.
func set_start_lights(n: int) -> void:
	if _lights_box == null:
		var root: Control = get_child(0)
		_lights_box = HBoxContainer.new()
		_lights_box.anchor_left = 0.5
		_lights_box.anchor_right = 0.5
		_lights_box.offset_left = -170
		_lights_box.offset_right = 170
		_lights_box.offset_top = 130
		_lights_box.offset_bottom = 190
		_lights_box.add_theme_constant_override("separation", 10)
		root.add_child(_lights_box)
		for k in 5:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(60, 60)
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(30)
			sb.border_color = Color(0.05, 0.05, 0.05)
			sb.set_border_width_all(5)
			p.add_theme_stylebox_override("panel", sb)
			_lights_box.add_child(p)
			_lights.append(p)
	_lights_box.visible = n >= 0
	for k in 5:
		var sb := _lights[k].get_theme_stylebox("panel") as StyleBoxFlat
		sb.bg_color = Color(1.0, 0.05, 0.03) if k < n else Color(0.15, 0.02, 0.02)

## Circular progress drawn while R is held.
class RestartRing extends Control:
	var progress := 0.0
	func _draw() -> void:
		if progress <= 0.0:
			return
		var c := size * 0.5
		draw_arc(c, 34.0, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 8.0, true)
		draw_arc(c, 34.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.8, 0.35), 8.0, true)
		draw_string(ThemeDB.fallback_font, c + Vector2(-6, 7), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

func set_restart_progress(v: float) -> void:
	if not is_equal_approx(_ring.progress, v):
		_ring.progress = v
		_ring.queue_redraw()

func set_units(unit: String) -> void:
	_unit_label.text = unit

func set_lap_count(current: int, total: int) -> void:
	if total <= 0:
		_lap_head.text = "TIME TRIAL  -  LAP"
	else:
		_lap_head.text = "LAP %d / %d" % [mini(current, total), total]

func _panel(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.55)
	sb.border_color = Color(1.0, 0.8, 0.35, 0.8)
	sb.border_width_left = 3
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _style(l: Label, size: int, col: Color) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)

func _label(parent: Control, text: String, size: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	_style(l, size, col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _bar(parent: Control, pos: Vector2, size: Vector2, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.position = pos
	b.size = size
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.corner_radius_top_left = 3
	bg.corner_radius_bottom_right = 3
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.corner_radius_top_left = 3
	fg.corner_radius_bottom_right = 3
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b

func _build_title(root: Control) -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title)
	var t := Label.new()
	t.text = "APEX RUSH"
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.offset_left = -500
	t.offset_right = 500
	t.offset_top = -130
	t.offset_bottom = -40
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(t, 84, Color.WHITE)
	_title.add_child(t)
	var s := Label.new()
	s.text = "MONTE CARLO  -  TIME TRIAL\nCross the line to start your flying lap. Beat the ghost."
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.offset_left = -500
	s.offset_right = 500
	s.offset_top = -40
	s.offset_bottom = 40
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(s, 22, GOLD)
	_title.add_child(s)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_title, "modulate:a", 0.0, 0.8)

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
	_update_fps()

## Optional performance counter. Built on first use, toggled from Settings.
func _update_fps() -> void:
	if int(GameState.settings.get("show_fps", 0)) == 0:
		if _fps_lbl:
			_fps_lbl.visible = false
		return
	if _fps_lbl == null:
		_fps_lbl = Label.new()
		_fps_lbl.anchor_left = 1.0
		_fps_lbl.anchor_right = 1.0
		_fps_lbl.offset_left = -180
		_fps_lbl.offset_right = -24
		_fps_lbl.offset_top = 20
		_fps_lbl.offset_bottom = 46
		_fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_style(_fps_lbl, 18, Color(0.75, 1.0, 0.8))
		add_child(_fps_lbl)
	_fps_lbl.visible = true
	_fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()

static func fmt(t: float) -> String:
	if t >= 1.0e9:
		return "--:--.---"
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]

func set_speed(kmh: float, gear: int, rpm_ratio: float) -> void:
	_speed.text = str(int(round(kmh)))
	_gear.text = str(gear)
	_rpm.value = rpm_ratio

## Speed streaks: speed_fraction is 0..1 of the car's top speed.
func set_speed_fx(speed_fraction: float, boosting: bool) -> void:
	if _speed_fx and _speed_fx.has_method("set_speed"):
		_speed_fx.set_speed(speed_fraction, boosting)

func set_boost(v: float, active: bool) -> void:
	_boost.value = v
	var a := 1.0 if active else 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004) * (1.0 if v >= 1.0 else 0.0)
	_boost.modulate = Color(1.4, 1.2, 0.8, 1.0) if active else Color(1, 1, 1, a)
	_boost_label.text = "OVERTAKE BOOST  ACTIVE" if active else "OVERTAKE BOOST  [SPACE]"

func set_lap(t: float, running: bool) -> void:
	_lap.text = fmt(t) if running else "OUT LAP"

func set_best(t: float) -> void:
	_best.text = "BEST  " + fmt(t)

func set_split(idx: int, t: float, delta_t: float, has_ref: bool) -> void:
	var txt := "S%d  %s" % [idx + 1, "%.3f" % t]
	var col := Color(0.85, 0.85, 0.88)
	if has_ref:
		txt += "   %s%.3f" % ["+" if delta_t >= 0.0 else "-", absf(delta_t)]
		col = RED if delta_t > 0.0 else GREEN
	_splits[idx].text = txt
	_splits[idx].add_theme_color_override("font_color", col)

func clear_splits() -> void:
	for k in 3:
		_splits[k].text = "S%d  --.---" % (k + 1)
		_splits[k].add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))

func set_targets(gold: float, silver: float, bronze: float) -> void:
	_targets.text = "GOLD     %s  (ghost)\nSILVER  %s\nBRONZE  %s" % [fmt(gold), fmt(silver), fmt(bronze)]

func toast(text: String, col: Color, duration := 2.0) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	_toast_t = duration
	_toast.modulate.a = 1.0

# ---------- conditions, damage and race flags ----------

var _weather_lbl: Label
var _damage_bar: ProgressBar
var _damage_lbl: Label
var _flag_lbl: Label
var _fps_lbl: Label

func _build_conditions(root: Control) -> void:
	var panel := _panel(root, Vector2(24, 232), Vector2(200, 84))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(panel, "CONDITIONS", 12, Color(0.7, 0.7, 0.75), Vector2(12, 6))
	_weather_lbl = _label(panel, "DRY", 20, Color(0.85, 0.9, 1.0), Vector2(12, 22))
	_damage_lbl = _label(panel, "DAMAGE  0%", 12, Color(0.7, 0.7, 0.75), Vector2(12, 50))
	_damage_bar = _bar(panel, Vector2(12, 66), Vector2(176, 8), Color(1.0, 0.35, 0.25))

	# race control flag strip, above the boost meter
	_flag_lbl = Label.new()
	_flag_lbl.anchor_left = 0.5
	_flag_lbl.anchor_right = 0.5
	_flag_lbl.anchor_top = 1.0
	_flag_lbl.anchor_bottom = 1.0
	_flag_lbl.offset_left = -300
	_flag_lbl.offset_right = 300
	_flag_lbl.offset_top = -130
	_flag_lbl.offset_bottom = -96
	_flag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_flag_lbl, 22, GOLD)
	_flag_lbl.modulate.a = 0.0
	root.add_child(_flag_lbl)

## Sky condition line. col tints the text (blue-ish when wet, amber when drying).
func set_weather(text: String, wetness: float) -> void:
	_weather_lbl.text = text
	var col := Color(0.85, 0.9, 1.0).lerp(Color(0.5, 0.7, 1.0), clampf(wetness, 0.0, 1.0))
	_weather_lbl.add_theme_color_override("font_color", col)

## Bodywork damage 0..1: green under 35%, amber to 70%, red beyond.
func set_damage(v: float) -> void:
	_damage_bar.value = v
	_damage_lbl.text = "DAMAGE  %d%%" % int(round(v * 100.0))
	var col := Color(0.35, 1.0, 0.45)
	if v >= 0.7:
		col = RED
	elif v >= 0.35:
		col = Color(1.0, 0.75, 0.2)
	_damage_lbl.add_theme_color_override("font_color", col)
	_damage_bar.modulate = Color(1, 1, 1, 1) if v > 0.0 else Color(1, 1, 1, 0.45)

## Race control message ("SAFETY CAR", "YELLOW FLAG"). "" clears it.
func set_flag(text: String, col := Color(1.0, 0.8, 0.35)) -> void:
	_flag_lbl.text = text
	_flag_lbl.add_theme_color_override("font_color", col)
	_flag_lbl.modulate.a = 1.0 if text != "" else 0.0
