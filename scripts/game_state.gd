extends RefCounted
## GameState: game mode, session state machine, race config and persisted settings.
## Static data shared across scenes; use it with
##   const GameState = preload("res://scripts/game_state.gd")
## Session states: MENU -> (QUALIFYING) -> RACE <-> PIT / PAUSED -> RESULTS -> MENU.

enum Mode { TIME_TRIAL, QUICK_RACE, CHAMPIONSHIP }
enum State { MENU, QUALIFYING, RACE, PIT, PAUSED, RESULTS }

const SETTINGS_PATH := "user://settings.cfg"
const LEADERBOARD_PATH := "user://leaderboard.json"
const RACE_SCENE := "res://main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const MAX_FLASHBACKS := 3
const CAMERA_NAMES := ["CHASE", "FAR CHASE", "COCKPIT", "HOOD", "TV", "TOP DOWN"]
const QUALITY_NAMES := ["Low", "Medium", "High"]
## Weather presets: index into WEATHER_NAMES, fed to weather.gd setup().
const WEATHER_NAMES := ["Dry", "Changeable", "Wet"]
const DIFFICULTIES := ["Rookie", "Pro", "Legend"]
const LAP_OPTIONS := [3, 5, 10]
## Race length choices: fixed lap counts first, then percentage distances that are
## converted into a lap count from the track length (see resolve_laps).
const RACE_LENGTHS := ["3 laps", "5 laps", "10 laps", "25% distance", "50% distance", "100% distance"]
## Target race duration in seconds for the three percentage options (short: 5-10 minutes).
const RACE_TARGET_SECONDS := [360.0, 480.0, 720.0]
const AI_OPTIONS := [0, 3, 5, 7, 9]
## Base AI pace (fraction of the ideal lap) per difficulty: Rookie, Pro, Legend.
const AI_SKILL := [0.88, 0.98, 1.03]
## Behaviour per difficulty, read by ai_car.gd apply_profile(): braking force (m/s^2),
## aggression band, ERS deployment willingness, divebomb willingness, mistake rate.
const AI_PROFILES := [
	{"brake": 36.0, "aggression": Vector2(0.2, 0.5), "ers": 0.12, "dive": 0.15, "mistakes": 0.030},
	{"brake": 48.0, "aggression": Vector2(0.5, 0.8), "ers": 0.55, "dive": 0.55, "mistakes": 0.020},
	{"brake": 54.0, "aggression": Vector2(0.75, 1.0), "ers": 0.95, "dive": 0.90, "mistakes": 0.008},
]
const DRIVERS := ["M. Varela", "K. Osei", "L. Brandt", "T. Nakamura", "R. Duval",
	"S. Kowalski", "A. Romano", "J. Hale", "D. Ferreira", "E. Lindqvist", "P. Mehta"]
