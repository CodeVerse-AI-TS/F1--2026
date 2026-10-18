extends Control
## Title screen: Single Player (quick race setup), Championship, Time Trial, Leaderboard, Settings, Quit.

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var _content: CenterContainer
var _swatch: ColorRect
var _first_button: Button

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
	v.add_child(UI.row("Track", UI.option(names, int(cfg["track"]), func(i: int) -> void: cfg["track"] = i)))
	if is_race:
		var laps_idx := maxi(GameState.LAP_OPTIONS.find(int(cfg["laps"])), 0)
		v.add_child(UI.row("Laps", UI.option(GameState.LAP_OPTIONS, laps_idx,
			func(i: int) -> void: cfg["laps"] = GameState.LAP_OPTIONS[i])))
	var team_names: Array = []
	for t in GameState.TEAMS:
		team_names.append(t["name"])
	var team_row := UI.row("Team", UI.option(team_names, int(cfg["team"]), _pick_team))
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(38, 38)
	team_row.add_child(_swatch)
	v.add_child(team_row)
	_pick_team(int(cfg["team"]))
	var note := "Race the clock over your chosen laps. Rival AI, difficulty and grid size arrive with the AI update." if is_race \
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

func _show_settings() -> void:
	_clear()
	var s := SettingsPanel.new()
	s.closed.connect(_clear)
	_content.add_child(s)
