extends Camera3D
## Race camera with six views (C cycles): chase, far chase, cockpit/halo, hood, TV trackside, top-down.
## Views blend smoothly; FOV widens with speed; shake on boost and kerbs.

enum View { CHASE, FAR, COCKPIT, HOOD, TV, TOP }

@export var car_path: NodePath
@export var track_path: NodePath
@export var distance := 6.2
@export var height := 1.9
@export var far_distance := 10.5
@export var far_height := 3.4
@export var transition_time := 0.45
@export var tv_spacing := 160.0
@export var top_height := 60.0
@export var kerb_shake_amount := 0.035

var car: CharacterBody3D
var track: Node3D
var view: int = View.CHASE
## 0..1, set by game.gd when the car rides a kerb.
var kerb_shake := 0.0

var _prev_view: int = View.CHASE
var _blend := 1.0
var _dir := Vector3.FORWARD
var _shake_t := 0.0
var _tv_index := -1
var _tv_pos := Vector3.ZERO

func _ready() -> void:
	car = get_node(car_path)
	track = get_node_or_null(track_path)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 160.0
	attrs.dof_blur_far_transition = 120.0
	attrs.dof_blur_amount = 0.05
	attributes = attrs
	snap()

func set_view(v: int, instant := false) -> void:
	_prev_view = view
	view = clampi(v, 0, View.size() - 1)
	_blend = 1.0 if instant else 0.0
	_tv_index = -1
	near = 0.04 if view == View.COCKPIT or view == View.HOOD else 0.1

func cycle() -> int:
	set_view((view + 1) % View.size())
	return view

func snap() -> void:
	var fwd := -car.global_transform.basis.z
	fwd.y = 0.0
	_dir = fwd.normalized()
	_blend = 1.0
	_tv_index = -1

func _process(delta: float) -> void:
	var xf := car.get_global_transform_interpolated()
	var fwd := -xf.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.01:
		_dir = _dir.slerp(fwd.normalized(), 1.0 - exp(-9.0 * delta)).normalized()
	var ratio := clampf(float(car.speed) / 88.0, 0.0, 1.2)
	var target := _view_xform(view, xf, ratio)
	var target_fov := _view_fov(view, ratio)
	if _blend < 1.0:
		# blend from the previous view (still tracked live) into the new one
		_blend = minf(1.0, _blend + delta / transition_time)
		var e := smoothstep(0.0, 1.0, _blend)
		target = _view_xform(_prev_view, xf, ratio).interpolate_with(target, e)
		target_fov = lerpf(_view_fov(_prev_view, ratio), target_fov, e)
	global_transform = target
	fov = lerpf(fov, target_fov, 1.0 - exp(-6.0 * delta))
	_shake_t += delta * 30.0
	var amp := ratio * ratio * 0.012 + (0.012 if car.boosting else 0.0) + kerb_shake * kerb_shake_amount
	if view == View.TOP or view == View.TV:
		amp *= 0.3
	h_offset = sin(_shake_t * 1.3) * amp
	v_offset = cos(_shake_t * 1.7 + kerb_shake * 9.0) * amp

func _look(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), from)

func _view_xform(v: int, xf: Transform3D, ratio: float) -> Transform3D:
	var o := xf.origin
	match v:
		View.FAR:
			return _look(o - _dir * (far_distance + ratio * 1.5) + Vector3.UP * far_height, o + _dir * 8.0 + Vector3.UP * 0.6)
		View.COCKPIT:
			return Transform3D(xf.basis * Basis(Vector3.RIGHT, -0.05), xf * Vector3(0, 1.08, -0.2))
		View.HOOD:
			return Transform3D(xf.basis * Basis(Vector3.RIGHT, -0.09), xf * Vector3(0, 1.35, 0.25))
		View.TV:
			return _tv_xform(o)
		View.TOP:
			return Transform3D(Basis.looking_at(Vector3.DOWN, _dir), o + Vector3.UP * top_height)
	return _look(o - _dir * (distance + ratio * 0.9) + Vector3.UP * (height - ratio * 0.15), o + _dir * 6.0 + Vector3.UP * 0.9)

## Broadcast camera: fixed trackside poles every tv_spacing metres, cut to the next as the car passes.
func _tv_xform(o: Vector3) -> Transform3D:
	if track == null:
		return _look(o - _dir * distance + Vector3.UP * height, o)
	var off: float = track.closest_offset(o)
	var idx := int(floor((off + tv_spacing * 0.5) / tv_spacing))
	if idx != _tv_index:
		_tv_index = idx
		var cxf: Transform3D = track.get_xform(idx * tv_spacing + tv_spacing * 0.35)
		var side := 1.0 if idx % 2 == 0 else -1.0
		_tv_pos = cxf.origin + cxf.basis.x * side * (float(track.HALF_W) + 9.0) + Vector3.UP * 5.5
	return _look(_tv_pos, o + Vector3.UP * 0.6)

func _view_fov(v: int, ratio: float) -> float:
	var boost := 8.0 if car.boosting else 0.0
	match v:
		View.FAR:
			return 62.0 + 12.0 * ratio + boost
		View.COCKPIT:
			return 78.0 + 12.0 * ratio + boost
		View.HOOD:
			return 74.0 + 12.0 * ratio + boost
		View.TV:
			var d := maxf(_tv_pos.distance_to(car.global_position), 1.0)
			return clampf(rad_to_deg(2.0 * atan(7.0 / d)), 8.0, 60.0)
		View.TOP:
			return 50.0
	return 70.0 + 14.0 * ratio + boost
