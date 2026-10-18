extends CharacterBody3D
## Arcade F1 handling: instant throttle, absolute grip, short braking, Overtake Boost.

signal wall_hit(impact: float)

@export var top_speed := 88.0      # ~317 km/h
@export var boost_speed := 101.0   # ~364 km/h
@export var gravity := 30.0
@export var boost_drain := 0.3
@export var boost_fill := 0.06
@export var drs_speed_bonus := 7.0   # extra top speed (m/s) with the flap open
@export var drs_accel_bonus := 3.0   # less drag: extra acceleration near top speed
@export var spark_speed := 78.0      # floor scrapes the tarmac above this speed

## DRS state: game.gd sets drs_available and drs_in_zone; the player opens it with "drs".
var drs_available := false
var drs_in_zone := false
var drs_open := false
## 0..1 kerb contact, set by game.gd (drives sparks).
var kerb := 0.0
var _was_floor := true
var _land_t := 0.0

const GEAR_TOPS := [0.2, 0.32, 0.44, 0.56, 0.68, 0.8, 0.9, 1.0]

var speed := 0.0
var steer := 0.0
var throttle_in := 0.0
var brake_in := 0.0
var boost := 1.0
var boosting := false
var controls_enabled := true
var gear := 1
var rpm := 4200.0
const CarModelScript = preload("res://scripts/car_model.gd")

var model: Node3D
var _hit_cd := 0.0
var _boost_vis := 0.0

func _ready() -> void:
	model = CarModelScript.new()
	add_child(model)
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(45.0)

func reset_to(xf: Transform3D) -> void:
	global_transform = xf
	speed = 0.0
	steer = 0.0
	velocity = Vector3.ZERO
	boost = 1.0
	gear = 1
	rpm = 4200.0
	drs_open = false
	drs_available = false
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	_hit_cd -= delta
	throttle_in = Input.get_action_strength("accelerate") if controls_enabled else 0.0
	brake_in = Input.get_action_strength("brake") if controls_enabled else 0.0
	var steer_in := Input.get_axis("steer_right", "steer_left") if controls_enabled else 0.0

	boosting = controls_enabled and Input.is_action_pressed("boost") and boost > 0.01 and speed > 5.0
	if boosting:
		boost = maxf(boost - boost_drain * delta, 0.0)
	else:
		boost = minf(boost + boost_fill * delta, 1.0)

	# DRS: open only inside a zone when earned; closes on braking or leaving the zone
	if controls_enabled and Input.is_action_just_pressed("drs") and drs_available and drs_in_zone:
		drs_open = true
	if drs_open and (brake_in > 0.1 or not drs_in_zone):
		drs_open = false

	var cap := boost_speed if boosting else top_speed
	if drs_open:
		cap += drs_speed_bonus
	if throttle_in > 0.0 and speed >= -0.5:
		var ratio := clampf(speed / cap, 0.0, 1.0)
		var accel := lerpf(24.0, 6.0, ratio * ratio) * throttle_in
		if boosting:
			accel += 10.0
		if drs_open:
			accel += drs_accel_bonus * ratio
		if speed < cap:
			speed = minf(speed + accel * delta, cap)
	if speed > cap:
		speed = move_toward(speed, cap, 14.0 * delta)
	if brake_in > 0.0:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, 52.0 * brake_in * delta)
		else:
			speed = move_toward(speed, -14.0, 12.0 * brake_in * delta)
	if throttle_in > 0.0 and speed < 0.0:
		speed = move_toward(speed, 0.0, 40.0 * delta)
	if throttle_in == 0.0 and brake_in == 0.0:
		speed = move_toward(speed, 0.0, (2.5 + absf(speed) * 0.02) * delta)

	# steering: yaw rate falls off with speed, grip never breaks
	steer = move_toward(steer, steer_in, (6.0 if steer_in != 0.0 else 8.0) * delta)
	var sp := absf(speed)
	var yaw := steer * lerpf(2.1, 0.85, clampf(sp / top_speed, 0.0, 1.0)) * clampf(sp / 5.0, 0.0, 1.0)
	if speed < 0.0:
		yaw = -yaw
	rotate_y(yaw * delta)

	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var vy := velocity.y
	if is_on_floor():
		vy = 0.0
	else:
		vy -= gravity * delta
	velocity = fwd * speed + Vector3.UP * vy
	move_and_slide()
	_handle_walls(fwd)
	_update_gearbox()

	# visuals
	_boost_vis = move_toward(_boost_vis, 1.0 if boosting else 0.0, 4.0 * delta)
	var on_floor := is_on_floor()
	if on_floor and not _was_floor and vy < -4.0:
		_land_t = 0.25  # bottomed out on landing
	_was_floor = on_floor
	_land_t = maxf(_land_t - delta, 0.0)
	var sparks := on_floor and speed > 40.0 and (kerb > 0.3 or speed > spark_speed or _land_t > 0.0)
	model.set_drs(drs_open)
	model.update_visual(delta, speed, steer, _boost_vis, brake_in, throttle_in, sparks)
	if on_floor:
		var n_local := (global_basis.inverse() * get_floor_normal()).normalized()
		var q := Quaternion(Vector3.UP, n_local)
		model.quaternion = model.quaternion.slerp(q, 0.2)

func _handle_walls(fwd: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.6:
			continue
		n.y = 0.0
		n = n.normalized()
		var into := -fwd.dot(n)
		if into <= 0.02:
			continue
		var impact := into * absf(speed)
		var along := fwd - n * fwd.dot(n)
		if along.length() > 0.1:
			rotate_y(fwd.signed_angle_to(along.normalized(), Vector3.UP) * 0.35)
		speed *= lerpf(0.97, 0.4, clampf(into * 1.6, 0.0, 1.0))
		global_position += n * 0.05
		if impact > 8.0 and _hit_cd <= 0.0:
			_hit_cd = 0.6
			wall_hit.emit(impact)
		break

func _update_gearbox() -> void:
	var sp := maxf(speed, 0.0)
	var top: float = GEAR_TOPS[gear - 1] * boost_speed
	var low: float = 0.0 if gear == 1 else GEAR_TOPS[gear - 2] * boost_speed
	if gear < 8 and sp > top * 0.97:
		gear += 1
	elif gear > 1 and sp < low * 0.8:
		gear -= 1
	top = GEAR_TOPS[gear - 1] * boost_speed
	var target := maxf(4200.0, sp / top * 12500.0)
	if sp < 2.0:
		target = maxf(target, 4200.0 + throttle_in * 4000.0)
	rpm = lerpf(rpm, minf(target, 12800.0), 0.25)

func kmh() -> float:
	return absf(speed) * 3.6
