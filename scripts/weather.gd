extends Node3D
## Dynamic weather: dry, damp, light rain and heavy rain.
## The session feeds `wetness` into the car tyres and the AI pace, and this node
## owns the rain particles and the atmosphere change so the sky matches the grip.

signal changed(label: String, wetness: float)

enum Mode { DRY, CHANGEABLE, WET }

const LABELS := ["DRY", "DAMP", "LIGHT RAIN", "HEAVY RAIN"]

@export var mode := Mode.CHANGEABLE
@export var change_min := 35.0          # seconds between weather rolls in changeable mode
@export var change_max := 70.0
@export var transition_rate := 0.09     # wetness units per second
@export var heavy_wetness := 0.95

var wetness := 0.0
var target := 0.0
var label := "DRY"

var _timer := 0.0
var _light_rain: CPUParticles3D
var _heavy_rain: CPUParticles3D
var _camera: Camera3D
var _env: Environment
var _base_ambient := 1.0
var _base_fog := 0.0
var _base_fog_enabled := false
var _base_vfog := 0.0
var _announced := ""

func _ready() -> void:
	_build_rain()

## Called by the session right after the node is added. p_mode: 0 dry, 1 changeable, 2 wet.
func setup(p_mode: int, p_camera: Camera3D) -> void:
	mode = clampi(p_mode, 0, 2)
	_camera = p_camera
	match mode:
		Mode.DRY:
			wetness = 0.0
			target = 0.0
			_timer = INF
		Mode.WET:
			wetness = 0.8
			target = heavy_wetness
			_timer = INF
		_:
			wetness = 0.0
			target = 0.0
			_timer = randf_range(change_min, change_max)
	label = _label_for(wetness)
	_announced = label

func _build_rain() -> void:
	# Two emitters so light and heavy rain have different densities without
	# restarting the particle system every frame.
	_light_rain = _make_emitter(700, 0.035)
	_heavy_rain = _make_emitter(1600, 0.045)
	_light_rain.emitting = false
	_heavy_rain.emitting = false

func _make_emitter(count: int, thickness: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = 1.1
	p.preprocess = 1.0
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(34, 9, 34)
	p.direction = Vector3(0, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 26.0
	p.initial_velocity_max = 34.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.35
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, 0.75, thickness)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.8, 0.92, 0.5)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	p.mesh = mesh
	p.visible = false
	add_child(p)
	return p

func _process(delta: float) -> void:
	_update_weather(delta)
	if _camera:
		# rain box centred a little above and around the camera
		global_position = _camera.global_position + Vector3(0, 10.0, 0)
	_apply_atmosphere()
	var light_on := wetness > 0.1
	var heavy_on := wetness > 0.55
	if _light_rain:
		_light_rain.visible = light_on
		_light_rain.emitting = light_on
	if _heavy_rain:
		_heavy_rain.visible = heavy_on
		_heavy_rain.emitting = heavy_on
	label = _label_for(wetness)
	if label != _announced:
		_announced = label
		changed.emit(label, wetness)

func _update_weather(delta: float) -> void:
	if mode == Mode.CHANGEABLE:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(change_min, change_max)
			target = _roll_target()
	wetness = move_toward(wetness, target, transition_rate * delta)

## Pick the next condition: mostly dry starts, rain builds and clears in stages.
func _roll_target() -> float:
	var roll := randf()
	if wetness < 0.2:
		return 0.0 if roll < 0.45 else (0.45 if roll < 0.82 else 0.9)
	if wetness < 0.7:
		return 0.0 if roll < 0.4 else (0.9 if roll < 0.7 else 0.45)
	return 0.0 if roll < 0.35 else (0.45 if roll < 0.8 else 0.9)

func _label_for(w: float) -> String:
	if w < 0.08:
		return LABELS[0]
	if w < 0.35:
		return LABELS[1]
	if w < 0.72:
		return LABELS[2]
	return LABELS[3]

func _apply_atmosphere() -> void:
	if _env == null:
		var world := get_viewport().world_3d
		if world == null or world.environment == null:
			return
		_env = world.environment
		_base_ambient = _env.ambient_light_energy
		_base_fog = _env.fog_density
		_base_fog_enabled = _env.fog_enabled
		_base_vfog = _env.volumetric_fog_density
	var w := clampf(wetness, 0.0, 1.0)
	_env.ambient_light_energy = _base_ambient * lerpf(1.0, 0.62, w)
	# thicken the haze as the rain arrives and restore it exactly when it clears
	_env.fog_enabled = _base_fog_enabled or w > 0.05
	_env.fog_density = maxf(_base_fog, lerpf(_base_fog, 0.018, w))
	if _env.volumetric_fog_enabled:
		_env.volumetric_fog_density = maxf(_base_vfog, lerpf(_base_vfog, 0.03, w))

## 0 dry .. 1 heavy rain; the session copies this into the cars and tyres.
func wetness_value() -> float:
	return wetness
