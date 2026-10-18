extends RefCounted
## GameState: game mode, session state machine, race config and persisted settings.
## Static data shared across scenes; use it with
##   const GameState = preload("res://scripts/game_state.gd")
## Session states: MENU -> (QUALIFYING) -> RACE <-> PIT / PAUSED -> RESULTS -> MENU.

enum Mode { TIME_TRIAL, QUICK_RACE, CHAMPIONSHIP }
enum State { MENU, QUALIFYING, RACE, PIT, PAUSED, RESULTS }

const SETTINGS_PATH := "user://settings.cfg"
const RACE_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const MAX_FLASHBACKS := 3
const CAMERA_NAMES := ["CHASE", "FAR CHASE", "COCKPIT", "HOOD", "TV", "TOP DOWN"]
const QUALITY_NAMES := ["Low", "Medium", "High"]
const DIFFICULTIES := ["Rookie", "Pro", "Legend"]
const LAP_OPTIONS := [3, 5, 10]
## Tracks grow into full data entries in Phase 4.
const TRACKS := [{"id": "monaco", "name": "Monte Carlo Street Circuit"}]
const TEAMS := [
	{"name": "Midnight Carbon", "color": Color(0.025, 0.025, 0.028), "secondary": Color(0.08, 0.08, 0.09), "accent": Color(1.0, 0.68, 0.22), "sponsor": "NOCTIS", "number": 1},
	{"name": "Scarlet Apex", "color": Color(0.55, 0.02, 0.02), "secondary": Color(0.95, 0.95, 0.92), "accent": Color(1.0, 0.85, 0.3), "sponsor": "ROSSO", "number": 16},
	{"name": "Titanium Arrow", "color": Color(0.55, 0.57, 0.6), "secondary": Color(0.03, 0.03, 0.04), "accent": Color(0.2, 0.9, 1.0), "sponsor": "ARGENT", "number": 44},
	{"name": "Papaya Rocket", "color": Color(0.95, 0.42, 0.05), "secondary": Color(0.05, 0.2, 0.6), "accent": Color(0.1, 0.5, 1.0), "sponsor": "PAPAYA", "number": 4},
	{"name": "Racing Green", "color": Color(0.02, 0.22, 0.12), "secondary": Color(0.75, 0.9, 0.2), "accent": Color(0.8, 1.0, 0.3), "sponsor": "VERDE", "number": 14},
	{"name": "Royal Blue", "color": Color(0.04, 0.1, 0.45), "secondary": Color(0.85, 0.1, 0.15), "accent": Color(1.0, 0.2, 0.3), "sponsor": "AZURE", "number": 33},
]
const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "boost", "drs", "restart", "camera_cycle", "pause"]

static var mode: int = Mode.TIME_TRIAL
static var state: int = State.MENU
static var config := {"track": 0, "laps": 3, "difficulty": 1, "team": 0, "ai_count": 0}
static var flashbacks := MAX_FLASHBACKS
static var settings := {"master": 0.8, "music": 0.6, "sfx": 0.9, "quality": 2, "camera": 0, "units": 0}
static var _initialized := false

## Call once from any scene's _ready (menu and race both do). Safe to call repeatedly.
static func ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_ensure_buses()
	load_settings()
	apply_settings()

static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func set_state(s: int) -> void:
	state = s

static func start_session(m: int) -> void:
	mode = m
	flashbacks = MAX_FLASHBACKS
	tree().paused = false
	set_state(State.RACE)
	tree().change_scene_to_file(RACE_SCENE)

static func go_to_menu() -> void:
	tree().paused = false
	set_state(State.MENU)
	tree().change_scene_to_file(MENU_SCENE)

static func team() -> Dictionary:
	return TEAMS[clampi(int(config["team"]), 0, TEAMS.size() - 1)]

# ---------- settings ----------

static func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

static func _set_vol(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

static func apply_settings() -> void:
	_set_vol("Master", float(settings["master"]))
	_set_vol("Music", float(settings["music"]))
	_set_vol("SFX", float(settings["sfx"]))
	var q := clampi(int(settings["quality"]), 0, 2)
	var vp := tree().root
	vp.scaling_3d_scale = [0.67, 0.85, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192][q], true)

static func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)

static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cf.get_value("settings", k, settings[k])

static func speed_display(kmh: float) -> float:
	return kmh if int(settings["units"]) == 0 else kmh * 0.621371

static func speed_unit() -> String:
	return "KM/H" if int(settings["units"]) == 0 else "MPH"

## Human-readable key list for an input action (used by the settings controls list).
static func action_keys(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var parts: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		parts.append(ev.as_text().replace(" (Physical)", "").replace(" - Physical", ""))
	return ", ".join(parts)
