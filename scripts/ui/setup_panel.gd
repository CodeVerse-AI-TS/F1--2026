extends PanelContainer
## Car setup: three sliders that trade top speed against grip and braking.
## aero: low drag vs downforce. susp: soft vs stiff (mechanical grip).
## bias: brake balance, front to rear (stability vs stopping power).

signal closed

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")

var _readout: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.panel_style())
	custom_minimum_size = Vector2(640, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UI.label("CAR SETUP", 30, UI.GOLD))
	var s: Dictionary = GameState.config.get("setup", {})
	v.add_child(UI.row("Aero balance", UI.slider(float(s.get("aero", 0.5)), _set.bind("aero"))))
	v.add_child(UI.row("Suspension", UI.slider(float(s.get("susp", 0.5)), _set.bind("susp"))))
	v.add_child(UI.row("Brake bias", UI.slider(float(s.get("bias", 0.5)), _set.bind("bias"))))
	_readout = UI.label("", 14, UI.TEXT_DIM)
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.custom_minimum_size = Vector2(560, 46)
	v.add_child(_readout)
	v.add_child(UI.label("Low aero = faster on straights, slower in corners. Front brake bias stops harder but locks up.",
		13, UI.TEXT_DIM))
	v.add_child(UI.button("BACK", _close))
	_refresh()

func _set(value: float, key: String) -> void:
	var setup: Dictionary = GameState.config.get("setup", {})
	setup[key] = value
	GameState.config["setup"] = setup
	_refresh()

## Mirrors the maths in car.gd apply_setup() so the player sees the trade-off.
func _refresh() -> void:
	var s: Dictionary = GameState.config.get("setup", {})
	var aero := clampf(float(s.get("aero", 0.5)), 0.0, 1.0)
	var susp := clampf(float(s.get("susp", 0.5)), 0.0, 1.0)
	var bias := clampf(float(s.get("bias", 0.5)), 0.0, 1.0)
	var top := lerpf(1.04, 0.96, aero)
	var grip := lerpf(0.95, 1.05, aero) * lerpf(0.97, 1.03, susp)
	var brake := lerpf(0.94, 1.06, bias)
	_readout.text = "Top speed x%.2f     Grip x%.2f     Braking x%.2f" % [top, grip, brake]

func _close() -> void:
	GameState.save_settings()
	closed.emit()
