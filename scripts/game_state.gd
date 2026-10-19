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
const AI_OPTIONS := [0, 3, 5, 7, 9]
## Base AI pace (fraction of the ideal lap) per difficulty: Rookie, Pro, Legend.
const AI_SKILL := [0.88, 0.94, 0.985]
const DRIVERS := ["M. Varela", "K. Osei", "L. Brandt", "T. Nakamura", "R. Duval",
	"S. Kowalski", "A. Romano", "J. Hale", "D. Ferreira", "E. Lindqvist", "P. Mehta"]
## Track catalogue. A track is either explicit "points" or a superellipse loop
## (count, rx, rz, power, elev, wobble). "drs" holds lap fractions.
const TRACK_DIFFICULTY := ["Easy", "Medium", "Hard"]
const TRACKS := [
	{
		"id": "monaco", "name": "Monte Carlo Street Circuit", "theme": "street",
		"half_w": 7.5, "difficulty": 3,
		"desc": "Harbour walls, zero run-off, the classic street lap.",
		"points": [
			Vector3(0, 0, 0), Vector3(0, 0, -260), Vector3(-40, 1, -335), Vector3(-140, 6, -365),
			Vector3(-260, 10, -325), Vector3(-330, 10, -245), Vector3(-295, 8, -175), Vector3(-360, 5, -110),
			Vector3(-420, 2, -40), Vector3(-405, 0, 60), Vector3(-335, 0, 112), Vector3(-300, 0, 88),
			Vector3(-262, 0, 128), Vector3(-150, 0, 160), Vector3(-92, 0, 118), Vector3(-58, 0, 168),
			Vector3(-8, 0, 120),
		],
		"drs": [{"detect": 0.94, "start": 0.03, "end": 0.22}],
	},
	{
		"id": "speed", "name": "Ocean Speedway", "theme": "speed",
		"half_w": 9.5, "difficulty": 1,
		"desc": "Long straights and flat-out sweepers. Top speed wins.",
		"count": 18, "rx": 1100.0, "rz": 700.0, "power": 3.4, "elev": 0.0, "wobble": 0.0,
		"drs": [{"detect": 0.9, "start": 0.02, "end": 0.3}],
	},
	{
		"id": "technical", "name": "Alpine Tech Park", "theme": "technical",
		"half_w": 8.0, "difficulty": 3,
		"desc": "Corner after corner with real elevation. Precision pays.",
		"count": 16, "rx": 430.0, "rz": 380.0, "power": 2.0, "elev": 34.0, "wobble": 0.18,
		"drs": [{"detect": 0.92, "start": 0.03, "end": 0.2}],
	},
	{
		"id": "desert", "name": "Dune Coast Circuit", "theme": "desert",
		"half_w": 9.0, "difficulty": 2,
		"desc": "Sand, sea air and fast flowing corners in the heat.",
		"count": 14, "rx": 650.0, "rz": 450.0, "power": 4.5, "elev": 10.0, "wobble": 0.08,
		"drs": [{"detect": 0.91, "start": 0.02, "end": 0.26}],
	},
	{
		"id": "night", "name": "Harbour Night Sprint", "theme": "night",
		"half_w": 8.0, "difficulty": 2,
		"desc": "Floodlit walls after dark. Brake points feel twice as far.",
		"count": 18, "rx": 460.0, "rz": 350.0, "power": 3.0, "elev": 14.0, "wobble": 0.05,
		"drs": [{"detect": 0.93, "start": 0.02, "end": 0.24}],
	},
]
## Per-theme sky, sun and scenery recipe used by scripts/track.gd.
const THEMES := {
	"street": {
		"sky_top": Color(0.62, 0.72, 0.86), "ambient": Color(0.55, 0.6, 0.72),
		"ambient_energy": 0.55, "haze": Color(0.85, 0.76, 0.62), "fog": 0.0016,
		"sun": Color(1.0, 0.86, 0.66), "sun_energy": 1.5,
		"ground": "cobblestone", "ground_tint": Color(0.82, 0.78, 0.72),
		"buildings": true, "harbour": true, "hills": true, "lamps": true,
		"vegetation": 0, "floodlights": false,
	},
	"speed": {
		"sky_top": Color(0.45, 0.62, 0.88), "ambient": Color(0.6, 0.68, 0.8),
		"ambient_energy": 0.7, "haze": Color(0.78, 0.85, 0.95), "fog": 0.0009,
		"sun": Color(1.0, 0.95, 0.88), "sun_energy": 1.8,
		"ground": "grass", "ground_tint": Color(0.42, 0.52, 0.32),
		"buildings": false, "harbour": false, "hills": true, "lamps": true,
		"vegetation": 1, "floodlights": false,
	},
	"technical": {
		"sky_top": Color(0.5, 0.66, 0.9), "ambient": Color(0.56, 0.64, 0.76),
		"ambient_energy": 0.6, "haze": Color(0.84, 0.88, 0.95), "fog": 0.0012,
		"sun": Color(1.0, 0.92, 0.82), "sun_energy": 1.7,
		"ground": "grass", "ground_tint": Color(0.38, 0.5, 0.3),
		"buildings": false, "harbour": false, "hills": true, "lamps": true,
		"vegetation": 2, "floodlights": false,
	},
	"desert": {
		"sky_top": Color(0.86, 0.72, 0.55), "ambient": Color(0.8, 0.72, 0.6),
		"ambient_energy": 0.85, "haze": Color(0.95, 0.86, 0.7), "fog": 0.0018,
		"sun": Color(1.0, 0.88, 0.62), "sun_energy": 2.1,
		"ground": "sand", "ground_tint": Color(0.88, 0.76, 0.55),
		"buildings": false, "harbour": true, "hills": true, "lamps": false,
		"vegetation": 3, "floodlights": false,
	},
	"night": {
		"sky_top": Color(0.02, 0.03, 0.07), "ambient": Color(0.12, 0.16, 0.28),
		"ambient_energy": 0.35, "haze": Color(0.1, 0.14, 0.24), "fog": 0.0022,
		"sun": Color(0.55, 0.68, 1.0), "sun_energy": 0.28,
		"ground": "asphalt", "ground_tint": Color(0.3, 0.32, 0.36),
		"buildings": true, "harbour": true, "hills": false, "lamps": true,
		"vegetation": 0, "floodlights": true,
	},
}
const TEAMS := [
	{"name": "Midnight Carbon", "color": Color(0.025, 0.025, 0.028), "secondary": Color(0.08, 0.08, 0.09), "accent": Color(1.0, 0.68, 0.22), "sponsor": "NOCTIS", "number": 1},
	{"name": "Scarlet Apex", "color": Color(0.55, 0.02, 0.02), "secondary": Color(0.95, 0.95, 0.92), "accent": Color(1.0, 0.85, 0.3), "sponsor": "ROSSO", "number": 16},
	{"name": "Titanium Arrow", "color": Color(0.55, 0.57, 0.6), "secondary": Color(0.03, 0.03, 0.04), "accent": Color(0.2, 0.9, 1.0), "sponsor": "ARGENT", "number": 44},
	{"name": "Papaya Rocket", "color": Color(0.95, 0.42, 0.05), "secondary": Color(0.05, 0.2, 0.6), "accent": Color(0.1, 0.5, 1.0), "sponsor": "PAPAYA", "number": 4},
	{"name": "Racing Green", "color": Color(0.02, 0.22, 0.12), "secondary": Color(0.75, 0.9, 0.2), "accent": Color(0.8, 1.0, 0.3), "sponsor": "VERDE", "number": 14},
	{"name": "Royal Blue", "color": Color(0.04, 0.1, 0.45), "secondary": Color(0.85, 0.1, 0.15), "accent": Color(1.0, 0.2, 0.3), "sponsor": "AZURE", "number": 33},
]
const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "boost", "drs",
	"pit_request", "compound_soft", "compound_medium", "compound_hard", "compound_inter", "compound_wet",
	"restart", "camera_cycle", "pause"]

