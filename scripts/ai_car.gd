extends AnimatableBody3D
## AI rival. Follows the track's ideal speed profile scaled by skill, picks a side to overtake
## slower cars, defends against cars close behind, and occasionally makes mistakes.
## game.gd calls drive() every physics frame with the positions of all other cars.

const CarModelScript = preload("res://scripts/car_model.gd")

@export var accel := 15.0
@export var brake := 36.0
@export var lookahead := 10.0
@export var lateral_speed := 3.0
@export var mistake_chance := 0.03     # per second at skill 0.9 (lower skill = more mistakes)
@export var straight_speed := 88.0     # flat-out top speed on straights (m/s)
@export var follow_distance := 18.0    # metres: start reacting to a car ahead

var track: Node3D
var team: Dictionary = {}
var driver := "AI"
var skill := 0.95
var aggression := 0.5
var distance := 0.0       # total race distance in metres (negative on the grid)
var speed := 0.0
var lateral := 0.0
var target_lateral := 0.0
var racing := false
var finished := false
var finish_time := 0.0
var model: Node3D
var _mistake_t := 0.0
var _clear_t := 0.0
var _braking := 0.0

## Tyres and pit strategy: the AI boxes once the rubber is past the threshold.
@export var pit_wear_threshold := 0.55
@export var ai_pit_service := 2.8
var wear := 0.0
var pit_phase := 0          # 0 racing, 1 in the pit lane, 2 stopped in the box
var _pit_timer := 0.0
var pit_lane_lat := 0.0

## Each driver holds a slightly different line so the field does not drive nose to tail.
var line_bias := 0.0
## True while the flap is open in a DRS zone with a clear road ahead.
var drs_open := false
@export var drs_top_bonus := 6.0        # extra m/s on a straight with the flap open

func _ready() -> void:
	add_to_group("ai_car")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.7, 5.6)
	cs.shape = box
	cs.position = Vector3(0, 0.38, 0)
	add_child(cs)
	model = CarModelScript.new()
	add_child(model)

## Place on the grid. Call after the node is in the tree.
func setup(p_track: Node3D, p_team: Dictionary, p_driver: String, start_distance: float, p_lateral: float, p_skill: float) -> void:
	track = p_track
	team = p_team
	driver = p_driver
	skill = p_skill
	aggression = randf_range(0.3, 0.9)
	distance = start_distance
	lateral = p_lateral
	target_lateral = p_lateral
	speed = 0.0
	racing = false
	finished = false
	_mistake_t = 0.0
	wear = 0.0
	pit_phase = 0
	_pit_timer = 0.0
	pit_lane_lat = -(float(track.HALF_W) + 4.8)
	line_bias = randf_range(-1.0, 1.0) * (float(track.HALF_W) - 3.0) * 0.45
	drs_open = false
	model.set_livery(p_team)
	_place(0.0, 0.0)
	reset_physics_interpolation()

