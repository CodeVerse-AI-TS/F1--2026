extends Node3D
## Session rules for the race scene.
## Time Trial: flying laps vs the gold ghost. Quick Race: N timed laps, then results.
## R tap = back to last checkpoint (flashback in Championship), hold R = restart race,
## C = cycle camera, Esc = pause menu.

const START_BACK := 90.0
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const GameState = preload("res://scripts/game_state.gd")
const AICar = preload("res://scripts/ai_car.gd")
const Tyres = preload("res://scripts/tyre_model.gd")
const Leaderboard = preload("res://scripts/leaderboard.gd")
const Championship = preload("res://scripts/championship.gd")
const StandingsScreen = preload("res://scripts/ui/standings_screen.gd")
const Weather = preload("res://scripts/weather.gd")
const SafetyCar = preload("res://scripts/safety_car.gd")
const Achievements = preload("res://scripts/achievements.gd")
const Replay = preload("res://scripts/replay.gd")

## Safety car: chance per completed lap that the race is neutralised, and how long it stays out.
@export var safety_car_chance := 0.22
@export var safety_car_duration := 24.0
@export var safety_car_pace := 27.0   # m/s the field is held to behind it

@export var pit_entry_speed_limit := 100.0  # km/h: above this on pit entry = speeding penalty
@export var pit_fast_stop := 2.4            # minimum crew time (seconds)
@export var pit_slow_stop := 6.5            # a botched stop
@export var pit_slow_chance := 0.12
@export var pit_time_penalty := 5.0         # seconds added for speeding in the pit lane

## Pit state: "" (none), "requested" (BOX this lap), "stopping" (crew working), "done".
var pit_state := ""
var next_compound := Tyres.MEDIUM
var pit_timer := 0.0
var _was_in_lane := false
var _pit_stops := 0

@export var grid_spacing := 9.0        # metres between grid slots
@export var grid_lateral := 2.6        # left/right stagger of the grid
@export var light_interval := 1.0      # seconds between each red light
@export var skill_spread := 0.025      # random pace variation between AI drivers

var ais: Array = []
## Weather node (rain, sky and the grip it feeds the cars) and the safety car.
var weather: Node3D
var safety: Node3D
## Records the player so the finish can be replayed from an orbiting camera.
var replay: Node3D
var safety_active := false
var _safety_t := 0.0
var race_started := false
var _lights_t := 0.0
var _go_delay := 0.5
var _player_lat := 0.0
var _player_pos := 1

@export var restart_hold_time := 1.0
@export var results_delay := 1.5
## Seconds of finish replay filmed before the results card appears (0 disables it).
@export var finish_replay_seconds := 7.0
@export var drs_gap := 1.0            # seconds to the car ahead at detection to earn DRS
@export var drs_from_lap := 1         # race laps completed before DRS is enabled
@export var delta_bucket := 10.0      # metres between live-delta samples

@onready var track = $Track
@onready var car: CharacterBody3D = $Car
@onready var cam: Camera3D = $ChaseCamera
@onready var ghost: Node3D = $Ghost
@onready var hud = $HUD

## Procedural audio bank: countdown, impacts, chimes, siren, squeal and rain.
const Sfx = preload("res://scripts/sfx.gd")
var sfx: Node
var _last_beep := 0

## Tunnel state: 0 = daylight, 1 = fully inside. Drives the sun dimming, the
## whiteout flash on exit and the acoustic echo on the engine and tyre scrub.
var _tunnel := 0.0
var _whiteout := 0.0
var _sun: DirectionalLight3D
var _sun_base := 1.0

var lap_running := false
var lap_time := 0.0
var sector := 0
var splits: Array[float] = []
var best_lap := INF
var best_splits: Array[float] = []
var gold := 0.0
var silver := 0.0
var bronze := 0.0
var is_race := false
var total_laps := 0
var laps_done := 0
var race_time := 0.0
var penalties := 0.0
var finished := false
var pause_menu: CanvasLayer
var _last_off := 0.0
var _checkpoint := {}
var _r_hold := 0.0
var _r_consumed := false
var _cur_trace := PackedFloat32Array()   # lap time at every delta_bucket metres this lap
var _best_trace := PackedFloat32Array()
var _last_bucket := -1
var _drs_was_in_zone := false
## Championship state for this session.
var is_championship := false
var is_qualifying := false
var _round_recorded := false
var standings: CanvasLayer

