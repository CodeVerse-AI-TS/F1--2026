extends CanvasLayer
## Championship standings overlay: driver table, constructor table, and either a
## continue action (next round) or a close action when opened from the main menu.
## After the final round it also shows the champion and the podium.

signal continue_pressed
signal close_pressed

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")
const Championship = preload("res://scripts/championship.gd")

var show_continue := true

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	panel.custom_minimum_size = Vector2(780, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(UI.label("CHAMPIONSHIP", 32, UI.GOLD))
	v.add_child(UI.label("%s   -   %s" % [Championship.round_label(),
		String(Championship.round_track()["name"])] if not Championship.finished
		else "SEASON COMPLETE", 17, UI.TEXT_DIM))

	# season outcome: champion and podium
	if Championship.finished:
		var top := Championship.drivers_sorted()
		if not top.is_empty():
			v.add_child(UI.label("CHAMPION:  %s" % String((top[0] as Dictionary)["name"]), 26, UI.GOLD))
		var podium := "PODIUM   "
		for i in mini(3, top.size()):
			podium += "%d. %s (%d)   " % [i + 1, String((top[i] as Dictionary)["name"]),
				int((top[i] as Dictionary)["points"])]
		v.add_child(UI.label(podium, 16, Color.WHITE))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	v.add_child(cols)

	# driver table
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	cols.add_child(dv)
	dv.add_child(UI.label("DRIVERS", 18, UI.GOLD))
	var dgrid := GridContainer.new()
	dgrid.columns = 4
	dgrid.add_theme_constant_override("h_separation", 20)
	dgrid.add_theme_constant_override("v_separation", 3)
	dv.add_child(dgrid)
	for h in ["POS", "DRIVER", "TEAM", "PTS"]:
		dgrid.add_child(UI.label(h, 13, UI.TEXT_DIM))
	var rows := Championship.drivers_sorted()
	for i in rows.size():
		var e: Dictionary = rows[i]
		var me := String(e["name"]) == Championship.player_name
		var col := UI.GOLD if me else Color.WHITE
		dgrid.add_child(UI.label("%d" % (i + 1), 16, col))
		dgrid.add_child(UI.label(String(e["name"]), 16, col))
		dgrid.add_child(UI.label(String(e["team"]), 15, UI.TEXT_DIM))
		dgrid.add_child(UI.label(str(int(e["points"])), 16, col))

	# constructor table
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	cols.add_child(tv)
	tv.add_child(UI.label("CONSTRUCTORS", 18, UI.GOLD))
	var tgrid := GridContainer.new()
	tgrid.columns = 3
	tgrid.add_theme_constant_override("h_separation", 20)
	tgrid.add_theme_constant_override("v_separation", 3)
	tv.add_child(tgrid)
	for h in ["POS", "TEAM", "PTS"]:
		tgrid.add_child(UI.label(h, 13, UI.TEXT_DIM))
	var teams := Championship.teams_sorted()
	for i in teams.size():
		var e: Dictionary = teams[i]
		var mine := String(e["name"]) == Championship.team_name(Championship.player_team)
		var col := UI.GOLD if mine else Color.WHITE
		tgrid.add_child(UI.label("%d" % (i + 1), 16, col))
		tgrid.add_child(UI.label(String(e["name"]), 16, col))
		tgrid.add_child(UI.label(str(int(e["points"])), 16, col))

	# last completed round's classification
	if not Championship.history.is_empty():
		var last: Dictionary = Championship.history[Championship.history.size() - 1]
		var line := "R%d  %s   " % [int(last.get("round", 0)), String(last.get("track", ""))]
		for e in (last.get("order", []) as Array):
			line += "%s %d  " % [String((e as Dictionary)["name"]), int((e as Dictionary)["points"])]
		var rl := UI.label(line, 13, Color(1, 1, 1, 0.6))
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(720, 0)
		v.add_child(rl)

	v.add_child(UI.label("Saved locally to user://championship.json", 12, Color(1, 1, 1, 0.4)))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	if show_continue:
		var next_txt := "BACK TO MENU" if Championship.finished else "NEXT ROUND"
		var b := UI.button(next_txt, _on_continue)
		buttons.add_child(b)
		b.grab_focus()
	buttons.add_child(UI.button("MENU" if show_continue else "BACK", _on_close))

func _on_continue() -> void:
	continue_pressed.emit()

func _on_close() -> void:
	close_pressed.emit()