## others: Array of {"node", "d" (race distance), "lat" (lateral offset), "speed"}.
func drive(delta: float, others: Array) -> void:
	if not racing:
		_place(delta, 0.0)
		return
	var half_w: float = track.HALF_W
	var off := fposmod(distance, track.length)
	# target speed from the braking-aware ideal profile, a little ahead of the car
	var vt: float = minf(track.speed_at(off + lookahead), track.speed_at(off + lookahead * 3.0))
	if vt >= 83.0:
		vt = straight_speed
	vt *= skill
	# random mistakes: lock-up / run wide, more often for weaker drivers and worn tyres
	_mistake_t -= delta
	var error_rate := mistake_chance * (1.0 - skill) * 10.0 * (1.0 + 1.5 * wear)
	if _mistake_t <= 0.0 and randf() < error_rate * delta:
		_mistake_t = randf_range(0.6, 1.4)
	if _mistake_t > 0.0:
		vt *= 0.72
	# DRS: open the flap in a zone when there is no car close enough ahead to have to defend
	drs_open = false
	for z in track.drs_zones:
		if _in_zone(off, z) and _gap_to_car_ahead(others) > 12.0:
			drs_open = true
	if drs_open:
		vt += drs_top_bonus
	# traffic: follow, overtake, defend
	var blocked := false
	for o in others:
		if o["node"] == self:
			continue
		var gap: float = o["d"] - distance
		var dl: float = o["lat"] - lateral
		if gap > 0.0 and gap < follow_distance and absf(dl) < 2.4:
			blocked = true
			if float(o["speed"]) < speed + 1.0:
				# pull out on whichever side of the car ahead has more room
				var room_right := (half_w - 1.8) - float(o["lat"])
				var room_left := (half_w - 1.8) + float(o["lat"])
				var side := 1.0 if room_right > room_left else -1.0
				target_lateral = side * (half_w - 2.2)
			if gap < 9.0:
				vt = minf(vt, float(o["speed"]) - 0.5)
		elif gap < 0.0 and gap > -12.0 and absf(dl) > 1.2 and aggression > 0.6 and _clear_t > 1.5:
			target_lateral = move_toward(target_lateral, o["lat"], 1.5 * delta)  # cover the attacker
	if blocked:
		_clear_t = 0.0
	else:
		_clear_t += delta
		if _clear_t > 2.5:
			target_lateral = move_toward(target_lateral, line_bias, delta)  # back to this driver's line
	# tyre wear grows in the corners, and the pace drops as the rubber goes off
	var corner := 1.0 - clampf(track.speed_at(off + lookahead) / 75.0, 0.0, 1.0)
	wear = clampf(wear + delta * (0.00045 + 0.0016 * corner), 0.0, 1.0)
	vt *= lerpf(1.0, 0.93, wear)
	# pit strategy: box when the tyres are gone, drive the lane at the limit, stop in the box
	var pit_entry: float = float(track.pit["entry"])
	if pit_phase == 0 and wear > pit_wear_threshold and fposmod(pit_entry - off, track.length) < 130.0:
		pit_phase = 1
	if pit_phase == 1:
		target_lateral = pit_lane_lat
		vt = minf(vt, 21.5)   # limiter, ~77 km/h
		if fposmod(off - float(track.pit["box"]), track.length) < 8.0:
			pit_phase = 2
			_pit_timer = ai_pit_service
	elif pit_phase == 2:
		target_lateral = pit_lane_lat
		vt = 0.0
		_pit_timer -= delta
		if _pit_timer <= 0.0:
			pit_phase = 0
			wear = 0.0
			target_lateral = line_bias
	else:
		target_lateral = clampf(target_lateral, -(half_w - 1.6), half_w - 1.6)
	_braking = 1.0 if vt < speed - 2.0 else 0.0
	speed = move_toward(speed, maxf(vt, 0.0), (accel if vt > speed else brake) * delta)
	distance += speed * delta
	var prev := lateral
	lateral = move_toward(lateral, target_lateral, lateral_speed * delta)
	_place(delta, (lateral - prev) / maxf(delta, 0.001))

## True when the offset sits inside a DRS zone (start may sit after the line).
func _in_zone(off: float, z: Dictionary) -> bool:
	var s: float = float(z["start"])
	var e: float = float(z["end"])
	return off >= s and off <= e if s <= e else (off >= s or off <= e)

## Metres to the nearest car ahead on the road (INF when the road ahead is clear).
func _gap_to_car_ahead(others: Array) -> float:
	var best := INF
	for o in others:
		if o["node"] == self:
			continue
		var gap: float = float(o["d"]) - distance
		if gap > 0.0:
			best = minf(best, gap)
	return best

func _place(delta: float, lat_vel: float) -> void:
	var xf: Transform3D = track.get_xform(fposmod(distance, track.length))
	xf.origin += xf.basis.x * lateral
	var yaw := -atan2(lat_vel, maxf(speed, 1.0))
	xf.basis = xf.basis * Basis(Vector3.UP, yaw)
	global_transform = xf
	if delta > 0.0:
		model.set_drs(drs_open)
		model.update_visual(delta, speed, clampf(yaw * 3.0, -1.0, 1.0), 0.0, _braking, 1.0 - _braking, false)
