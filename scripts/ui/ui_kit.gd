extends RefCounted
## Shared code-built UI widgets for menus (dark glass panels, gold accents).

const GOLD := Color(1.0, 0.8, 0.35)
const TEXT_DIM := Color(0.72, 0.72, 0.78)

static func panel_style(alpha := 0.85) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.045, alpha)
	sb.border_color = Color(GOLD, 0.85)
	sb.border_width_left = 4
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	return sb

static func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 4
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func button(text: String, cb: Callable, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.05, 0.05, 0.07, 0.75), Color(1, 1, 1, 0.15)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.12, 0.1, 0.06, 0.9), GOLD))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.25, 0.18, 0.05, 0.95), GOLD))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0.12, 0.1, 0.06, 0.9), GOLD))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.04, 0.04, 0.05, 0.5), Color(1, 1, 1, 0.05)))
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(cb)
	return b

static func label(text: String, font_size := 18, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l

static func option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, items.size() - 1))
	o.custom_minimum_size = Vector2(260, 38)
	o.item_selected.connect(cb)
	return o

static func slider(value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(260, 30)
	s.value_changed.connect(cb)
	return s

static func row(label_text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(label_text, 18, TEXT_DIM)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	h.add_child(control)
	return h
