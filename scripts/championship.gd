extends RefCounted
## Championship season: five rounds, one per circuit. Every weekend is a qualifying
## session (one flying lap sets your grid slot) followed by a race. Points go to the
## top ten with 25-18-15-12-10-8-6-4-2-1, and both a driver and a constructor table
## are kept. The whole season is saved to user://championship.json.
##
## The state lives in static vars, so it survives the scene changes between the
## qualifying and race sessions. Use it with
##   const Championship = preload("res://scripts/championship.gd")

const GameState = preload("res://scripts/game_state.gd")

const SAVE_PATH := "user://championship.json"
const POINTS := [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]
const FIELD_SIZE := 10        # the player plus nine rivals
const ROUNDS := 5
## One round per circuit in this order: street, speedway, technical, desert, night.
const ROUND_TRACKS := [0, 1, 2, 3, 4]

static var active := false
static var finished := false
static var round_index := 0
static var player_name := "DRIVER"
static var player_team := 0
static var driver_points: Dictionary = {}
static var team_points: Dictionary = {}
static var history: Array = []      # one entry per completed round
static var grid: Array = []         # qualifying classification, fastest first

# ---------- season setup ----------

## Clears every table. The config still holds the player's name and team.
static func reset() -> void:
	active = false
	finished = false
	round_index = 0
	player_name = String(GameState.config.get("player_name", "DRIVER"))
	player_team = int(GameState.config.get("team", 0))
	driver_points.clear()
	team_points.clear()
	history.clear()
	grid.clear()

## Starts a fresh five-round season with the given driver name and team.
static func new_season(driver: String, team: int) -> void:
	reset()
	active = true
	player_name = driver.strip_edges().to_upper()
	if player_name == "":
		player_name = "DRIVER"
	player_team = clampi(team, 0, GameState.TEAMS.size() - 1)
	GameState.config["player_name"] = player_name
	GameState.config["team"] = player_team
	_ensure_points()
	save()

static func team_name(idx: int) -> String:
	return String(GameState.TEAMS[clampi(idx, 0, GameState.TEAMS.size() - 1)]["name"])

## The ten seats on the grid: the player plus nine rivals, two cars per team.
static func field() -> Array:
	var out: Array = []
	var used := {}
	var pt := clampi(player_team, 0, GameState.TEAMS.size() - 1)
	out.append({"name": player_name, "team": pt, "seat": 0,
		"number": int(GameState.TEAMS[pt]["number"]), "player": true})
	used["%d_0" % pt] = true
	var d := 0
	for t in GameState.TEAMS.size():
		for seat in 2:
			if out.size() >= FIELD_SIZE:
				return out
			var key := "%d_%d" % [t, seat]
			if used.has(key):
				continue
			used[key] = true
			var number := int(GameState.TEAMS[t]["number"]) + (0 if seat == 0 else 50)
			out.append({"name": GameState.DRIVERS[d % GameState.DRIVERS.size()], "team": t,
				"seat": seat, "number": number, "player": false})
			d += 1
	return out

## Every driver on the entry list starts the season on zero points.
static func _ensure_points() -> void:
	for e in field():
		var n := String(e["name"])
		if not driver_points.has(n):
			driver_points[n] = 0
		var tn := team_name(int(e["team"]))
		if not team_points.has(tn):
			team_points[tn] = 0

static func team_of(driver: String) -> String:
	for e in field():
		if String(e["name"]) == driver:
			return team_name(int(e["team"]))
	return ""

# ---------- rounds ----------

static func round_track_index() -> int:
	return int(ROUND_TRACKS[clampi(round_index, 0, ROUND_TRACKS.size() - 1)])

static func round_track() -> Dictionary:
	return GameState.TRACKS[round_track_index()]

static func round_label() -> String:
	return "ROUND %d / %d" % [mini(round_index + 1, ROUNDS), ROUNDS]

## Loads this round's circuit and starts the qualifying session.
static func start_qualifying() -> void:
	_ensure_points()
	GameState.mode = GameState.Mode.CHAMPIONSHIP
	GameState.qualifying = true
	GameState.config["track"] = round_track_index()
	GameState.config["ai_count"] = FIELD_SIZE - 1
	GameState.flashbacks = GameState.MAX_FLASHBACKS
	grid.clear()
	GameState.tree().paused = false
	GameState.set_state(GameState.State.QUALIFYING)
	GameState.tree().change_scene_to_file(GameState.RACE_SCENE)