static var mode: int = Mode.TIME_TRIAL
static var state: int = State.MENU
static var config := {"track": 0, "laps": 3, "difficulty": 1, "team": 0, "ai_count": 7}
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

# ---------- tracks ----------

static func track() -> Dictionary:
	return TRACKS[clampi(int(config["track"]), 0, TRACKS.size() - 1)]

## Control points for a track entry: explicit points, or a generated superellipse loop.
static func track_points(data: Dictionary) -> Array:
	if data.has("points") and not (data["points"] as Array).is_empty():
		return (data["points"] as Array).duplicate()
	var n := maxi(int(data.get("count", 16)), 4)
	var rx: float = float(data.get("rx", 450.0))
	var rz: float = float(data.get("rz", 340.0))
	var power: float = maxf(float(data.get("power", 3.0)), 1.2)
	var elev: float = float(data.get("elev", 0.0))
	var wobble: float = float(data.get("wobble", 0.0))
	var out: Array = []
	for i in n:
		var a := TAU * float(i) / float(n)
		var c := cos(a)
		var s := sin(a)
		var k := 1.0 + wobble * sin(a * 3.0)
		var x := signf(c) * pow(absf(c), 2.0 / power) * rx * k
		var z := signf(s) * pow(absf(s), 2.0 / power) * rz * k
		var y := elev * (0.5 - 0.5 * cos(a * 2.0))
		out.append(Vector3(x, y, z))
	return out

static func _curve_from(data: Dictionary) -> Curve3D:
	var src := track_points(data)
	var c := Curve3D.new()
	var n := src.size()
	for i in n + 1:
		var p: Vector3 = src[i % n]
		var prev: Vector3 = src[(i - 1 + n) % n]
		var nxt: Vector3 = src[(i + 1) % n]
		var h := (nxt - prev) / 5.0
		c.add_point(p, -h, h)
	return c

## Centre line in XZ, normalised to 0..1. Used by track previews and the minimap.
static func track_preview(data: Dictionary, steps := 180) -> PackedVector2Array:
	var c := _curve_from(data)
	var total := c.get_baked_length()
	var raw: Array[Vector2] = []
	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)
	for i in steps + 1:
		var p := c.sample_baked(total * float(i) / float(steps))
		raw.append(Vector2(p.x, p.z))
		minv = Vector2(minf(minv.x, p.x), minf(minv.y, p.z))
		maxv = Vector2(maxf(maxv.x, p.x), maxf(maxv.y, p.z))
	var span := maxf(maxf(maxv.x - minv.x, maxv.y - minv.y), 1.0)
	var out := PackedVector2Array()
	for v in raw:
		out.append((v - minv) / span)
	return out

## Lap length in metres, measured on the same curve the race track builds.
static func track_length(data: Dictionary) -> float:
	var c := _curve_from(data)
	c.bake_interval = 2.0
	return c.get_baked_length()

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
