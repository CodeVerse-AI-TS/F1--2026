extends RefCounted
## Local achievement profile. Each unlock is persisted to user://achievements.json
## and reported once, so the session can toast it without repeating on reload.

const PATH := "user://achievements.json"

## id -> [title, description]
const DEFS := {
	"first_lap": ["FIRST LAP", "Complete a timed lap"],
	"gold_lap": ["GOLD PACE", "Beat the gold target time"],
	"first_win": ["WINNER", "Win a race outright"],
	"podium": ["PODIUM", "Finish a race in the top three"],
	"pit_crew": ["PIT CREW", "Complete a pit stop"],
	"rain_driver": ["RAIN DRIVER", "Finish a race in the wet"],
	"champion": ["CHAMPION", "Win a championship round"],
	"clean_lap": ["CLEAN SHEET", "Set a lap with no barrier contact"],
}

static var unlocked: Dictionary = {}
static var _loaded := false

static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		unlocked = parsed

static func save_profile() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(unlocked, "  "))

## True only the first time an id is unlocked, so callers can toast it once.
static func unlock(id: String) -> bool:
	load_profile()
	if unlocked.has(id) or not DEFS.has(id):
		return false
	unlocked[id] = Time.get_datetime_string_from_system(false, true)
	save_profile()
	return true

static func title(id: String) -> String:
	return String((DEFS.get(id, ["", ""]) as Array)[0])

static func count() -> int:
	load_profile()
	return unlocked.size()

static func total() -> int:
	return DEFS.size()
