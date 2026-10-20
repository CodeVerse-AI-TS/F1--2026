extends Node3D
## Cinematic replay of the closing seconds of a race.
## The session records the player transform a few times a second; at the chequered
## flag this node hides the real car, walks a matching model through the samples
## and films it with its own orbiting camera.

const CarModelScript = preload("res://scripts/car_model.gd")

@export var sample_hz := 20.0        # recording rate
@export var orbit_distance := 13.0   # metres the replay camera sits from the car
@export var orbit_height := 4.5
@export var orbit_speed := 0.12      # full orbits per second

var model: Node3D
var camera: Camera3D
var samples: Array = []
var playing := false
var _t := 0.0
var _last_sample_t := -999.0
var _last_t := 0.0

func _ready() -> void:
	model = CarModelScript.new()
	add_child(model)
	model.visible = false
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.2
	add_child(camera)

## Match the player's livery so the replay car looks like the one that just raced.
func set_livery(team: Dictionary) -> void:
	if model and model.has_method("set_livery"):
		model.set_livery(team)

func clear() -> void:
	samples.clear()
	_last_sample_t = -999.0
	_last_t = 0.0

## t is the race clock in seconds; samples are thinned to sample_hz.
func record(t: float, xf: Transform3D) -> void:
	if t - _last_sample_t < 1.0 / maxf(sample_hz, 1.0):
		return
	_last_sample_t = t
	samples.append({"t": t, "xf": xf})
	# a long race must not grow without bound: keep the most recent stretch
	while samples.size() > 40000:
		samples.pop_front()

func has_data() -> bool:
	return samples.size() > 4

## Rewind `seconds` from the newest sample and start filming.
func start(seconds: float) -> void:
	if not has_data():
		return
	_last_t = float((samples[samples.size() - 1] as Dictionary)["t"])
	var first_t: float = float((samples[0] as Dictionary)["t"])
	_t = maxf(_last_t - seconds, first_t)
	playing = true
	model.visible = true
	camera.make_current()

func stop() -> void:
	playing = false
	model.visible = false

func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	var xf := _transform_at(_t)
	model.global_transform = xf
	var target := xf.origin + Vector3(0.0, 1.1, 0.0)
	var ang := _t * orbit_speed * TAU
	camera.global_position = target + Vector3(cos(ang) * orbit_distance, orbit_height, sin(ang) * orbit_distance)
	camera.look_at(target, Vector3.UP)
	if _t > _last_t + 0.8:
		stop()

## Interpolated transform at time t from the recorded samples.
func _transform_at(t: float) -> Transform3D:
	var n := samples.size()
	if n == 0:
		return Transform3D()
	if t <= float((samples[0] as Dictionary)["t"]):
		return (samples[0] as Dictionary)["xf"]
	for i in range(n - 1, -1, -1):
		var a: Dictionary = samples[i]
		if float(a["t"]) <= t:
			if i >= n - 1:
				return a["xf"]
			var b: Dictionary = samples[i + 1]
			var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var w := clampf((t - float(a["t"])) / span, 0.0, 1.0)
			var xa: Transform3D = a["xf"]
			var xb: Transform3D = b["xf"]
			var out := xa
			out.origin = xa.origin.lerp(xb.origin, w)
			out.basis = xa.basis.slerp(xb.basis, w)
			return out
	return samples[n - 1]["xf"]