func _ready() -> void:
	GameState.ensure_init()
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	is_race = GameState.mode != GameState.Mode.TIME_TRIAL
	is_championship = GameState.mode == GameState.Mode.CHAMPIONSHIP
	is_qualifying = GameState.qualifying
	# race length: championship rounds are fixed and short; quick races follow the
	# chosen lap count or percentage distance scaling
	if is_championship:
		total_laps = GameState.championship_laps
	else:
		total_laps = GameState.resolve_laps(track.data, int(GameState.config.get("length", 0))) if is_race else 0
	gold = track.ideal_time * 1.04
	silver = track.ideal_time * 1.12
	bronze = track.ideal_time * 1.25
	hud.set_targets(gold, silver, bronze)
	hud.set_units(GameState.speed_unit())
	hud.setup_minimap(track.data)
	var team: Dictionary = GameState.team()
	car.model.set_livery(team)
	# circuit setup and driving aids chosen in the menu
	# cinematic finish replay: records the player and films the closing seconds
	replay = Replay.new()
	replay.name = "Replay"
	add_child(replay)
	replay.set_livery(team)
	car.apply_setup(GameState.config.get("setup", {}))
	car.traction_assist = 1.0 if int(GameState.settings.get("traction", 1)) == 1 else 0.0
	car.brake_assist = 1.0 if int(GameState.settings.get("brake_aid", 0)) == 1 else 0.0
	car.wall_hit.connect(_on_wall_hit)
	car.gear_shifted.connect(func(_g: int) -> void: sfx.play("gear_pop", -4.5))
	_setup_weather()
	_setup_safety_car()
	cam.set_view(int(GameState.settings["camera"]), true)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.restart_pressed.connect(func() -> void: _on_resume(); restart())
	pause_menu.camera_pressed.connect(_cycle_camera)
	pause_menu.continue_pressed.connect(_on_round_continue)
	if is_qualifying:
		_start_qualifying_session()
		return
	if is_race:
		_spawn_ai(int(GameState.config["ai_count"]))
	restart()

## Weather lives in its own node: it owns the rain and the atmosphere, the session
## only reads its wetness and pushes it into the car and the rivals.
func _setup_weather() -> void:
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(int(GameState.config.get("weather", 1)), cam)
	weather.changed.connect(_on_weather_changed)
	hud.set_weather(weather.label, weather.wetness)

func _on_weather_changed(text: String, wetness: float) -> void:
	hud.toast(text + "  -  GRIP CHANGING", hud.SILVER, 2.5)
	# auto-dry call: a soaked track punishes slick tyres, so suggest the wet compound
	if wetness > 0.6 and car.tyres.compound < Tyres.INTER:
		hud.toast("WET TRACK  -  BOX FOR INTERMEDIATES", hud.RED, 3.0)

func _setup_safety_car() -> void:
	safety = SafetyCar.new()
	safety.name = "SafetyCar"
	add_child(safety)
	safety.setup(track)

## Neutralise the race: the safety car comes out, everyone is held to its pace.
func _deploy_safety_car() -> void:
	if safety_active or safety == null:
		return
	safety_active = true
	_safety_t = safety_car_duration
	var off: float = track.closest_offset(car.global_position)
	safety.deploy(fposmod(off - 260.0, track.length))
	safety.pace = safety_car_pace
	car.neutral_limit = safety_car_pace
	for ai in ais:
		ai.pace_limit = safety_car_pace
	hud.set_flag("SAFETY CAR", hud.GOLD)
	sfx.play("siren", -4.0)
	sfx.play("radio")
	hud.show_team_radio("Safety Car deployed! Keep delta positive, hold position.", "RACE ENGINEER")
	hud.toast("SAFETY CAR DEPLOYED  -  HOLD POSITION", hud.GOLD, 3.0)

func _retire_safety_car() -> void:
	safety_active = false
	safety.retire()
	car.neutral_limit = 0.0
	for ai in ais:
		ai.pace_limit = 0.0
	hud.set_flag("")
	sfx.play("radio")
	hud.show_team_radio("Safety Car in this lap. Green flag racing on exit.", "RACE ENGINEER")
	hud.toast("SAFETY CAR IN  -  GREEN FLAG", hud.GREEN, 2.5)

func _update_safety_car(delta: float) -> void:
	if not safety_active:
		return
	_safety_t -= delta
	if _safety_t <= 0.0:
		_retire_safety_car()

## Tunnel light: the sun dims to a fraction under the vault, the sky ambient drops,
## and bursting out of the portal fires a short whiteout the camera viewport fades down.
## track.tunnel_light() gives a 0..1 ramp over the portal threshold so nothing snaps.
func _update_tunnel(off: float) -> void:
	var target: float = track.tunnel_light(off)
	_tunnel = move_toward(_tunnel, target, 0.9 * get_physics_process_delta_time())
	if _sun == null:
		var look := get_node_or_null("Look")
		if look:
			_sun = look.get_node_or_null("Sun") as DirectionalLight3D
			if _sun:
				_sun_base = _sun.light_energy
	if _sun:
		_sun.light_energy = lerpf(_sun_base, _sun_base * 0.18, _tunnel)
	# exit flash: highest rate of leaving the tunnel, then decays back to clear
	if target < _tunnel - 0.0001 and _tunnel > 0.35:
		_whiteout = 1.0
	if _whiteout > 0.0:
		_whiteout = maxf(_whiteout - get_physics_process_delta_time() * 1.8, 0.0)
		hud.set_whiteout(_whiteout)
	# acoustic echo: the engine and the tyre scrub pick up the tunnel slap-back
	if sfx and sfx.has_method("set_tunnel"):
		sfx.set_tunnel(_tunnel, absf(car.speed) / 60.0)
	if cam and cam.has_method("set_tunnel"):
		cam.set_tunnel(_tunnel)

