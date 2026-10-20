extends Control
## Live minimap: circuit outline plus one marker per car. The player is a chevron that
## points where the car is actually heading, wrapped in a pulsing halo and tagged with
## the current race position; rivals stay as smaller dots tinted with their team colour.
## game.gd feeds one entry per car:
##   {"pos": Vector3, "player": bool, "color": Color, "dir": Vector2, "rank": int}

const GameState = preload("res://scripts/game_state.gd")

const PLAYER_COLOR := Color(1.0, 0.82, 0.25)
const AI_COLOR := Color(0.95, 0.95, 0.98)
const BADGE_BG := Color(0.04, 0.04, 0.06, 0.92)

@export var padding := 12.0
@export var outline_width := 3.0
@export var car_radius := 4.0
@export var player_radius := 9.0
@export var pulse_speed := 4.5
@export var badge_size := 11

var data: Dictionary = {}
var cars: Array = []
var _pts := PackedVector2Array()
var _color := Color(0.85, 0.85, 0.9)
var _pulse := 0.0

## Track geometry is converted once; drawing only re-projects on resize.
func setup(track_data: Dictionary) -> void:
	data = track_data
	# raw world XZ: car transforms are world space, so the outline must be too
	_pts = GameState.track_world_points(track_data, 240)
	if not track_data.is_empty():
		var t: Dictionary = GameState.THEMES.get(String(track_data.get("theme", "street")), {})
		if not t.is_empty():
			_color = (t["sun"] as Color).lerp(Color.WHITE, 0.35)
	queue_redraw()

func set_cars(list: Array) -> void:
	cars = list
	queue_redraw()

## Drives the halo pulse. Only redraws while there is something to animate.
func _process(delta: float) -> void:
	if cars.is_empty():
		return
	_pulse += delta
	queue_redraw()

## World XZ to local pixels, keeping the circuit's aspect ratio inside the panel.
func _fit(p: Vector2) -> Vector2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q in _pts:
		mn = mn.min(q)
		mx = mx.max(q)
	var span := mx - mn
	if span.x <= 0.001 or span.y <= 0.001:
		return size * 0.5
	var s := minf((size.x - padding * 2.0) / span.x, (size.y - padding * 2.0) / span.y)
	var drawn := span * s
	var origin := (size - drawn) * 0.5
	return origin + (p - mn) * s

func _draw() -> void:
	if _pts.size() < 2:
		return
	var line := PackedVector2Array()
	for p in _pts:
		line.append(_fit(p))
	line.append(line[0])
	# dark halo so the shape reads on any sky, then the bright track line
	draw_polyline(line, Color(0, 0, 0, 0.65), outline_width + 3.0, true)
	draw_polyline(line, _color, outline_width, true)
	# start / finish tick
	if _pts.size() > 2:
		var a := _fit(_pts[0])
		var b := _fit(_pts[3])
		draw_line(a, b, Color(1, 1, 1, 0.9), 2.0, true)
	# rivals first so the player marker always sits on top
	for c in cars:
		if c.get("player", false):
			continue
		var pos: Vector3 = c.get("pos", Vector3.ZERO)
		var p := _fit(Vector2(pos.x, pos.z))
		var col: Color = c.get("color", AI_COLOR)
		draw_circle(p, car_radius + 1.0, Color(0, 0, 0, 0.78))
		draw_circle(p, car_radius - 0.5, col)
	for c in cars:
		if not c.get("player", false):
			continue
		var pos: Vector3 = c.get("pos", Vector3.ZERO)
		var p := _fit(Vector2(pos.x, pos.z))
		var dir: Vector2 = c.get("dir", Vector2(0, -1))
		_draw_player(p, dir, int(c.get("rank", 0)))

## Player marker: two halo rings out of phase, a soft glow disc and a heading chevron.
func _draw_player(p: Vector2, dir: Vector2, rank: int) -> void:
	var t := 0.5 + 0.5 * sin(_pulse * pulse_speed)
	var halo := player_radius + 3.0 + t * 5.5
	draw_arc(p, halo, 0.0, TAU, 28, Color(PLAYER_COLOR, 0.45 * (1.0 - t)), 2.0, true)
	# white disc under the chevron: the player reads against any track or background tint
	draw_circle(p, player_radius + 2.5, Color(0, 0, 0, 0.9))
	draw_circle(p, player_radius + 0.5, Color(1, 1, 1, 0.95))
	draw_arc(p, player_radius + 3.5, 0.0, TAU, 26, Color(PLAYER_COLOR, 0.9), 2.0, true)

	var fwd := dir
	if fwd.length_squared() < 0.0001:
		fwd = Vector2(0.0, -1.0)
	fwd = fwd.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var tip := p + fwd * player_radius * 1.15
	var back := p - fwd * (player_radius * 0.6)
	var small := PackedVector2Array([
		tip,
		back + side * player_radius * 0.78,
		back - side * player_radius * 0.78,
	])
	var outer := PackedVector2Array()
	for v in small:
		outer.append(p + (v - p) * 1.4)
	draw_colored_polygon(outer, Color(0, 0, 0, 0.85))
	draw_colored_polygon(small, PLAYER_COLOR)

	if rank > 0:
		_draw_badge(p, rank)

## High-contrast "P3"-style badge beside the player blip, kept inside the panel.
func _draw_badge(p: Vector2, rank: int) -> void:
	var text := "P%d" % rank
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size).x
	var h := float(badge_size) + 4.0
	var at := p + Vector2(player_radius + 3.0, -player_radius - h - 1.0)
	at.x = clampf(at.x, 2.0, maxf(2.0, size.x - w - 6.0))
	at.y = clampf(at.y, 2.0, maxf(2.0, size.y - h - 2.0))
	var rect := Rect2(at + Vector2(-2.0, 0.0), Vector2(w + 4.0, h))
	draw_rect(rect, BADGE_BG, true)
	draw_rect(rect, PLAYER_COLOR, false, 1.0)
	draw_string(font, at + Vector2(0.0, float(badge_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size, PLAYER_COLOR)
