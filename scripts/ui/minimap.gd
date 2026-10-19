extends Control
## Live minimap: draws the circuit outline from the track data and a dot for every car.
## game.gd feeds one entry per car: {"pos": Vector3 (world), "player": bool, "name": String}.

const GameState = preload("res://scripts/game_state.gd")

const PLAYER_COLOR := Color(1.0, 0.82, 0.25)
const AI_COLOR := Color(0.95, 0.95, 0.98)

@export var padding := 12.0
@export var outline_width := 3.0
@export var car_radius := 4.0

var data: Dictionary = {}
var cars: Array = []
var _pts := PackedVector2Array()
var _color := Color(0.85, 0.85, 0.9)

## Track geometry is converted once; drawing only re-projects on resize.
func setup(track_data: Dictionary) -> void:
	data = track_data
	_pts = GameState.track_preview(track_data, 240)
	if not track_data.is_empty():
		var t: Dictionary = GameState.THEMES.get(String(track_data.get("theme", "street")), {})
		if not t.is_empty():
			_color = (t["sun"] as Color).lerp(Color.WHITE, 0.35)
	queue_redraw()

func set_cars(list: Array) -> void:
	cars = list
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
	for c in cars:
		var pos: Vector3 = c.get("pos", Vector3.ZERO)
		var p := _fit(Vector2(pos.x, pos.z))
		if c.get("player", false):
			draw_circle(p, car_radius + 2.0, Color(0, 0, 0, 0.8))
			draw_circle(p, car_radius, PLAYER_COLOR)
		else:
			draw_circle(p, car_radius - 1.0, AI_COLOR)
