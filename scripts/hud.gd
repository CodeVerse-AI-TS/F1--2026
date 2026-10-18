extends CanvasLayer
## Race HUD: lap timer and splits, targets, speed/gear/rpm, Overtake Boost meter, toasts.

const GOLD := Color(1.0, 0.8, 0.35)
const SILVER := Color(0.82, 0.86, 0.92)
const BRONZE := Color(0.85, 0.55, 0.32)
const GREEN := Color(0.35, 1.0, 0.45)
const PURPLE := Color(0.8, 0.45, 1.0)
const RED := Color(1.0, 0.3, 0.25)

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

const DRS_COLORS := [Color(0.25, 0.25, 0.28, 0.85), Color(1.0, 0.65, 0.1, 0.95), Color(0.2, 0.9, 0.3, 0.95)]
const LED_COUNT := 15

func _ready() -> void:
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
	var hint := _label(root, "W/S throttle-brake   A/D steer   SPACE boost   E DRS   C camera   R checkpoint (hold: restart)   ESC pause", 14, Color(1, 1, 1, 0.55), Vector2(24, 0))
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

static func fmt(t: float) -> String:
	if t >= 1.0e9:
		return "--:--.---"
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]

func set_speed(kmh: float, gear: int, rpm_ratio: float) -> void:
	_speed.text = str(int(round(kmh)))
	_gear.text = str(gear)
	_rpm.value = rpm_ratio

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
