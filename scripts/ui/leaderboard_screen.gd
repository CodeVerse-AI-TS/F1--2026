extends PanelContainer
## Local leaderboard screen: pick a circuit, switch between Time Trial / Race /
## Championship tabs, and read the top 10 with the newest entry highlighted.
## Reads and writes the same user://leaderboard.json the race submits to.

signal closed

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")
const Leaderboard = preload("res://scripts/leaderboard.gd")

var _track_idx := 0
var _mode_idx := 0
var _grid: GridContainer
var _empty: Label
var _tabs: Array[Button] = []
var _track_pick: OptionButton

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.panel_style())
	custom_minimum_size = Vector2(760, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UI.label("LEADERBOARD", 30, UI.GOLD))

	# circuit picker and the three mode tabs
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 14)
	var names: Array = []
	for t in GameState.TRACKS:
		names.append(t["name"])
	_track_pick = UI.option(names, _track_idx, _on_track)
	_track_pick.custom_minimum_size = Vector2(330, 38)
	pick_row.add_child(_track_pick)
	v.add_child(pick_row)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for i in Leaderboard.MODE_NAMES.size():
		var b := Button.new()
		b.text = Leaderboard.MODE_NAMES[i]
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(180, 40)
		b.pressed.connect(_on_mode.bind(i))
		tabs.add_child(b)
		_tabs.append(b)
	v.add_child(tabs)

	# header row: the columns the entries fill
	var head := GridContainer.new()
	head.columns = 6
	head.add_theme_constant_override("h_separation", 26)
	for h in ["POS", "DRIVER", "TIME", "DATE", "CAR", "LEVEL"]:
		head.add_child(UI.label(h, 14, UI.TEXT_DIM))
	v.add_child(head)

	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 26)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)

	_empty = UI.label("", 16, UI.TEXT_DIM)
	v.add_child(_empty)
	v.add_child(UI.label("Saved locally to user://leaderboard.json", 13, Color(1, 1, 1, 0.45)))
	v.add_child(UI.button("BACK", _close))

	_refresh()

func _on_track(idx: int) -> void:
	_track_idx = idx
	_refresh()

func _on_mode(idx: int) -> void:
	_mode_idx = idx
	_refresh()

## Rebuild the tab styling and the ten entry rows for the current selection.
func _refresh() -> void:
	for i in _tabs.size():
		var active := i == _mode_idx
		_tabs[i].add_theme_color_override("font_color", UI.GOLD if active else Color(1, 1, 1, 0.7))
		_tabs[i].disabled = false
	for c in _grid.get_children():
		c.queue_free()
	var track_id := String(GameState.TRACKS[_track_idx]["id"])
	var mode_key: String = Leaderboard.MODE_KEYS[_mode_idx]
	var rows: Array = Leaderboard.rows(Leaderboard.load_board(), track_id, mode_key)
	if rows.is_empty():
		_empty.text = "No %s times for this circuit yet." % Leaderboard.MODE_NAMES[_mode_idx].to_lower()
		return
	_empty.text = ""
	for i in rows.size():
		var e: Dictionary = rows[i]
		var newest := int(e.get("id", -1)) == Leaderboard.last_entry_id
		var col := UI.GOLD if newest else Color.WHITE
		_grid.add_child(UI.label("%d" % (i + 1), 17, col))
		_grid.add_child(UI.label(String(e.get("name", "DRIVER")), 17, col))
		_grid.add_child(UI.label(Leaderboard.fmt(float(e.get("time", 0.0))), 17, col))
		_grid.add_child(UI.label(String(e.get("date", "")), 15, UI.TEXT_DIM))
		_grid.add_child(UI.label(String(e.get("car", "")), 15, UI.TEXT_DIM))
		_grid.add_child(UI.label(String(e.get("difficulty", "")), 15, UI.TEXT_DIM))

func _close() -> void:
	closed.emit()