## Rivals: two cars per team (skipping the player's team), named drivers, skill from difficulty.
func _spawn_ai(n: int) -> void:
	var player_team := int(GameState.config["team"])
	var teams: Array = []
	for t in GameState.TEAMS.size():
		if t != player_team:
			teams.append(t)
	for i in n:
		var ai: AnimatableBody3D = AICar.new()
		ai.name = "AI_%d" % i
		add_child(ai)
		var team: Dictionary = GameState.TEAMS[teams[(i / 2) % teams.size()]].duplicate()
		team["number"] = int(team["number"]) + (0 if i % 2 == 0 else 50)
		ai.set_meta("team", team)
		ai.set_meta("driver", GameState.DRIVERS[i % GameState.DRIVERS.size()])
		ais.append(ai)

func _grid_xform(slot: int) -> Dictionary:
	var off: float = track.length - 14.0 - slot * grid_spacing
	var lat := -grid_lateral if slot % 2 == 0 else grid_lateral
	return {"off": off, "lat": lat}

## Cars in qualifying order for a championship round (fastest first).
func _championship_grid() -> Array:
	var nodes: Array = []
	for row in Championship.grid:
		var driver := String((row as Dictionary).get("name", ""))
		if driver == Championship.player_name:
			nodes.append(car)
			continue
		for ai in ais:
			if String(ai.get_meta("driver")) == driver:
				nodes.append(ai)
				break
	return nodes

## Default grid: the player in the middle of the field, rivals alternating around them.
func _default_grid() -> Array:
	var nodes: Array = []
	var slots := ais.size() + 1
	var player_slot := slots / 2
	var s := 0
	for i in slots:
		if i == player_slot:
			nodes.append(car)
		else:
			nodes.append(ais[s])
			s += 1
	return nodes

# ---------- qualifying ----------

## One flying lap on an empty circuit. The lap time is handed to the championship
## script, which turns it into a grid slot, then the race scene reloads.
func _start_qualifying_session() -> void:
	total_laps = 1
	car.reset_to(track.get_xform(track.length - START_BACK))
	car.controls_enabled = true
	race_started = true
	laps_done = 0
	race_time = 0.0
	lap_running = false
	lap_time = 0.0
	_last_off = track.closest_offset(car.global_position)
	ghost.visible = false
	hud.set_lap_count(1, 1)
	_save_checkpoint()
	GameState.set_state(GameState.State.QUALIFYING)
	hud.toast("QUALIFYING  -  ONE FLYING LAP SETS YOUR GRID SLOT", hud.GOLD, 3.0)

func _finish_qualifying(t: float) -> void:
	car.controls_enabled = false
	lap_running = false
	hud.toast("QUALIFYING LAP   %s" % hud.fmt(t), hud.GOLD, 2.5)
	await get_tree().create_timer(2.2).timeout
	Championship.record_qualifying(t, track.ideal_time)
	Championship.start_race()

## Driver key used for championship points: the player's name, or the rival's name.
func _entry_key(node) -> String:
	if node == car:
		return Championship.player_name
	return String(node.get_meta("driver"))

## Puts everyone on the grid and starts the lights sequence.
func _setup_grid() -> void:
	var base_skill: float = GameState.AI_SKILL[int(GameState.config["difficulty"])]
	# championship rounds line up in qualifying order; everything else uses a mixed grid
	var order: Array = _championship_grid() if is_championship and not Championship.grid.is_empty() \
		else _default_grid()
	for i in order.size():
		var g := _grid_xform(i)
		var node = order[i]
		if node == car:
			var xf: Transform3D = track.get_xform(g["off"])
			xf.origin += xf.basis.x * float(g["lat"])
			car.reset_to(xf)
			continue
		var ai: AnimatableBody3D = node
		ai.setup(track, ai.get_meta("team"), ai.get_meta("driver"), float(g["off"]) - track.length,
			g["lat"], clampf(base_skill + randf_range(-skill_spread, skill_spread), 0.8, 1.03))
		ai.apply_profile(GameState.AI_PROFILES[clampi(int(GameState.config["difficulty"]), 0, 2)])
	race_started = false
	_lights_t = 0.0
	_go_delay = randf_range(0.2, 1.2)
	car.controls_enabled = false
	hud.set_start_lights(0)

## Full restart of the session (race or time trial).
func restart() -> void:
	if is_race:
		_setup_grid()
	else:
		car.reset_to(track.get_xform(track.length - START_BACK))
		car.controls_enabled = true
		race_started = true
	cam.snap()
	lap_running = false
	lap_time = 0.0
	sector = 0
	splits.clear()
	laps_done = 0
	race_time = 0.0
	penalties = 0.0
	finished = false
	ghost.visible = false
	# fresh tyres, full tank and a clear pit state for the new run
	pit_state = ""
	pit_timer = 0.0
	_pit_stops = 0
	_was_in_lane = false
	car.service(next_compound)
	hud.set_pit_banner("")
	hud.clear_splits()
	hud.set_lap_count(1, total_laps)
	_last_off = track.closest_offset(car.global_position)
	_save_checkpoint()
	GameState.set_state(GameState.State.RACE)

