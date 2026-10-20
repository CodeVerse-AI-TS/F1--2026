extends AnimatableBody3D
## AI rival. Follows the track's braking-aware ideal profile scaled by skill, deploys an
## ERS boost on the straights, takes a slipstream tow off the car ahead, dives up the
## inside in braking zones and defends when someone closes in. game.gd calls drive()
## every physics frame with the positions of all other cars.

const CarModelScript = preload("res://scripts/car_model.gd")

@export_group("Handling")
@export var accel := 18.0              # matches the player car's launch, otherwise rivals lose ground every corner exit
@export var brake := 48.0              # m/s^2: late-braking capability
@export var lookahead := 10.0
@export var lateral_speed := 3.0
@export var mistake_chance := 0.03     # per second at skill 0.9 (lower skill = more mistakes)
@export var straight_speed := 88.0     # flat-out top speed on straights (m/s)
@export var follow_distance := 18.0    # metres: start reacting to a car ahead

@export_group("ERS overtake boost")
@export var ers_speed := 98.0          # top speed while the boost is deployed (m/s)
@export var boost_accel := 26.0        # extra acceleration while boosting
@export var ers_drain := 0.30          # charge burned per second
@export var ers_regen := 0.055         # charge recovered per second
@export var ers_min_deploy := 0.18     # never fire the boost below this charge

@export_group("Aero and combat")
@export var draft_gain := 1.12         # 12% acceleration in a slipstream
@export var draft_range := 25.0        # metres behind a car where the tow starts
@export var dive_distance := 45.0      # metres into a braking zone to try a divebomb

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
var _ers_t := 0.0
var _dive_t := 0.0

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
## 0 dry .. 1 heavy rain, mirrored from the session; a wet track costs the AI pace.
var wetness := 0.0
## Set by the session under a safety car: the field may not exceed this speed (m/s).
var pace_limit := 0.0
@export var drs_top_bonus := 6.0        # extra m/s on a straight with the flap open

## Energy store for the overtake boost and the difficulty knobs that drive it.
var ers := 1.0
var ers_active := false
var ers_use := 0.5       # 0 never deploys .. 1 always looks for a boost
var dive_chance := 0.5   # willingness to stick a nose up the inside

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

