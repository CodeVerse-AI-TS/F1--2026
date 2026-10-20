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
@export var pit_speed_kmh := 80.0    # pit lane limiter
@export var fuel_burn := 0.0022      # tank fraction burned per second at full throttle
@export var fuel_mass_effect := 0.05 # how much a full tank costs in acceleration

const TyreModelScript = preload("res://scripts/tyre_model.gd")

## Tyres: compound, per-wheel wear, temperature and the grip they give right now.
var tyres = TyreModelScript.new()
var wetness := 0.0                   # 0 dry .. 1 heavy rain (set by the session)
## Bodywork damage: 0 = pristine, 1 = about to retire. Cheap arcade penalty, repaired in the pits.
var damage := 0.0
var damage_rate := 0.012              # damage added per impact unit above the threshold
var damage_repair := 0.45             # how much of the damage a pit stop repairs
var fuel := 1.0                      # 1 = full tank
var pit_limiter := false             # game.gd sets this inside the pit lane
var pit_servicing := false           # car held in the pit box while the crew works
var wheelspin := 0.0
## m/s. When a safety car is out the session caps the field to this pace; 0 disables it.
var neutral_limit := 0.0

## Driving aids, 0 = off .. 1 = full. Set once from the settings by game.gd.
var traction_assist := 0.0
var brake_assist := 0.0
## Corner speed the session expects here (m/s); 0 disables the braking aid.
var target_speed := 0.0
## Car setup multipliers from the setup screen: they trade top speed against grip.
var setup_grip := 1.0
var setup_top := 1.0
var setup_brake := 1.0

## Called once by the session with the saved circuit setup.
func apply_setup(s: Dictionary) -> void:
	var aero := clampf(float(s.get("aero", 0.5)), 0.0, 1.0)
	var susp := clampf(float(s.get("susp", 0.5)), 0.0, 1.0)
	var bias := clampf(float(s.get("bias", 0.5)), 0.0, 1.0)
	# low aero: less drag (more top speed) but less cornering grip, and the reverse
	setup_top = lerpf(1.04, 0.96, aero)
	setup_grip = lerpf(0.95, 1.05, aero) * lerpf(0.97, 1.03, susp)
	setup_brake = lerpf(0.94, 1.06, bias)

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
## 0..1 tyre scrub, drives the squeal audio layer and nothing else.
var slip := 0.0
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
	pit_servicing = false
	pit_limiter = false
	damage = 0.0
	reset_physics_interpolation()

## Called by the session after a pit stop: fresh set of tyres and a full tank.
func service(compound: int) -> void:
	tyres.reset(compound)
	fuel = 1.0
	damage = maxf(damage - damage_repair, 0.0)  # the crew taps out the worst dents
	model.set_compound_color(tyres.colour())

## 1 = new, 0 = completely worn. Drives the HUD and the rain-tyre call.
func tyre_wear() -> float:
	return tyres.wear

