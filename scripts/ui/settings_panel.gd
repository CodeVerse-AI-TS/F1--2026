extends PanelContainer
## Settings: volumes, graphics quality, default camera, units, and the controls list.
## Used by both the main menu and the in-race pause menu.

signal closed

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.panel_style())
	custom_minimum_size = Vector2(640, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UI.label("SETTINGS", 30, UI.GOLD))
	var s: Dictionary = GameState.settings
	v.add_child(UI.row("Master volume", UI.slider(float(s["master"]), _set_f.bind("master"))))
	v.add_child(UI.row("Music volume", UI.slider(float(s["music"]), _set_f.bind("music"))))
	v.add_child(UI.row("SFX volume", UI.slider(float(s["sfx"]), _set_f.bind("sfx"))))
	v.add_child(UI.row("Graphics quality", UI.option(GameState.QUALITY_NAMES, int(s["quality"]), _set_i.bind("quality"))))
	v.add_child(UI.row("Default camera", UI.option(GameState.CAMERA_NAMES, int(s["camera"]), _set_i.bind("camera"))))
	v.add_child(UI.row("Speed units", UI.option(["km/h", "mph"], int(s["units"]), _set_i.bind("units"))))
	v.add_child(UI.label("CONTROLS", 22, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	for a in GameState.ACTIONS:
		grid.add_child(UI.label(String(a).replace("_", " ").capitalize(), 16, UI.TEXT_DIM))
		grid.add_child(UI.label(GameState.action_keys(a), 16))
	v.add_child(grid)
	v.add_child(UI.button("BACK", _close))

func _set_f(value: float, key: String) -> void:
	GameState.settings[key] = value
	GameState.apply_settings()

func _set_i(idx: int, key: String) -> void:
	GameState.settings[key] = idx
	GameState.apply_settings()

func _close() -> void:
	GameState.save_settings()
	closed.emit()
