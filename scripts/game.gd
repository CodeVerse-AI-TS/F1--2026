extends Node3D
## Session rules for the race scene.
## Time Trial: flying laps vs the gold ghost. Quick Race: N timed laps, then results.
## R tap = back to last checkpoint (flashback in Championship), hold R = restart race,
## C = cycle camera, Esc = pause menu.

const START_BACK := 90.0
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const GameState = preload("res://scripts/game_state.gd")

@export var restart_hold_time := 1.0
@export var results_delay := 1.5
@export var drs_gap := 1.0            # seconds to the car ahead at detection to earn DRS
@export var drs_from_lap := 1         # race laps completed before DRS is enabled
@export var delta_bucket := 10.0      # metres between live-delta samples

@onready var track = $Track
@onready var car: CharacterBody3D = $Car
@onready var cam: Camera3D = $ChaseCamera
@onready var ghost: Node3D = $Ghost
@onready var hud = $HUD

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

func _ready() -> void:
	GameState.ensure_init()
	is_race = GameState.mode != GameState.Mode.TIME_TRIAL
	total_laps = int(GameState.config["laps"]) if is_race else 0
	gold = track.ideal_time * 1.04
	silver = track.ideal_time * 1.12
	bronze = track.ideal_time * 1.25
	hud.set_targets(gold, silver, bronze)
	hud.set_units(GameState.speed_unit())
	var team: Dictionary = GameState.team()
	car.model.set_livery(team)
	car.wall_hit.connect(_on_wall_hit)
	cam.set_view(int(GameState.settings["camera"]), true)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.restart_pressed.connect(func() -> void: _on_resume(); restart())
	pause_menu.camera_pressed.connect(_cycle_camera)
	restart()

## Full restart of the session (race or time trial).
func restart() -> void:
	car.reset_to(track.get_xform(track.length - START_BACK))
	car.controls_enabled = true
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
	if car.global_position.y < -20.0:
		_restore_checkpoint()
		return
	var off: float = track.closest_offset(car.global_position)
	_update_drs(_last_off, off)
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

	if lap_running and not finished:
		lap_time += delta
		race_time += delta
		# the gold ghost is the "car ahead" until AI rivals arrive
		ghost.visible = true
		ghost.place(track, track.offset_at_time(lap_time * track.ideal_time / gold), delta)
		_update_delta(off)
		var gap := _gap_to_ghost(off)
		hud.set_gap("GHOST  %s%.2fs" % ["+" if gap >= 0.0 else "-", absf(gap)])
	else:
		hud.set_gap("")

	var rpm_ratio := clampf((car.rpm - 4000.0) / 8800.0, 0.0, 1.0)
	hud.set_lap(lap_time, lap_running)
	hud.set_speed(GameState.speed_display(car.kmh()), car.gear, rpm_ratio)
	hud.set_rev_leds(rpm_ratio)
	hud.set_boost(car.boost, car.boosting)
	hud.set_drs(2 if car.drs_open else (1 if car.drs_available and car.drs_in_zone or car.drs_available else 0))

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
	var gap := _gap_to_ghost(off)
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

func _finish_lap() -> void:
	var t := lap_time
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
	hud.toast(msg, col, 4.0)

func _finish_race() -> void:
	finished = true
	lap_running = false
	car.controls_enabled = false
	GameState.set_state(GameState.State.RESULTS)
	hud.toast("CHEQUERED FLAG", Color.WHITE, 2.0)
	await get_tree().create_timer(results_delay).timeout
	var body := "%s  -  %d laps\n\nTotal time    %s\nBest lap       %s\nPenalties      +%.1fs" % [
		GameState.TRACKS[int(GameState.config["track"])]["name"], total_laps,
		hud.fmt(race_time), hud.fmt(best_lap), penalties]
	get_tree().paused = true
	pause_menu.show_results("RACE COMPLETE", body)

func _on_wall_hit(impact: float) -> void:
	if not lap_running or finished:
		return
	var pen := 1.0 if impact > 25.0 else 0.5
	lap_time += pen
	race_time += pen
	penalties += pen
	hud.toast("BARRIER  +%.1fs" % pen, hud.RED, 1.2)