# ---------- checkpoints / flashback ----------

func _save_checkpoint() -> void:
	_checkpoint = {
		"xf": car.global_transform, "speed": car.speed, "lap_time": lap_time, "race_time": race_time,
		"sector": sector, "splits": splits.duplicate(), "lap_running": lap_running, "off": _last_off,
	}

func _restore_checkpoint() -> void:
	if _checkpoint.is_empty():
		return
	car.reset_to(_checkpoint["xf"])
	car.speed = _checkpoint["speed"]
	lap_time = _checkpoint["lap_time"]
	race_time = _checkpoint["race_time"]
	sector = _checkpoint["sector"]
	splits.assign(_checkpoint["splits"])
	lap_running = _checkpoint["lap_running"]
	_last_off = _checkpoint["off"]
	cam.snap()

func _tap_restart() -> void:
	if GameState.mode == GameState.Mode.CHAMPIONSHIP:
		if GameState.flashbacks <= 0:
			hud.toast("NO FLASHBACKS LEFT", hud.RED, 1.5)
			return
		GameState.flashbacks -= 1
		_restore_checkpoint()
		hud.toast("FLASHBACK  (%d left)" % GameState.flashbacks, hud.GOLD, 1.5)
	else:
		_restore_checkpoint()
		hud.toast("BACK TO CHECKPOINT", hud.GOLD, 1.2)