## Difficulty profile from game_state.gd: brake force, aggression band, ERS use, errors.
func apply_profile(profile: Dictionary) -> void:
	brake = float(profile.get("brake", brake))
	ers_use = float(profile.get("ers", ers_use))
	dive_chance = float(profile.get("dive", dive_chance))
	mistake_chance = float(profile.get("mistakes", mistake_chance))
	var ag: Vector2 = profile.get("aggression", Vector2(0.4, 0.8))
	aggression = randf_range(ag.x, ag.y)

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
	_ers_t = 0.0
	_dive_t = 0.0
	ers = 1.0
	ers_active = false
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
	# corner pace: sharper drivers look less far ahead, so they brake later and commit
	var la: float = lookahead * lerpf(1.15, 0.72, clampf((skill - 0.85) / 0.20, 0.0, 1.0))
	# skill shapes CORNERING only. Multiplying the straight-line speed by skill used to
	# cap a Rookie at 77 m/s against the player's 88, which made the field look parked.
	var pace: float = lerpf(0.99, 1.045, clampf((skill - 0.86) / 0.17, 0.0, 1.0))
	var vt: float = minf(track.speed_at(off + la), track.speed_at(off + la * 2.8)) * pace
	# a straight is any stretch where the profile opens up: the old 80 threshold was
	# never reached on most circuits, so the AI almost never used its top speed
	var open_road: float = track.speed_at(off + la * 3.0)
	var straight: bool = open_road >= 70.0
	if straight:
		vt = maxf(vt, lerpf(straight_speed * 0.985, straight_speed, clampf((skill - 0.86) / 0.17, 0.0, 1.0)))
	# rain costs grip, so the field slows; under a safety car the pace is fixed
	vt *= lerpf(1.0, 0.88, wetness)
	if pace_limit > 0.0:
		vt = minf(vt, pace_limit)

	# who is around us: gap to the nearest car ahead and whether we sit in its tow
	var ahead_gap := INF
	var ahead_lat := 0.0
	var drafting := false
	for o in others:
		if o["node"] == self:
			continue
		var gap: float = float(o["d"]) - distance
		if gap <= 0.0:
			continue
		if gap < ahead_gap:
			ahead_gap = gap
			ahead_lat = float(o["lat"])
		if gap < draft_range and absf(float(o["lat"]) - lateral) < 2.8:
			drafting = true
	drafting = drafting and straight and pit_phase == 0

	# ERS: recharge constantly, fire it on a straight to attack, defend or stretch a gap
	ers = minf(ers + ers_regen * delta, 1.0)
	_ers_t -= delta
	if not straight or pit_phase != 0 or pace_limit > 0.0:
		ers_active = false
	elif _ers_t <= 0.0:
		_ers_t = randf_range(0.7, 2.0)
		var chasing: bool = ahead_gap < 90.0
		ers_active = ers > ers_min_deploy and randf() < ers_use and (chasing or aggression > 0.65)
	if ers_active:
		ers = maxf(ers - ers_drain * delta, 0.0)
		if ers <= 0.0:
			ers_active = false
			_ers_t = randf_range(1.0, 2.5)
		else:
			vt = maxf(vt, ers_speed)

	# random mistakes: lock-up / run wide, more often for weaker drivers and worn tyres
	_mistake_t -= delta
	var error_rate := mistake_chance * clampf((1.0 - skill) * 10.0, 0.05, 6.0) * (1.0 + 1.5 * wear)
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

	# traffic: follow, overtake, dive up the inside, defend
	var blocked := false
	for o in others:
		if o["node"] == self:
			continue
		var gap: float = float(o["d"]) - distance
		var dl: float = float(o["lat"]) - lateral
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

	# divebomb: in a braking zone behind a slower car, commit to the inside line
	_dive_t = maxf(_dive_t - delta, 0.0)
	if _dive_t <= 0.0 and blocked and pit_phase == 0 and aggression > 0.5 \
			and ahead_gap < dive_distance and _braking_zone(off):
		if randf() < dive_chance * delta * 5.0:
			_dive_t = randf_range(0.8, 1.6)
	if _dive_t > 0.0:
		target_lateral = _inside_line(off, half_w)

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
	# acceleration: ERS adds thrust, a slipstream multiplies whatever we have
	var push := accel + (boost_accel if ers_active else 0.0)
	if drafting:
		push *= draft_gain
	speed = move_toward(speed, maxf(vt, 0.0), (push if vt > speed else brake) * delta)
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

## True when the track is slowing down over the next stretch, i.e. a braking zone.
func _braking_zone(off: float) -> bool:
	return track.speed_at(off + 15.0) < track.speed_at(off) - 6.0

## Which side of the track is the inside of the corner just ahead (+1 right, -1 left).
func _inside_line(off: float, half_w: float) -> float:
	var t1: Vector3 = track.sample_tangent(off)
	var t2: Vector3 = track.sample_tangent(fposmod(off + 25.0, track.length))
	var turn := t1.signed_angle_to(t2, Vector3.UP)
	return (half_w - 2.2) * (1.0 if turn < 0.0 else -1.0)

func _place(delta: float, lat_vel: float) -> void:
	var xf: Transform3D = track.get_xform(fposmod(distance, track.length))
	xf.origin += xf.basis.x * lateral
	var yaw := -atan2(lat_vel, maxf(speed, 1.0))
	xf.basis = xf.basis * Basis(Vector3.UP, yaw)
	global_transform = xf
	if delta > 0.0:
		model.set_drs(drs_open)
		model.update_visual(delta, speed, clampf(yaw * 3.0, -1.0, 1.0), 0.0, _braking, 1.0 - _braking, false)
