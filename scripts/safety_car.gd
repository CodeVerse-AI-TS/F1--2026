extends Node3D
## Safety car: circulates at a fixed pace while the race is neutralised.
## The session deploys and retires it; it only owns its own pace and lights.

const CarModelScript = preload("res://scripts/car_model.gd")

@export var pace := 26.0          # m/s, roughly 95 km/h
@export var flash_rate := 3.0     # amber roof light flashes per second

var track: Node3D
var distance := 0.0
var active := false
var model: Node3D

var _flash := 0.0
var _light_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	model = CarModelScript.new()
	add_child(model)
	model.set_livery({
		"name": "Safety Car",
		"color": Color(0.72, 0.74, 0.78),
		"secondary": Color(0.08, 0.08, 0.1),
		"accent": Color(1.0, 0.62, 0.12),
		"sponsor": "SC",
		"number": 0,
	})
	_build_lights()
	visible = false
	set_process(false)

func setup(p_track: Node3D) -> void:
	track = p_track
	if track:
		_place()

func deploy(from_offset: float) -> void:
	if track == null:
		return
	active = true
	distance = from_offset
	visible = true
	set_process(true)
	_place()

func retire() -> void:
	active = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not active:
		return
	distance += pace * delta
	_place()
	_flash += delta * flash_rate
	var on := int(_flash) % 2 == 0
	for m in _light_mats:
		m.emission_energy_multiplier = 5.0 if on else 0.4

func _place() -> void:
	if track == null:
		return
	global_transform = track.get_xform(fposmod(distance, track.length))

func _build_lights() -> void:
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.55, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.05)
		mat.emission_energy_multiplier = 0.4
		mi.material_override = mat
		mi.position = Vector3(0.22 * side, 1.02, 0.15)
		model.add_child(mi)
		_light_mats.append(mat)