## The race session for the same round, with the grid built in qualifying.
static func start_race() -> void:
	GameState.qualifying = false
	GameState.tree().paused = false
	GameState.set_state(GameState.State.RACE)
	GameState.tree().change_scene_to_file(GameState.RACE_SCENE)

## Loads the next round's circuit and starts its qualifying session.
static func start_next_round() -> void:
	if finished:
		return
	start_qualifying()

## Builds the qualifying classification: your flying lap plus simulated rival laps.
## ideal_time is the circuit's own reference lap, which sets the rivals' pace.
static func record_qualifying(player_time: float, ideal_time: float) -> void:
	_ensure_points()
	var rows: Array = []
	var base: float = GameState.AI_SKILL[clampi(int(GameState.config.get("difficulty", 1)), 0, 2)]
	var i := 0
	for e in field():
		if bool(e["player"]):
			rows.append({"name": String(e["name"]), "team": int(e["team"]),
				"time": player_time, "player": true})
			continue
		# each rival has a small fixed pace edge or deficit on top of the difficulty
		var skill := clampf(base + randf_range(-0.028, 0.018) + float(i) * 0.0022, 0.80, 1.02)
		var t := ideal_time / skill * (1.0 + randf_range(0.0, 0.012))
		rows.append({"name": String(e["name"]), "team": int(e["team"]), "time": t, "player": false})
		i += 1
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"]))
	grid = rows
	save()

## Your slot in the last qualifying classification (0 = pole).
static func player_grid_slot() -> int:
	for i in grid.size():
		if bool((grid[i] as Dictionary).get("player", false)):
			return i
	return 0

## Awards points for the finish order (driver names, winner first) and moves on.
static func complete_round(order: Array) -> void:
	_ensure_points()
	var round_no := round_index + 1
	var rows: Array = []
	for i in order.size():
		var n := String(order[i])
		var pts: int = int(POINTS[i]) if i < POINTS.size() else 0
		driver_points[n] = int(driver_points.get(n, 0)) + pts
		var tn := team_of(n)
		if tn != "":
			team_points[tn] = int(team_points.get(tn, 0)) + pts
		rows.append({"name": n, "points": pts})
	history.append({"round": round_no, "track": String(round_track()["name"]), "order": rows})
	round_index += 1
	finished = round_index >= ROUNDS
	save()

# ---------- standings ----------

## Driver table, most points first (ties broken alphabetically).
static func drivers_sorted() -> Array:
	var rows: Array = []
	for n in driver_points.keys():
		rows.append({"name": String(n), "points": int(driver_points[n]), "team": team_of(String(n))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) == int(b["points"]):
			return String(a["name"]) < String(b["name"])
		return int(a["points"]) > int(b["points"]))
	return rows

## Constructor table, most points first.
static func teams_sorted() -> Array:
	var rows: Array = []
	for n in team_points.keys():
		rows.append({"name": String(n), "points": int(team_points[n])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) == int(b["points"]):
			return String(a["name"]) < String(b["name"])
		return int(a["points"]) > int(b["points"]))
	return rows

## Your position in the driver table (1 based).
static func player_position() -> int:
	var rows := drivers_sorted()
	for i in rows.size():
		if String((rows[i] as Dictionary)["name"]) == player_name:
			return i + 1
	return rows.size() + 1

static func player_points() -> int:
	return int(driver_points.get(player_name, 0))

# ---------- saving ----------

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func save() -> void:
	var data := {
		"active": active, "finished": finished, "round": round_index,
		"player_name": player_name, "player_team": player_team,
		"drivers": driver_points, "teams": team_points,
		"history": history, "grid": grid,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()

## Reads the saved season. Returns false when there is nothing to load.
static func load_season() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	active = bool(d.get("active", false))
	finished = bool(d.get("finished", false))
	round_index = int(d.get("round", 0))
	player_name = String(d.get("player_name", "DRIVER"))
	player_team = int(d.get("player_team", 0))
	driver_points = _int_dict(d.get("drivers", {}))
	team_points = _int_dict(d.get("teams", {}))
	history = d.get("history", [])
	grid = d.get("grid", [])
	return active

## JSON turns every number into a float, so points come back as ints here.
static func _int_dict(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = v
	for k in src.keys():
		out[String(k)] = int(src[k])
	return out
