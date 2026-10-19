extends RefCounted
## Local leaderboard persisted to user://leaderboard.json.
## Shape: { "<track_id>": { "time_trial": [entry], "race": [entry], "championship": [entry] } }
## An entry: {"id": int, "name": String, "time": float, "date": String,
##            "car": String, "difficulty": String, "laps": int}
## Each list is sorted fastest first and trimmed to MAX_ENTRIES.
## The newest entry id is kept in memory so screens can highlight it.

const PATH := "user://leaderboard.json"
const MAX_ENTRIES := 10
const MODE_KEYS := ["time_trial", "race", "championship"]
const MODE_NAMES := ["TIME TRIAL", "RACE", "CHAMPIONSHIP"]

static var last_entry_id := -1

static func load_board() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func save_board(board: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Leaderboard: could not open %s for writing" % PATH)
		return
	f.store_string(JSON.stringify(board, "\t"))

## Rows for one track and mode, fastest first. Always returns an Array (possibly empty).
static func rows(board: Dictionary, track_id: String, mode_key: String) -> Array:
	var track_rows: Dictionary = board.get(track_id, {})
	var list: Array = track_rows.get(mode_key, [])
	return list

## Adds a time to the board and returns {"entry": Dictionary, "rank": int, "is_record": bool}.
## rank is 1-based, 0 when the time did not make the top MAX_ENTRIES.
static func submit(track_id: String, mode_key: String, seconds: float, name: String,
		car_name: String, difficulty: String, laps: int) -> Dictionary:
	if seconds <= 0.0 or not MODE_KEYS.has(mode_key):
		return {}
	var board := load_board()
	var track_rows: Dictionary = board.get(track_id, {})
	var list: Array = track_rows.get(mode_key, [])
	var best_before := INF
	for r in list:
		best_before = minf(best_before, float((r as Dictionary).get("time", INF)))
	last_entry_id += 1
	if last_entry_id <= 0:
		last_entry_id = int(Time.get_unix_time_from_system())
	var entry := {
		"id": last_entry_id,
		"name": name if name.strip_edges() != "" else "DRIVER",
		"time": seconds,
		"date": Time.get_date_string_from_system(),
		"car": car_name,
		"difficulty": difficulty,
		"laps": laps,
	}
	list.append(entry)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("time", INF)) < float(b.get("time", INF)))
	if list.size() > MAX_ENTRIES:
		list.resize(MAX_ENTRIES)
	track_rows[mode_key] = list
	board[track_id] = track_rows
	save_board(board)
	var rank := 0
	for i in list.size():
		if int((list[i] as Dictionary).get("id", -1)) == last_entry_id:
			rank = i + 1
			break
	return {"entry": entry, "rank": rank, "is_record": seconds < best_before}

## Clears one board (used by the leaderboard screen's reset button).
static func clear_track(track_id: String, mode_key: String) -> void:
	var board := load_board()
	var track_rows: Dictionary = board.get(track_id, {})
	track_rows.erase(mode_key)
	board[track_id] = track_rows
	save_board(board)

## Formats seconds as m:ss.mmm.
static func fmt(t: float) -> String:
	if t <= 0.0 or t >= 1.0e9:
		return "--:--.---"
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]