## Track catalogue. A track is either explicit "points" or a superellipse loop
## (count, rx, rz, power, elev, wobble). "drs" holds lap fractions.
const TRACK_DIFFICULTY := ["Easy", "Medium", "Hard"]
const TRACKS := [
	{
		"id": "spa", "name": "Spa-Francorchamps", "theme": "forest",
		"half_w": 8.5, "difficulty": 3, "corners": 19, "length_km": 7.004,
		"desc": "Ardennes forest, the greatest elevation change in racing: La Source downhill, the 40 m climb through Eau Rouge and Raidillon, and the flat-out Kemmel Straight.",
		"points": [
			Vector3(0, 0, 0), Vector3(0, 0, -420), Vector3(-30, 1, -520), Vector3(-120, 3, -560),
			Vector3(-190, 5, -520), Vector3(-200, 6, -430), Vector3(-240, 8, -360),
			Vector3(-330, 15, -330), Vector3(-420, 24, -350), Vector3(-470, 31, -420),
			Vector3(-520, 38, -500), Vector3(-640, 46, -560), Vector3(-800, 48, -580),
			Vector3(-950, 46, -600), Vector3(-1090, 42, -640), Vector3(-1180, 38, -720),
			Vector3(-1200, 34, -830), Vector3(-1150, 30, -940), Vector3(-1060, 27, -1000),
			Vector3(-950, 24, -1010), Vector3(-860, 22, -970), Vector3(-820, 20, -890),
			Vector3(-860, 17, -820), Vector3(-950, 15, -790), Vector3(-1060, 14, -760),
			Vector3(-1140, 14, -680), Vector3(-1150, 15, -580), Vector3(-1110, 17, -500),
			Vector3(-1040, 19, -450), Vector3(-960, 20, -420), Vector3(-880, 19, -400),
			Vector3(-800, 17, -380), Vector3(-730, 14, -330), Vector3(-690, 11, -260),
			Vector3(-700, 9, -180), Vector3(-760, 8, -120), Vector3(-840, 8, -90),
			Vector3(-900, 8, -40), Vector3(-880, 6, 40), Vector3(-820, 4, 90),
			Vector3(-760, 2, 70), Vector3(-700, 0, 20), Vector3(-620, 0, -10),
			Vector3(-520, 0, 0),
		],
		"drs": [
			{"detect_m": 1990.0, "start_m": 2050.0, "end_m": 2740.0},
			{"detect_m": 6460.0, "start_m": 6520.0, "end_m": 6890.0},
		],
		"pit": {"entry": 0.955, "exit": 0.06, "box": 0.985},
		"banking": 1.0,
		# a rock gallery bored through the hillside on the plunge out of Les Combes,
		# placed by control point so it sits on the descent it belongs to
		"tunnels": [{"start_pt": 15, "end_pt": 18, "height": 7.2, "wall_extra": 1.4}],
	},
	{
		"id": "monza", "name": "Autodromo Nazionale Monza", "theme": "park",
		"half_w": 9.0, "difficulty": 1, "corners": 11, "length_km": 5.793,
		"desc": "The Temple of Speed in the royal park. Rettifilo, the Curva Grande, Lesmo, Ascari and the Parabolica - slipstream, brake, repeat.",
		"points": [
			Vector3(0, 0, 0), Vector3(0, 0, -600), Vector3(-10, 0, -760),
			Vector3(-70, 0, -840), Vector3(-170, 0, -850), Vector3(-250, 0, -800),
			Vector3(-280, 0, -720), Vector3(-260, 0, -620),
			Vector3(-300, 0, -540), Vector3(-380, 0, -520), Vector3(-470, 0, -480),
			Vector3(-560, 0, -440), Vector3(-680, 0, -420), Vector3(-820, 0, -430),
			Vector3(-950, 0, -470),
			Vector3(-1030, 0, -520), Vector3(-1060, 0, -600), Vector3(-1040, 0, -680),
			Vector3(-970, 0, -720), Vector3(-900, 0, -700),
			Vector3(-880, 1, -600), Vector3(-890, 2, -480), Vector3(-930, 3, -360),
			Vector3(-900, 3, -260), Vector3(-820, 2, -200), Vector3(-700, 1, -190),
			Vector3(-560, 0, -200), Vector3(-420, 0, -230), Vector3(-300, 0, -220),
			Vector3(-190, 0, -180),
			Vector3(-120, 0, -110), Vector3(-80, 0, -40), Vector3(0, 0, 0),
		],
		"drs": [
			{"detect_m": 60.0, "start_m": 140.0, "end_m": 640.0},
			{"detect_m": 2870.0, "start_m": 2980.0, "end_m": 4700.0},
		],
		"pit": {"entry": 0.93, "exit": 0.05, "box": 0.975},
		"banking": 0.35,
		# the Serraglio back straight ducks under the historic park overpass
		"tunnels": [{"start_pt": 12, "end_pt": 14, "height": 7.6, "wall_extra": 1.6}],
	},
	{
		"id": "silverstone", "name": "Silverstone Circuit", "theme": "airfield",
		"half_w": 9.0, "difficulty": 2, "corners": 18, "length_km": 5.891,
		"desc": "The Home of British Motorsport: Abbey, Village, the Wellington Straight, Copse, then the Maggotts-Becketts-Chapel complex into Hangar Straight and Stowe.",
		"points": [
			Vector3(0, 0, 0), Vector3(20, 0, -200), Vector3(60, 0, -330),
			Vector3(130, 1, -400), Vector3(230, 2, -410), Vector3(320, 2, -370),
			Vector3(370, 1, -290), Vector3(360, 0, -200),
			Vector3(300, 0, -150), Vector3(210, 0, -160), Vector3(150, 0, -230),
			Vector3(150, 0, -330),
			Vector3(210, 0, -420), Vector3(320, 0, -470), Vector3(450, 0, -480),
			Vector3(560, 0, -440),
			Vector3(620, 0, -350), Vector3(690, 0, -280), Vector3(790, 0, -250),
			Vector3(860, 0, -180), Vector3(850, 0, -100),
			Vector3(930, 0, -60), Vector3(1050, 0, -50), Vector3(1160, 1, -90),
			Vector3(1220, 2, -180), Vector3(1210, 2, -300), Vector3(1150, 2, -370),
			Vector3(1040, 1, -390), Vector3(900, 1, -380), Vector3(780, 0, -400),
			Vector3(680, 0, -430), Vector3(570, 0, -440), Vector3(450, 0, -350),
			Vector3(380, 0, -240), Vector3(300, 0, -150), Vector3(180, 0, -110),
			Vector3(80, 0, -70), Vector3(0, 0, -20),
		],
		"drs": [
			{"detect_m": 760.0, "start_m": 860.0, "end_m": 1330.0},
			{"detect_m": 2300.0, "start_m": 2400.0, "end_m": 3080.0},
		],
		"pit": {"entry": 0.94, "exit": 0.05, "box": 0.98},
		"banking": 0.6,
		# Hangar Straight runs through a concrete underpass at the airfield perimeter
		"tunnels": [{"start_pt": 16, "end_pt": 19, "height": 6.8, "wall_extra": 1.2}],
	},
	{
		"id": "suzuka", "name": "Suzuka Circuit", "theme": "grandstand",
		"half_w": 8.5, "difficulty": 3, "corners": 18, "length_km": 5.807,
		"desc": "The world's only figure-eight: the S-curves, Degner, the hairpin, Spoon, the 330 km/h back straight, 130R and the Casio Triangle under the lights.",
		"points": [
			Vector3(0, 0, 0), Vector3(-90, 0, -60), Vector3(-160, 1, -160),
			Vector3(-170, 2, -280), Vector3(-140, 3, -390),
			Vector3(-150, 4, -500), Vector3(-200, 5, -590), Vector3(-290, 6, -630),
			Vector3(-390, 7, -610), Vector3(-450, 7, -540),
			Vector3(-430, 6, -450), Vector3(-370, 5, -390),
			Vector3(-300, 5, -340), Vector3(-230, 4, -290),
			Vector3(-190, 3, -220), Vector3(-210, 2, -160),
			Vector3(-290, 2, -140), Vector3(-350, 2, -180),
			Vector3(-370, 2, -250),
			Vector3(-410, 2, -330), Vector3(-490, 2, -360), Vector3(-560, 2, -320),
			Vector3(-590, 2, -240), Vector3(-570, 2, -150),
			Vector3(-520, 1, -90), Vector3(-460, 0, -60),
			Vector3(-380, 0, -40), Vector3(-300, 0, -60),
			Vector3(-260, 0, -130), Vector3(-240, 0, -220),
			Vector3(-200, 0, -280), Vector3(-120, 0, -300),
			Vector3(-40, 0, -260), Vector3(10, 0, -180),
			Vector3(20, 0, -90), Vector3(0, 0, -20),
		],
		"drs": [
			{"detect_m": 3200.0, "start_m": 3300.0, "end_m": 4300.0},
			{"detect_m": 5300.0, "start_m": 5350.0, "end_m": 5650.0},
		],
		"pit": {"entry": 0.95, "exit": 0.05, "box": 0.982},
		"banking": 0.5,
		# underpass between the hairpin exit and the run down to 130R
		"tunnels": [{"start_m": 1500.0, "end_m": 1760.0, "height": 6.4, "wall_extra": 1.0}],
	},
	{
		"id": "monaco", "name": "Monte Carlo Street Circuit", "theme": "street",
		"half_w": 7.5, "difficulty": 3, "corners": 16, "length_km": 2.85, "banking": 0.0,
		"desc": "Harbour walls with no run-off: Sainte Devote, the long climb carried over the city to the Casino plateau, the tunnel bored through the rock, the covered gallery on the descent, then the flyover across the start straight and the dive back down to the line.",
		"points": [
			# main straight, start line at the harbour end
			Vector3(0, 0, 0), Vector3(0, 0, -180), Vector3(0, 0, -360),
			# T1 Sainte Devote: one clean 70 m radius onto the west climb
			Vector3(-3, 0.2, -379), Vector3(-11, 0.6, -397), Vector3(-24, 1.2, -412),
			Vector3(-40, 2.0, -423), Vector3(-58, 2.8, -429), Vector3(-78, 3.4, -431),
			# Beau Rivage climb across the hillside
			Vector3(-150, 4.6, -439), Vector3(-235, 6.2, -446), Vector3(-320, 7.8, -450),
			Vector3(-400, 9.0, -444), Vector3(-462, 9.6, -434),
			# Casino plateau sweeper
			Vector3(-493, 9.9, -422), Vector3(-509, 10.0, -409), Vector3(-522, 10.0, -396),
			Vector3(-532, 10.0, -381), Vector3(-538, 10.0, -368), Vector3(-540, 9.9, -352),
			Vector3(-542, 9.8, -320), Vector3(-543, 9.5, -288),
			# Massenet: the plateau turns back east
			Vector3(-541, 9.4, -273), Vector3(-535, 9.3, -259), Vector3(-526, 9.2, -247),
			Vector3(-514, 9.1, -238), Vector3(-500, 9.0, -232), Vector3(-485, 8.9, -230),
			# the flyover run: a viaduct carried east over the city
			Vector3(-440, 8.8, -228), Vector3(-370, 8.6, -226), Vector3(-295, 8.4, -224),
			Vector3(-220, 8.2, -222), Vector3(-145, 8.0, -220), Vector3(-70, 7.8, -218),
			# the crossing: this deck passes over the start straight
			Vector3(0, 7.6, -216),
			Vector3(80, 7.4, -214), Vector3(150, 7.2, -208), Vector3(205, 7.0, -192),
			# descent round the east side, with the covered gallery
			Vector3(235, 6.6, -165), Vector3(250, 6.2, -130), Vector3(258, 5.8, -85),
			Vector3(262, 5.3, -30), Vector3(262, 4.8, 30), Vector3(258, 4.3, 90),
			Vector3(250, 3.9, 140), Vector3(236, 3.5, 180), Vector3(214, 3.2, 212),
			Vector3(184, 2.9, 236),
			# seafront run back west
			Vector3(146, 2.7, 250), Vector3(110, 2.6, 252), Vector3(75, 2.5, 252),
			Vector3(50, 2.4, 251), Vector3(35, 2.3, 250),
			# final right-hander: a single 35 m quarter arc, entered square to the seafront
			# and leaving it dead centre on the start straight, so the lap closes clean
			Vector3(17.5, 2.0, 245.3), Vector3(4.7, 1.7, 232.5), Vector3(0, 1.3, 215),
			Vector3(0, 0.8, 185), Vector3(0, 0.3, 150),
		],
		"drs": [{"detect": 0.95, "start": 0.02, "end": 0.10}],
		"pit": {"entry": 0.93, "exit": 0.05, "box": 0.975},
		# The tunnel bored through the rock on the climb (control points 10 -> 13) and a
		# covered gallery on the east descent (points 39 -> 43), both placed by point index
		# so they sit exactly on the section of road they belong to.
		"tunnels": [
			{"start_pt": 10, "end_pt": 13, "height": 7.0, "wall_extra": 1.3},
			{"start_pt": 39, "end_pt": 43, "height": 6.2, "wall_extra": 1.0},
		],
	},
]
## Per-theme sky, sun and scenery recipe used by scripts/track.gd.
const THEMES := {
	# Spa: cool Ardennes forest light, deep green and a lot of tree cover.
	"forest": {
		"sky_top": Color(0.55, 0.66, 0.82), "ambient": Color(0.48, 0.55, 0.62),
		"ambient_energy": 0.6, "haze": Color(0.74, 0.80, 0.84), "fog": 0.0014,
		"sun": Color(1.0, 0.94, 0.84), "sun_energy": 1.6,
		"ground": "grass", "ground_tint": Color(0.30, 0.44, 0.26),
		"buildings": false, "harbour": false, "hills": true, "lamps": true,
		"vegetation": 3, "floodlights": false,
	},
	# Monza: Royal Park, flat, sunny, dense broadleaf parkland.
	"park": {
		"sky_top": Color(0.52, 0.70, 0.92), "ambient": Color(0.62, 0.68, 0.74),
		"ambient_energy": 0.75, "haze": Color(0.86, 0.88, 0.84), "fog": 0.0008,
		"sun": Color(1.0, 0.96, 0.86), "sun_energy": 2.0,
		"ground": "grass", "ground_tint": Color(0.36, 0.50, 0.28),
		"buildings": false, "harbour": false, "hills": false, "lamps": true,
		"vegetation": 3, "floodlights": false,
	},
	# Silverstone: open airfield, huge run-off, big British sky.
	"airfield": {
		"sky_top": Color(0.58, 0.68, 0.82), "ambient": Color(0.66, 0.70, 0.76),
		"ambient_energy": 0.8, "haze": Color(0.88, 0.90, 0.92), "fog": 0.0006,
		"sun": Color(1.0, 0.97, 0.92), "sun_energy": 1.7,
		"ground": "grass", "ground_tint": Color(0.40, 0.52, 0.30),
		"buildings": false, "harbour": false, "hills": false, "lamps": true,
		"vegetation": 1, "floodlights": false,
	},
	# Monaco: pale Mediterranean stone pressed right up to the walls, warm low sun.
	# A street circuit has no grass and no trees, so both stay off.
	"street": {
		"sky_top": Color(0.60, 0.73, 0.90), "ambient": Color(0.68, 0.68, 0.68),
		"ambient_energy": 0.90, "haze": Color(0.89, 0.87, 0.81), "fog": 0.0010,
		"sun": Color(1.0, 0.93, 0.80), "sun_energy": 2.0,
		"ground": "cobblestone", "ground_tint": Color(0.80, 0.76, 0.68),
		"buildings": true, "harbour": false, "hills": true, "lamps": true,
		"vegetation": 0, "floodlights": false,
	},
	# Suzuka: night grandstand, floodlights, cool colour temperature.
	"grandstand": {
		"sky_top": Color(0.03, 0.05, 0.11), "ambient": Color(0.16, 0.20, 0.32),
		"ambient_energy": 0.45, "haze": Color(0.12, 0.16, 0.26), "fog": 0.0020,
		"sun": Color(0.60, 0.74, 1.0), "sun_energy": 0.35,
		"ground": "asphalt", "ground_tint": Color(0.30, 0.32, 0.36),
		"buildings": true, "harbour": false, "hills": true, "lamps": true,
		"vegetation": 2, "floodlights": true,
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
## "setup" is the car setup screen: 0..1 sliders, 0.5 is neutral on every axis.
static var config := {"track": 0, "laps": 3, "length": 0, "difficulty": 1, "team": 0,
	"ai_count": 7, "player_name": "DRIVER", "weather": 1,
	"setup": {"aero": 0.5, "susp": 0.5, "bias": 0.5}}
static var flashbacks := MAX_FLASHBACKS
## Championship sessions: the race scene loads as a qualifying run first, then as the race.
static var qualifying := false
## Championship race distance in laps (kept short so a full season stays playable).
static var championship_laps := 4
## traction / brake_aid are driving aids: 0 off, 1 on. They only help the player.
static var settings := {"master": 0.8, "music": 0.6, "sfx": 0.9, "quality": 2, "camera": 0, "units": 0,
	"show_fps": 0, "traction": 1, "brake_aid": 0}
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

## Centre line in raw world XZ metres, on the same curve the race track builds.
## The minimap needs this: car positions are world space, so they can only be
## projected against an outline that lives in the same space.
static func track_world_points(data: Dictionary, steps := 180) -> PackedVector2Array:
	var c := _curve_from(data)
	var total := c.get_baked_length()
	var out := PackedVector2Array()
	for i in steps + 1:
		var p := c.sample_baked(total * float(i) / float(steps))
		out.append(Vector2(p.x, p.z))
	return out

## Lap length in metres, measured on the same curve the race track builds.
static func track_length(data: Dictionary) -> float:
	var c := _curve_from(data)
	c.bake_interval = 2.0
	return c.get_baked_length()

## Rough corner count: one per continuous run of meaningful direction change.
## Real circuits declare "corners" in their data, which wins when present.
static func track_corners(data: Dictionary) -> int:
	if data.has("corners"):
		return int(data["corners"])
	var c := _curve_from(data)
	c.bake_interval = 4.0
	var total := c.get_baked_length()
	var steps := maxi(int(total / 4.0), 8)
	var corners := 0
	var in_corner := false
	var prev := 0.0
	for i in steps:
		var a := c.sample_baked(total * float(i) / float(steps))
		var b := c.sample_baked(total * float(i + 1) / float(steps))
		var dir := atan2(b.z - a.z, b.x - a.x)
		if i > 0:
			if absf(angle_difference(prev, dir)) > 0.02:
				if not in_corner:
					corners += 1
					in_corner = true
			else:
				in_corner = false
		prev = dir
	return corners

## Lap count for the chosen race-length option. Fixed options return their lap count;
## percentage options aim at a target race duration using the track's ideal pace,
## so a short race stays roughly 5-10 minutes whatever the circuit length.
static func resolve_laps(data: Dictionary, length_index: int) -> int:
	var idx := clampi(length_index, 0, RACE_LENGTHS.size() - 1)
	if idx <= 2:
		return int(LAP_OPTIONS[idx])
	# percentage options: average arcade pace turns the lap length into a lap time estimate
	var metres := track_length(data)
	var est_lap := clampf(metres / 52.0, 18.0, 190.0)
	var target: float = float(RACE_TARGET_SECONDS[clampi(idx - 3, 0, RACE_TARGET_SECONDS.size() - 1)])
	return clampi(int(round(target / est_lap)), 2, 99)

## Fastest recorded lap for a track (0 when nothing is recorded yet).
## Reads the same user://leaderboard.json the leaderboard screen writes.
static func best_lap_for(track_id: String, mode_key := "time_trial") -> float:
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if f == null:
		return 0.0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0.0
	var board: Dictionary = parsed
	var entry: Dictionary = board.get(track_id, {})
	var rows: Array = entry.get(mode_key, [])
	var best := 0.0
	for r in rows:
		var t := float((r as Dictionary).get("time", 0.0))
		if t > 0.0 and (best == 0.0 or t < best):
			best = t
	return best

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