func _process(delta: float) -> void:
	# R: tap = checkpoint, hold = full restart (no hold restart in Championship)
	var allow_hold := GameState.mode != GameState.Mode.CHAMPIONSHIP
	if Input.is_action_pressed("restart") and not finished:
		_r_hold += delta
		if allow_hold:
			hud.set_restart_progress(clampf((_r_hold - 0.15) / (restart_hold_time - 0.15), 0.0, 1.0))
		if allow_hold and _r_hold >= restart_hold_time and not _r_consumed:
			_r_consumed = true
			restart()
			hud.toast("RACE RESTARTED", hud.GOLD, 1.2)
	else:
		if _r_hold > 0.0 and not _r_consumed:
			_tap_restart()
		_r_hold = 0.0
		_r_consumed = false
		hud.set_restart_progress(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished:
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		GameState.set_state(GameState.State.PAUSED)
		pause_menu.open()
	elif event.is_action_pressed("camera_cycle"):
		_cycle_camera()
	elif event.is_action_pressed("pit_request"):
		_pit_request()
	elif event.is_action_pressed("compound_soft"):
		_set_compound(Tyres.SOFT)
	elif event.is_action_pressed("compound_medium"):
		_set_compound(Tyres.MEDIUM)
	elif event.is_action_pressed("compound_hard"):
		_set_compound(Tyres.HARD)
	elif event.is_action_pressed("compound_inter"):
		_set_compound(Tyres.INTER)
	elif event.is_action_pressed("compound_wet"):
		_set_compound(Tyres.WET)

func _on_resume() -> void:
	get_tree().paused = false
	GameState.set_state(GameState.State.RACE)
	hud.set_units(GameState.speed_unit())  # settings may have changed while paused

func _cycle_camera() -> void:
	var v: int = cam.cycle()
	GameState.settings["camera"] = v  # remember the player's last choice
	GameState.save_settings()
	hud.toast(GameState.CAMERA_NAMES[v] + " CAM", Color.WHITE, 0.9)

# ---------- lap logic ----------

func _physics_process(delta: float) -> void:
	if is_race:
		_race_update(delta)
	if car.global_position.y < -20.0:
		_restore_checkpoint()
		return
	var off: float = track.closest_offset(car.global_position)
	_update_drs(_last_off, off)
	_pit_update(delta, off)
	var d := off - _last_off
	var L: float = track.length
	if d < -L * 0.5:
		_cross_line()
	elif d > L * 0.5:
		sector = -1  # reversed over the line: lap invalid
	elif lap_running and sector >= 0:
		if sector == 0 and off > L / 3.0 and off < L * 0.6:
			_split(0)
		elif sector == 1 and off > L * 2.0 / 3.0:
			_split(1)
	_last_off = off

	# kerb / track-edge shake for the camera
	var center: Vector3 = track.sample_pos(off)
	var right: Vector3 = (track.sample_tangent(off) as Vector3).cross(Vector3.UP).normalized()
	var lat := absf((car.global_position - center).dot(right))
	cam.kerb_shake = clampf(lat - (float(track.HALF_W) - 1.4), 0.0, 1.0) * clampf(absf(car.speed) / 30.0, 0.0, 1.0)
	car.kerb = cam.kerb_shake

	# weather: one wetness value feeds the player, the rivals and the HUD
	if weather:
		car.wetness = weather.wetness_value()
		hud.set_weather(weather.label, car.wetness)
		for ai in ais:
			ai.wetness = car.wetness
	# braking aid: hand the car the corner speed it is approaching so it can shed speed
	if car.brake_assist > 0.0:
		car.target_speed = track.speed_at(off + 45.0)
	else:
		car.target_speed = 0.0
	hud.set_damage(car.damage)
	# continuous audio: tyre scrub follows the car, rain follows the sky
	sfx.set_loop("squeal", car.slip * 0.5)
	sfx.set_loop("rain", car.wetness * 0.35)
	sfx.set_loop("rumble", car.kerb * 0.55)
	_update_tunnel(off)
	_update_safety_car(delta)
	# film material: the session keeps a short trace of the player for the finish replay
	if is_race and race_started and not finished:
		replay.record(race_time, car.global_transform)

	if lap_running and not finished:
		lap_time += delta
		if not is_race:
			race_time += delta  # races time from lights out in _race_update
		_update_delta(off)
		# the gold ghost is the "car ahead" only when there are no AI rivals
		ghost.visible = ais.is_empty()
		if ais.is_empty():
			ghost.place(track, track.offset_at_time(lap_time * track.ideal_time / gold), delta)
			var gap := _gap_to_ghost(off)
			hud.set_gap("GHOST  %s%.2fs" % ["+" if gap >= 0.0 else "-", absf(gap)])
	elif ais.is_empty():
		hud.set_gap("")

	var rpm_ratio := clampf((car.rpm - 4000.0) / 8800.0, 0.0, 1.0)
	hud.set_lap(lap_time, lap_running)
	hud.set_speed(GameState.speed_display(car.kmh()), car.gear, rpm_ratio)
	# screen-edge streaks build from about 55% of top speed and flare on boost
	var fx := clampf((absf(car.speed) / maxf(car.top_speed, 1.0) - 0.55) / 0.45, 0.0, 1.0)
	hud.set_speed_fx(fx, car.boosting)
	hud.set_rev_leds(rpm_ratio)
	hud.set_boost(car.boost, car.boosting)
	hud.set_drs(2 if car.drs_open else (1 if car.drs_available and car.drs_in_zone or car.drs_available else 0))
	hud.set_tyres(car.tyres.wheels, car.tyres.short(), car.tyres.colour(), car.tyres.temp_state())
	# minimap: the player gets a heading chevron, a halo and their position tag; rivals
	# are smaller dots tinted with their team accent
	var p_fwd: Vector3 = -car.global_transform.basis.z
	var dots: Array = [{"pos": car.global_position, "player": true,
		"dir": Vector2(p_fwd.x, p_fwd.z).normalized(), "rank": _player_pos}]
	for ai in ais:
		var a_fwd: Vector3 = -ai.global_transform.basis.z
		var col := Color(0.95, 0.95, 0.98)
		var tm = ai.get_meta("team", null)
		if tm is Dictionary:
			col = tm.get("color", col)
		dots.append({"pos": ai.global_position, "player": false,
			"dir": Vector2(a_fwd.x, a_fwd.z).normalized(), "color": col})
	hud.set_minimap(dots)

# ---------- pit lane and pit stops ----------

## Signed lateral offset of the car from the track centre line (+ = right of travel).
func _lateral(off: float) -> float:
	var center: Vector3 = track.sample_pos(off)
	var right: Vector3 = (track.sample_tangent(off) as Vector3).cross(Vector3.UP).normalized()
	return (car.global_position - center).dot(right)

## Pit limiter, speeding penalty and the stop sequence. Called once per physics frame.
## The limiter only bites when the car is actually in the pit lane beside the track,
## never on the racing line where the same offsets are the start/finish straight.
func _pit_update(delta: float, off: float) -> void:
	var in_lane: bool = track.in_pit_lane(off) and absf(_lateral(off)) > float(track.HALF_W) - 0.5
	car.pit_limiter = in_lane
	if in_lane and not _was_in_lane:
		# entry: the limiter engages automatically; arriving far too fast is a penalty
		if car.kmh() > pit_entry_speed_limit:
			_apply_penalty(pit_time_penalty, "PIT SPEEDING")
		if pit_state == "requested":
			hud.toast("PIT LANE", hud.GOLD, 1.5)
	_was_in_lane = in_lane

	match pit_state:
		"requested":
			# arm the stop, then hold the car in the box while the crew works
			if in_lane and _near_box(off) and car.speed < 25.0:
				pit_state = "stopping"
				car.pit_servicing = true
				pit_timer = randf_range(pit_fast_stop, pit_fast_stop + 1.1)
				if randf() < pit_slow_chance:
					pit_timer = pit_slow_stop
					hud.toast("SLOW STOP!", hud.RED, 2.0)
				hud.set_pit_banner("CREW WORKING  %.1fs" % pit_timer, hud.GREEN)
			elif not in_lane:
				hud.set_pit_banner("BOX THIS LAP  -  1-4 TYRES", hud.GOLD)
		"stopping":
			pit_timer -= delta
			hud.set_pit_banner("CREW WORKING  %.1fs" % maxf(pit_timer, 0.0), hud.GREEN)
			if pit_timer <= 0.0:
				car.pit_servicing = false
				car.service(next_compound)
				sfx.play("clunk", -4.0, 1.1)  # wheel guns off, car drops
				_pit_stops += 1
				pit_state = "done"
				_unlock("pit_crew")
				hud.toast("%s TYRES ON  -  GO GO GO" % Tyres.COMPOUNDS[next_compound]["name"], hud.GREEN, 2.0)
				hud.set_pit_banner("")
		"done":
			if not in_lane:
				pit_state = ""
			else:
				hud.set_pit_banner("PIT EXIT  -  LIMITER ON", hud.SILVER)
		_:
			hud.set_pit_banner("")

func _near_box(off: float) -> bool:
	return fposmod(off - float(track.pit["box"]), track.length) < 16.0

func _apply_penalty(seconds: float, reason: String) -> void:
	lap_time += seconds
	race_time += seconds
	penalties += seconds
	hud.toast("%s  +%.1fs" % [reason, seconds], hud.RED, 2.0)

## P requests a stop for the next lap; pressing it again cancels the request.
func _pit_request() -> void:
	if not is_race or finished:
		return
	if pit_state == "requested":
		pit_state = ""
		hud.set_pit_banner("")
		hud.toast("PIT REQUEST CANCELLED", hud.SILVER, 1.5)
		return
	if pit_state == "":
		pit_state = "requested"
		hud.set_pit_banner("BOX BOX", hud.GOLD)
		hud.toast("BOX THIS LAP  -  %s TYRES" % Tyres.COMPOUNDS[next_compound]["name"], hud.GOLD, 2.0)

## 1-4 pick the tyre compound the next stop will fit.
func _set_compound(c: int) -> void:
	next_compound = clampi(c, 0, Tyres.COMPOUNDS.size() - 1)
	var info: Dictionary = Tyres.COMPOUNDS[next_compound]
	car.model.set_compound_color(info["color"])
	hud.toast("NEXT TYRES:  %s" % info["name"], info["color"], 1.5)

# ---------- race: lights, AI, positions ----------

## Player race distance in metres, on the same scale as ai.distance (negative on the grid).
func _player_progress() -> float:
	var L: float = track.length
	if lap_running:
		return laps_done * L + _last_off
	return _last_off - L if _last_off > L * 0.5 else _last_off

func _race_update(delta: float) -> void:
	if not race_started:
		# five red lights one per interval, then a random pause, then lights out
		_lights_t += delta
		var lit := mini(int(_lights_t / light_interval), 5)
		if lit != _last_beep and lit < 5:
			_last_beep = lit
			sfx.play("beep", -6.0)
		hud.set_start_lights(lit)
		if _lights_t >= light_interval * 5.0 + _go_delay:
			race_started = true
			race_time = 0.0
			car.controls_enabled = true
			for ai in ais:
				ai.racing = true
			hud.set_start_lights(-1)
			sfx.play("beep_go", -3.0)
			_last_beep = -1
			hud.toast("LIGHTS OUT AND AWAY WE GO", Color.WHITE, 2.0)
	elif not finished:
		race_time += delta
	# player lateral offset across the track (for AI traffic awareness)
	var off := _last_off
	var right: Vector3 = (track.sample_tangent(off) as Vector3).cross(Vector3.UP).normalized()
	_player_lat = (car.global_position - (track.sample_pos(off) as Vector3)).dot(right)
	var others: Array = [{"node": car, "d": _player_progress(), "lat": _player_lat, "speed": car.speed}]
	for ai in ais:
		others.append({"node": ai, "d": ai.distance, "lat": ai.lateral, "speed": ai.speed})
	var L: float = track.length
	for ai in ais:
		ai.drive(delta, others)
		if race_started and not ai.finished and ai.distance >= total_laps * L:
			ai.finished = true
			ai.finish_time = race_time
	if ais.is_empty():
		return
	var order := _standings()
	var lines := ""
	for i in order.size():
		var e: Dictionary = order[i]
		if e["player"]:
			_player_pos = i + 1
		if i < 10:
			lines += ("> " if e["player"] else "   ") + "%d  %s\n" % [i + 1, e["name"]]
	hud.set_race_info(_player_pos, order.size(), lines)
	var gap := _gap_ahead()
	hud.set_gap("CAR AHEAD  +%.2fs" % gap if gap > 0.0 else "LEADING")

## Everyone sorted by race distance (finished cars first, in finishing order).
func _standings() -> Array:
	var L: float = track.length
	var list: Array = [{"name": "YOU", "player": true, "node": car,
		"score": total_laps * L + 1.0e6 - race_time if finished else _player_progress()}]
	for ai in ais:
		var score: float = total_laps * L + 1.0e6 - float(ai.finish_time) if ai.finished else float(ai.distance)
		list.append({"name": "%s #%d" % [ai.driver, int(ai.team.get("number", 0))], "player": false, "node": ai, "score": score})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return list

## Seconds to the nearest AI car ahead on the road (0 when nobody is ahead).
func _gap_ahead() -> float:
	var me := _player_progress()
	var best := INF
	for ai in ais:
		var d: float = float(ai.distance) - me
		if d > 0.0 and d < best:
			best = d
	if best == INF:
		return 0.0
	return best / maxf(absf(car.speed), 10.0)

# ---------- DRS ----------

## True when travelling forward from prev to cur passes the offset p (handles the lap wrap).
func _passed(prev: float, cur: float, p: float) -> bool:
	var L: float = track.length
	if cur >= prev and cur - prev < L * 0.5:
		return p > prev and p <= cur
	if prev - cur > L * 0.5:  # wrapped over the line
		return p > prev or p <= cur
	return false

func _in_zone(off: float, z: Dictionary) -> bool:
	var s: float = z["start"]
	var e: float = z["end"]
	return off >= s and off <= e if s <= e else (off >= s or off <= e)

## Seconds the player is behind the gold ghost at this offset (positive = ghost ahead).
func _gap_to_ghost(off: float) -> float:
	return lap_time - track.time_at_offset(off) * gold / track.ideal_time

func _drs_eligible(off: float) -> bool:
	if not is_race:
		return true  # time trial runs qualifying rules: DRS free in every zone
	if laps_done < drs_from_lap or not lap_running:
		return false
	var gap := _gap_to_ghost(off) if ais.is_empty() else _gap_ahead()
	return gap > 0.0 and gap <= drs_gap

func _update_drs(prev: float, off: float) -> void:
	var in_zone := false
	for z in track.drs_zones:
		if _passed(prev, off, z["detect"]):
			car.drs_available = _drs_eligible(off)
			if is_race and car.drs_available:
				hud.toast("DRS ENABLED", hud.GREEN, 1.2)
		if _in_zone(off, z):
			in_zone = true
	if _drs_was_in_zone and not in_zone:
		car.drs_available = false  # used up at the end of the zone
	_drs_was_in_zone = in_zone
	car.drs_in_zone = in_zone

# ---------- live delta ----------

func _update_delta(off: float) -> void:
	var b := int(off / delta_bucket)
	if b == _last_bucket or b < 0 or b >= _cur_trace.size():
		return
	_last_bucket = b
	_cur_trace[b] = lap_time
	var has_ref := b < _best_trace.size() and _best_trace[b] >= 0.0
	hud.set_delta(lap_time - (_best_trace[b] if has_ref else 0.0), has_ref)

func _split(idx: int) -> void:
	var prev := 0.0
	for s in splits:
		prev += s
	var t := lap_time - prev
	splits.append(t)
	var has_ref := best_splits.size() > idx
	hud.set_split(idx, t, t - best_splits[idx] if has_ref else 0.0, has_ref)
	sector = idx + 1
	_save_checkpoint()

func _cross_line() -> void:
	# a completed lap can bring the safety car out for a few neutralised laps
	if is_race and race_started and not finished and not safety_active and laps_done >= 1:
		if randf() < safety_car_chance:
			_deploy_safety_car()
	# qualifying: a clean lap goes to the championship grid, anything else restarts it
	if is_qualifying:
		if not lap_running:
			_start_lap()  # out lap: crossing the line starts the flying lap
		elif sector == 2:
			_finish_qualifying(lap_time)
		else:
			hud.toast("LAP INVALID  -  TRY AGAIN", hud.RED, 2.0)
			_start_lap()
		return
	if lap_running and sector == 2:
		_split(2)
		_finish_lap()
		if is_race:
			laps_done += 1
			if laps_done >= total_laps:
				_finish_race()
				return
			hud.set_lap_count(laps_done + 1, total_laps)
	elif lap_running:
		hud.toast("LAP INVALID", hud.RED)
	_start_lap()

func _start_lap() -> void:
	lap_running = true
	lap_time = 0.0
	sector = 0
	splits.clear()
	hud.clear_splits()
	_cur_trace = PackedFloat32Array()
	_cur_trace.resize(int(track.length / delta_bucket) + 1)
	_cur_trace.fill(-1.0)
	_last_bucket = -1
	_save_checkpoint()

## Local achievement: toasted once, the first time it is earned.
func _unlock(id: String) -> void:
	if Achievements.unlock(id):
		hud.toast("ACHIEVEMENT  %s" % Achievements.title(id), hud.PURPLE, 3.0)

func _finish_lap() -> void:
	var t := lap_time
	if t < 1.0e9:
		_unlock("first_lap")
		if t <= gold:
			_unlock("gold_lap")
		if penalties <= 0.01:
			_unlock("clean_lap")
		if car.wetness > 0.5:
			_unlock("rain_driver")
	var medal := "NO MEDAL"
	var col: Color = Color.WHITE
	if t <= gold:
		medal = "GOLD - GHOST BEATEN"
		col = hud.GOLD
	elif t <= silver:
		medal = "SILVER"
		col = hud.SILVER
	elif t <= bronze:
		medal = "BRONZE"
		col = hud.BRONZE
	var msg: String = "%s   %s" % [hud.fmt(t), medal]
	if t < best_lap:
		best_lap = t
		best_splits = splits.duplicate()
		_best_trace = _cur_trace.duplicate()
		hud.set_best(t)
		msg += "\nNEW BEST LAP"
		col = hud.PURPLE if medal == "NO MEDAL" else col
	if not is_race:
		# time trial: every completed lap is a leaderboard entry for this circuit
		var res := Leaderboard.submit(String(GameState.track()["id"]), "time_trial", t,
			String(GameState.config.get("player_name", "DRIVER")), String(GameState.team()["name"]),
			String(GameState.DIFFICULTIES[clampi(int(GameState.config["difficulty"]), 0, 2)]), 1)
		if not res.is_empty() and int(res["rank"]) > 0:
			msg += "\nLEADERBOARD  P%d" % int(res["rank"])
	hud.toast(msg, col, 4.0)
	# a new best gets the brighter three-note chime, a normal lap the two-note one
	sfx.play("best" if t <= best_lap + 0.0001 else "lap", -3.0)

func _finish_race() -> void:
	finished = true
	lap_running = false
	car.controls_enabled = false
	GameState.set_state(GameState.State.RESULTS)
	hud.toast("CHEQUERED FLAG", Color.WHITE, 2.0)
	sfx.play("finish", -2.0)
	# film the closing seconds from an orbiting camera before the results card
	if replay.has_data():
		car.model.visible = false
		replay.start(finish_replay_seconds)
		await get_tree().create_timer(finish_replay_seconds).timeout
		replay.stop()
		car.model.visible = true
		cam.make_current()
	await get_tree().create_timer(results_delay).timeout
	var body := "%s  -  %d laps\n\n" % [GameState.TRACKS[int(GameState.config["track"])]["name"], total_laps]
	var order := _standings()
	var finish_pos := 1
	for i in order.size():
		if (order[i] as Dictionary).get("player", false):
			finish_pos = i + 1
			break
	if finish_pos == 1:
		_unlock("first_win")
		if is_championship:
			_unlock("champion")
	if finish_pos <= 3:
		_unlock("podium")
	if car.wetness > 0.5:
		_unlock("rain_driver")
	var L: float = track.length
	for i in order.size():
		var e: Dictionary = order[i]
		var t: float
		if e["player"]:
			t = race_time
		elif e["node"].finished:
			t = e["node"].finish_time
		else:  # estimate the finish from remaining distance at current pace
			var ai = e["node"]
			t = race_time + (total_laps * L - float(ai.distance)) / maxf(float(ai.speed), 40.0)
		body += "P%-3d %-16s %s\n" % [i + 1, e["name"], hud.fmt(t)]
	body += "\nYour best lap   %s\nPenalties        +%.1fs" % [hud.fmt(best_lap), penalties]
	# the finishing time goes to the local board: championship rounds get their own tab
	var mode_key := "championship" if GameState.mode == GameState.Mode.CHAMPIONSHIP else "race"
	var saved := Leaderboard.submit(String(GameState.track()["id"]), mode_key, race_time,
		String(GameState.config.get("player_name", "DRIVER")), String(GameState.team()["name"]),
		String(GameState.DIFFICULTIES[clampi(int(GameState.config["difficulty"]), 0, 2)]), total_laps)
	if not saved.is_empty() and int(saved["rank"]) > 0:
		body += "\n%s board   P%d / 10" % ["CHAMPIONSHIP" if mode_key == "championship" else "RACE", int(saved["rank"])]
	# championship: award round points and show where the season stands
	var keys: Array = []
	for e in order:
		keys.append(_entry_key(e["node"]))
	if is_championship and not _round_recorded:
		_round_recorded = true
		Championship.complete_round(keys)
		body += "\nROUND POINTS\n"
		for i in keys.size():
			var pts: int = int(Championship.POINTS[i]) if i < Championship.POINTS.size() else 0
			body += "P%-3d %-16s %2d pts\n" % [i + 1, String(keys[i]), pts]
		body += "\nSeason   P%d   %d pts" % [Championship.player_position(), Championship.player_points()]
	get_tree().paused = true
	pause_menu.show_results("RACE COMPLETE", body, is_championship)

## Championship only: the results card's continue button opens the season standings.
func _on_round_continue() -> void:
	if standings != null:
		return
	standings = StandingsScreen.new()
	add_child(standings)
	standings.continue_pressed.connect(_on_next_round)
	standings.close_pressed.connect(func() -> void:
		get_tree().paused = false
		GameState.go_to_menu())

func _on_next_round() -> void:
	get_tree().paused = false
	if Championship.finished:
		GameState.go_to_menu()
		return
	Championship.start_next_round()

func _on_wall_hit(impact: float) -> void:
	if not lap_running or finished:
		return
	var pen := 1.0 if impact > 25.0 else 0.5
	lap_time += pen
	race_time += pen
	penalties += pen
	# pitch falls with the hit so a light graze ticks and a big one thuds
	sfx.play("impact", -2.0, clampf(1.25 - impact / 60.0, 0.7, 1.2))
	hud.toast("BARRIER  +%.1fs" % pen, hud.RED, 1.2)
	# harder hits sound deeper and louder, so the size of the mistake is audible
	var loud := clampf(impact / 40.0, 0.0, 1.0)
	sfx.play("impact", lerpf(-10.0, -1.0, loud), lerpf(1.25, 0.85, loud))
