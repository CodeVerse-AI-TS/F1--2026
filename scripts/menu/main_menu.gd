extends Control
## Title screen: Single Player (quick race setup), Championship, Time Trial, Leaderboard, Settings, Quit.

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var _content: CenterContainer
var _swatch: ColorRect
var _first_button: Button
var _preview: TrackPreview
var _info: Label

func _ready() -> void:
	GameState.ensure_init()
	GameState.set_state(GameState.State.MENU)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 90
	h.offset_right = -60
	h.offset_top = 60
	h.offset_bottom = -60
	add_child(h)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	left.add_child(UI.label("APEX RUSH", 96))
	left.add_child(UI.label("F1 ARCADE RACING", 22, UI.GOLD))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	left.add_child(gap)
	_first_button = UI.button("SINGLE PLAYER", _show_setup.bind(GameState.Mode.QUICK_RACE))
	left.add_child(_first_button)
	var champ := UI.button("CHAMPIONSHIP   (soon)", func() -> void: pass)
	champ.disabled = true
	champ.tooltip_text = "Season mode arrives with the championship update."
	left.add_child(champ)
	left.add_child(UI.button("TIME TRIAL", _show_setup.bind(GameState.Mode.TIME_TRIAL)))
	var board := UI.button("LEADERBOARD   (soon)", func() -> void: pass)
	board.disabled = true
	board.tooltip_text = "Local leaderboard arrives with the leaderboard update."
	left.add_child(board)
	left.add_child(UI.button("SETTINGS", _show_settings))
	left.add_child(UI.button("QUIT", func() -> void: get_tree().quit()))
	_content = CenterContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_content)
	_first_button.grab_focus()

func _build_background() -> void:
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.015, 0.04))
	grad.set_color(1, Color(0.35, 0.17, 0.05))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.2, 0.0)
	tex.fill_to = Vector2(1.0, 1.0)
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# speed stripes
	for k in 5:
		var r := ColorRect.new()
		r.color = Color(1.0, 0.75, 0.3, 0.05 + k * 0.02)
		r.size = Vector2(2600, 6 + k * 3)
		r.position = Vector2(-300, 520 + k * 46)
		r.rotation = -0.22
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()

func _panel(title: String) -> VBoxContainer:
	_clear()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel_style())
	p.custom_minimum_size = Vector2(560, 0)
	_content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label(title, 30, UI.GOLD))
	return v

func _show_setup(mode: int) -> void:
	var is_race := mode == GameState.Mode.QUICK_RACE
	var v := _panel("QUICK RACE" if is_race else "TIME TRIAL")
	var cfg: Dictionary = GameState.config
	var names: Array = []
	for t in GameState.TRACKS:
		names.append(t["name"])
	v.add_child(UI.row("Track", UI.option(names, int(cfg["track"]), _pick_track)))
	_preview = TrackPreview.new()
	_preview.custom_minimum_size = Vector2(520, 132)
	v.add_child(_preview)
	_info = UI.label("", 15, UI.TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(500, 0)
	v.add_child(_info)
	_pick_track(int(cfg["track"]))
	if is_race:
		var laps_idx := maxi(GameState.LAP_OPTIONS.find(int(cfg["laps"])), 0)
		v.add_child(UI.row("Laps", UI.option(GameState.LAP_OPTIONS, laps_idx,
			func(i: int) -> void: cfg["laps"] = GameState.LAP_OPTIONS[i])))
		v.add_child(UI.row("Difficulty", UI.option(GameState.DIFFICULTIES, int(cfg["difficulty"]),
			func(i: int) -> void: cfg["difficulty"] = i)))
		var ai_idx := maxi(GameState.AI_OPTIONS.find(int(cfg["ai_count"])), 0)
		v.add_child(UI.row("AI opponents", UI.option(GameState.AI_OPTIONS, ai_idx,
			func(i: int) -> void: cfg["ai_count"] = GameState.AI_OPTIONS[i])))
	var team_names: Array = []
	for t in GameState.TEAMS:
		team_names.append(t["name"])
	var team_row := UI.row("Team", UI.option(team_names, int(cfg["team"]), _pick_team))
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(38, 38)
	team_row.add_child(_swatch)
	v.add_child(team_row)
	_pick_team(int(cfg["team"]))
	var note := "Grid start against AI rivals. Lights out, then race for position over your chosen laps." if is_race \
		else "Flying laps against the gold ghost. Beat your best and the medal targets."
	var nl := UI.label(note, 15, UI.TEXT_DIM)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(500, 0)
	v.add_child(nl)
	var start := UI.button("START", func() -> void: GameState.start_session(mode), 26)
	v.add_child(start)
	start.grab_focus()

func _pick_team(i: int) -> void:
	GameState.config["team"] = i
	if _swatch:
		_swatch.color = GameState.TEAMS[i]["color"].lerp(Color.WHITE, 0.1)

## Track choice: updates the preview drawing and the length / corners / difficulty / best lap line.
func _pick_track(i: int) -> void:
	GameState.config["track"] = i
	var data: Dictionary = GameState.TRACKS[i]
	if _preview:
		_preview.set_points(GameState.track_preview(data, 220))
	if _info:
		var km := GameState.track_length(data) / 1000.0
		var best := GameState.best_lap_for(String(data["id"]))
		var best_txt := "no lap yet" if best <= 0.0 else _fmt(best)
		_info.text = "%.2f km   -   %d corners   -   %s   -   best %s\n%s" % [
			km, GameState.track_corners(data),
			GameState.TRACK_DIFFICULTY[clampi(int(data["difficulty"]), 0, 2)],
			best_txt, data.get("desc", "")]

func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]

## Flat circuit drawing for the setup panel (points arrive normalised 0..1).
class TrackPreview extends Control:
	var pts := PackedVector2Array()
	var line_color := Color(1.0, 0.82, 0.3)

	func set_points(p: PackedVector2Array) -> void:
		pts = p
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		if pts.size() < 3:
			return
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for q in pts:
			mn = mn.min(q)
			mx = mx.max(q)
		var span := mx - mn
		var s: float = minf((size.x - 26.0) / maxf(span.x, 0.0001), (size.y - 26.0) / maxf(span.y, 0.0001))
		var off := (size - span * s) * 0.5
		var line := PackedVector2Array()
		for q in pts:
			line.append(off + (q - mn) * s)
		line.append(line[0])
		draw_polyline(line, Color(0, 0, 0, 0.75), 7.0, true)
		draw_polyline(line, line_color, 3.0, true)
		draw_circle(line[0], 5.0, Color(1, 1, 1))
		draw_circle(line[0], 2.5, Color(0.1, 0.1, 0.1))

func _show_settings() -> void:
	_clear()
	var s := SettingsPanel.new()
	s.closed.connect(_clear)
	_content.add_child(s)
