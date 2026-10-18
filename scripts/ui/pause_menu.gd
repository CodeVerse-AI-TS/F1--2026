extends CanvasLayer
## In-race pause menu (Resume, Restart Race, Change Camera, Settings, Quit to Menu)
## and the post-race results card. Runs while the tree is paused.

signal resume_pressed
signal restart_pressed
signal camera_pressed

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var _center: CenterContainer
var _panel: PanelContainer
var _title: Label
var _body: Label
var _resume: Button
var _camera: Button
var _settings_btn: Button
var _settings: Control
var _results_mode := false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.panel_style())
	_center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_title = UI.label("PAUSED", 40, UI.GOLD)
	v.add_child(_title)
	_body = UI.label("", 20)
	v.add_child(_body)
	_resume = UI.button("RESUME", _on_resume)
	v.add_child(_resume)
	v.add_child(UI.button("RESTART RACE", func() -> void: _close(); restart_pressed.emit()))
	_camera = UI.button("CHANGE CAMERA", func() -> void: camera_pressed.emit())
	v.add_child(_camera)
	_settings_btn = UI.button("SETTINGS", _open_settings)
	v.add_child(_settings_btn)
	v.add_child(UI.button("QUIT TO MENU", func() -> void: GameState.go_to_menu()))
	visible = false

func open() -> void:
	_results_mode = false
	_title.text = "PAUSED"
	_body.visible = false
	_resume.visible = true
	_camera.visible = true
	_settings_btn.visible = true
	_show_main()
	visible = true
	_resume.grab_focus()

func show_results(title: String, body: String) -> void:
	_results_mode = true
	_title.text = title
	_body.text = body
	_body.visible = true
	_resume.visible = false
	_camera.visible = false
	_settings_btn.visible = false
	_show_main()
	visible = true

func _show_main() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
	_panel.visible = true

func _open_settings() -> void:
	_panel.visible = false
	_settings = SettingsPanel.new()
	_settings.closed.connect(_show_main)
	_center.add_child(_settings)

func _on_resume() -> void:
	_close()
	resume_pressed.emit()

func _close() -> void:
	_show_main()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _results_mode and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings:
			_show_main()
		else:
			_on_resume()