func _physics_process(delta: float) -> void:
	_hit_cd -= delta
	if pit_servicing:
		# held in the pit box while the crew works; engine idles, no input
		speed = move_toward(speed, 0.0, 40.0 * delta)
		velocity = Vector3.ZERO
		throttle_in = 0.0
		brake_in = 1.0
		tyres.update(delta, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, wetness)
		model.update_visual(delta, 0.0, 0.0, 0.0, 1.0, 0.0, false)
		_update_gearbox()
		return
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

	# tyre state: wear, temperature, the grip multiplier and wet-weather grip
	var slide := absf(steer) * clampf(absf(speed) / 60.0, 0.0, 1.0)
	var speed_frac := clampf(absf(speed) / top_speed, 0.0, 1.0)
	tyres.update(delta, slide, brake_in, throttle_in, speed_frac,
		1.0 if boosting else 0.0, kerb, wetness)
	# normalised 0..1 grip: 1 = a fresh, warm soft tyre on a dry track
	var grip := clampf(tyres.grip_multiplier(wetness) / 1.06, 0.15, 1.0) * setup_grip
	# tyre scrub for the squeal layer: steering above a walking pace on worn or wet rubber
	slip = clampf((absf(steer) - 0.25) * clampf(absf(speed) / 30.0, 0.0, 1.0) * (2.0 - grip), 0.0, 1.0)
	# 0..1 how hard the tyres are being scrubbed sideways, read by the squeal layer.
	# Only a real slide counts: full lock at walking pace must stay silent.
	slip = clampf((absf(steer) * clampf(absf(speed) / 45.0, 0.0, 1.0) - 0.35) / 0.65, 0.0, 1.0)
	slip *= clampf((1.15 - grip) * 2.2, 0.0, 1.0)
	# a bent car loses aero and turns in worse, so damage costs lap time until repaired
	grip *= lerpf(1.0, 0.84, damage)
	# fuel load: heavier at the start of a stint, so acceleration and top speed grow as it burns
	var load_factor := 1.0 - fuel * fuel_mass_effect
	var cap := (boost_speed if boosting else top_speed) * setup_top * lerpf(0.985, 1.0, load_factor)
	if drs_open:
		cap += drs_speed_bonus
	cap *= lerpf(1.0, 0.93, damage)  # damaged bodywork costs top speed
	# neutralised race: the safety car sets the pace for the whole field
	if neutral_limit > 0.0:
		cap = minf(cap, neutral_limit)
		boosting = false
	if speed > cap:
		speed = move_toward(speed, cap, 14.0 * delta)
	# pit lane speed limiter: hard cap while the limiter is armed
	var limit_speed := pit_speed_kmh / 3.6
	if pit_limiter and speed > limit_speed:
		speed = move_toward(speed, limit_speed, 30.0 * delta)
	if throttle_in > 0.0 and speed >= -0.5:
		var ratio := clampf(speed / cap, 0.0, 1.0)
		var accel := lerpf(24.0, 6.0, ratio * ratio) * throttle_in
		if boosting:
			accel += 10.0
		if drs_open:
			accel += drs_accel_bonus * ratio
		accel *= lerpf(0.72, 1.0, grip)  # a worn or cold tyre spins up instead of pushing
		# traction control: trims torque instead of lighting the rear tyres up
		if traction_assist > 0.0 and grip < 0.95:
			accel *= lerpf(1.0, lerpf(0.78, 1.0, grip), traction_assist)
		accel *= lerpf(0.97, 1.0, load_factor)
		if speed < cap:
			speed = minf(speed + accel * delta, cap)
	# braking assist: bleeds speed automatically when the corner ahead demands it
	if brake_assist > 0.0 and target_speed > 1.0 and speed > target_speed * 1.02:
		var over := clampf((speed - target_speed) / maxf(target_speed, 1.0), 0.0, 1.0)
		speed = move_toward(speed, target_speed, 46.0 * brake_assist * over * delta)
	if brake_in > 0.0:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, 52.0 * setup_brake * brake_in * delta)
		else:
			speed = move_toward(speed, -14.0, 12.0 * brake_in * delta)
	if throttle_in > 0.0 and speed < 0.0:
		speed = move_toward(speed, 0.0, 40.0 * delta)
	if throttle_in == 0.0 and brake_in == 0.0:
		speed = move_toward(speed, 0.0, (2.5 + absf(speed) * 0.02) * delta)
	# fuel burns off with throttle, boost and speed; the tank refills at a stop
	fuel = maxf(fuel - fuel_burn * throttle_in * (1.0 + 0.6 * float(boosting)) * delta, 0.0)

	# steering: yaw rate falls off with speed; a worn or cold tyre turns in late and slides wide
	steer = move_toward(steer, steer_in, (6.0 if steer_in != 0.0 else 8.0) * delta)
	var sp := absf(speed)
	var turn := lerpf(0.82, 1.0, grip)
	var yaw := steer * lerpf(2.1, 0.85, clampf(sp / top_speed, 0.0, 1.0)) * clampf(sp / 5.0, 0.0, 1.0) * turn
	# understeer: below full grip the car keeps drifting outward through a corner
	if grip < 0.9 and sp > 25.0:
		speed = move_toward(speed, speed * lerpf(1.0, 0.985, (0.9 - grip) * 10.0), 2.0 * delta)
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
	var floor_n := get_floor_normal()
	if on_floor and floor_n.length_squared() > 0.001:
		# align the body to the surface; a zero normal on the first grounded frame
		# would make Quaternion() fail, so both vectors are checked first
		var n_local := (global_basis.inverse() * floor_n).normalized()
		if n_local.length_squared() > 0.001:
			model.quaternion = model.quaternion.slerp(Quaternion(Vector3.UP, n_local), 0.2)

func _handle_walls(fwd: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var hit := c.get_collider() as Node
		if hit and hit.is_in_group("ai_car"):
			speed *= 0.985  # car-to-car contact: scrub a little speed, no barrier penalty
			continue
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
			# bodywork takes a hit; the crew can only patch part of it in the pits
			damage = clampf(damage + maxf(impact - 8.0, 0.0) * damage_rate, 0.0, 1.0)
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
