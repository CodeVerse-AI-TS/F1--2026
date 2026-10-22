class_name PodiumScreen
extends CanvasLayer
## Post-race podium celebration screen: top 3 driver step tiers, trophies,
## points awarded (+25, +18, +15...) and full race classification table.

signal continue_pressed
signal restart_pressed
signal menu_pressed

const UI = preload("res://scripts/ui/ui_kit.gd")
const GameState = preload("res://scripts/game_state.gd")

const FIA_POINTS := [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]
const TROPHY_COLORS := [
	Color(1.0, 0.82, 0.25),  # Gold P1
	Color(0.85, 0.88, 0.92),  # Silver P2
	Color(0.85, 0.55, 0.35),  # Bronze P3
]

func setup(results: Array, track_name: String, is_championship := false) -> void:
	layer = 25
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# dark backdrop
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.025, 0.035, 0.92)
	root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	root.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	margin.add_child(v)

	# Header title
	v.add_child(UI.title("🏆 GRAND PRIX PODIUM"))
	v.add_child(UI.label(track_name.to_upper() + "  -  OFFICIAL CLASSIFICATION", 14, UI.TEXT_DIM))

	# Top 3 Podium Tier Columns
	var podium_row := HBoxContainer.new()
	podium_row.alignment = BoxContainer.ALIGNMENT_CENTER
	podium_row.add_theme_constant_override("separation", 24)
	v.add_child(podium_row)

	# Visual podium display order: P2 (left), P1 (center, elevated), P3 (right)
	var podium_indices := [1, 0, 2]
	var heights := [140.0, 180.0, 110.0]
	for idx in 3:
		var pos_idx: int = podium_indices[idx]
		if pos_idx >= results.size():
			continue
		var r: Dictionary = results[pos_idx]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_BOTTOM
		col.custom_minimum_size = Vector2(200, 220)
		podium_row.add_child(col)

		var trophy := Label.new()
		trophy.text = ["🥈 2ND", "🥇 1ST", "🥉 3RD"][idx]
		trophy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trophy.add_theme_font_size_override("font_size", 18 if idx != 1 else 22)
		trophy.add_theme_color_override("font_color", TROPHY_COLORS[pos_idx])
		col.add_child(trophy)

		var name_lbl := Label.new()
		name_lbl.text = String(r.get("name", "Driver"))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15 if idx != 1 else 17)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(name_lbl)

		var time_lbl := Label.new()
		var gap_str := "WINNER" if pos_idx == 0 else "+%.3fs" % float(r.get("gap", 0.0))
		time_lbl.text = "%s  (+%d pts)" % [gap_str, FIA_POINTS[pos_idx]]
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_lbl.add_theme_font_size_override("font_size", 12)
		time_lbl.add_theme_color_override("font_color", UI.GOLD if pos_idx == 0 else UI.TEXT_DIM)
		col.add_child(time_lbl)

		# Tier pedestal box
		var pedestal := Panel.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.08, 0.1, 0.14, 0.9)
		psb.border_color = TROPHY_COLORS[pos_idx]
		psb.border_width_top = 4
		psb.set_corner_radius_all(4)
		pedestal.add_theme_stylebox_override("panel", psb)
		pedestal.custom_minimum_size = Vector2(200, heights[idx])
		col.add_child(pedestal)

	# Full Classification List (P4 down)
	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", UI.panel_style(0.6))
	v.add_child(list_panel)

	var list_v := VBoxContainer.new()
	list_v.add_theme_constant_override("separation", 6)
	list_panel.add_child(list_v)

	for i in range(3, mini(results.size(), 8)):
		var r: Dictionary = results[i]
		var line := HBoxContainer.new()
		var pts_award := FIA_POINTS[i] if i < FIA_POINTS.size() else 0
		var pos_str := "P%d" % (i + 1)
		var d_name: String = String(r.get("name", "Driver"))
		var d_gap := "+%.3fs" % float(r.get("gap", 0.0))
		var row_lbl := UI.label("%-4s  %-24s  %10s  (+%d pts)" % [pos_str, d_name, d_gap, pts_award], 13, Color(0.88, 0.88, 0.92))
		line.add_child(row_lbl)
		list_v.add_child(line)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	v.add_child(btn_row)

	var cont_text := "CONTINUE CHAMPIONSHIP" if is_championship else "NEXT RACE"
	btn_row.add_child(UI.button(cont_text, func() -> void: continue_pressed.emit()))
	btn_row.add_child(UI.button("RESTART", func() -> void: restart_pressed.emit()))
	btn_row.add_child(UI.button("MAIN MENU", func() -> void: menu_pressed.emit()))
